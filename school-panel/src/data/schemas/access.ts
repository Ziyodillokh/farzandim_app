import { z } from 'zod';
import { msg } from './common';

/** Bola logini (kontrakt K1): kichik lotin harfi bilan boshlanadi, jami 4–24 belgi. */
export const LOGIN_PATTERN = /^[a-z][a-z0-9._]{3,23}$/;
export const LOGIN_MIN = 4;
export const LOGIN_MAX = 24;

/** Login maydoni: bo'sh — "tizim taklif qilsin" (`undefined`), aks holda kichik harfga o'tkazilib tekshiriladi. */
const loginField = z
  .string()
  .trim()
  .toLowerCase()
  .refine((v) => v === '' || LOGIN_PATTERN.test(v), msg.login)
  .transform((v) => (v === '' ? undefined : v))
  .optional();

/** Kirish ma'lumotlarini berish/tiklash: forma va mock servis BIR XIL sxemadan foydalanadi. */
export const issueCredentialsSchema = z.object({
  login: loginField,
  signOutDevices: z.boolean().optional(),
});

export type IssueCredentialsFormInput = z.input<typeof issueCredentialsSchema>;
