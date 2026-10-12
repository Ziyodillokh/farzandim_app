import { z } from 'zod';
import { isoDateSchema, msg, phoneSchema, requiredText } from './common';

export const guardianInputSchema = z.object({
  fullName: requiredText(80),
  phone: phoneSchema,
  relation: z.enum(['MOTHER', 'FATHER', 'GRANDPARENT', 'OTHER']),
});

export const studentInputSchema = z.object({
  lastName: requiredText(40),
  firstName: requiredText(40),
  middleName: z.string().trim().max(60, msg.tooLong).default(''),
  gender: z.enum(['MALE', 'FEMALE']),
  birthDate: isoDateSchema,
  classId: z.string().min(1, msg.required),
  device: z.enum(['IOS', 'ANDROID', 'NONE']),
});

export const studentCreateSchema = studentInputSchema.extend({
  guardian: guardianInputSchema.optional(),
});

/** O'quvchi kartasidagi xodim eslatmasi: 1–1000 belgi (auditga matn yozilmaydi). */
export const STUDENT_NOTE_MAX = 1000;
export const studentNoteSchema = z.object({ text: requiredText(STUDENT_NOTE_MAX) });

export type StudentInput = z.input<typeof studentInputSchema>;
export type StudentNoteInput = z.input<typeof studentNoteSchema>;
export type StudentCreateInput = z.input<typeof studentCreateSchema>;
export type GuardianInput = z.input<typeof guardianInputSchema>;
