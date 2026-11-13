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

/** O'quvchi qo'shilayotganda ko'pi bilan shuncha ota-ona (masalan, ona va ota). */
export const MAX_CREATE_GUARDIANS = 2;

/**
 * Yangi o'quvchi + ota-onalari (backend bilan bir xil). `guardian` — eski shakl (bitta), `guardians` — yangisi;
 * ikkalasi bitta ro'yxatga yig'iladi. Bir xil telefon ikki marta kelmaydi.
 */
export const studentCreateSchema = studentInputSchema
  .extend({
    guardian: guardianInputSchema.optional(),
    guardians: z.array(guardianInputSchema).max(MAX_CREATE_GUARDIANS, msg.tooLong).optional(),
  })
  .transform(({ guardian, guardians, ...student }) => ({
    ...student,
    guardians: [...(guardian ? [guardian] : []), ...(guardians ?? [])],
  }))
  .refine((s) => s.guardians.length <= MAX_CREATE_GUARDIANS, { path: ['guardians'], message: msg.tooLong })
  .refine((s) => new Set(s.guardians.map((g) => g.phone)).size === s.guardians.length, {
    path: ['guardians', 1, 'phone'],
    message: msg.duplicatePhone,
  });

/** Formadagi ota-ona qoralamasi — hech narsa yozilmasa yuborilmaydi. */
export const guardianDraftSchema = z.object({
  fullName: z.string(),
  phone: z.string(),
  relation: guardianInputSchema.shape.relation,
});
export type GuardianDraft = z.infer<typeof guardianDraftSchema>;

/** Qoralamaga biror narsa yozilganmi ("+998 " prefiksi hisobga olinmaydi). */
export const isGuardianDraftFilled = (g: GuardianDraft) => g.fullName.trim() !== '' || g.phone.replace(/\D/g, '').length > 3;

/** Yangi o'quvchi formasi: to'ldirilgan ota-ona qoralamalarida ism, telefon va takrorlanmaslik tekshiriladi. */
export const studentCreateFormSchema = studentInputSchema
  .extend({ guardians: z.array(guardianDraftSchema).max(MAX_CREATE_GUARDIANS) })
  .superRefine((form, ctx) => {
    const phones: string[] = [];
    form.guardians.forEach((g, i) => {
      if (!isGuardianDraftFilled(g)) return;
      if (!g.fullName.trim()) ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['guardians', i, 'fullName'], message: msg.required });
      const phone = phoneSchema.safeParse(g.phone);
      if (!phone.success) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['guardians', i, 'phone'], message: msg.phone });
        return;
      }
      if (phones.includes(phone.data)) ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['guardians', i, 'phone'], message: msg.duplicatePhone });
      phones.push(phone.data);
    });
  });

type Relation = GuardianDraft['relation'];

const RELATIONS: ReadonlyArray<[RegExp, Relation]> = [
  [/^(ona|onasi|мать|мама|mother|mom)/i, 'MOTHER'],
  [/^(ota|otasi|отец|папа|father|dad)/i, 'FATHER'],
  [/^(buvi|bobo|buvisi|bobosi|бабушка|дедушка|grand)/i, 'GRANDPARENT'],
];

/** CSV «Kimligi»: «ona», «otasi», «бабушка», «MOTHER» → munosabat; bo'sh / noma'lum → `OTHER` (backend bilan bir xil). */
export function parseRelation(value: string): Relation {
  const text = value.trim();
  return RELATIONS.find(([re]) => re.test(text))?.[1] ?? 'OTHER';
}

/** O'quvchi kartasidagi xodim eslatmasi: 1–1000 belgi (auditga matn yozilmaydi). */
export const STUDENT_NOTE_MAX = 1000;
export const studentNoteSchema = z.object({ text: requiredText(STUDENT_NOTE_MAX) });

export type StudentInput = z.input<typeof studentInputSchema>;
export type StudentNoteInput = z.input<typeof studentNoteSchema>;
export type StudentCreateInput = z.input<typeof studentCreateSchema>;
export type StudentCreateFormValues = z.input<typeof studentCreateFormSchema>;
export type GuardianInput = z.input<typeof guardianInputSchema>;
