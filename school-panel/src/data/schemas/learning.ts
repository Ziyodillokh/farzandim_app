import { z } from 'zod';
import { isoDateSchema, msg, optionalText } from './common';

export const MATERIAL_KINDS = ['AUDIOBOOK', 'VIDEO', 'TEST'] as const;
export const SUBJECTS = ['MATH', 'ENGLISH', 'HISTORY', 'LITERATURE', 'GEOGRAPHY', 'BIOLOGY', 'IT', 'NATIVE'] as const;

/** Topshiriq: material + sinf(lar) + muddat + izoh. */
export const assignmentInputSchema = z.object({
  materialId: z.string({ required_error: msg.required }).min(1, msg.required),
  classIds: z.array(z.string().min(1)).min(1, msg.atLeastOne),
  dueDate: isoDateSchema,
  note: optionalText(300),
});

export const materialFilterSchema = z.object({
  kind: z.enum(MATERIAL_KINDS).optional(),
  subject: z.enum(SUBJECTS).optional(),
  grade: z.number().int().min(1).max(11).optional(),
  search: z.string().trim().max(80).optional(),
});

export type AssignmentInput = z.input<typeof assignmentInputSchema>;
export type MaterialFilter = z.input<typeof materialFilterSchema>;
