// Xabarlar moduli kirish sxemalari — panel `school-panel/src/data/schemas/comms.ts`
// bilan bir xil qoidalar (zod v4). Sana / vaqt qiymatlari qo'shimcha ravishda
// haqiqiy sana ekanligi tekshiriladi (xabar kaliti o'sha — `errors.form.invalidDate`).

import { z } from 'zod';
import { isDayKey } from '../../common/time/tashkent';
import { listQuerySchema, msg, requiredText } from '../common/school-zod';
import { parseLocalDateTime } from './comms-time';

/** Xabar matni chegarasi (push + kelajakda SMS zaxira). */
export const MESSAGE_BODY_MAX = 1000;
export const MESSAGE_TITLE_MAX = 120;
export const REMINDER_BODY_MAX = 500;
export const NOTE_MAX = 300;
export const VERIFICATION_MESSAGE_MAX = 500;
export const MAX_SHIFT_MONTHS = 12;
/** Bir so'rovdagi id'lar chegarasi (butun maktab oilalari ham sig'adi). */
export const MAX_IDS = 5000;

const idList = () => z.array(z.string().min(1)).max(MAX_IDS, msg.tooLong);

export const AUDIENCE_KINDS = ['SCHOOL', 'CLASSES', 'GUARDIANS'] as const;
export const PRIORITIES = ['NORMAL', 'IMPORTANT'] as const;
export const MESSAGE_STATUSES = ['DRAFT', 'SCHEDULED', 'SENT'] as const;
export const REMINDER_KINDS = ['MEETING', 'EXAM', 'EVENT', 'HOLIDAY', 'ANNOUNCEMENT', 'SCHEDULE_CHANGE'] as const;
export const REMINDER_REPEATS = ['NONE', 'WEEKLY', 'MONTHLY'] as const;
export const PAYMENT_FILTERS = ['ALL', 'DUE_SOON', 'PREPAID', 'PAUSED'] as const;
export const VERIFICATION_STATUSES = ['OPEN', 'ANSWERED', 'CLOSED'] as const;

export type AudienceKind = (typeof AUDIENCE_KINDS)[number];
export type MessagePriority = (typeof PRIORITIES)[number];
export type MessageStatus = (typeof MESSAGE_STATUSES)[number];
export type ReminderKind = (typeof REMINDER_KINDS)[number];
export type ReminderRepeat = (typeof REMINDER_REPEATS)[number];
export type PaymentFilterKind = (typeof PAYMENT_FILTERS)[number];
export type VerificationStatus = (typeof VERIFICATION_STATUSES)[number];

/** "YYYY-MM-DD" — haqiqiy kalendar sanasi. */
export const dayKeySchema = z.string({ error: msg.required }).refine(isDayKey, msg.date);

/** `datetime-local` qiymati: "2026-10-14T08:00" (soniya ixtiyoriy) — Toshkent vaqti. */
export const localDateTimeSchema = z
  .string({ error: msg.required })
  .refine((v) => parseLocalDateTime(v) !== null, msg.date);

export const audienceSchema = z
  .object({
    kind: z.enum(AUDIENCE_KINDS),
    classIds: idList().default([]),
    guardianIds: idList().default([]),
  })
  .superRefine((value, ctx) => {
    if (value.kind === 'CLASSES' && value.classIds.length === 0) {
      ctx.addIssue({ code: 'custom', path: ['classIds'], message: msg.atLeastOne });
    }
    if (value.kind === 'GUARDIANS' && value.guardianIds.length === 0) {
      ctx.addIssue({ code: 'custom', path: ['guardianIds'], message: msg.atLeastOne });
    }
  })
  .transform((value) => ({
    kind: value.kind,
    classIds: value.kind === 'CLASSES' ? [...new Set(value.classIds)] : [],
    guardianIds: value.kind === 'GUARDIANS' ? [...new Set(value.guardianIds)] : [],
  }));

export type Audience = z.output<typeof audienceSchema>;

export const announcementInputSchema = z.object({
  title: requiredText(MESSAGE_TITLE_MAX),
  body: requiredText(MESSAGE_BODY_MAX),
  priority: z.enum(PRIORITIES),
  audience: audienceSchema,
});

export type AnnouncementInput = z.output<typeof announcementInputSchema>;

/** Yuborish parametri: bo'sh — darhol, aks holda rejalashtirish vaqti (tekshiruvi — `parseSchedule`). */
export const sendOptionsSchema = z.object({
  scheduledAt: z.string().max(40, msg.date).nullable().optional(),
});

export const reminderInputSchema = z.object({
  kind: z.enum(REMINDER_KINDS),
  title: requiredText(MESSAGE_TITLE_MAX),
  body: requiredText(REMINDER_BODY_MAX),
  audience: audienceSchema,
  sendAt: localDateTimeSchema,
  repeat: z.enum(REMINDER_REPEATS),
  active: z.boolean().default(true),
});

export const reminderActiveSchema = z.object({ active: z.boolean({ error: msg.required }) });

/** Izoh — "kim tasdiqladi" (buxgalteriya, chek va h.k.): audit uchun majburiy. */
const noteSchema = requiredText(NOTE_MAX);

export const paymentShiftSchema = z.object({ nextDate: dayKeySchema, note: noteSchema });

export const paymentPauseSchema = z.object({ note: noteSchema });

export const paymentBulkShiftSchema = z
  .object({
    ids: idList().min(1, msg.atLeastOne),
    months: z.number().int().min(1).max(MAX_SHIFT_MONTHS).optional(),
    date: dayKeySchema.optional(),
    note: noteSchema,
    /** Oylar bo'yicha surishda — "oldindan to'langan oylar" ham oshiriladi. */
    markPrepaid: z.boolean().default(false),
  })
  .refine((v) => (v.months === undefined) !== (v.date === undefined), {
    message: msg.required,
    path: ['months'],
  });

/** Yangi to'lov eslatmasi (oila uchun) — panelda hozircha UI yo'q. */
export const paymentCreateSchema = z.object({
  guardianId: z.string({ error: msg.required }).min(1, msg.required),
  studentIds: idList().optional(),
  nextDate: dayKeySchema,
  note: noteSchema,
});

export const verificationAnswerSchema = z.object({
  text: requiredText(MESSAGE_BODY_MAX),
  newDate: dayKeySchema.nullable().default(null),
});

/** Ota-ona ilovasi: "to'laganman, tekshiring" so'rovi. */
export const verificationCreateSchema = z.object({
  paymentReminderId: z.string({ error: msg.required }).min(1, msg.required),
  message: requiredText(VERIFICATION_MESSAGE_MAX),
});

// ── Ro'yxat filtrlari (panel `*Filter` turlari) ──

export const announcementFilterSchema = listQuerySchema.extend({
  limit: z.coerce.number().int().min(1).max(500).default(12),
  status: z.enum(MESSAGE_STATUSES).optional(),
});

export const reminderFilterSchema = listQuerySchema.extend({
  when: z.enum(['UPCOMING', 'PAST']).optional(),
  kind: z.enum(REMINDER_KINDS).optional(),
});

export const paymentFilterSchema = listQuerySchema.extend({
  filter: z.enum(PAYMENT_FILTERS).optional(),
});

export const verificationFilterSchema = listQuerySchema.extend({
  status: z.enum(VERIFICATION_STATUSES).optional(),
});

export const overviewQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(20).default(3),
});

/** Ota-ona ilovasi ro'yxatlari. */
export const parentPageSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});
