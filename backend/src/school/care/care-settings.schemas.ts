// Bola ovozi sozlamalari (mas'ul psixolog, o'rinbosar, ish vaqti, javob muddati).
// Xabarlar — panel i18n kalitlari: `errors.form.<kalit>` (VALIDATION `maydon: kalit`).

import { z } from 'zod';
import { hhmmSchema, msg } from '../common/school-zod';
import { hhmmToMinutes } from './care-working-time';

export const SETTINGS_MSG = {
  /** Xodim topilmadi / faol emas / psixolog emas. */
  invalidStaff: 'errors.form.invalidStaff',
  duplicate: 'errors.form.duplicate',
  outOfRange: 'errors.form.outOfRange',
} as const;

export const DISPLAY_NAME_MAX = 40;
export const SLA_MINUTES = { min: 15, max: 1440 } as const;
export const SLA_HOURS = { min: 1, max: 168 } as const;

const staffId = z.string().trim().min(1, msg.required).max(64, msg.tooLong).nullish().transform((v) => v ?? null);
const displayName = z
  .string()
  .trim()
  .max(DISPLAY_NAME_MAX, msg.tooLong)
  .nullish()
  .transform((v) => (v ? v : null));

export const careSettingsInputSchema = z
  .object({
    psychologistStaffId: staffId,
    psychologistDisplayName: displayName,
    deputyStaffId: staffId,
    deputyDisplayName: displayName,
    workDays: z
      .array(z.number().int().min(1, SETTINGS_MSG.outOfRange).max(7, SETTINGS_MSG.outOfRange))
      .min(1, msg.atLeastOne)
      .max(7, SETTINGS_MSG.outOfRange)
      .default([1, 2, 3, 4, 5]),
    workStart: hhmmSchema.default('09:00'),
    workEnd: hhmmSchema.default('17:00'),
    urgentSlaMinutes: z
      .number()
      .int()
      .min(SLA_MINUTES.min, SETTINGS_MSG.outOfRange)
      .max(SLA_MINUTES.max, SETTINGS_MSG.outOfRange)
      .default(60),
    normalSlaHours: z
      .number()
      .int()
      .min(SLA_HOURS.min, SETTINGS_MSG.outOfRange)
      .max(SLA_HOURS.max, SETTINGS_MSG.outOfRange)
      .default(24),
  })
  .superRefine((v, ctx) => {
    if (new Set(v.workDays).size !== v.workDays.length) {
      ctx.addIssue({ code: 'custom', path: ['workDays'], message: SETTINGS_MSG.duplicate });
    }
    if (v.deputyStaffId !== null && v.deputyStaffId === v.psychologistStaffId) {
      ctx.addIssue({ code: 'custom', path: ['deputyStaffId'], message: SETTINGS_MSG.duplicate });
    }
    if (!(hhmmToMinutes(v.workStart) < hhmmToMinutes(v.workEnd))) {
      ctx.addIssue({ code: 'custom', path: ['workEnd'], message: msg.endBeforeStart });
    }
  });

export type CareSettingsInput = z.output<typeof careSettingsInputSchema>;
