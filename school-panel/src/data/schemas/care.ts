import { z } from 'zod';
import { isoDateSchema, msg, requiredText } from './common';

/**
 * Bola ovozi sxemalari — forma va mock servis bir xil sxemadan foydalanadi.
 * Xabarlar — i18n kalitlari (`errors.form.*`).
 */
export const AGE_GROUPS = ['G1_4', 'G5_8', 'G9_11'] as const;
export const CARE_TOPICS = ['WELLBEING', 'LEARNING', 'PEERS', 'SAFETY', 'SUPPORT', 'FEEDBACK'] as const;
export const CARE_REQUEST_STATUSES = ['NEW', 'IN_PROGRESS', 'SCHEDULED', 'RESOLVED'] as const;
export const CARE_BREAKDOWNS = ['SCHOOL', 'AGE_GROUP', 'GRADE', 'CLASS'] as const;

export const MAX_SURVEY_QUESTIONS = 12;

const ageGroupsSchema = z.array(z.enum(AGE_GROUPS)).min(1, msg.atLeastOne);

export const careAggregateQuerySchema = z.object({
  surveyId: z.string().min(1).optional(),
  breakdown: z.enum(CARE_BREAKDOWNS),
});

export const careStatusSchema = z.object({ status: z.enum(CARE_REQUEST_STATUSES) });

export const careNoteSchema = z.object({ text: requiredText(1000) });

/** "YYYY-MM-DDTHH:MM" (datetime-local) yoki to'liq ISO. */
export const careMeetingSchema = z.object({
  meetingAt: z
    .string({ required_error: msg.required })
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

export type CareAggregateQuery = z.input<typeof careAggregateQuerySchema>;
export type CareBreakdown = (typeof CARE_BREAKDOWNS)[number];
export type CareSurveyInput = z.input<typeof careSurveyInputSchema>;
export type CareQuestionInput = z.input<typeof careQuestionInputSchema>;
