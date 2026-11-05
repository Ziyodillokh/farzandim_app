// ─────────────────────────────────────────────────────────────────────
// Daily Learning — urinish uchun savollarni tanlash
// ─────────────────────────────────────────────────────────────────────
//
// Oddiy (aralash) urinish: fan banki, sinfga mos savollar ustun. Mavzu
// urinishi: mavzu puli (faqat shu sinfga mos faol savollar). Ikkalasida ham
// `pickQuestions` qoidasi bir xil (adaptiv qiyinlik, yaqinda ko'rilmaganlar).

import { Injectable, NotFoundException } from '@nestjs/common';
import {
  LearningAttemptStatus,
  LearningQuestion,
  LearningQuestionStatus,
  LearningSubject,
  LearningTopic,
  Prisma,
} from '@prisma/client';
import { addDays } from '../../common/time/tashkent';
import { attemptSeed, PickableQuestion, pickQuestions } from './domain/question-picker';
import { percentOf } from './domain/rewards';
import { DAILY_QUESTION_COUNT, subjectIndex } from './domain/subjects';
import { LearningTopicsService } from './learning-topics.service';

/** Adaptiv qiyinlik uchun so'nggi natijalar soni. */
const RECENT_RESULTS = 5;
/** Shu kunlar ichida berilgan savollar iloji boricha takrorlanmaydi. */
const RECENTLY_SEEN_DAYS = 3;
/**
 * Sinfga mos savollar shuncha yoki ko'p bo'lsa — FAQAT ular beriladi (2-sinf
 * bolasiga 5-sinf savoli tushmasin; test qisqaroq bo'lishi mumkin). Kam
 * bo'lsa — eng yaqin sinf savollari bilan to'ldiriladi.
 */
const MIN_IN_GRADE_QUESTIONS = 5;

export interface PickParams {
  childId: string;
  subject: LearningSubject;
  grade: number;
  today: string;
  ordinal: number;
  /** null — oddiy aralash urinish. */
  topic: LearningTopic | null;
}

@Injectable()
export class LearningPickService {
  constructor(private readonly topics: LearningTopicsService) {}

  /** Mavzu urinishi uchun mavzuni tekshirish (422 `TOPIC_NOT_AVAILABLE`). */
  requireStartableTopic(
    tx: Prisma.TransactionClient,
    subject: LearningSubject,
    topicId: string,
  ): Promise<LearningTopic> {
    return this.topics.requireStartable(tx, subject, topicId);
  }

  async pickForChild(tx: Prisma.TransactionClient, params: PickParams): Promise<LearningQuestion[]> {
    const { childId, subject, grade, today, ordinal, topic } = params;
    const pool = topic
      ? await this.topics.inGradePool(tx, topic.id, grade)
      : await this.subjectPool(tx, subject);
    if (topic) this.topics.assertPoolSufficient(topic, pool);

    const recent = await this.recentResults(tx, { childId, subject, topicId: topic?.id ?? null });
    const total = recent.reduce((s, r) => s + r.total, 0);
    const seen = await tx.learningAnswer.findMany({
      where: {
        attempt: { childId, subject, day: { gte: addDays(today, -RECENTLY_SEEN_DAYS) } },
      },
      select: { questionId: true },
    });
    const picked = pickQuestions({
      pool: topic ? pool : preferInGrade(pool, grade),
      grade,
      count: DAILY_QUESTION_COUNT,
      recentPercent:
        total === 0 ? null : percentOf(recent.reduce((s, r) => s + r.correct, 0), total),
      recentlySeen: new Set(seen.map((s) => s.questionId)),
      seed: attemptSeed(today, subjectIndex(subject), ordinal),
    });
    const full = await tx.learningQuestion.findMany({
      where: { id: { in: picked.map((q) => q.id) } },
    });
    const byId = new Map(full.map((q) => [q.id, q]));
    return picked.map((q) => byId.get(q.id)!);
  }

  private async subjectPool(
    tx: Prisma.TransactionClient,
    subject: LearningSubject,
  ): Promise<PickableQuestion[]> {
    const pool = await tx.learningQuestion.findMany({
      where: { subject, status: LearningQuestionStatus.ACTIVE },
      select: { id: true, difficulty: true, minGrade: true, maxGrade: true },
    });
    if (pool.length === 0) {
      throw new NotFoundException({
        message: 'No questions for this subject yet',
        code: 'NO_QUESTIONS',
      });
    }
    return pool;
  }

  /**
   * Adaptiv qiyinlik uchun so'nggi natijalar: mavzu urinishida — avval shu
   * mavzu bo'yicha, bo'lmasa fan bo'yicha.
   */
  private async recentResults(
    tx: Prisma.TransactionClient,
    params: { childId: string; subject: LearningSubject; topicId: string | null },
  ): Promise<{ correct: number; total: number }[]> {
    const { childId, subject, topicId } = params;
    const query = (extra: Prisma.LearningAttemptWhereInput) =>
      tx.learningAttempt.findMany({
        where: { childId, subject, status: LearningAttemptStatus.COMPLETED, ...extra },
        orderBy: { completedAt: 'desc' },
        take: RECENT_RESULTS,
        select: { correct: true, total: true },
      });
    if (topicId) {
      const onTopic = await query({ topicId });
      if (onTopic.length > 0) return onTopic;
    }
    return query({});
  }
}

/** Sinfga mos savollar yetarli bo'lsa — faqat ular, aks holda butun fan banki. */
function preferInGrade(pool: PickableQuestion[], grade: number): PickableQuestion[] {
  const inGrade = pool.filter((q) => grade >= q.minGrade && grade <= q.maxGrade);
  return inGrade.length >= MIN_IN_GRADE_QUESTIONS ? inGrade : pool;
}
