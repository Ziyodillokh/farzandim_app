// ─────────────────────────────────────────────────────────────────────
// Daily Learning — o'quv profili, kunlik test urinishlari va natijalar
// ─────────────────────────────────────────────────────────────────────
//
// Server haqiqat manbai: savollar adaptiv tanlanadi, javob serverda
// tekshiriladi (to'g'ri javob va izoh faqat javobdan keyin), DON / XP
// yakunda fan bo'yicha KUNLIK BIRINCHI urinishga bir marta beriladi.
// Bola bo'yicha tranzaksion advisory lock — "boshlash" / "yakunlash" ikki
// marta bosilsa ham bitta urinish va bitta mukofot.

import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  LearningAttemptStatus,
  LearningQuestion,
  LearningSubject,
  LearningTopic,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { isoWeekStart, tashkentDay } from '../../common/time/tashkent';
import { GamificationService } from '../gamification/gamification.service';
import { LocalizedText } from './domain/localized';
import { donFor, xpFor } from './domain/rewards';
import { fromApiSubject, isTaughtIn, profileError, toApiSubject } from './domain/subjects';
import { fillTopicText, TopicText } from './domain/topic-input';
import {
  ListResultsQueryDto,
  SaveLearningProfileDto,
  SubmitAnswerDto,
} from './dto/learning.dto';
import { hasMasteredTopic } from './learning-mastery.query';
import { requireProfile } from './learning-profile.guard';
import { LearningPickService } from './learning-pick.service';
import { TOPIC_REF_SELECT, toTopicRef } from './learning-topic.mapper';
import {
  AnswerView,
  AttemptView,
  ProfileView,
  ResultView,
  ReviewItemView,
  toAnswerView,
  toProfileView,
  toQuestionView,
  toResultView,
} from './learning.mapper';

const DEFAULT_RESULTS_LIMIT = 30;

@Injectable()
export class LearningService {
  private readonly logger = new Logger(LearningService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly gamification: GamificationService,
    private readonly picker: LearningPickService,
  ) {}

  /** Test uchun almashtiriladi. */
  protected now(): Date {
    return new Date();
  }

  // ── Bola ───────────────────────────────────────────────────────────

  /** CHILD token egasining `Child.id`si. */
  async childIdForUser(userId: string): Promise<string> {
    const child = await this.prisma.child.findUnique({
      where: { childUserId: userId },
      select: { id: true },
    });
    if (!child) throw new ForbiddenException('Child profile required');
    return child.id;
  }

