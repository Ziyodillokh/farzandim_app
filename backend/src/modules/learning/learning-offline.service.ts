/**
 * U10 · Oflayn to'plam: internet yo'q paytda mashq qilish uchun haftalik
 * to'plam va oflayn bajarilgan urinishlarni qabul qilish.
 *
 * - `GET /learning/offline-pack` — profil fanlari bo'yicha bittadan mashq
 *   to'plami (to'g'ri javob va izoh bilan — oflaynda ham izoh ko'rinsin),
 *   7 kun amal qiladi. Har to'plam server kalitli HMAC bilan imzolanadi:
 *   urinish faqat shu bolaga berilgan savollar bilan qabul qilinadi.
 * - `POST /learning/offline-attempts` — imzo va muddat tekshiriladi, javoblar
 *   SERVERDA baholanadi (ilova hisobiga ishonilmaydi), urinish id si ilova
 *   bergan UUID (qayta yuborish — o'sha natija). DON / XP oddiy qoida bilan:
 *   shu fan va shu kunning birinchi kunlik urinishi bo'lsa, bir marta.
 */
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { LearningQuestion, Prisma } from '@prisma/client';
import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import { EnvConfig } from '../../common/config/env.schema';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { LocalizedText } from './domain/localized';
import { fromApiSubject, isTaughtIn, toApiSubject } from './domain/subjects';
import { OfflineAttemptDto } from './dto/offline.dto';
import { requireProfile } from './learning-profile.guard';
import { LearningPickService } from './learning-pick.service';
import { QuestionView, ResultView, toQuestionView } from './learning.mapper';
import {
  isUniqueViolation,
  LearningService,
  lockChild,
  mainTopic,
} from './learning.service';

export const OFFLINE_PACK_VERSION = 1;
export const OFFLINE_PACK_DAYS = 7;
/** To'plam muddati tugagach ham bajarilganlarini yuborish uchun vaqt. */
export const OFFLINE_UPLOAD_GRACE_DAYS = 7;
/** Bitta to'plamda eng ko'p fan. */
const MAX_SUBJECTS = 4;
/** Qurilma soati bilan farq (kelajakdagi `completedAt` rad etiladi). */
const CLOCK_SKEW_MS = 5 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;
/** Oddiy urinishlar seed'idan ajralib turishi uchun. */
const OFFLINE_ORDINAL_BASE = 50;

export interface OfflineQuestionView extends QuestionView {
  correctIndex: number;
  explanation: LocalizedText | null;
}

export interface OfflineSetView {
  subject: string;
  topic: LocalizedText | null;
  questions: OfflineQuestionView[];
  signature: string;
}

export interface OfflinePackView {
  packId: string;
  version: number;
  issuedAt: string;
  expiresAt: string;
  sets: OfflineSetView[];
}

