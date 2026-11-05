// Yozma vazifa kirish sxemalari (child multipart maydonlari va xodim baholashi).

import { z } from 'zod';
import { msg } from '../common/school-zod';

export const COMMENT_MAX = 1000;
export const REVIEW_NOTE_MAX = 500;

const blankToNull = (v: string | null | undefined) => (v ? v : null);

/** Multipart matn maydonlari: `comment` (ixtiyoriy), `requestId` (ixtiyoriy UUID, takroriy so'rovlar uchun). */
export const submissionFieldsSchema = z.object({
  comment: z.string().trim().max(COMMENT_MAX, msg.tooLong).nullish().transform(blankToNull),
  requestId: z.guid({ error: msg.required }).nullish().transform((v) => v ?? null),
});

export const reviewInputSchema = z.object({
  status: z.enum(['ACCEPTED', 'RETURNED'], { error: msg.required }),
  note: z.string().trim().max(REVIEW_NOTE_MAX, msg.tooLong).nullish().transform(blankToNull),
});

export type SubmissionFields = z.output<typeof submissionFieldsSchema>;
