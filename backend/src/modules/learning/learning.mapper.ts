// DB yozuvlari → API ko'rinishlari. Savol to'g'ri javobi va izohi faqat
// javob berilgandan keyin (yoki yakunlangan urinish tahlilida) chiqadi.

import {
  LearningAnswer,
  LearningAttempt,
  LearningProfile,
  LearningQuestion,
} from '@prisma/client';
import { LocalizedText } from './domain/localized';
import { percentOf } from './domain/rewards';
import { ApiSubject, toApiSubject } from './domain/subjects';

export interface ProfileView {
  grade: number;
  subjects: ApiSubject[];
  updatedAt: Date;
}

export interface QuestionView {
  id: string;
  difficulty: number;
  topic: LocalizedText;
  prompt: LocalizedText;
  options: LocalizedText[];
}

export interface AnswerView {
  questionId: string;
  selectedIndex: number;
  isCorrect: boolean;
  correctIndex: number;
  explanation: LocalizedText;
}

export interface AttemptView {
  id: string;
  subject: ApiSubject;
  status: LearningAttempt['status'];
  isDaily: boolean;
  day: string;
  startedAt: Date;
  total: number;
  questions: QuestionView[];
  answers: AnswerView[];
}

export interface ResultView {
  id: string;
  subject: ApiSubject;
  topic: LocalizedText | null;
  correct: number;
  total: number;
  percent: number;
  isDaily: boolean;
  xpEarned: number;
  donEarned: number;
  date: Date;
  durationSeconds: number;
}

export interface ReviewItemView {
  question: QuestionView & { correctIndex: number; explanation: LocalizedText };
  selectedIndex: number | null;
  isCorrect: boolean;
}

export function toProfileView(p: LearningProfile): ProfileView {
  return {
    grade: p.grade,
    subjects: p.subjects.map(toApiSubject),
    updatedAt: p.updatedAt,
  };
}

export function toQuestionView(q: LearningQuestion): QuestionView {
  return {
    id: q.id,
    difficulty: q.difficulty,
    topic: q.topic as unknown as LocalizedText,
    prompt: q.prompt as unknown as LocalizedText,
    options: q.options as unknown as LocalizedText[],
  };
}

export function toAnswerView(a: LearningAnswer, q: LearningQuestion): AnswerView {
  return {
    questionId: a.questionId,
    selectedIndex: a.selectedIndex,
    isCorrect: a.isCorrect,
    correctIndex: q.answerIndex,
    explanation: q.explanation as unknown as LocalizedText,
  };
}

export function toResultView(a: LearningAttempt): ResultView {
  const completedAt = a.completedAt ?? a.startedAt;
  return {
    id: a.id,
    subject: toApiSubject(a.subject),
    topic: (a.topic as unknown as LocalizedText | null) ?? null,
    correct: a.correct,
    total: a.total,
    percent: percentOf(a.correct, a.total),
    isDaily: a.isDaily,
    xpEarned: a.xpEarned,
    donEarned: a.donEarned,
    date: completedAt,
    durationSeconds: Math.max(
      0,
      Math.round((completedAt.getTime() - a.startedAt.getTime()) / 1000),
    ),
  };
}
