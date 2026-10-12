import { z } from 'zod';

import { hhmmToMinutes } from '@/lib/utils';
import { hhmmSchema, msg, requiredText } from './common';

/**
 * School Mode kiruvchi ma'lumotlari. Umumiy xabarlar — `msg.*`; modulga xos
 * xabarlar — `schoolMode.validation.*` (UI `t()` bilan tarjima qiladi).
 */
export const smMsg = {
  overlap: 'schoolMode.validation.overlap',
  edgeLesson: 'schoolMode.validation.edgeLesson',
  untilPast: 'schoolMode.validation.untilPast',
  untilTooFar: 'schoolMode.validation.untilTooFar',
  alreadyActive: 'schoolMode.validation.alreadyActive',
  appExists: 'schoolMode.validation.appExists',
} as const;

export const BLOCKABLE_CATEGORIES = ['GAME', 'SOCIAL', 'VIDEO'] as const;
export const APP_CATEGORIES = ['GAME', 'SOCIAL', 'VIDEO', 'EDU', 'OTHER'] as const;
export const MAX_PERIODS = 24;

export const policyPatchSchema = z.object({
  blockedCategories: z.array(z.enum(BLOCKABLE_CATEGORIES)).min(1, msg.atLeastOne).optional(),
  relaxDuringBreaks: z.boolean().optional(),
  enabled: z.boolean().optional(),
  /** Siyosat qo'llanadigan smenalar (sinf → smena → siyosat). */
  shiftIds: z.array(z.string().min(1)).optional(),
});

export const allowedAppSchema = z.object({
  name: requiredText(40),
  category: z.enum(APP_CATEGORIES),
});

export const bellPeriodInputSchema = z
  .object({ start: hhmmSchema, end: hhmmSchema, kind: z.enum(['LESSON', 'BREAK']) })
  .refine((p) => hhmmToMinutes(p.end) > hhmmToMinutes(p.start), { message: msg.endBeforeStart, path: ['end'] });

/** Davrlar: vaqt bo'yicha o'sib boradi, ustma-ust tushmaydi, dars bilan boshlanib dars bilan tugaydi. */
export const shiftUpdateSchema = z
  .object({
    weekdays: z
      .array(z.number().int().min(1).max(7))
      .min(1, msg.atLeastOne)
      .refine((days) => new Set(days).size === days.length, msg.atLeastOne),
    periods: z.array(bellPeriodInputSchema).min(1, msg.atLeastOne).max(MAX_PERIODS, msg.tooLong),
  })
  .superRefine((value, ctx) => {
    const { periods } = value;
    for (let i = 1; i < periods.length; i++) {
      const prev = periods[i - 1];
      const cur = periods[i];
      if (prev && cur && hhmmToMinutes(cur.start) < hhmmToMinutes(prev.end)) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, message: smMsg.overlap, path: ['periods', i, 'start'] });
        return;
      }
    }
    const first = periods[0];
    const last = periods[periods.length - 1];
    if ((first && first.kind !== 'LESSON') || (last && last.kind !== 'LESSON')) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, message: smMsg.edgeLesson, path: ['periods'] });
    }
  });

/** `until` — ISO sana-vaqt yoki bugungi "HH:MM". Muddat chegaralari servisda (demo soati bo'yicha). */
export const exceptionInputSchema = z.object({
  studentId: z.string().min(1, msg.required),
  until: z
    .string()
    .trim()
    .min(1, msg.required)
    .refine((v) => /^([01]\d|2[0-3]):[0-5]\d$/.test(v) || !Number.isNaN(Date.parse(v)), msg.time),
  reason: requiredText(300),
});

export const emergencyInputSchema = z
  .object({
    scope: z.enum(['SCHOOL', 'CLASS']),
    classIds: z.array(z.string().min(1)).default([]),
    reason: requiredText(300),
  })
  .refine((v) => v.scope === 'SCHOOL' || v.classIds.length > 0, { message: msg.atLeastOne, path: ['classIds'] });

export const remindInputSchema = z.array(z.string().min(1)).min(1, msg.atLeastOne).max(1000, msg.tooLong);

export type PolicyPatch = z.input<typeof policyPatchSchema>;
export type AllowedAppInput = z.input<typeof allowedAppSchema>;
export type BellPeriodInput = z.input<typeof bellPeriodInputSchema>;
export type ShiftUpdateInput = z.input<typeof shiftUpdateSchema>;
export type ExceptionInput = z.input<typeof exceptionInputSchema>;
export type EmergencyInput = z.input<typeof emergencyInputSchema>;
