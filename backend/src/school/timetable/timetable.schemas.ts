// Dars jadvali kirish sxemalari. Xabarlar — panel i18n kalitlari (`errors.form.*`).

import { LearningSubject } from '@prisma/client';
import { z } from 'zod';
import { msg } from '../common/school-zod';

export const TIMETABLE_MAX_WEEKDAY = 6;
export const MAX_SUBJECT = 60;
export const MAX_ROOM = 20;
export const MAX_TEACHER = 80;
/** Bitta sinf haftasi: 6 kun x eng ko'pi bilan shuncha dars. */
export const MAX_LESSONS = 6 * 15;

export const timetableMsg = {
  weekday: 'errors.form.invalidWeekday',
  period: 'errors.form.invalidPeriod',
  duplicate: 'errors.form.duplicate',
} as const;

/** Fan kalitlari: `LearningSubject` kichik harfda ('math', 'english', ...). */
export const SUBJECT_KEYS: ReadonlySet<string> = new Set(Object.values(LearningSubject).map((s) => s.toLowerCase()));

const optionalName = (max: number) =>
  z
    .string()
    .trim()
    .max(max, msg.tooLong)
    .nullish()
    .transform((v) => (v ? v : null));

export const lessonInputSchema = z.object({
  weekday: z.number({ error: msg.required }).int(timetableMsg.weekday).min(1, timetableMsg.weekday).max(TIMETABLE_MAX_WEEKDAY, timetableMsg.weekday),
  periodNo: z.number({ error: msg.required }).int(timetableMsg.period).min(1, timetableMsg.period).max(30, timetableMsg.period),
  subject: z.string({ error: msg.required }).trim().min(1, msg.required).max(MAX_SUBJECT, msg.tooLong),
  room: optionalName(MAX_ROOM),
  teacherName: optionalName(MAX_TEACHER),
});

export const timetableInputSchema = z.object({
  lessons: z.array(lessonInputSchema, { error: msg.required }).max(MAX_LESSONS, msg.tooLong),
});

export type LessonInput = z.output<typeof lessonInputSchema>;

/** Bola ilovasi: `?date=YYYY-MM-DD` (bo'sh — bugun, Toshkent). */
export const timetableDayQuerySchema = z.object({
  date: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, msg.date)
    .optional(),
});
