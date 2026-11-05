import type { Id } from './common';
import type { BellPeriod } from './school';

/** Dars jadvali haftasi: dushanba..shanba (ISO 1..6). Yakshanba — dars yo'q. */
export type TimetableWeekday = 1 | 2 | 3 | 4 | 5 | 6;

/**
 * Jadvaldagi bitta dars. `periodNo` — sinf smenasidagi DARS (LESSON) davrining raqami.
 * `subject` — kichik harfli fan kaliti (`math`, `native`, …) YOKI erkin matn (≤ 60 belgi).
 */
export type TimetableLesson = {
  weekday: TimetableWeekday;
  periodNo: number;
  subject: string;
  room?: string | null;
  teacherName?: string | null;
};

export type TimetableShift = { id: Id; name: string; periods: BellPeriod[] };

/** `GET /school/timetable/classes/:classId`. */
export type ClassTimetable = { classId: Id; shift: TimetableShift; lessons: TimetableLesson[] };

/** `PUT /school/timetable/classes/:classId` — haftani to'liq almashtiradi. */
export type TimetableInput = { lessons: TimetableLesson[] };

/** Mock baza yozuvi: sinfning haftalik jadvali. */
export type TimetableRecord = { classId: Id; lessons: TimetableLesson[] };
