// Haftalik o'quv faolligi (I02) — sof funksiyalar (DB'siz).
//
// Hafta: ISO (dushanba–yakshanba), Toshkent kuni. Urinishning kuni — `LearningAttempt.day`
// (boshlangan Toshkent kuni; `learning-stats.ts` va ota-ona hisoboti ham shunday).

import { addDays, DayKey, isoWeekStart } from '../../../common/time/tashkent';
import { streakFromDays } from './learning-stats';

/** Bitta urinishning hisoblanadigan eng uzun davomiyligi (daqiqa) — uzoq qolib ketgan urinish uchun. */
export const MAX_ATTEMPT_MINUTES = 60;
const SECONDS_PER_MINUTE = 60;
const MS_PER_SECOND = 1000;
const DAYS_PER_WEEK = 7;
/** Streak hisobi uchun orqaga qaraladigan kunlar (chegarasiz tarixni skanerlamaslik uchun). */
export const STREAK_LOOKBACK_DAYS = 366;

export interface WeeklyAttempt {
  day: DayKey;
  startedAt: Date;
  completedAt: Date | null;
}

export interface WeekSummary {
  weekStart: DayKey;
  sessions: number;
  minutes: number;
  activeDays: number;
  streak: number;
}

export interface WeeklyReport {
  weeks: WeekSummary[];
  firstWeek: boolean;
}

/** Urinish davomiyligi, soniya (natija ko'rinishidagi `durationSeconds` bilan bir xil). */
export function attemptDurationSeconds(attempt: Pick<WeeklyAttempt, 'startedAt' | 'completedAt'>): number {
  if (!attempt.completedAt) return 0;
  return Math.max(
    0,
    Math.round((attempt.completedAt.getTime() - attempt.startedAt.getTime()) / MS_PER_SECOND),
  );
}

/** Daqiqa: har urinish MAX_ATTEMPT_MINUTES bilan cheklanadi, yig'indi yaxlitlanadi. */
export function cappedMinutes(attempts: readonly WeeklyAttempt[]): number {
  const capSeconds = MAX_ATTEMPT_MINUTES * SECONDS_PER_MINUTE;
  const seconds = attempts.reduce((sum, a) => sum + Math.min(attemptDurationSeconds(a), capSeconds), 0);
  return Math.round(seconds / SECONDS_PER_MINUTE);
}

function summarizeWeek(
  weekStart: DayKey,
  asOf: DayKey,
  attempts: readonly WeeklyAttempt[],
  completedDays: ReadonlySet<DayKey>,
): WeekSummary {
  const weekEnd = addDays(weekStart, DAYS_PER_WEEK - 1);
  const inWeek = attempts.filter((a) => a.day >= weekStart && a.day <= weekEnd);
  return {
    weekStart,
    sessions: inWeek.length,
    minutes: cappedMinutes(inWeek),
    activeDays: new Set(inWeek.map((a) => a.day)).size,
    streak: streakFromDays(completedDays, asOf),
  };
}

/**
 * Joriy va oldingi ISO hafta (eskisi birinchi).
 *
 * - `attempts` — shu ikki haftadagi YAKUNLANGAN urinishlar;
 * - `completedDays` — streak uchun yakunlangan urinishli kunlar (kamida `STREAK_LOOKBACK_DAYS`
 *   orqaga; `today`dan keyingisi bo'lmaydi);
 * - streak — hafta oxirigacha (joriy hafta: bugungacha), `learning-stats.ts` qoidasi bilan;
 * - `hasEarlierActivity` — joriy haftadan OLDIN yakunlangan urinish bor (`firstWeek` = yo'q).
 *   Alohida beriladi: streak oynasi bilan cheklanmasin.
 */
export function buildWeeklyReport(params: {
  today: DayKey;
  attempts: readonly WeeklyAttempt[];
  completedDays: ReadonlySet<DayKey>;
  hasEarlierActivity: boolean;
}): WeeklyReport {
  const { today, attempts, completedDays, hasEarlierActivity } = params;
  const currentStart = isoWeekStart(today);
  const previousStart = addDays(currentStart, -DAYS_PER_WEEK);
  const previousEnd = addDays(currentStart, -1);
  return {
    weeks: [
      summarizeWeek(previousStart, previousEnd, attempts, completedDays),
      summarizeWeek(currentStart, today, attempts, completedDays),
    ],
    firstWeek: !hasEarlierActivity,
  };
}
