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

/** Ommaviy taklif filtri — ota-onalar ro'yxatidagi joriy filtr. */
export const bulkInviteSchema = z.object({
  classId: z.string().min(1).optional(),
  search: z.string().trim().max(100, msg.tooLong).optional(),
});

export type BulkInviteInput = z.input<typeof bulkInviteSchema>;
