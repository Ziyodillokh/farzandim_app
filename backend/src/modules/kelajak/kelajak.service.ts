// ─────────────────────────────────────────────────────────────────────
// Parvoz Kelajak — bola sessiyalari (docs/KELAJAK-REJA.md §3–§4)
// ─────────────────────────────────────────────────────────────────────
//
// Har test turi Toshkent kuni bo'yicha kuniga BITTA sessiya: POST bugungi
// sessiyani qaytaradi (yangi, davom etayotgan yoki yakunlangan). Yosh
// qat'iy (`?? 8` yo'q) — boshqa guruhning savoli hech qachon tushmaydi.
// Javob sessiya ochiq ekan o'zgartiriladi ("orqaga"); o'tgan kunda
// boshlangan ochiq sessiya qaysi endpoint chaqirilmasin ABANDONED bo'ladi.
// Ochiq matn SchoolCryptoService bilan shifrlanadi (kalit yo'q bo'lsa ochiq
// savollar tanlanmaydi). Bola bo'yicha advisory lock — boshlash / javob /
// yakunlash navbat bilan, yakunlash idempotent.

import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { KelajakSession, KelajakSessionStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { SchoolCryptoService } from '../../school/common/school-crypto.service';
import { KelajakAge, KelajakAgeGroup, resolveKelajakAge } from './domain/age';
import { decideAnswer } from './domain/answer';
import {
  isKelajakTestType,
  KELAJAK_TESTS,
  KelajakTestType,
  TEXT_ANSWER_TYPE,
  testCategories,
} from './domain/catalog';
import { kelajakSeed, pickKelajakQuestions } from './domain/picker';
import { buildSessionResult } from './domain/profile';
import { ProfileSession, SCORING_VERSION, toScoredItems } from './domain/scoring';
import { KelajakAnswerDto } from './dto/kelajak.dto';
import {
  closeStaleSessions,
  Db,
  isOpenStatus,
  isStaleOpen,
  loadActivityLabel,
  loadAnswerHistory,
  loadChildAge,
  loadKelajakProfile,
  lockChild,
  lockQuestionForAnswer,
  questionsInOrder,
} from './kelajak.loader';
import { activityLabeler, parseStoredResult, toSessionView } from './kelajak.mapper';
import { AnswerView, SessionAnswerView, SessionView } from './kelajak.views';

const AGE_ERRORS: Readonly<Record<Exclude<KelajakAge['status'], 'OK'>, string>> = {
  AGE_REQUIRED: 'Child age or birth date is required',
  AGE_OUT_OF_RANGE: 'Kelajak tests are available for ages 7–18',
};

const sessionClosed = () => new ConflictException({ message: 'Session is closed', code: 'SESSION_CLOSED' });
const notInSession = () =>
  new BadRequestException({ message: 'Question is not part of this session', code: 'QUESTION_NOT_IN_SESSION' });

/** Tranzaksiya natijasi: o'tgan kungi sessiya yopildi (xato tranzaksiyadan KEYIN — yopilish saqlansin). */
type Outcome<T> = { closed: true } | { closed: false; value: T };

@Injectable()
export class KelajakService {
  private readonly logger = new Logger(KelajakService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: SchoolCryptoService,
  ) {}

  /** Test uchun almashtiriladi. */
  protected now(): Date {
    return new Date();
  }

  // ── Kirish ─────────────────────────────────────────────────────────

  /** CHILD token egasining `Child.id`si. */
  async childIdForUser(userId: string): Promise<string> {
    const child = await this.prisma.child.findUnique({ where: { childUserId: userId }, select: { id: true } });
    if (!child) throw new ForbiddenException('Child profile required');
    return child.id;
  }

  /** Ota-ona shu bolaning egasi — aks holda 404 / 403. */
  async assertParentOwns(parentUserId: string, childId: string): Promise<void> {
    const child = await this.prisma.child.findUnique({ where: { id: childId }, select: { parentId: true } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== parentUserId) throw new ForbiddenException('Forbidden');
  }

  // ── Sessiyalar ─────────────────────────────────────────────────────

  /** Bugungi sessiya: yangi, davom etayotgan yoki yakunlangan (refresh xavfsiz). */
  async startSession(childId: string, rawType: string): Promise<SessionView> {
    if (!isKelajakTestType(rawType)) {
      throw new BadRequestException({ message: 'Unknown test type', code: 'UNKNOWN_TYPE' });
    }
    const type = rawType;
    const now = this.now();
    const today = tashkentDay(now);

    const sessionId = await this.prisma.$transaction(async (tx) => {
      await lockChild(tx, childId);
      const age = resolveKelajakAge(await loadChildAge(tx, childId), today);
      if (age.status !== 'OK' || !age.ageGroup) {
        const code = age.status === 'OK' ? 'AGE_OUT_OF_RANGE' : age.status;
        throw new ConflictException({ message: AGE_ERRORS[code], code });
      }

      // O'tgan kunlarda yakunlanmay qolgan sessiyalar yopiladi.
      await closeStaleSessions(tx, childId, today);
      const existing = await tx.kelajakSession.findFirst({
        where: { childId, type, day: today, status: { not: KelajakSessionStatus.ABANDONED } },
        orderBy: { startedAt: 'desc' },
      });
      if (existing && (existing.status === KelajakSessionStatus.COMPLETED || existing.ageGroup === age.ageGroup)) {
        return existing.id;
      }
      // Kun ichida yosh guruhi o'zgargan (sana tahrirlangan) — eski guruh savollari aralashmasin.
      if (existing) {
        await tx.kelajakSession.update({ where: { id: existing.id }, data: { status: KelajakSessionStatus.ABANDONED } });
      }

      const questionIds = await this.pickForChild(tx, { childId, type, ageGroup: age.ageGroup, today });
      if (questionIds.length === 0) {
        throw new NotFoundException({ message: 'No questions for this test yet', code: 'NO_QUESTIONS' });
      }
      const created = await tx.kelajakSession.create({
        data: { childId, type, ageGroup: age.ageGroup, day: today, questionIds, total: questionIds.length, startedAt: now },
        select: { id: true },
      });
      return created.id;
    });

    return this.sessionView(childId, sessionId);
  }

  async sessionView(childId: string, sessionId: string): Promise<SessionView> {
    // O'tgan kundagi ochiq sessiya ko'rishda ham yopiq (ABANDONED) chiqsin.
    await closeStaleSessions(this.prisma, childId, tashkentDay(this.now()));
    const session = await ownSession(this.prisma, childId, sessionId);
    // Ochiq matn faqat ochiq sessiyada ochiladi (yopiqda u qaytarilmaydi).
    const open = isOpenStatus(session.status);
    const [questions, answers] = await Promise.all([
      questionsInOrder(this.prisma, session.questionIds),
      this.prisma.kelajakAnswer.findMany({
        where: { sessionId },
        orderBy: { position: 'asc' },
        select: { questionId: true, value: true, textEnc: true },
      }),
    ]);
    const result = session.status === KelajakSessionStatus.COMPLETED ? parseStoredResult(session.result) : null;
    const label = result ? await loadActivityLabel(this.prisma, [result.insightCodes]) : activityLabeler(new Map());
    return toSessionView({
      session,
      questions,
      answers: answers.map((a) => ({
        questionId: a.questionId,
        value: a.value,
        text: open ? this.decryptText(a.textEnc) : null,
      })),
      label,
    });
  }

  /** Javobni saqlash / o'zgartirish (`text: ""` — o'chirish); faqat bugungi ochiq sessiyada. */
  async answer(childId: string, sessionId: string, questionId: string, dto: KelajakAnswerDto): Promise<AnswerView> {
    const now = this.now();
    const today = tashkentDay(now);
    const outcome = await this.prisma.$transaction(async (tx): Promise<Outcome<AnswerView>> => {
      await lockChild(tx, childId);
      const session = await ownSession(tx, childId, sessionId);
      if (isStaleOpen(session, today)) {
        await abandon(tx, session.id);
        return { closed: true };
      }
      if (!isOpenStatus(session.status)) throw sessionClosed();
      const position = session.questionIds.indexOf(questionId);
      if (position < 0) throw notInSession();
      const question = await lockQuestionForAnswer(tx, questionId);
      // Himoya: savol boshqa yosh guruhiga o'tkazilgan bo'lsa — bu sessiyaniki emas.
      if (!question || question.ageGroup !== session.ageGroup) throw notInSession();
      const decision = decideAnswer(
        { answerType: question.answerType, options: question.options as unknown as Array<{ value: number }> },
        dto,
      );
      if (!decision.ok) throw new BadRequestException({ message: decision.error, code: 'INVALID_ANSWER' });

      const stored: SessionAnswerView =
        decision.kind === 'clear'
          ? { questionId, value: null, text: null }
          : {
              questionId,
              value: decision.kind === 'value' ? decision.value : null,
              text: decision.kind === 'text' ? decision.text : null,
            };
      if (decision.kind === 'clear') {
        await tx.kelajakAnswer.deleteMany({ where: { sessionId, questionId } });
      } else {
        const data = { value: stored.value, textEnc: stored.text === null ? null : this.crypto.encrypt(stored.text) };
        await tx.kelajakAnswer.upsert({
          where: { sessionId_questionId: { sessionId, questionId } },
          create: { sessionId, questionId, position, answeredAt: now, ...data },
          update: { answeredAt: now, ...data },
        });
      }

      const startsProgress = decision.kind !== 'clear' && session.status === KelajakSessionStatus.STARTED;
      if (startsProgress) {
        await tx.kelajakSession.update({ where: { id: sessionId }, data: { status: KelajakSessionStatus.IN_PROGRESS } });
      }
      return {
        closed: false,
        value: {
          ...stored,
          sessionStatus: startsProgress ? KelajakSessionStatus.IN_PROGRESS : session.status,
          answeredCount: await tx.kelajakAnswer.count({ where: { sessionId } }),
        },
      };
    });
    if (outcome.closed) throw sessionClosed();
    return outcome.value;
  }

  /**
   * Yakunlash — natija (kodlar va ballar) bir marta yoziladi; qayta chaqiruv
   * shu natijani qaytaradi. Majburiy savollar va kamida bitta javob kerak.
   */
  async complete(childId: string, sessionId: string): Promise<SessionView> {
    const now = this.now();
    const today = tashkentDay(now);
    const outcome = await this.prisma.$transaction(async (tx): Promise<Outcome<null>> => {
      await lockChild(tx, childId);
      const session = await ownSession(tx, childId, sessionId);
      if (session.status === KelajakSessionStatus.COMPLETED) return { closed: false, value: null };
      if (isStaleOpen(session, today)) {
        await abandon(tx, session.id);
        return { closed: true };
      }
      if (session.status === KelajakSessionStatus.ABANDONED) throw sessionClosed();

      const answers = await tx.kelajakAnswer.findMany({
        where: { sessionId },
        select: { questionId: true, value: true, answeredAt: true },
      });
      const answered = new Set(answers.map((a) => a.questionId));
      const questions = await questionsInOrder(tx, session.questionIds);
      const required = questions.filter((q) => q.required && !answered.has(q.id)).map((q) => q.id);
      // Faqat ixtiyoriy savolli test (Career Lab, ochiq fikr) ham bo'sh holda yakunlanmaydi.
      const remaining = required.length === 0 && answers.length === 0 ? questions.map((q) => q.id) : required;
      if (remaining.length > 0) {
        throw new BadRequestException({ message: 'Not all required questions are answered', code: 'UNANSWERED', remaining });
      }

      const current: ProfileSession = { id: session.id, type: session.type, day: session.day, completedAt: now, answers };
      const loaded = await loadKelajakProfile(tx, { childId, ageGroup: session.ageGroup, now, current });
      const result = buildSessionResult(toScoredItems(answers, loaded.questions), loaded.profile);
      await tx.kelajakSession.update({
        where: { id: sessionId },
        data: {
          status: KelajakSessionStatus.COMPLETED,
          completedAt: now,
          result: result as unknown as Prisma.InputJsonValue,
          scoringVersion: SCORING_VERSION,
        },
      });
      return { closed: false, value: null };
    });
    if (outcome.closed) throw sessionClosed();
    return this.sessionView(childId, sessionId);
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  private async pickForChild(
    tx: Db,
    params: { childId: string; type: KelajakTestType; ageGroup: KelajakAgeGroup; today: string },
  ): Promise<string[]> {
    const { childId, type, ageGroup, today } = params;
    const config = KELAJAK_TESTS[type];
    // Shifrlash kaliti yo'q — ochiq javobni saqlab bo'lmaydi, ochiq savollar berilmaydi.
    const textFilter = this.crypto.isConfigured() ? {} : { answerType: { not: TEXT_ANSWER_TYPE } };
    const pool = await tx.kelajakQuestion.findMany({
      where: { active: true, ageGroup, category: { in: testCategories(config) }, ...textFilter },
      select: { id: true, category: true, ageGroup: true, answerType: true, active: true },
      orderBy: { externalId: 'asc' },
    });
    const picked = pickKelajakQuestions({
      config,
      ageGroup,
      pool,
      lastAnsweredAt: await loadAnswerHistory(tx, childId),
      seed: kelajakSeed(today, type, childId),
    });
    return picked.map((q) => q.id);
  }

  /** Shifrlangan matn → ochiq matn (faqat bolaga); ochilmasa — null (log'da matnsiz). */
  private decryptText(textEnc: string | null): string | null {
    if (textEnc === null) return null;
    try {
      return this.crypto.decrypt(textEnc);
    } catch (e) {
      this.logger.warn(`kelajak: ochiq javob ochilmadi (${(e as Error).name})`);
      return null;
    }
  }
}

async function abandon(tx: Db, sessionId: string): Promise<void> {
  await tx.kelajakSession.update({ where: { id: sessionId }, data: { status: KelajakSessionStatus.ABANDONED } });
}

async function ownSession(db: Db, childId: string, sessionId: string): Promise<KelajakSession> {
  const session = await db.kelajakSession.findUnique({ where: { id: sessionId } });
  if (!session || session.childId !== childId) {
    throw new NotFoundException({ message: 'Session not found', code: 'SESSION_NOT_FOUND' });
  }
  return session;
}
