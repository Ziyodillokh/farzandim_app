// Mavzular katalogi fixture'lari: mavzu, mavzuga bog'langan savollar va
// bolaning yakunlangan urinish / javoblari (to'g'ridan-to'g'ri bazaga).

import type {
  LearningQuestion,
  LearningSubject,
  LearningTopic,
  LearningTopicStatus,
  PrismaClient,
} from '@prisma/client';
import { randomUUID } from 'node:crypto';

export interface TopicPatch {
  subject?: LearningSubject;
  key?: string;
  title?: object;
  goal?: object | null;
  minGrade?: number;
  maxGrade?: number;
  position?: number;
  status?: LearningTopicStatus;
}

export function createTopic(prisma: PrismaClient, patch: TopicPatch = {}): Promise<LearningTopic> {
  const key = patch.key ?? `topic-${randomUUID().slice(0, 8)}`;
  return prisma.learningTopic.create({
    data: {
      subject: patch.subject ?? 'MATH',
      key,
      title: patch.title ?? { uz: `Mavzu ${key}` },
      goal: patch.goal === null ? undefined : (patch.goal ?? { uz: `Maqsad ${key}` }),
      minGrade: patch.minGrade ?? 5,
      maxGrade: patch.maxGrade ?? 9,
      position: patch.position ?? 0,
      status: patch.status ?? 'ACTIVE',
    },
  });
}

export interface TopicQuestionOptions {
  subject?: LearningSubject;
  minGrade?: number;
  maxGrade?: number;
  status?: 'ACTIVE' | 'DRAFT' | 'ARCHIVED';
  difficulty?: number;
}

/** `count` ta savol; `topicId` berilsa mavzuga bog'lanadi. */
export async function createQuestions(
  prisma: PrismaClient,
  count: number,
  topicId: string | null,
  options: TopicQuestionOptions = {},
): Promise<LearningQuestion[]> {
  const questions: LearningQuestion[] = [];
  for (let i = 0; i < count; i++) {
    questions.push(
      await prisma.learningQuestion.create({
        data: {
          subject: options.subject ?? 'MATH',
          difficulty: options.difficulty ?? (i % 3) + 1,
          minGrade: options.minGrade ?? 5,
          maxGrade: options.maxGrade ?? 9,
          topic: { uz: 'Eski mavzu', ru: 'Старая тема', en: 'Old topic' },
          topicId,
          prompt: { uz: `Savol ${i}?`, ru: `Вопрос ${i}?`, en: `Question ${i}?` },
          options: ['a', 'b', 'c', 'd'].map((v) => ({ uz: v, ru: v, en: v })),
          answerIndex: 0,
          explanation: { uz: 'izoh', ru: 'пояснение', en: 'note' },
          status: options.status ?? 'ACTIVE',
        },
      }),
    );
  }
  return questions;
}

export interface FinishedAttemptOptions {
  /** Urinish mavzu bo'yicha emas (oddiy aralash) bo'lsa — null. */
  attemptTopicId?: string | null;
  status?: 'COMPLETED' | 'IN_PROGRESS' | 'ABANDONED';
  /** Eng birinchi javob vaqti; keyingilari 1 daqiqadan keyin. */
  startedAt?: Date;
  subject?: LearningSubject;
}

/**
 * Bolaning urinishi: har savolga `flags[i]` (to'g'ri / xato) javob. Javob
 * vaqtlari `startedAt` dan boshlab 1 daqiqa oralig'ida.
 */
export async function recordAttempt(
  prisma: PrismaClient,
  childId: string,
  questions: readonly LearningQuestion[],
  flags: readonly boolean[],
  options: FinishedAttemptOptions = {},
) {
  const startedAt = options.startedAt ?? new Date('2026-11-01T09:00:00.000Z');
  const status = options.status ?? 'COMPLETED';
  const answered = Math.min(questions.length, flags.length);
  const correct = flags.slice(0, answered).filter(Boolean).length;
  const attempt = await prisma.learningAttempt.create({
    data: {
      childId,
      subject: options.subject ?? 'MATH',
      day: startedAt.toISOString().slice(0, 10),
      isDaily: false,
      status,
      questionIds: questions.map((q) => q.id),
      topicId: options.attemptTopicId ?? null,
      correct: status === 'COMPLETED' ? correct : 0,
      total: questions.length,
      startedAt,
      completedAt: status === 'COMPLETED' ? new Date(startedAt.getTime() + answered * 60_000) : null,
    },
  });
  for (let i = 0; i < answered; i++) {
    await prisma.learningAnswer.create({
      data: {
        attemptId: attempt.id,
        questionId: questions[i].id,
        position: i,
        selectedIndex: flags[i] ? 0 : 1,
        isCorrect: flags[i],
        answeredAt: new Date(startedAt.getTime() + (i + 1) * 60_000),
      },
    });
  }
  return attempt;
}
