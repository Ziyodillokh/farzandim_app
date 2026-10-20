// Panel sxemalari (school-panel/src/data/schemas/students.ts, classes.ts
// `bulkInviteSchema`) — forma va API bir xil qoidada tekshiriladi.

import { z } from 'zod';
import { isoDateSchema, listQuerySchema, msg, phoneSchema, requiredText } from '../common/school-zod';

export const guardianInputSchema = z.object({
  fullName: requiredText(80),
  phone: phoneSchema,
  relation: z.enum(['MOTHER', 'FATHER', 'GRANDPARENT', 'OTHER'], { error: msg.required }),
});

export const studentInputSchema = z.object({
  lastName: requiredText(40),
  firstName: requiredText(40),
  middleName: z.string().trim().max(60, msg.tooLong).default(''),
  gender: z.enum(['MALE', 'FEMALE'], { error: msg.required }),
  birthDate: isoDateSchema,
  classId: z.string({ error: msg.required }).min(1, msg.required),
  device: z.enum(['IOS', 'ANDROID', 'NONE'], { error: msg.required }),
});

export const studentCreateSchema = studentInputSchema.extend({
  guardian: guardianInputSchema.optional(),
});

/** O'quvchi kartasidagi xodim eslatmasi: 1–1000 belgi (auditga matn yozilmaydi). */
export const STUDENT_NOTE_MAX = 1000;
export const studentNoteSchema = z.object({ text: requiredText(STUDENT_NOTE_MAX) });

const linkStatus = z.enum(['NOT_INVITED', 'INVITED', 'LINKED']);
const flag = z
  .union([z.boolean(), z.enum(['true', 'false'])])
  .transform((v) => v === true || v === 'true');

export const studentFilterSchema = listQuerySchema.extend({
  classId: z.string().min(1).optional(),
  linkStatus: linkStatus.optional(),
  device: z.enum(['IOS', 'ANDROID', 'NONE']).optional(),
  includeArchived: flag.optional(),
});

export const guardianFilterSchema = listQuerySchema.extend({
  classId: z.string().min(1).optional(),
  linkStatus: linkStatus.optional(),
});

export const bulkInviteSchema = z.object({
  classId: z.string().min(1).optional(),
  search: z.string().trim().max(100, msg.tooLong).optional(),
});

/** CSV import: bir martada ko'pi bilan shuncha qator (katta maktab ~2000 o'quvchi). */
export const IMPORT_MAX_ROWS = 2000;
export const importRowsSchema = z.object({
  rows: z
    .array(z.array(z.string().max(200, msg.tooLong)).max(12))
    .min(1, msg.required)
    .max(IMPORT_MAX_ROWS, msg.tooLong),
});

/** Ota-ona ilovasi: taklif kodi (6 belgi, katta-kichik harf farqsiz). */
export const redeemSchema = z.object({
  code: z
    .string({ error: msg.required })
    .trim()
    .toUpperCase()
    .regex(/^[A-Z0-9]{6}$/, 'errors.school.inviteCodeFormat'),
});

export const childLinkSchema = z.object({ childId: z.string().uuid().nullable() });

export type StudentFilter = z.output<typeof studentFilterSchema>;
export type GuardianFilter = z.output<typeof guardianFilterSchema>;
export type StudentCreate = z.output<typeof studentCreateSchema>;
export type GuardianData = z.output<typeof guardianInputSchema>;
