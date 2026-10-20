// Panel zod sxemalari bilan bir xil qoidalar (school-panel/src/data/schemas)
// — xabarlar i18n kalitlari, panel forma xatosini shu bo'yicha ko'rsatadi.

import { z } from 'zod';
import { invalid } from './school-errors';

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
  z.string({ error: msg.required }).trim().min(1, msg.required).max(max, msg.tooLong);

export const optionalText = (max = 500) => z.string().trim().max(max, msg.tooLong).default('');

/** "+998 90 123 45 67" — bo'shliqlar ixtiyoriy, saqlashda normallashtiriladi. */
export const phoneSchema = z
  .string({ error: msg.required })
  .trim()
  .transform((v) => v.replace(/[^\d+]/g, ''))
  .refine((v) => /^\+998\d{9}$/.test(v), msg.phone)
  .transform((v) => `${v.slice(0, 4)} ${v.slice(4, 6)} ${v.slice(6, 9)} ${v.slice(9, 11)} ${v.slice(11, 13)}`);

export const hhmmSchema = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, msg.time);
export const isoDateSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, msg.date);
export const emailSchema = z.string().trim().email(msg.email).or(z.literal(''));

/** Kiruvchi ma'lumotni tekshirish — xato bo'lsa VALIDATION (`yo'l: xabar`). */
export function parseOrThrow<S extends z.ZodType>(schema: S, input: unknown): z.output<S> {
  const result = schema.safeParse(input);
  if (!result.success) {
    const first = result.error.issues[0];
    throw invalid(first ? `${first.path.join('.')}: ${first.message}` : 'invalid');
  }
  return result.data;
}

/** Ro'yxat so'rovi (panel `ListQuery`). */
export const listQuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(500).default(20),
  search: z.string().trim().max(100).optional(),
  sortBy: z.string().max(40).optional(),
  sortDir: z.enum(['asc', 'desc']).optional(),
});

export type ListQuery = z.output<typeof listQuerySchema>;

export function paginate<T>(items: T[], total: number, query: ListQuery) {
  return {
    items,
    pagination: {
      page: query.page,
      limit: query.limit,
      total,
      totalPages: Math.max(1, Math.ceil(total / query.limit)),
    },
  };
}
