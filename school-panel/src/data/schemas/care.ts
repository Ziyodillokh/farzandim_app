import { z } from 'zod';
import { hhmmSchema, isoDateSchema, msg, requiredText } from './common';

/**
 * Bola ovozi sxemalari — forma va mock servis bir xil sxemadan foydalanadi.
 * Xabarlar — i18n kalitlari (`errors.form.*`).
 */
export const AGE_GROUPS = ['G1_4', 'G5_8', 'G9_11'] as const;
export const CARE_TOPICS = ['WELLBEING', 'LEARNING', 'PEERS', 'SAFETY', 'SUPPORT', 'FEEDBACK'] as const;
export const CARE_REQUEST_STATUSES = ['NEW', 'IN_PROGRESS', 'SCHEDULED', 'RESOLVED'] as const;
export const CARE_BREAKDOWNS = ['SCHOOL', 'AGE_GROUP', 'GRADE', 'CLASS'] as const;

export const MAX_SURVEY_QUESTIONS = 12;

/** Sozlamalar chegaralari — forma, mock servis va backend (kontrakt C) bir xil. */
export const CARE_SETTINGS_LIMITS = {
  displayName: 40,
  urgentSlaMinutes: { min: 15, max: 1440 },
  normalSlaHours: { min: 1, max: 168 },
} as const;

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

const careSettingsMsg = {
  slaMinutes: 'errors.form.slaMinutesRange',
  slaHours: 'errors.form.slaHoursRange',
  deputySame: 'errors.form.deputySame',
  duplicateDay: 'errors.form.duplicateDay',
} as const;

const staffIdSchema = z.string().min(1, msg.required).nullable();
/** Bo'sh qator — «ko'rsatilmagan» (null): bolaga xodimning to'liq ismi ko'rinadi. */
const displayNameSchema = z
  .string()
  .trim()
  .max(CARE_SETTINGS_LIMITS.displayName, msg.tooLong)
  .nullable()
  .transform((v) => (v ? v : null));
const numberIn = (min: number, max: number, message: string) =>
  z.number({ required_error: msg.required, invalid_type_error: message }).int(message).min(min, message).max(max, message);

export const careSettingsInputSchema = z
  .object({
    psychologistStaffId: staffIdSchema,
    psychologistDisplayName: displayNameSchema,
    deputyStaffId: staffIdSchema,
    deputyDisplayName: displayNameSchema,
    workDays: z
      .array(z.number().int().min(1).max(7))
      .min(1, msg.atLeastOne)
      .refine((days) => new Set(days).size === days.length, careSettingsMsg.duplicateDay),
    workStart: hhmmSchema,
    workEnd: hhmmSchema,
    urgentSlaMinutes: numberIn(CARE_SETTINGS_LIMITS.urgentSlaMinutes.min, CARE_SETTINGS_LIMITS.urgentSlaMinutes.max, careSettingsMsg.slaMinutes),
    normalSlaHours: numberIn(CARE_SETTINGS_LIMITS.normalSlaHours.min, CARE_SETTINGS_LIMITS.normalSlaHours.max, careSettingsMsg.slaHours),
  })
  .refine((v) => v.workStart < v.workEnd, { path: ['workEnd'], message: msg.endBeforeStart })
  .refine((v) => !v.deputyStaffId || v.deputyStaffId !== v.psychologistStaffId, { path: ['deputyStaffId'], message: careSettingsMsg.deputySame });

export type CareAggregateQuery = z.input<typeof careAggregateQuerySchema>;
export type CareBreakdown = (typeof CARE_BREAKDOWNS)[number];
export type CareSurveyInput = z.input<typeof careSurveyInputSchema>;
export type CareQuestionInput = z.input<typeof careQuestionInputSchema>;
export type CareSettingsInput = z.input<typeof careSettingsInputSchema>;
