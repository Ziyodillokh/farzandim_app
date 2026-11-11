// Admin → Maktablar: kiruvchi ma'lumot. Chegaralar maktab paneli bilan bir xil
// (sozlamalar: nom ≤ 100, qisqa nom ≤ 12, shahar ≤ 40; xodim: F.I.Sh. ≤ 80,
// login `^[a-z0-9._-]{3,32}$`) — keyin direktor sozlamalarni saqlaganda xato
// chiqmasin. Xabarlar o'zbekcha: admin panel ularni to'g'ridan-to'g'ri ko'rsatadi.

import { BadRequestException } from '@nestjs/common';
import { SchoolStaffRole } from '@prisma/client';
import { z } from 'zod';
import { isProtectedRole } from '../../school/auth/permissions';
import { SCHOOL_CODE_PATTERN } from '../../school/common/school-bootstrap';

export const STAFF_USERNAME_PATTERN = /^[a-z0-9._-]{3,32}$/;
export const DEFAULT_DIRECTOR_USERNAME = 'direktor';
export const MAX_PAGE_LIMIT = 100;

const LIMITS = { name: 100, shortName: 12, city: 40, fullName: 80, position: 80, search: 100 } as const;

/**
 * Admin beradigan / tiklaydigan hisoblar: direktor va himoyalangan rollar
 * (psixolog). Qolgan xodimlarni direktor panelda o'zi boshqaradi.
 */
export const isAdminManagedRole = (role: SchoolStaffRole): boolean =>
  role === SchoolStaffRole.DIRECTOR || isProtectedRole(role);

export const ADMIN_MANAGED_ROLES: readonly SchoolStaffRole[] = Object.values(SchoolStaffRole).filter(isAdminManagedRole);

const DEFAULT_POSITION: Partial<Record<SchoolStaffRole, string>> = {
  DIRECTOR: 'Direktor',
  PSYCHOLOGIST: 'Psixolog',
};

export const defaultPosition = (role: SchoolStaffRole): string => DEFAULT_POSITION[role] ?? '';

const text = (label: string, max: number) =>
  z
    .string({ error: `${label} kiritilmagan` })
    .trim()
    .min(1, `${label} kiritilmagan`)
    .max(max, `${label} ${max} belgidan oshmasin`);

const usernameSchema = z
  .string({ error: 'Login kiritilmagan' })
  .trim()
  .toLowerCase()
  .regex(STAFF_USERNAME_PATTERN, 'Login: 3–32 belgi, faqat a-z, 0-9, ".", "_", "-"');

export const createSchoolSchema = z.object({
  code: z
    .string({ error: 'Maktab kodi kiritilmagan' })
    .trim()
    .toLowerCase()
    .regex(SCHOOL_CODE_PATTERN, 'Maktab kodi: 2–40 belgi, faqat a-z, 0-9 va "-"'),
  name: text('Maktab nomi', LIMITS.name),
  shortName: z
    .string()
    .trim()
    .max(LIMITS.shortName, `Qisqa nom ${LIMITS.shortName} belgidan oshmasin`)
    .optional()
    .transform((v) => v || undefined),
  city: text('Shahar / tuman', LIMITS.city),
  director: z.object(
    {
      fullName: text('Direktor F.I.Sh.', LIMITS.fullName),
      username: usernameSchema.default(DEFAULT_DIRECTOR_USERNAME),
    },
    { error: "Direktor ma'lumoti kiritilmagan" },
  ),
});

export const addStaffSchema = z.object({
  role: z.enum(ADMIN_MANAGED_ROLES as [SchoolStaffRole, ...SchoolStaffRole[]], {
    error: "Rol: faqat direktor yoki psixolog (qolganlarini direktor panelda qo'shadi)",
  }),
  fullName: text('F.I.Sh.', LIMITS.fullName),
  username: usernameSchema,
  position: z
    .string()
    .trim()
    .max(LIMITS.position, `Lavozim ${LIMITS.position} belgidan oshmasin`)
    .optional()
    .transform((v) => v || undefined),
});

/** `username` — faqat xodimning logini yo'q bo'lsa (direktor hisobni o'chirgan). */
export const resetPasswordSchema = z
  .object({ resetTotp: z.boolean().default(false), username: usernameSchema.optional() })
  .default({ resetTotp: false });

export const listSchoolsSchema = z.object({
  q: z.string().trim().max(LIMITS.search).optional().transform((v) => v || undefined),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(MAX_PAGE_LIMIT).default(20),
});

export type CreateSchoolInput = z.output<typeof createSchoolSchema>;
export type AddStaffInput = z.output<typeof addStaffSchema>;
export type ListSchoolsInput = z.output<typeof listSchoolsSchema>;

/** Xato — 400 `{ code: 'VALIDATION', message: "maydon: xabar" }`. */
export function parseAdminInput<S extends z.ZodType>(schema: S, input: unknown): z.output<S> {
  const result = schema.safeParse(input ?? undefined);
  if (result.success) return result.data;
  const first = result.error.issues[0];
  const path = first?.path.join('.');
  throw new BadRequestException({
    code: 'VALIDATION',
    message: first ? (path ? `${path}: ${first.message}` : first.message) : 'Noto\'g\'ri ma\'lumot',
  });
}
