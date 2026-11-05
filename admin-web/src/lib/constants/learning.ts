/**
 * Kunlik o'quv (Daily Learning) — mavzular katalogi uchun YAGONA ro'yxatlar.
 *
 * Fan qiymatlari backend `API_SUBJECTS` (backend/src/modules/learning/domain/
 * subjects.ts) bilan bir xil: API kichik harfda ishlaydi (DB enum — `MATH`).
 * Chegaralar ham o'sha yerdagi `MIN_GRADE` / `MAX_GRADE` bilan mos.
 */
import type { LearningQuestionStatus, LearningSubject, LearningTopicStatus } from '@/types/api.types';

/** Tablar va formadagi tartib: aniq fanlar, tillar, keyin tabiiy fanlar. */
export const LEARNING_SUBJECTS: ReadonlyArray<{ value: LearningSubject; label: string }> = [
  { value: 'math', label: 'Matematika' },
  { value: 'native', label: 'Ona tili' },
  { value: 'english', label: 'Ingliz tili' },
  { value: 'russian', label: 'Rus tili' },
  { value: 'history', label: 'Tarix' },
  { value: 'biology', label: 'Biologiya' },
  { value: 'chemistry', label: 'Kimyo' },
  { value: 'physics', label: 'Fizika' },
  { value: 'geography', label: 'Geografiya' },
  { value: 'informatics', label: 'Informatika' },
];

export const DEFAULT_LEARNING_SUBJECT: LearningSubject = LEARNING_SUBJECTS[0]!.value;

export function isLearningSubject(value: string): value is LearningSubject {
  return LEARNING_SUBJECTS.some((s) => s.value === value);
}

export function subjectLabel(subject: string): string {
  return LEARNING_SUBJECTS.find((s) => s.value === subject)?.label ?? subject;
}

/**
 * Mavzu bolaga taklif qilinishi uchun kamida shuncha FAOL savol kerak
 * (backend bilan bir xil qoida). Undan kam bo'lsa panelda ogohlantiramiz.
 */
export const MIN_TOPIC_QUESTIONS = 10;

/** Sinflar chegarasi (backend `MIN_GRADE` / `MAX_GRADE`). */
export const MIN_GRADE = 1;
export const MAX_GRADE = 11;
export const GRADE_OPTIONS: readonly number[] = Array.from(
  { length: MAX_GRADE - MIN_GRADE + 1 },
  (_, i) => MIN_GRADE + i,
);

/** Mavzu kaliti: kichik lotin harf/raqam, so'zlar bitta `-` bilan (backend bilan bir xil). */
export const TOPIC_KEY_PATTERN = /^[a-z0-9]+(-[a-z0-9]+)*$/;
export const TOPIC_KEY_MAX = 80;

export const TOPIC_STATUS_LABELS: Record<LearningTopicStatus, string> = {
  ACTIVE: 'Faol',
  HIDDEN: 'Yashirin',
};

export const QUESTION_STATUS_LABELS: Record<LearningQuestionStatus, string> = {
  ACTIVE: 'Faol',
  DRAFT: 'Qoralama',
  ARCHIVED: 'Arxiv',
};

/** "5–7-sinf" yoki bitta sinf bo'lsa "5-sinf". */
export function gradeRangeLabel(minGrade: number, maxGrade: number): string {
  return minGrade === maxGrade ? `${minGrade}-sinf` : `${minGrade}–${maxGrade}-sinf`;
}
