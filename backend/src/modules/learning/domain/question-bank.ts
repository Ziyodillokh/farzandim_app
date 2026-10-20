// Savollar banki yozuvi validatsiyasi — admin importi, ma'lumot migratsiyasi
// generatori va admin CRUD bir xil qoidadan foydalanadi.

import { LearningSubject } from '@prisma/client';
import { LocalizedText, parseLocalized } from './localized';
import { MAX_GRADE, MIN_GRADE } from './subjects';

export const MIN_DIFFICULTY = 1;
export const MAX_DIFFICULTY = 3;
export const MIN_OPTIONS = 2;
export const MAX_OPTIONS = 6;

export const TEXT_LIMITS = {
  topic: 40,
  prompt: 400,
  option: 120,
  explanation: 600,
} as const;

export interface BankQuestion {
  externalId: string | null;
  subject: LearningSubject;
  difficulty: number;
  minGrade: number;
  maxGrade: number;
  topic: LocalizedText;
  prompt: LocalizedText;
  options: LocalizedText[];
  answerIndex: number;
  explanation: LocalizedText;
}

export type ParseResult =
  | { ok: true; value: BankQuestion }
  | { ok: false; error: string };

const isInt = (v: unknown): v is number => Number.isInteger(v);

/**
 * Bank formatidagi bitta savol (`{id, difficulty, grades:[min,max], topic,
 * question, options, answer, explanation}`) yoki admin formati
 * (`prompt`, `minGrade`, `maxGrade`, `answerIndex`).
 */
export function parseBankQuestion(
  raw: unknown,
  subject: LearningSubject,
): ParseResult {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return { ok: false, error: 'savol obyekt bo\'lishi kerak' };
  }
  const q = raw as Record<string, unknown>;

  const externalId = q.id ?? q.externalId ?? null;
  if (externalId !== null && (typeof externalId !== 'string' || !/^[a-z0-9_-]{1,64}$/i.test(externalId))) {
    return { ok: false, error: 'id: lotin harf/raqam, 64 belgigacha' };
  }

  const difficulty = q.difficulty;
  if (!isInt(difficulty) || difficulty < MIN_DIFFICULTY || difficulty > MAX_DIFFICULTY) {
    return { ok: false, error: `difficulty: ${MIN_DIFFICULTY}..${MAX_DIFFICULTY}` };
  }

  const grades = Array.isArray(q.grades) ? q.grades : [q.minGrade, q.maxGrade];
  const [minGrade, maxGrade] = grades;
  if (
    !isInt(minGrade) ||
    !isInt(maxGrade) ||
    minGrade < MIN_GRADE ||
    maxGrade > MAX_GRADE ||
    minGrade > maxGrade
  ) {
    return { ok: false, error: `grades: [min, max], ${MIN_GRADE}..${MAX_GRADE}` };
  }

  const topic = parseLocalized(q.topic, 'topic', TEXT_LIMITS.topic);
  if (!topic.ok) return topic;
  const prompt = parseLocalized(q.question ?? q.prompt, 'question', TEXT_LIMITS.prompt);
  if (!prompt.ok) return prompt;
  const explanation = parseLocalized(q.explanation, 'explanation', TEXT_LIMITS.explanation);
  if (!explanation.ok) return explanation;

  if (!Array.isArray(q.options) || q.options.length < MIN_OPTIONS || q.options.length > MAX_OPTIONS) {
    return { ok: false, error: `options: ${MIN_OPTIONS}..${MAX_OPTIONS} ta variant` };
  }
  const options: LocalizedText[] = [];
  for (const [i, option] of q.options.entries()) {
    const parsed = parseLocalized(option, `options[${i}]`, TEXT_LIMITS.option);
    if (!parsed.ok) return parsed;
    options.push(parsed.value);
  }
  for (const lang of ['uz', 'ru', 'en'] as const) {
    if (new Set(options.map((o) => o[lang])).size !== options.length) {
      return { ok: false, error: `options: ${lang} tilida takror variant` };
    }
  }

  const answerIndex = q.answer ?? q.answerIndex;
  if (!isInt(answerIndex) || answerIndex < 0 || answerIndex >= options.length) {
    return { ok: false, error: 'answer: variantlar oralig\'idagi indeks' };
  }

  return {
    ok: true,
    value: {
      externalId: externalId as string | null,
      subject,
      difficulty,
      minGrade,
      maxGrade,
      topic: topic.value,
      prompt: prompt.value,
      options,
      answerIndex,
      explanation: explanation.value,
    },
  };
}
