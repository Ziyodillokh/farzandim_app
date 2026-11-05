// Topshiriq kirish sxemasi: katalog materiali (test / audiokitob) YOKI yozma vazifa.
// Yozma vazifa: `materialId = 'written'` (yoki `materialKind = 'WRITTEN'`), sarlavha majburiy.

import { z } from 'zod';
import { isoDateSchema, msg, optionalText } from '../common/school-zod';

export const WRITTEN_KIND = 'WRITTEN';
export const WRITTEN_MATERIAL_ID = 'written';
export const MAX_TITLE = 120;
export const MIN_ESTIMATED_MINUTES = 1;
export const MAX_ESTIMATED_MINUTES = 240;

const OUT_OF_RANGE = 'errors.form.outOfRange';

export const assignmentInputSchema = z
  .object({
    materialKind: z.string().optional(),
    materialId: z.string().min(1, msg.required).max(80).optional(),
    title: z.string().trim().max(MAX_TITLE, msg.tooLong).optional(),
    estimatedMinutes: z
      .number({ error: OUT_OF_RANGE })
      .int(OUT_OF_RANGE)
      .min(MIN_ESTIMATED_MINUTES, OUT_OF_RANGE)
      .max(MAX_ESTIMATED_MINUTES, OUT_OF_RANGE)
      .optional(),
    classIds: z.array(z.string().min(1)).min(1, msg.atLeastOne).max(60),
    dueDate: isoDateSchema,
    note: optionalText(300),
  })
  .superRefine((v, ctx) => {
    const written = v.materialKind === WRITTEN_KIND || v.materialId === WRITTEN_MATERIAL_ID;
    if (!written) {
      if (!v.materialId) ctx.addIssue({ code: 'custom', path: ['materialId'], message: msg.required });
      return;
    }
    if (v.materialId && v.materialId !== WRITTEN_MATERIAL_ID) {
      ctx.addIssue({ code: 'custom', path: ['materialId'], message: msg.required });
    }
    if (!v.title) ctx.addIssue({ code: 'custom', path: ['title'], message: msg.required });
  });

export type AssignmentInput = z.output<typeof assignmentInputSchema>;

export const isWrittenInput = (v: AssignmentInput) => v.materialKind === WRITTEN_KIND || v.materialId === WRITTEN_MATERIAL_ID;
