import { z } from 'zod';

import { msg } from './common';

/** Ma'lum fanlar (kichik harfli kalitlar) — backend shartnomasi. Boshqa fan — erkin matn. */
export const TIMETABLE_SUBJECT_KEYS = [
  'math',
  'native',
  'english',
  'russian',
  'history',
  'biology',
  'chemistry',
  'physics',
  'geography',
  'informatics',
] as const;

export type TimetableSubjectKey = (typeof TIMETABLE_SUBJECT_KEYS)[number];

export const TIMETABLE_WEEKDAYS = [1, 2, 3, 4, 5, 6] as const;

export const TIMETABLE_SUBJECT_MAX = 60;
export const TIMETABLE_ROOM_MAX = 20;
export const TIMETABLE_TEACHER_MAX = 80;
/** Bir kunda eng ko'pi bilan shuncha dars davri (himoya chegarasi). */
export const TIMETABLE_MAX_PERIOD_NO = 20;

const optionalField = (max: number) =>
  z
    .string()
    .trim()
    .max(max, msg.tooLong)
    .nullish()
    .transform((v) => (v ? v : undefined));

const lessonSchema = z.object({
  weekday: z.number().int().min(1).max(6),
  periodNo: z.number().int().min(1).max(TIMETABLE_MAX_PERIOD_NO),
  subject: z.string({ required_error: msg.required }).trim().min(1, msg.required).max(TIMETABLE_SUBJECT_MAX, msg.tooLong),
  room: optionalField(TIMETABLE_ROOM_MAX),
  teacherName: optionalField(TIMETABLE_TEACHER_MAX),
});

/** `PUT` tanasi: dars ro'yxati; (kun, davr) juftligi takrorlanmasligi shart. */
export const timetableInputSchema = z
  .object({ lessons: z.array(lessonSchema).max(TIMETABLE_WEEKDAYS.length * TIMETABLE_MAX_PERIOD_NO) })
  .superRefine((value, ctx) => {
    const seen = new Set<string>();
    value.lessons.forEach((lesson, index) => {
      const key = `${lesson.weekday}:${lesson.periodNo}`;
      if (seen.has(key)) ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['lessons', index], message: 'duplicate lesson' });
      seen.add(key);
    });
  });

export type TimetableParsed = z.output<typeof timetableInputSchema>;
