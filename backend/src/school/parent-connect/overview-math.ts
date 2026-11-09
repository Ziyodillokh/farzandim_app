// "Farzandim maktabda" statistikasi — sof hisob-kitoblar (testlanadi).
// Reyting va boshqa bolalar bilan shaxsiy solishtirish YO'Q: sinf bilan faqat
// o'rtacha (kamida K o'quvchi bo'lsa).

import { AttendanceStatus } from '@prisma/client';
import { addDays, isoWeekday } from '../../common/time/tashkent';
import { hhmmToMinutes, minutesToHhmm } from '../attendance/attendance-time';
import { addCount, attendedRate, DayCounts, EMPTY_COUNTS } from '../attendance/attendance-view';

/** Sinf o'rtachasi kamida shuncha o'quvchi bo'lsa ko'rsatiladi (maxfiylik). */
export const CLASS_MIN_STUDENTS = 5;
/** Haftalik dinamika — oxirgi nechta hafta. */
export const TREND_WEEKS = 8;

export interface OverviewDay {
  date: string;
  schoolDay: boolean;
  status: AttendanceStatus | null;
  inAt: string | null;
}

export interface Period {
  kind: 'QUARTER' | 'YEAR';
  no: number | null;
  from: string;
  to: string;
}

/** Joriy chorak (maktab sozlamasida bo'lsa), aks holda o'quv yili (1-sentabrdan). */
export function pickPeriod(quarters: unknown, today: string): Period {
  const list = Array.isArray(quarters) ? quarters : [];
  for (const raw of list) {
    const q = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
    const start = typeof q.start === 'string' ? q.start : '';
    const end = typeof q.end === 'string' ? q.end : '';
    if (/^\d{4}-\d{2}-\d{2}$/.test(start) && /^\d{4}-\d{2}-\d{2}$/.test(end) && start <= today && today <= end) {
      return { kind: 'QUARTER', no: typeof q.no === 'number' ? q.no : null, from: start, to: today };
    }
  }
  const year = Number(today.slice(0, 4));
  const month = Number(today.slice(5, 7));
  return { kind: 'YEAR', no: null, from: `${month >= 9 ? year : year - 1}-09-01`, to: today };
}

/** Belgilangan o'quv kunlari bo'yicha hisob (bugun hali belgilanmagan bo'lsa — kutilmoqda). */
export function attendanceCounts(days: readonly OverviewDay[]): DayCounts {
  return days.filter((d) => d.schoolDay).reduce((acc, d) => addCount(acc, d.status), EMPTY_COUNTS);
}

/** Kelgan kunlardagi o'rtacha kirish vaqti ("08:09") yoki `null`. */
export function averageArrival(days: readonly OverviewDay[]): string | null {
  const minutes = days
    .filter((d) => d.schoolDay && d.inAt && (d.status === 'PRESENT' || d.status === 'LATE' || d.status === 'LEFT_EARLY'))
    .map((d) => hhmmToMinutes(d.inAt!))
    .filter((m) => Number.isFinite(m));
  if (minutes.length === 0) return null;
  return minutesToHhmm(minutes.reduce((a, b) => a + b, 0) / minutes.length);
}

/**
 * O'z vaqtida kelish seriyasi: oxirgi o'quv kunidan orqaga — `PRESENT` (kechikmasdan)
 * kunlar. Hali belgilanmagan oxirgi kun (masalan, bugun ertalab) seriyani uzmaydi.
 */
export function onTimeStreak(days: readonly OverviewDay[]): number {
  const school = days.filter((d) => d.schoolDay).sort((a, b) => b.date.localeCompare(a.date));
  let streak = 0;
  for (const [i, d] of school.entries()) {
    if (d.status === null && i === 0) continue;
    if (d.status !== 'PRESENT') break;
    streak += 1;
  }
  return streak;
}

/** Oxirgi `weeks` hafta (dushanbadan) bo'yicha kelish foizi; belgilangan kun yo'q — `null`. */
export function weeklyRates(days: readonly OverviewDay[], today: string, weeks = TREND_WEEKS) {
  const monday = addDays(today, 1 - isoWeekday(today));
  const byDate = new Map(days.map((d) => [d.date, d]));
  return Array.from({ length: weeks }, (_, k) => {
    const start = addDays(monday, -7 * (weeks - 1 - k));
    const week = Array.from({ length: 7 }, (_, i) => byDate.get(addDays(start, i))).filter(
      (d): d is OverviewDay => Boolean(d && d.date <= today),
    );
    const counts = attendanceCounts(week);
    return { weekStart: start, rate: counts.total - counts.pending > 0 ? attendedRate(counts) : null };
  });
}

/** Sinf o'rtachasi (foiz) — o'quvchilar soni chegaradan kam bo'lsa `null`. */
export function classAverage(students: number, attended: number, marked: number): number | null {
  if (students < CLASS_MIN_STUDENTS || marked <= 0) return null;
  return Math.round((attended / marked) * 100);
}
