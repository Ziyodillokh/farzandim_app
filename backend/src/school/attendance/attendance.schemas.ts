// Davomat kirish sxemalari (panel `school-panel/src/data/schemas/attendance.ts`)
// + so'rov parametrlari. Xabarlar — panel i18n kalitlari.

import { z } from 'zod';
import { isDayKey } from '../../common/time/tashkent';
import { hhmmSchema, isoDateSchema, msg, requiredText } from '../common/school-zod';

export const ATTENDANCE_STATUSES = ['PRESENT', 'LATE', 'ABSENT', 'LEFT_EARLY', 'EXCUSED'] as const;

const idSchema = z.string({ error: msg.required }).trim().min(1, msg.required).max(64, msg.tooLong);
const statusSchema = z.enum(ATTENDANCE_STATUSES, { error: msg.required });

/** Haqiqiy kalendar kuni (`2026-02-30`, `2026-13-45` emas). */
const dayKeySchema = isoDateSchema.refine(isDayKey, msg.date);

/** `"2026-10"` — oy 01–12. */
export const monthSchema = z.string({ error: msg.required }).regex(/^\d{4}-(0[1-9]|1[0-2])$/, msg.date);

export const correctionSchema = z.object({
  studentId: idSchema,
  date: dayKeySchema,
  status: statusSchema,
  reason: requiredText(200),
});

export const earlyExitInputSchema = z.object({
  studentId: idSchema,
  time: hhmmSchema,
  reason: requiredText(160),
  pickupBy: requiredText(80),
});

/** Qo'lda belgilash (bugun): mavjud holatni o'zgartirishda sabab servisda talab qilinadi. */
export const markSchema = z.object({
  studentId: idSchema,
  status: statusSchema,
  reason: z.string().trim().max(200, msg.tooLong).default(''),
});

export const decisionSchema = z.object({ approve: z.boolean({ error: msg.required }) });

export const kioskCheckInSchema = z.object({ code: requiredText(64) });

export const childCheckInSchema = z.object({ token: z.string({ error: msg.required }).trim().min(1, msg.required).max(512, msg.tooLong) });

// ─── So'rov (query) parametrlari ────────────────────────────────────

export const dayQuerySchema = z.object({ date: dayKeySchema.optional() });

export const feedQuerySchema = z.object({
  classId: z.string().trim().min(1).max(64).optional(),
  kind: z.enum(['IN', 'OUT']).optional(),
  limit: z.coerce.number().int().min(1).max(500).default(50),
});

export const earlyExitQuerySchema = z.object({
  status: z.enum(['PENDING', 'APPROVED', 'REJECTED']).optional(),
});

export const limitQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(500).default(100),
});

export const monthReportQuerySchema = z.object({ month: monthSchema, classId: idSchema });

export const studentMonthQuerySchema = z.object({ month: monthSchema });

export const trendQuerySchema = z.object({
  daysBack: z.coerce.number().int().min(0).max(120).default(14),
});

export const kioskSearchQuerySchema = z.object({ q: z.string().max(100).default('') });

export const parentAttendanceQuerySchema = z.object({
  studentId: idSchema,
  month: monthSchema.optional(),
});
