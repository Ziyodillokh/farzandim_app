// Ota-ona xulosasi va haftalik hisobot ko'rsatkichlari — sof funksiyalar.
// Bola ilovasidagi `learning_stats.dart` bilan bir xil ta'riflar.

import { LearningSubject } from '@prisma/client';
import { addDays, DayKey } from '../../../common/time/tashkent';
import { percentOf } from './rewards';
import { ApiSubject, toApiSubject } from './subjects';

export interface StatResult {
  subject: LearningSubject;
  correct: number;
  total: number;
  day: DayKey;
}

export interface SubjectStat {
  subject: ApiSubject;
  percent: number;
  tests: number;
}

export interface LearningSummary {
  from: DayKey;
  to: DayKey;
  periodDays: number;
  testsCount: number;
  correctAnswers: number;
  totalAnswers: number;
  /** Davr bo'yicha umumiy foiz (`null` — test yo'q). */
  overallPercent: number | null;
  /** Oldingi teng davr foizi. */
  previousPercent: number | null;
  /** `overall - previous` (ikkalasi bo'lsa). */
  growthPercent: number | null;
  subjects: SubjectStat[];
  strongSubject: ApiSubject | null;
  focusSubject: ApiSubject | null;
  activeDays: number;
  /** Ketma-ket test yechilgan kunlar (bugun yoki kechadan orqaga). */
  streakDays: number;
}

const inRange = (day: DayKey, from: DayKey, to: DayKey) => day >= from && day <= to;

function percent(results: readonly StatResult[]): number | null {
  const total = results.reduce((s, r) => s + r.total, 0);
  return total === 0 ? null : percentOf(results.reduce((s, r) => s + r.correct, 0), total);
}

export function learningStreak(results: readonly StatResult[], today: DayKey): number {
  const days = new Set(results.map((r) => r.day));
  let day = days.has(today) ? today : addDays(today, -1);
  let streak = 0;
  while (days.has(day)) {
    streak++;
    day = addDays(day, -1);
  }
  return streak;
}

/**
 * [results] — kamida `2 × periodDays` (o'sish uchun) va streak uchun
 * yetarli tarix. Fan tartibi: [order] (profil) birinchi, keyin boshqalar.
 */
export function summarizeLearning(params: {
  results: readonly StatResult[];
  today: DayKey;
  periodDays: number;
  order?: readonly LearningSubject[];
}): LearningSummary {
  const { results, today, periodDays, order = [] } = params;
  const from = addDays(today, -(periodDays - 1));
  const prevFrom = addDays(from, -periodDays);
  const prevTo = addDays(from, -1);

  const current = results.filter((r) => inRange(r.day, from, today));
  const previous = results.filter((r) => inRange(r.day, prevFrom, prevTo));
  const overallPercent = percent(current);
  const previousPercent = percent(previous);

  const subjectOrder = [
    ...order,
    ...Object.values(LearningSubject).filter((s) => !order.includes(s)),
  ];
  const subjects: SubjectStat[] = [];
  for (const subject of subjectOrder) {
    const own = current.filter((r) => r.subject === subject);
    const p = percent(own);
    if (p !== null) subjects.push({ subject: toApiSubject(subject), percent: p, tests: own.length });
  }
  let strong: SubjectStat | null = null;
  let weak: SubjectStat | null = null;
  for (const s of subjects) {
    if (!strong || s.percent > strong.percent) strong = s;
    if (!weak || s.percent < weak.percent) weak = s;
  }

  return {
    from,
    to: today,
    periodDays,
    testsCount: current.length,
    correctAnswers: current.reduce((s, r) => s + r.correct, 0),
    totalAnswers: current.reduce((s, r) => s + r.total, 0),
    overallPercent,
    previousPercent,
    growthPercent:
      overallPercent !== null && previousPercent !== null
        ? overallPercent - previousPercent
        : null,
    subjects,
    strongSubject: strong?.subject ?? null,
    focusSubject:
      weak && strong && weak.subject !== strong.subject ? weak.subject : null,
    activeDays: new Set(current.map((r) => r.day)).size,
    streakDays: learningStreak(results, today),
  };
}