@Injectable()
export class LearningOfflineService {
  private readonly secret: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly picker: LearningPickService,
    private readonly learning: LearningService,
    config: ConfigService<EnvConfig, true>,
  ) {
    const base = config.get('JWT_ACCESS_SECRET', { infer: true });
    this.secret = createHmac('sha256', base)
      .update('farzandim:learning-offline-pack:v1')
      .digest('hex');
  }

  protected now(): Date {
    return new Date();
  }

  /** To'plamdagi bitta fan imzosi (bola, to'plam, fan, savollar, muddat). */
  sign(
    childId: string,
    packId: string,
    subject: string,
    questionIds: readonly string[],
    expiresAt: string,
  ): string {
    return createHmac('sha256', this.secret)
      .update([childId, packId, subject, questionIds.join(','), expiresAt].join('|'))
      .digest('hex');
  }

  async pack(childId: string): Promise<OfflinePackView> {
    const now = this.now();
    const today = tashkentDay(now);
    const packId = randomUUID();
    const expiresAt = new Date(now.getTime() + OFFLINE_PACK_DAYS * DAY_MS).toISOString();
    const sets = await this.prisma.$transaction(async (tx) => {
      const profile = await requireProfile(tx, childId);
      const subjects = profile.subjects
        .filter((s) => isTaughtIn(s, profile.grade))
        .slice(0, MAX_SUBJECTS);
      const result: OfflineSetView[] = [];
      for (const [i, subject] of subjects.entries()) {
        const picked = await this.picker.pickForChild(tx, {
          childId,
          subject,
          grade: profile.grade,
          today,
          ordinal: OFFLINE_ORDINAL_BASE + i,
          topic: null,
        });
        if (picked.length === 0) continue;
        const api = toApiSubject(subject);
        result.push({
          subject: api,
          topic: mainTopic(picked),
          questions: picked.map(offlineQuestion),
          signature: this.sign(childId, packId, api, picked.map((q) => q.id), expiresAt),
        });
      }
      return result;
    });
    return {
      packId,
      version: OFFLINE_PACK_VERSION,
      issuedAt: now.toISOString(),
      expiresAt,
      sets,
    };
  }

  async upload(childId: string, dto: OfflineAttemptDto): Promise<ResultView> {
    const existing = await this.prisma.learningAttempt.findUnique({
      where: { id: dto.clientAttemptId },
      select: { childId: true },
    });
    if (existing) return this.alreadyUploaded(childId, dto.clientAttemptId, existing.childId);

    this.assertSigned(childId, dto);
    const now = this.now();
    const completedAt = new Date(dto.completedAt);
    const expiresAt = new Date(dto.expiresAt);
    if (completedAt.getTime() > now.getTime() + CLOCK_SKEW_MS) {
      throw new BadRequestException({ message: 'completedAt is in the future', code: 'BAD_TIME' });
    }
    if (
      completedAt > expiresAt ||
      now.getTime() > expiresAt.getTime() + OFFLINE_UPLOAD_GRACE_DAYS * DAY_MS ||
      completedAt.getTime() < expiresAt.getTime() - OFFLINE_PACK_DAYS * DAY_MS - CLOCK_SKEW_MS
    ) {
      throw new ConflictException({ message: 'Offline pack expired', code: 'PACK_EXPIRED' });
    }
    const subject = fromApiSubject(dto.subject);
    if (!subject) throw new BadRequestException('Unknown subject');

    const ids = dto.questionIds;
    const answers = new Map(dto.answers.map((a) => [a.questionId, a.selectedIndex]));
    if (
      new Set(ids).size !== ids.length ||
      answers.size !== dto.answers.length ||
      answers.size !== ids.length ||
      ids.some((id) => !answers.has(id))
    ) {
      throw new BadRequestException({ message: 'Every question needs one answer', code: 'UNANSWERED' });
    }
    const rows = await this.prisma.learningQuestion.findMany({ where: { id: { in: ids } } });
    const byId = new Map(rows.map((q) => [q.id, q]));
    const questions = ids.map((id) => byId.get(id)).filter((q): q is LearningQuestion => !!q);
    if (questions.length !== ids.length) {
      throw new BadRequestException({ message: 'Unknown question', code: 'QUESTION_NOT_FOUND' });
    }
    for (const q of questions) {
      if (answers.get(q.id)! >= (q.options as unknown[]).length) {
        throw new BadRequestException('selectedIndex is out of range');
      }
    }

    const day = tashkentDay(completedAt);
    try {
      await this.prisma.$transaction(async (tx) => {
        await lockChild(tx, childId);
        const profile = await requireProfile(tx, childId);
        const dailyDone = await tx.learningAttempt.count({
          where: { childId, subject, day, isDaily: true },
        });
        await tx.learningAttempt.create({
          data: {
            id: dto.clientAttemptId,
            childId,
            subject,
            day,
            // DON — shu fan va kunning birinchi kunlik urinishi bo'lsa (onlayn bilan bir qoida).
            isDaily: profile.subjects.includes(subject) && dailyDone === 0,
            questionIds: ids,
            topic: mainTopic(questions) as unknown as Prisma.InputJsonValue,
            total: ids.length,
            startedAt: completedAt,
          },
        });
        await tx.learningAnswer.createMany({
          data: questions.map((q, position) => ({
            attemptId: dto.clientAttemptId,
            questionId: q.id,
            position,
            selectedIndex: answers.get(q.id)!,
            isCorrect: answers.get(q.id) === q.answerIndex,
          })),
        });
      });
    } catch (e) {
      // Parallel takror yuborish — birinchisi yutadi.
      if (!isUniqueViolation(e)) throw e;
      const raced = await this.prisma.learningAttempt.findUniqueOrThrow({
        where: { id: dto.clientAttemptId },
        select: { childId: true },
      });
      return this.alreadyUploaded(childId, dto.clientAttemptId, raced.childId);
    }
    return this.learning.completeAttempt(childId, dto.clientAttemptId);
  }

  private alreadyUploaded(childId: string, attemptId: string, owner: string): Promise<ResultView> {
    if (owner !== childId) {
      throw new ConflictException({ message: 'Attempt id is taken', code: 'ATTEMPT_ID_TAKEN' });
    }
    return this.learning.completeAttempt(childId, attemptId);
  }

  private assertSigned(childId: string, dto: OfflineAttemptDto): void {
    const expected = Buffer.from(
      this.sign(childId, dto.packId, dto.subject, dto.questionIds, dto.expiresAt),
      'hex',
    );
    const given = Buffer.from(dto.signature, 'hex');
    if (given.length !== expected.length || !timingSafeEqual(given, expected)) {
      throw new ForbiddenException({ message: 'Pack signature is invalid', code: 'PACK_SIGNATURE_INVALID' });
    }
  }
}

function offlineQuestion(q: LearningQuestion): OfflineQuestionView {
  return {
    ...toQuestionView(q),
    correctIndex: q.answerIndex,
    explanation: (q.explanation as unknown as LocalizedText | null) ?? null,
  };
}