  /** Ota-ona shu bolaning egasi — aks holda 404 / 403. */
  async assertParentOwns(parentUserId: string, childId: string): Promise<void> {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
      select: { parentId: true },
    });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== parentUserId) throw new ForbiddenException('Forbidden');
  }

  // ── Profil ─────────────────────────────────────────────────────────

  async getProfile(childId: string): Promise<ProfileView | null> {
    const profile = await this.prisma.learningProfile.findUnique({
      where: { childId },
    });
    return profile ? toProfileView(profile) : null;
  }

  async saveProfile(
    childId: string,
    dto: SaveLearningProfileDto,
  ): Promise<ProfileView> {
    const subjects = dto.subjects.map((s) => fromApiSubject(s)!);
    const error = profileError(dto.grade, subjects);
    if (error) throw new BadRequestException(error);
    const profile = await this.prisma.learningProfile.upsert({
      where: { childId },
      create: { childId, grade: dto.grade, subjects },
      update: { grade: dto.grade, subjects },
    });
    return toProfileView(profile);
  }

  // ── Urinishlar ─────────────────────────────────────────────────────

  /**
   * Fan bo'yicha testni boshlash yoki bugungi yakunlanmagan urinishni
   * davom ettirish (javob berilgan savollar va ularning natijasi bilan).
   * `topicId` berilsa — shu mavzu savollaridan; davom ettirish ham shu mavzu
   * bo'yicha (oddiy va mavzu urinishlari bir-biriga aralashmaydi).
   */
  async startAttempt(
    childId: string,
    apiSubject: string,
    topicId: string | null = null,
  ): Promise<AttemptView> {
    const subject = fromApiSubject(apiSubject);
    if (!subject) throw new BadRequestException('Unknown subject');
    const today = tashkentDay(this.now());

    const attemptId = await this.prisma.$transaction(async (tx) => {
      await lockChild(tx, childId);
      const profile = await requireProfile(tx, childId);
      if (!isTaughtIn(subject, profile.grade)) {
        throw new BadRequestException({
          message: 'Subject is not taught in this grade',
          code: 'SUBJECT_NOT_IN_GRADE',
        });
      }
      const topic = topicId ? await this.picker.requireStartableTopic(tx, subject, topicId) : null;

      // O'tgan kunlarda yarim qolgan urinishlar yopiladi.
      await tx.learningAttempt.updateMany({
        where: {
          childId,
          subject,
          status: LearningAttemptStatus.IN_PROGRESS,
          day: { lt: today },
        },
        data: { status: LearningAttemptStatus.ABANDONED },
      });
      const open = await tx.learningAttempt.findFirst({
        where: {
          childId,
          subject,
          day: today,
          status: LearningAttemptStatus.IN_PROGRESS,
          topicId: topic?.id ?? null,
        },
        select: { id: true },
      });
      if (open) return open.id;

      const todays = await tx.learningAttempt.findMany({
        where: { childId, subject, day: today },
        select: { isDaily: true },
      });
      const picked = await this.picker.pickForChild(tx, {
        childId,
        subject,
        grade: profile.grade,
        today,
        ordinal: todays.length,
        topic,
      });
      const attempt = await tx.learningAttempt.create({
        data: {
          childId,
          subject,
          day: today,
          // Kunlik (DON) urinish — faqat profil fanlari bo'yicha; boshqa fan
          // (masalan eski natijadagi tavsiya) — amaliyot.
          isDaily: profile.subjects.includes(subject) && !todays.some((a) => a.isDaily),
          questionIds: picked.map((q) => q.id),
          topicId: topic?.id ?? null,
          topic: (topic ? topicTitle(topic) : mainTopic(picked)) as unknown as Prisma.InputJsonValue,
          total: picked.length,
        },
        select: { id: true },
      });
      return attempt.id;
    });

    return this.attemptView(childId, attemptId);
  }

  async submitAnswer(
    childId: string,
    attemptId: string,
    dto: SubmitAnswerDto,
  ): Promise<AnswerView> {
    const attempt = await this.ownAttempt(childId, attemptId);
    const position = attempt.questionIds.indexOf(dto.questionId);
    if (position < 0) {
      throw new BadRequestException({
        message: 'Question is not part of this attempt',
        code: 'QUESTION_NOT_IN_ATTEMPT',
      });
    }
    const question = await this.prisma.learningQuestion.findUniqueOrThrow({
      where: { id: dto.questionId },
    });

    // Idempotent: qayta yuborilgan javob — saqlangan natija (o'zgarmaydi).
    const existing = await this.prisma.learningAnswer.findUnique({
      where: { attemptId_questionId: { attemptId, questionId: dto.questionId } },
    });
    if (existing) return toAnswerView(existing, question);

    if (attempt.status !== LearningAttemptStatus.IN_PROGRESS) {
      throw new ConflictException({ message: 'Attempt is closed', code: 'ATTEMPT_CLOSED' });
    }
    const optionCount = (question.options as unknown[]).length;
    if (dto.selectedIndex >= optionCount) {
      throw new BadRequestException('selectedIndex is out of range');
    }

    try {
      const answer = await this.prisma.learningAnswer.create({
        data: {
          attemptId,
          questionId: dto.questionId,
          position,
          selectedIndex: dto.selectedIndex,
          isCorrect: dto.selectedIndex === question.answerIndex,
        },
      });
      return toAnswerView(answer, question);
    } catch (e) {
      // Parallel takror so'rov — birinchisi yutadi.
      if (isUniqueViolation(e)) {
        const stored = await this.prisma.learningAnswer.findUniqueOrThrow({
          where: { attemptId_questionId: { attemptId, questionId: dto.questionId } },
        });
        return toAnswerView(stored, question);
      }
      throw e;
    }
  }

  /** Yakunlash — natija va (kunlik birinchi urinish bo'lsa) DON / XP. */
  async completeAttempt(childId: string, attemptId: string): Promise<ResultView> {
    const now = this.now();
    const { attempt, profile } = await this.prisma.$transaction(async (tx) => {
      await lockChild(tx, childId);
      const current = await tx.learningAttempt.findUnique({
        where: { id: attemptId },
        include: { answers: { select: { isCorrect: true } }, topicRef: { select: TOPIC_REF_SELECT } },
      });
      if (!current || current.childId !== childId) {
        throw new NotFoundException('Attempt not found');
      }
      if (current.status === LearningAttemptStatus.COMPLETED) {
        return { attempt: current, profile: null };
      }
      if (current.status === LearningAttemptStatus.ABANDONED) {
        throw new ConflictException({ message: 'Attempt is closed', code: 'ATTEMPT_CLOSED' });
      }
      const remaining = current.total - current.answers.length;
      if (remaining > 0) {
        throw new BadRequestException({
          message: 'Not all questions are answered',
          code: 'UNANSWERED',
          remaining,
        });
      }

      const correct = current.answers.filter((a) => a.isCorrect).length;
      const xp = current.isDaily ? xpFor(correct, current.total) : 0;
      const don = current.isDaily ? donFor(correct, current.total) : 0;
      const completed = await tx.learningAttempt.update({
        where: { id: attemptId },
        data: {
          status: LearningAttemptStatus.COMPLETED,
          completedAt: now,
          correct,
          xpEarned: xp,
          donEarned: don,
          // Yakunlangan hafta maktab hisobotida o'zgarmaydi: o'tgan haftada boshlangan urinish — snapshot'siz.
          schoolClassId: isoWeekStart(current.day) === isoWeekStart(tashkentDay(now)) ? await schoolClassOf(tx, childId) : null,
        },
        include: { topicRef: { select: TOPIC_REF_SELECT } },
      });
      const award = await this.gamification.awardInTx(tx, childId, {
        type: 'DAILY_LEARNING',
        xpDelta: xp,
        donDelta: don,
        relatedId: attemptId,
      });
      return { attempt: completed, profile: award?.profile ?? null };
    });

    if (profile) this.gamification.notifyProfileUpdated(childId, profile);
    if (attempt.topicId) await this.unlockTopicMaster(childId, attempt.topicId);
    return toResultView(attempt);
  }

  /**
   * "Mavzu ustasi" yutug'i: mavzu bo'yicha urinishdan keyin shu mavzu "o'zlashtirilgan"
   * bo'lsa (`domain/topic-mastery.ts` qoidasi) ochiladi. Xato natijani buzmaydi.
   */
  private async unlockTopicMaster(childId: string, topicId: string): Promise<void> {
    try {
      if (await hasMasteredTopic(this.prisma, childId, [topicId])) {
        await this.gamification.unlockAchievement(childId, 'topic_master');
      }
    } catch (e) {
      this.logger.error(`topic_master yutug'i berilmadi (child ${childId})`, e as Error);
    }
  }

  async attemptView(childId: string, attemptId: string): Promise<AttemptView> {
    const attempt = await this.ownAttempt(childId, attemptId);
    const [questions, answers] = await Promise.all([
      this.questionsInOrder(attempt.questionIds),
      this.prisma.learningAnswer.findMany({
        where: { attemptId },
        orderBy: { position: 'asc' },
      }),
    ]);
    const byId = new Map(questions.map((q) => [q.id, q]));
    return {
      id: attempt.id,
      subject: toApiSubject(attempt.subject),
      status: attempt.status,
      isDaily: attempt.isDaily,
      day: attempt.day,
      startedAt: attempt.startedAt,
      total: attempt.total,
      topic: attempt.topicRef ? toTopicRef(attempt.topicRef) : null,
      questions: questions.map(toQuestionView),
      answers: answers.map((a) => toAnswerView(a, byId.get(a.questionId)!)),
    };
  }

  // ── Natijalar ──────────────────────────────────────────────────────

  async listResults(
    childId: string,
    query: ListResultsQueryDto,
  ): Promise<{ items: ResultView[]; nextBefore: string | null }> {
    const limit = query.limit ?? DEFAULT_RESULTS_LIMIT;
    const subject = query.subject ? fromApiSubject(query.subject) : null;
    const rows = await this.prisma.learningAttempt.findMany({
      where: {
        childId,
        status: LearningAttemptStatus.COMPLETED,
        ...(subject && { subject }),
        ...(query.before && { completedAt: { lt: query.before } }),
      },
      orderBy: { completedAt: 'desc' },
      take: limit + 1,
      include: { topicRef: { select: TOPIC_REF_SELECT } },
    });
    const items = rows.slice(0, limit).map(toResultView);
    const nextBefore =
      rows.length > limit ? items[items.length - 1].date.toISOString() : null;
    return { items, nextBefore };
  }

  /** Yakunlangan urinish tahlili: savol, to'g'ri javob, bolaning javobi, izoh. */
  async review(
    childId: string,
    attemptId: string,
  ): Promise<{ result: ResultView; items: ReviewItemView[] }> {
    const attempt = await this.ownAttempt(childId, attemptId);
    if (attempt.status !== LearningAttemptStatus.COMPLETED) {
      throw new ConflictException({ message: 'Attempt is not completed', code: 'NOT_COMPLETED' });
    }
    const [questions, answers] = await Promise.all([
      this.questionsInOrder(attempt.questionIds),
      this.prisma.learningAnswer.findMany({ where: { attemptId } }),
    ]);
    const answerByQuestion = new Map(answers.map((a) => [a.questionId, a]));
    return {
      result: toResultView(attempt),
      items: questions.map((q) => {
        const answer = answerByQuestion.get(q.id);
        return {
          question: {
            ...toQuestionView(q),
            correctIndex: q.answerIndex,
            explanation: q.explanation as unknown as LocalizedText,
          },
          selectedIndex: answer?.selectedIndex ?? null,
          isCorrect: answer?.isCorrect ?? false,
        };
      }),
    };
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  private async ownAttempt(childId: string, attemptId: string) {
    const attempt = await this.prisma.learningAttempt.findUnique({
      where: { id: attemptId },
      include: { topicRef: { select: TOPIC_REF_SELECT } },
    });
    if (!attempt || attempt.childId !== childId) {
      throw new NotFoundException('Attempt not found');
    }
    return attempt;
  }

  private async questionsInOrder(ids: string[]): Promise<LearningQuestion[]> {
    const rows = await this.prisma.learningQuestion.findMany({
      where: { id: { in: ids } },
    });
    const byId = new Map(rows.map((q) => [q.id, q]));
    return ids.map((id) => byId.get(id)).filter((q): q is LearningQuestion => !!q);
  }
}

