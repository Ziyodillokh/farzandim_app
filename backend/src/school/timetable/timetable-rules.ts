// Dars jadvali qoidalari (sof funksiyalar): fan kaliti normallashtirish, smenaga mosligi,
// takrorlar. Smena davrlari `periods` JSON — faqat DARS (LESSON) davrlari jadvalga qo'yiladi.

import { invalid } from '../common/school-errors';
import { BellPeriod } from '../school-mode/school-mode-time';
import { LessonInput, SUBJECT_KEYS, timetableMsg } from './timetable.schemas';

/** 'MATH' / ' math ' -> 'math' (LearningSubject kaliti); erkin nom o'zgarishsiz. */
export function normalizeSubject(subject: string): string {
  const trimmed = subject.trim();
  const lower = trimmed.toLowerCase();
  return SUBJECT_KEYS.has(lower) ? lower : trimmed;
}

/** Bazadagi `periods` JSON -> tur (buzilgan elementlar tashlanadi). */
export function parsePeriods(value: unknown): BellPeriod[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((item): BellPeriod[] => {
    const p = item as Partial<BellPeriod> | null;
    const ok =
      p &&
      typeof p.no === 'number' &&
      typeof p.start === 'string' &&
      typeof p.end === 'string' &&
      (p.kind === 'LESSON' || p.kind === 'BREAK');
    return ok ? [{ no: p.no!, start: p.start!, end: p.end!, kind: p.kind! }] : [];
  });
}

export const lessonPeriods = (periods: readonly BellPeriod[]): BellPeriod[] => periods.filter((p) => p.kind === 'LESSON');

/**
 * Darslar shu smenaga mosmi: hafta kuni smena o'quv kunlaridan, `periodNo` — smenadagi DARS
 * davri, (kun, davr) takrorlanmaydi. Birinchi xato `lessons.<i>.<maydon>: <kalit>` bilan.
 */
export function assertLessonsFitShift(
  lessons: readonly LessonInput[],
  shift: { weekdays: readonly number[]; periods: readonly BellPeriod[] },
): void {
  const periodNos = new Set(lessonPeriods(shift.periods).map((p) => p.no));
  const seen = new Set<string>();
  lessons.forEach((lesson, i) => {
    if (!shift.weekdays.includes(lesson.weekday)) throw invalid(`lessons.${i}.weekday: ${timetableMsg.weekday}`);
    if (!periodNos.has(lesson.periodNo)) throw invalid(`lessons.${i}.periodNo: ${timetableMsg.period}`);
    const key = `${lesson.weekday}:${lesson.periodNo}`;
    if (seen.has(key)) throw invalid(`lessons.${i}.periodNo: ${timetableMsg.duplicate}`);
    seen.add(key);
  });
}
