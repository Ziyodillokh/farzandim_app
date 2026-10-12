import { z } from 'zod';
import { msg } from './common';

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

export type ClassInput = z.input<typeof classInputSchema>;
