// Fanlar, sinflar va kunlik reja chegaralari — bola ilovasidagi
// (`farzandim_child/lib/features/learning/domain/subject.dart`) bilan bir xil.

import { LearningSubject } from '@prisma/client';

export const MIN_GRADE = 1;
export const MAX_GRADE = 11;
export const MIN_SUBJECTS = 1;
export const MAX_SUBJECTS = 5;

/** Har fan bo'yicha kunlik savollar soni. */
export const DAILY_QUESTION_COUNT = 10;

/** Fan maktabda o'qitila boshlanadigan sinf. */
export const SUBJECT_MIN_GRADE: Record<LearningSubject, number> = {
  MATH: 1,
  ENGLISH: 1,
  NATIVE: 1,
  HISTORY: 5,
  BIOLOGY: 5,
  GEOGRAPHY: 5,
  PHYSICS: 6,
  CHEMISTRY: 7,
  INFORMATICS: 5,
  RUSSIAN: 1,
};

/** API'dagi fan nomi (`math`) — ilovadagi enum nomi bilan bir xil. */
export const API_SUBJECTS = [
  'math',
  'english',
  'native',
  'history',
  'biology',
  'geography',
  'physics',
  'chemistry',
  'informatics',
  'russian',
] as const;

export type ApiSubject = (typeof API_SUBJECTS)[number];

export function toApiSubject(subject: LearningSubject): ApiSubject {
  return subject.toLowerCase() as ApiSubject;
}

export function fromApiSubject(value: string): LearningSubject | null {
  const upper = value.toUpperCase();
  return (Object.values(LearningSubject) as string[]).includes(upper)
    ? (upper as LearningSubject)
    : null;
}

export function isTaughtIn(subject: LearningSubject, grade: number): boolean {
  return grade >= SUBJECT_MIN_GRADE[subject];
}

/** Fan tartib raqami (urug' hisobi uchun barqaror). */
export function subjectIndex(subject: LearningSubject): number {
  return Object.values(LearningSubject).indexOf(subject);
}

/**
 * Profil validatsiyasi — xato matni yoki `null`. Fanlar takrorlanmasin,
 * soni chegarada va hammasi shu sinfda o'qitilsin.
 */
export function profileError(
  grade: number,
  subjects: readonly LearningSubject[],
): string | null {
  if (!Number.isInteger(grade) || grade < MIN_GRADE || grade > MAX_GRADE) {
    return `grade ${MIN_GRADE}..${MAX_GRADE} oralig'ida bo'lishi kerak`;
  }
  if (subjects.length < MIN_SUBJECTS || subjects.length > MAX_SUBJECTS) {
    return `${MIN_SUBJECTS}..${MAX_SUBJECTS} ta fan tanlanishi kerak`;
  }
  if (new Set(subjects).size !== subjects.length) {
    return 'fanlar takrorlanmasligi kerak';
  }
  const notTaught = subjects.filter((s) => !isTaughtIn(s, grade));
  if (notTaught.length > 0) {
    return `${notTaught.map(toApiSubject).join(', ')} ${grade}-sinfda o'qitilmaydi`;
  }
  return null;
}
