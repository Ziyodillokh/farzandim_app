import { z } from 'zod';
import { hhmmSchema, isoDateSchema, requiredText } from './common';

export const correctionSchema = z.object({
  studentId: z.string().min(1),
  date: isoDateSchema,
  status: z.enum(['PRESENT', 'LATE', 'ABSENT', 'LEFT_EARLY', 'EXCUSED']),
  reason: requiredText(200),
});

export const earlyExitInputSchema = z.object({
  studentId: z.string().min(1),
  time: hhmmSchema,
  reason: requiredText(160),
  pickupBy: requiredText(80),
});

export type CorrectionInput = z.input<typeof correctionSchema>;
export type EarlyExitInput = z.input<typeof earlyExitInputSchema>;
