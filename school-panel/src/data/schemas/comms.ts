import { z } from 'zod';

import { isoDateSchema, msg, requiredText } from './common';

/** Xabar matni chegarasi (push + SMS zaxira; SMS 160 belgilik qismlarga bo'linadi). */
export const MESSAGE_BODY_MAX = 1000;
export const MESSAGE_TITLE_MAX = 120;
export const SMS_SEGMENT = 160;

/** `datetime-local` qiymati: "2026-10-14T08:00" (soniya ixtiyoriy). */
export const localDateTimeSchema = z
  .string({ required_error: msg.required })
  .regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$/, msg.date);

export const audienceSchema = z
  .object({
    kind: z.enum(['SCHOOL', 'CLASSES', 'GUARDIANS']),
    classIds: z.array(z.string().min(1)).default([]),
    guardianIds: z.array(z.string().min(1)).default([]),
  })
  .superRefine((value, ctx) => {
    if (value.kind === 'CLASSES' && value.classIds.length === 0) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['classIds'], message: msg.atLeastOne });
    }
    if (value.kind === 'GUARDIANS' && value.guardianIds.length === 0) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['guardianIds'], message: msg.atLeastOne });
    }
  })
  .transform((value) => ({
    kind: value.kind,
    classIds: value.kind === 'CLASSES' ? [...new Set(value.classIds)] : [],
    guardianIds: value.kind === 'GUARDIANS' ? [...new Set(value.guardianIds)] : [],
  }));

export const announcementInputSchema = z.object({
  title: requiredText(MESSAGE_TITLE_MAX),
  body: requiredText(MESSAGE_BODY_MAX),
  priority: z.enum(['NORMAL', 'IMPORTANT']),
  audience: audienceSchema,
});

export const reminderInputSchema = z.object({
  kind: z.enum(['MEETING', 'EXAM', 'EVENT', 'HOLIDAY', 'ANNOUNCEMENT', 'SCHEDULE_CHANGE']),
  title: requiredText(MESSAGE_TITLE_MAX),
  body: requiredText(500),
  audience: audienceSchema,
  sendAt: localDateTimeSchema,
  repeat: z.enum(['NONE', 'WEEKLY', 'MONTHLY']),
  active: z.boolean().default(true),
});

/** Izoh — "kim tasdiqladi" (buxgalteriya, chek va h.k.): audit uchun majburiy. */
const noteSchema = requiredText(300);

export const paymentShiftSchema = z.object({
  nextDate: isoDateSchema,
  note: noteSchema,
});

export const paymentPauseSchema = z.object({ note: noteSchema });

export const MAX_SHIFT_MONTHS = 12;

export const paymentBulkShiftSchema = z
  .object({
    ids: z.array(z.string().min(1)).min(1, msg.atLeastOne),
    months: z.number().int().min(1).max(MAX_SHIFT_MONTHS).optional(),
    date: isoDateSchema.optional(),
    note: noteSchema,
    /** Oylar bo'yicha surishda — "oldindan to'langan oylar" ham oshiriladi. */
    markPrepaid: z.boolean().default(false),
  })
  .refine((v) => (v.months === undefined) !== (v.date === undefined), { message: msg.required, path: ['months'] });

export const verificationAnswerSchema = z.object({
  text: requiredText(MESSAGE_BODY_MAX),
  newDate: isoDateSchema.nullable().default(null),
});

export type AudienceInput = z.input<typeof audienceSchema>;
export type AnnouncementInput = z.input<typeof announcementInputSchema>;
export type ReminderInput = z.input<typeof reminderInputSchema>;
export type PaymentShiftInput = z.input<typeof paymentShiftSchema>;
export type PaymentBulkShiftInput = z.input<typeof paymentBulkShiftSchema>;
export type VerificationAnswerInput = z.input<typeof verificationAnswerSchema>;
