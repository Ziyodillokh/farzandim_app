import type { Mastery } from '@/data/contracts';

export const DIFFICULTY_LEVELS = ['level1', 'level2', 'level3'] as const;
export type DifficultyLevel = (typeof DIFFICULTY_LEVELS)[number];

/** Tartibli (ordinal) ko'k shkala: oson → murakkab, ikkala mavzuda ham fon bilan farqlanadi. */
export const DIFFICULTY_COLORS: Record<DifficultyLevel, string> = {
  level1: '#38bdf8',
  level2: '#3b82f6',
  level3: '#1d4ed8',
};

/** Qiyinlik ma'lumoti bormi (o'zlashtirish yo'q bo'lsa servis nollar qaytaradi). */
export function hasDifficulty(d: Mastery['difficulty']): boolean {
  return d.level1 + d.level2 + d.level3 > 0;
}
