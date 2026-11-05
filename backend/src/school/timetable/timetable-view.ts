// Dars jadvali ko'rinishlari (sof): kunlik jadval va dam olish kuni sababi.

import { SchoolTimetableLesson } from '@prisma/client';
import { isoWeekday } from '../../common/time/tashkent';
import { BellPeriod } from '../school-mode/school-mode-time';
import { lessonPeriods } from './timetable-rules';

export type DayOff = { reason: 'WEEKEND' } | { reason: 'HOLIDAY'; name: string };

export interface ChildLesson {
  periodNo: number;
  start: string;
  end: string;
  subject: string;
  room: string | null;
  teacherName: string | null;
}

/** Hafta kuni smena o'quv kunlaridan emas -> WEEKEND; bayram -> HOLIDAY (nomi bilan). */
export function dayOffOf(
  date: string,
  shift: { weekdays: readonly number[] },
  holidays: ReadonlyMap<string, string>,
): DayOff | null {
  if (!shift.weekdays.includes(isoWeekday(date))) return { reason: 'WEEKEND' };
  const holiday = holidays.get(date);
  return holiday === undefined ? null : { reason: 'HOLIDAY', name: holiday };
}

/**
 * Kunning darslari: vaqtlar smena davrlaridan. Smenada endi yo'q davr (qo'ng'iroq jadvali
 * keyin o'zgargan) — vaqtini bilib bo'lmaydi, o'tkazib yuboriladi.
 */
export function lessonsForDay(
  lessons: readonly SchoolTimetableLesson[],
  periods: readonly BellPeriod[],
  weekday: number,
): ChildLesson[] {
  const byNo = new Map(lessonPeriods(periods).map((p) => [p.no, p]));
  return lessons
    .filter((l) => l.weekday === weekday)
    .sort((a, b) => a.periodNo - b.periodNo)
    .flatMap((l): ChildLesson[] => {
      const period = byNo.get(l.periodNo);
      return period
        ? [{ periodNo: l.periodNo, start: period.start, end: period.end, subject: l.subject, room: l.room, teacherName: l.teacherName }]
        : [];
    });
}
