import { z } from 'zod';
import { isoDateSchema, msg, optionalText } from './common';

export const MATERIAL_KINDS = ['AUDIOBOOK', 'VIDEO', 'TEST'] as const;
export const SUBJECTS = ['MATH', 'ENGLISH', 'HISTORY', 'LITERATURE', 'GEOGRAPHY', 'BIOLOGY', 'IT', 'NATIVE', 'PHYSICS', 'CHEMISTRY', 'RUSSIAN'] as const;

/** Yozma vazifaning `materialId` qiymati (katalogda material yo'q — backend shartnomasi). */
export const WRITTEN_MATERIAL_ID = 'written';
export const WRITTEN_TITLE_MAX = 120;
export const NOTE_MAX = 300;
export const ESTIMATED_MINUTES_MIN = 1;
export const ESTIMATED_MINUTES_MAX = 240;
export const REVIEW_NOTE_MAX = 500;

/** Topshiriq: material (yoki yozma vazifa) + sinf(lar) + muddat + izoh. */
export const assignmentInputSchema = z
  .object({
    materialId: z.string({ required_error: msg.required }).min(1, msg.required),
    classIds: z.array(z.string().min(1)).min(1, msg.atLeastOne),
    dueDate: isoDateSchema,
    note: optionalText(NOTE_MAX),
    /** Faqat yozma vazifada majburiy (≤ 120). */
    title: z.string().trim().max(WRITTEN_TITLE_MAX, msg.tooLong).optional(),
    /** Taxminiy vaqt, daqiqa — barcha turlarda ixtiyoriy. */
    estimatedMinutes: z
      .number({ invalid_type_error: msg.minutes })
      .int(msg.minutes)
      .min(ESTIMATED_MINUTES_MIN, msg.minutes)
      .max(ESTIMATED_MINUTES_MAX, msg.minutes)
      .optional(),
  })
  .superRefine((value, ctx) => {
    if (value.materialId === WRITTEN_MATERIAL_ID && !value.title?.trim()) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['title'], message: msg.required });
    }
  });

/** Topshirilgan ishni tekshirish: qabul qilish yoki izoh bilan qaytarish (qaytarishda izoh majburiy). */
export const reviewInputSchema = z
  .object({
    status: z.enum(['ACCEPTED', 'RETURNED']),
    note: z.string().trim().max(REVIEW_NOTE_MAX, msg.tooLong).optional(),
  })
  .superRefine((value, ctx) => {
    if (value.status === 'RETURNED' && !value.note?.trim()) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['note'], message: msg.required });
    }
  });

export const materialFilterSchema = z.object({
  kind: z.enum(MATERIAL_KINDS).optional(),
  subject: z.enum(SUBJECTS).optional(),
  grade: z.number().int().min(1).max(11).optional(),
  search: z.string().trim().max(80).optional(),
});

export type AssignmentInput = z.input<typeof assignmentInputSchema>;
export type MaterialFilter = z.input<typeof materialFilterSchema>;
export type ReviewInput = z.input<typeof reviewInputSchema>;
