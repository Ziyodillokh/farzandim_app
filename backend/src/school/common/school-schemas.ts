// Panel kirish sxemalari (school-panel/src/data/schemas: school, classes,
// staff) — forma va API bir xil qoidada tekshiriladi.

import { z } from 'zod';
import {
  emailSchema,
  isoDateSchema,
  msg,
  phoneSchema,
  requiredText,
} from './school-zod';

export const schoolProfileSchema = z.object({
  name: requiredText(100),
  shortName: requiredText(12),
  city: requiredText(40),
  address: z.string().trim().max(120, msg.tooLong).default(''),
  phone: z.string().trim().max(24, msg.tooLong).default(''),
  academicYear: requiredText(12),
  lateAfterMinutes: z.coerce.number().int().min(0).max(60),
});

export const holidayInputSchema = z.object({ date: isoDateSchema, name: requiredText(60) });

export const classInputSchema = z.object({
  grade: z.coerce.number().int().min(1, msg.required).max(11, msg.required),
  letter: z
    .string()
    .trim()
    .min(1, msg.required)
    .max(2, msg.tooLong)
    .transform((v) => v.toUpperCase()),
  shiftId: z.string().min(1, msg.required),
  homeroomStaffId: z.string().nullable().default(null),
  room: z.string().trim().max(10, msg.tooLong).default(''),
});

export const STAFF_ROLES = ['DIRECTOR', 'ADMIN', 'HOMEROOM', 'PSYCHOLOGIST', 'DUTY', 'TEACHER'] as const;

export const staffInputSchema = z.object({
  fullName: requiredText(80),
  position: requiredText(80),
  role: z.enum(STAFF_ROLES),
  phone: phoneSchema,
  email: emailSchema.default(''),
  classIds: z.array(z.string()).default([]),
  active: z.boolean().default(true),
});

/** Sinf rahbari kamida bitta sinfga biriktirilishi shart. */
export const staffFormSchema = staffInputSchema.superRefine((value, ctx) => {
  if (value.role === 'HOMEROOM' && value.classIds.length === 0) {
    ctx.addIssue({ code: 'custom', path: ['classIds'], message: msg.atLeastOne });
  }
});

/** Xodimga panel hisobi (login + vaqtinchalik parol). */
export const staffAccountSchema = z.object({
  username: z
    .string()
    .trim()
    .toLowerCase()
    .regex(/^[a-z0-9._-]{3,32}$/, 'errors.form.invalidUsername'),
  password: z.string().min(10, msg.tooShort).max(200, msg.tooLong),
});

/** Logo — data URL (≤ 256 px, SVG/PNG/JPEG/WebP). */
export const LOGO_PATTERN = /^data:image\/(png|jpeg|webp|svg\+xml);base64,/;
export const MAX_LOGO_BYTES = 350_000;

/** Xodim rasmi — faqat raster (SVG emas), ~90 KB gacha. */
export const PHOTO_PATTERN = /^data:image\/(jpeg|webp|png);base64,[A-Za-z0-9+/=]+$/;
export const MAX_PHOTO_CHARS = 120_000;
