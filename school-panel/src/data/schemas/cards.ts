import { z } from 'zod';

import { msg } from './common';

/**
 * NFC karta kiritish (backend `cards.schemas.ts` bilan bir xil). Karta Web NFC yoki USB
 * o'qigich bilan o'qiladi: `uid` — chip seriya raqami, `url` — kartadagi NDEF manzil.
 */
export const CARD_BLOCK_REASONS = ['LOST', 'BLOCKED'] as const;

const UID_HEX_LENGTHS = new Set([8, 14, 20]);

/** Seriya raqami: ajratgichlarsiz katta hex (4, 7 yoki 10 bayt), aks holda `null`. */
export function normalizeCardUid(raw: string): string | null {
  const compact = raw.replace(/[\s:-]/g, '');
  if (!/^[0-9a-f]+$/i.test(compact) || !UID_HEX_LENGTHS.has(compact.length)) return null;
  return compact.toUpperCase();
}

export const cardAssignSchema = z
  .object({
    studentId: z.string().min(1, msg.required),
    uid: z.string().trim().max(64, msg.tooLong).optional(),
    url: z.string().trim().max(1024, msg.tooLong).optional(),
    number: z.string().trim().min(1, msg.required).max(32, msg.tooLong).optional(),
  })
  .refine((d) => Boolean(d.url) || (d.uid ? normalizeCardUid(d.uid) !== null : false), { message: msg.cardUid, path: ['uid'] });

export const cardBlockSchema = z.object({
  reason: z.enum(CARD_BLOCK_REASONS),
  note: z.string().trim().max(200, msg.tooLong).optional(),
});

export const cardTapSchema = z
  .object({
    uid: z.string().trim().max(64, msg.tooLong).optional(),
    url: z.string().trim().max(1024, msg.tooLong).optional(),
    kioskId: z.string().trim().max(64, msg.tooLong).optional(),
    tappedAt: z.string().datetime({ message: msg.date }).optional(),
  })
  .refine((d) => Boolean(d.uid || d.url), { message: msg.cardUid, path: ['uid'] });

export type CardAssignInput = z.infer<typeof cardAssignSchema>;
export type CardBlockInput = z.infer<typeof cardBlockSchema>;
export type CardTapInput = z.infer<typeof cardTapSchema>;
