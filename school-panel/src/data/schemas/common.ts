import { z } from 'zod';

/**
 * Zod xabarlari — i18n kalitlari (UI `t(message)` bilan tarjima qiladi).
 * Forma va mock servis BIR XIL sxemadan foydalanadi (backend DTO validatsiyasi kabi).
 */
export const msg = {
  required: 'errors.form.required',
  tooShort: 'errors.form.tooShort',
  tooLong: 'errors.form.tooLong',
  phone: 'errors.form.invalidPhone',
  email: 'errors.form.invalidEmail',
  time: 'errors.form.invalidTime',
  date: 'errors.form.invalidDate',
  endBeforeStart: 'errors.form.endBeforeStart',
  atLeastOne: 'errors.form.selectAtLeastOne',
} as const;

export const requiredText = (max = 120) =>
  z.string({ required_error: msg.required }).trim().min(1, msg.required).max(max, msg.tooLong);

export const optionalText = (max = 500) => z.string().trim().max(max, msg.tooLong).default('');

/** "+998 90 123 45 67" — bo'shliqlar ixtiyoriy, saqlashda normallashtiriladi. */
export const phoneSchema = z
  .string({ required_error: msg.required })
  .trim()
  .transform((v) => v.replace(/[^\d+]/g, ''))
  .refine((v) => /^\+998\d{9}$/.test(v), msg.phone)
  .transform((v) => `${v.slice(0, 4)} ${v.slice(4, 6)} ${v.slice(6, 9)} ${v.slice(9, 11)} ${v.slice(11, 13)}`);

export const hhmmSchema = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, msg.time);
export const isoDateSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, msg.date);
export const emailSchema = z.string().trim().email(msg.email).or(z.literal(''));
