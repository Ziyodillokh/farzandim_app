// Bola ovozi sxemalari (school-panel/src/data/schemas/care.ts) + bola
// ilovasidan keladigan javob va murojaat.

import { z } from 'zod';
import { isoDateSchema, msg, requiredText } from '../common/school-zod';

export const AGE_GROUPS = ['G1_4', 'G5_8', 'G9_11'] as const;
export const CARE_TOPICS = ['WELLBEING', 'LEARNING', 'PEERS', 'SAFETY', 'SUPPORT', 'FEEDBACK'] as const;
export const CARE_REQUEST_STATUSES = ['NEW', 'IN_PROGRESS', 'SCHEDULED', 'RESOLVED'] as const;
export const CARE_BREAKDOWNS = ['SCHOOL', 'AGE_GROUP', 'GRADE', 'CLASS'] as const;
export const CARE_TOPIC_TAGS = ['LEARNING', 'PEERS', 'BULLYING', 'FAMILY', 'EMOTIONS', 'SAFETY', 'OTHER'] as const;
export const MAX_SURVEY_QUESTIONS = 12;

export type AgeGroup = (typeof AGE_GROUPS)[number];
export type CareTopic = (typeof CARE_TOPICS)[number];
export type CareBreakdown = (typeof CARE_BREAKDOWNS)[number];
export type CareRequestStatus = (typeof CARE_REQUEST_STATUSES)[number];

export const ageGroupOf = (grade: number): AgeGroup => (grade <= 4 ? 'G1_4' : grade <= 8 ? 'G5_8' : 'G9_11');

const ageGroupsSchema = z.array(z.enum(AGE_GROUPS)).min(1, msg.atLeastOne);

export const careAggregateQuerySchema = z.object({
  surveyId: z.string().min(1).optional(),
  breakdown: z.enum(CARE_BREAKDOWNS),
});

export const careStatusSchema = z.object({ status: z.enum(CARE_REQUEST_STATUSES) });
export const careNoteSchema = z.object({ text: requiredText(1000) });

/** "YYYY-MM-DDTHH:MM" (datetime-local, Toshkent vaqti) yoki to'liq ISO. */
export const careMeetingSchema = z.object({
  meetingAt: z
    .string({ error: msg.required })
    .min(1, msg.required)
    .refine((v) => /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(v) && !Number.isNaN(Date.parse(v)), msg.date),
});

export const careSurveyInputSchema = z.object({
  title: requiredText(120),
  weekStart: isoDateSchema,
  ageGroups: ageGroupsSchema,
  questionIds: z.array(z.string().min(1)).min(1, msg.atLeastOne).max(MAX_SURVEY_QUESTIONS, msg.tooLong),
});

export const careQuestionInputSchema = z.object({
  text: z.object({ uz: requiredText(220), ru: requiredText(220) }),
  topic: z.enum(CARE_TOPICS),
  ageGroups: ageGroupsSchema,
  reverse: z.boolean(),
  active: z.boolean(),
});

export const careRequestFilterSchema = z.object({
  status: z.enum(CARE_REQUEST_STATUSES).optional(),
  urgency: z.enum(['NORMAL', 'URGENT']).optional(),
  search: z.string().trim().max(100).optional(),
});

/** Bola ilovasi: so'rovnoma javoblari (savol → 1..5). */
export const careAnswersSchema = z.object({
  answers: z
    .record(z.string().min(1).max(64), z.number().int().min(1).max(5))
    .refine((a) => Object.keys(a).length >= 1, msg.atLeastOne)
    .refine((a) => Object.keys(a).length <= MAX_SURVEY_QUESTIONS, msg.tooLong),
});

/** Bola ilovasi: psixologga murojaat. */
export const careRequestInputSchema = z.object({
  topic: z.enum(CARE_TOPIC_TAGS),
  message: requiredText(1000),
  urgency: z.enum(['NORMAL', 'URGENT']).default('NORMAL'),
});