/**
 * Maktab hisobotlari uchun snapshot: yakunlash paytida bola bog'langan faol
 * maktabdagi sinf (bog'lanmagan / arxivlangan — null, maktabga ko'rinmaydi).
 */
async function schoolClassOf(tx: Prisma.TransactionClient, childId: string): Promise<string | null> {
  const link = await tx.schoolStudent.findUnique({
    where: { childId },
    select: { classId: true, archived: true, school: { select: { status: true } } },
  });
  return link && !link.archived && link.school.status === 'ACTIVE' ? link.classId : null;
}

/** Bola bo'yicha tranzaksion qulf (boshlash / yakunlash navbat bilan). */
async function lockChild(tx: Prisma.TransactionClient, childId: string): Promise<void> {
  await tx.$queryRaw`SELECT 1 AS locked FROM pg_advisory_xact_lock(hashtextextended(${`learning:${childId}`}, 0))`;
}

/** Mavzu urinishining eski `topic` ustuni: sarlavha (uch tilda to'ldirilgan). */
function topicTitle(topic: LearningTopic): LocalizedText {
  return fillTopicText(topic.title as unknown as TopicText);
}

/** Eng ko'p uchragan mavzu — natija sarlavhasi uchun. */
function mainTopic(questions: LearningQuestion[]): LocalizedText | null {
  const counts = new Map<string, { topic: LocalizedText; count: number }>();
  for (const q of questions) {
    const topic = q.topic as unknown as LocalizedText;
    const entry = counts.get(topic.uz) ?? { topic, count: 0 };
    entry.count++;
    counts.set(topic.uz, entry);
  }
  let best: { topic: LocalizedText; count: number } | null = null;
  for (const entry of counts.values()) {
    if (!best || entry.count > best.count) best = entry;
  }
  return best?.topic ?? null;
}

function isUniqueViolation(e: unknown): boolean {
  return e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002';
}
