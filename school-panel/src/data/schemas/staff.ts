import { z } from 'zod';
import { emailSchema, msg, phoneSchema, requiredText } from './common';

export const staffInputSchema = z.object({
  fullName: requiredText(80),
  position: requiredText(80),
  role: z.enum(['DIRECTOR', 'ADMIN', 'HOMEROOM', 'PSYCHOLOGIST', 'DUTY', 'TEACHER']),
  phone: phoneSchema,
  email: emailSchema.default(''),
  classIds: z.array(z.string()).default([]),
  active: z.boolean().default(true),
});

/** Sinf rahbari kamida bitta sinfga biriktirilishi shart (forma va servis bir xil). */
export const staffFormSchema = staffInputSchema.superRefine((value, ctx) => {
  if (value.role === 'HOMEROOM' && value.classIds.length === 0) {
    ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['classIds'], message: msg.atLeastOne });
  }
});

/** Rollar: sinf(lar)ga bog'liq doira — faqat shu rollarda `classIds` saqlanadi. */
export const CLASS_SCOPED_ROLES = ['HOMEROOM', 'TEACHER'] as const;

export type StaffInput = z.input<typeof staffInputSchema>;
