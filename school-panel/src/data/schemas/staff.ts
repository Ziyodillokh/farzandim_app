import { z } from 'zod';
import { emailSchema, phoneSchema, requiredText } from './common';

export const staffInputSchema = z.object({
  fullName: requiredText(80),
  position: requiredText(80),
  role: z.enum(['DIRECTOR', 'ADMIN', 'HOMEROOM', 'PSYCHOLOGIST', 'DUTY', 'TEACHER']),
  phone: phoneSchema,
  email: emailSchema.default(''),
  classIds: z.array(z.string()).default([]),
  active: z.boolean().default(true),
});

export type StaffInput = z.input<typeof staffInputSchema>;
