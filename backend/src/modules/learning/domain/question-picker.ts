// Adaptiv savol tanlash — bola ilovasidagi `pickQuestions` bilan bir xil
// qoida: so'nggi natija → maqsadli qiyinlik (past → oson, o'rta → o'rta,
// yuqori → qiyin), sinfga mos va yaqinda ko'rilmagan savollar birinchi,
// bir urug'da tanlov barqaror, natija osondan qiyinga tartiblanadi.

import { DayKey } from '../../../common/time/tashkent';
import { SUCCESS_PERCENT } from './rewards';

export interface PickableQuestion {
  id: string;
  difficulty: number;
  minGrade: number;
  maxGrade: number;
}

export function targetDifficulty(recentPercent: number | null): number {
  if (recentPercent === null) return 1;
  if (recentPercent >= SUCCESS_PERCENT) return 3;
  if (recentPercent >= 60) return 2;
  return 1;
}

export function gradeDistance(q: PickableQuestion, grade: number): number {
  if (grade < q.minGrade) return q.minGrade - grade;
  if (grade > q.maxGrade) return grade - q.maxGrade;
  return 0;
}

/** Barqaror psevdo-tasodifiy generator (mulberry32). */
export function seededRandom(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function shuffled<T>(items: readonly T[], seed: number): T[] {
  const random = seededRandom(seed);
  const result = [...items];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

export function pickQuestions<T extends PickableQuestion>(params: {
  pool: readonly T[];
  grade: number;
  count: number;
  recentPercent: number | null;
  recentlySeen: ReadonlySet<string>;
  seed: number;
}): T[] {
  const { pool, grade, count, recentPercent, recentlySeen, seed } = params;
  if (pool.length === 0 || count <= 0) return [];
  const target = targetDifficulty(recentPercent);
  const cost = (q: T) =>
    gradeDistance(q, grade) * 10 +
    (recentlySeen.has(q.id) ? 4 : 0) +
    Math.abs(q.difficulty - target);
  return shuffled(pool, seed)
    .map((q, order) => ({ q, order, cost: cost(q) }))
    .sort((a, b) => a.cost - b.cost || a.order - b.order)
    .slice(0, count)
    .map((x) => x.q)
    .sort((a, b) => a.difficulty - b.difficulty);
}

/** Kun + fan (+ amaliyot raqami) uchun barqaror urug'. */
export function attemptSeed(day: DayKey, subjectIndex: number, ordinal: number): number {
  const [y, m, d] = day.split('-').map(Number);
  return ((y * 10000 + m * 100 + d) * 31 + subjectIndex) * 97 + ordinal;
}
