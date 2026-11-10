// Maktabning o'z o'quv materiali (o'qituvchi qo'shadi): sxema, id va ko'rinishlar — sof mantiq.
// Katalogdagi id `school:<uuid>`, tur `LESSON`; topshiriq sifatida sinflarga yuboriladi. Matn — oddiy matn
// (HTML emas), havola — faqat https (bola ilovasi tashqi brauzerda ochadi).

import { SchoolLearningMaterial } from '@prisma/client';
import { z } from 'zod';
import { msg } from '../common/school-zod';
import { MAX_ESTIMATED_MINUTES, MIN_ESTIMATED_MINUTES } from './school-learning.schemas';
import type { Material, PanelSubject } from './school-learning-catalog';

export const LESSON_KIND = 'LESSON';
export const SCHOOL_MATERIAL_PREFIX = 'school:';
export const MATERIAL_TITLE_MAX = 120;
export const MATERIAL_BODY_MAX = 4000;
export const MATERIAL_LINK_MAX = 500;

export const PANEL_SUBJECTS = [
  'MATH',
  'ENGLISH',
  'HISTORY',
  'LITERATURE',
  'GEOGRAPHY',
  'BIOLOGY',
  'IT',
  'NATIVE',
  'PHYSICS',
  'CHEMISTRY',
  'RUSSIAN',
] as const satisfies readonly PanelSubject[];

const OUT_OF_RANGE = 'errors.form.outOfRange';

/** Faqat https; foydalanuvchi ma'lumoti (`user:pass@`) bilan havola rad etiladi. */
const httpsUrl = z
  .string()
  .trim()
  .max(MATERIAL_LINK_MAX, msg.tooLong)
  .refine((value) => {
    try {
      const url = new URL(value);
      return url.protocol === 'https:' && !url.username && !url.password && url.hostname.includes('.');
    } catch {
      return false;
    }
  }, 'errors.form.invalidUrl');

export const materialInputSchema = z.object({
  title: z.string().trim().min(3, msg.tooShort).max(MATERIAL_TITLE_MAX, msg.tooLong),
  subject: z.enum(PANEL_SUBJECTS, { error: msg.required }),
  grades: z
    .array(z.number().int().min(1, OUT_OF_RANGE).max(11, OUT_OF_RANGE))
    .min(1, msg.atLeastOne)
    .max(11)
    .transform((g) => [...new Set(g)].sort((a, b) => a - b)),
  body: z.string().trim().min(1, msg.required).max(MATERIAL_BODY_MAX, msg.tooLong),
  linkUrl: z
    .preprocess((v) => (v === undefined || (typeof v === 'string' && v.trim() === '') ? null : v), httpsUrl.nullable())
    .transform((v) => v ?? null),
  estimatedMinutes: z
    .number({ error: OUT_OF_RANGE })
    .int(OUT_OF_RANGE)
    .min(MIN_ESTIMATED_MINUTES, OUT_OF_RANGE)
    .max(MAX_ESTIMATED_MINUTES, OUT_OF_RANGE),
});

export type MaterialInput = z.output<typeof materialInputSchema>;

export const schoolMaterialId = (id: string) => `${SCHOOL_MATERIAL_PREFIX}${id}`;

/** `school:<uuid>` → uuid; boshqa id — `null`. */
export function parseSchoolMaterialId(materialId: string): string | null {
  return materialId.startsWith(SCHOOL_MATERIAL_PREFIX) ? materialId.slice(SCHOOL_MATERIAL_PREFIX.length) || null : null;
}

/** Panel katalogidagi maktab materiali: Parvoz materiali shakli + egasi, matn, havola. */
export interface SchoolMaterialView extends Omit<Material, 'kind'> {
  kind: typeof LESSON_KIND;
  own: true;
  body: string;
  linkUrl: string | null;
  byStaffId: string;
  byName: string;
  canEdit: boolean;
  createdAt: string;
}

export function toMaterialView(
  m: SchoolLearningMaterial,
  ctx: { byName: string; canEdit: boolean },
): SchoolMaterialView {
  return {
    id: schoolMaterialId(m.id),
    kind: LESSON_KIND,
    title: m.title,
    subject: m.subject as PanelSubject,
    grades: [...m.grades],
    durationMin: m.estimatedMinutes,
    questions: 0,
    own: true,
    body: m.body,
    linkUrl: m.linkUrl,
    byStaffId: m.byStaffId,
    byName: ctx.byName,
    canEdit: ctx.canEdit,
    createdAt: m.createdAt.toISOString(),
  };
}
