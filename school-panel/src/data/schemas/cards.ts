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

/** O'nlik ko'rinishdagi UID uzunligi → bayt soni (USB o'qigichlar 4 baytni 10 raqam qilib yozadi). */
const DECIMAL_UID_BYTES: Readonly<Record<number, number>> = { 10: 4, 15: 7, 16: 7, 17: 7 };

/**
 * USB o'qigich (klaviatura rejimi) yozgan raqam: hex bo'lsa — o'zi, o'nlik bo'lsa — hex'ga
 * o'giriladi. Bir xil o'qigich bilan biriktirilgan va tegizilgan karta doim bir xil chiqadi.
 */
export function normalizeReaderUid(raw: string): string | null {
  const hex = normalizeCardUid(raw);
  if (hex) return hex;
  const digits = raw.trim();
  const bytes = /^\d+$/.test(digits) ? DECIMAL_UID_BYTES[digits.length] : undefined;
  if (!bytes) return null;
  const value = BigInt(digits);
  if (value >= BigInt(2) ** BigInt(bytes * 8)) return null;
  return value.toString(16).toUpperCase().padStart(bytes * 2, '0');
}

export const cardAssignSchema = z
  .object({
    studentId: z.string().min(1, msg.required),
    uid: z.string().trim().max(64, msg.tooLong).optional(),
    url: z.string().trim().max(1024, msg.tooLong).optional(),
  })
  .refine((d) => Boolean(d.url) || (d.uid ? normalizeReaderUid(d.uid) !== null : false), { message: msg.cardUid, path: ['uid'] });

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

/** Karta partiyasi: tanlangan sinflardagi kartasiz o'quvchilarga raqam ajratish. */
export const cardReserveSchema = z.object({ classIds: z.array(z.string().min(1)).min(1, msg.required).max(500, msg.tooLong) });

/** Partiyadagi raqamga chipni bog'lash. */
export const cardBindSchema = z
  .object({ uid: z.string().trim().max(64, msg.tooLong).optional(), url: z.string().trim().max(1024, msg.tooLong).optional() })
  .refine((d) => Boolean(d.url) || (d.uid ? normalizeReaderUid(d.uid) !== null : false), { message: msg.cardUid, path: ['uid'] });

/** Ta'minotchi fayli: bir yo'la ko'pi bilan shuncha qator. */
export const MAX_IMPORT_ROWS = 2_000;
export const cardImportSchema = z.object({
  rows: z
    .array(z.object({ number: z.string().trim().min(1, msg.required).max(32, msg.tooLong), uid: z.string().trim().min(1, msg.required).max(64, msg.tooLong) }))
    .min(1, msg.required)
    .max(MAX_IMPORT_ROWS, msg.tooLong),
});

export type CardAssignInput = z.infer<typeof cardAssignSchema>;
export type CardReserveInput = z.infer<typeof cardReserveSchema>;
export type CardBindInput = z.infer<typeof cardBindSchema>;
export type CardImportInput = z.infer<typeof cardImportSchema>;
export type CardBlockInput = z.infer<typeof cardBlockSchema>;
export type CardTapInput = z.infer<typeof cardTapSchema>;
