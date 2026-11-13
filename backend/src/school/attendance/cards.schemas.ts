// NFC kartalar: biriktirish, bloklash, kiosk tegishi (panel `school-panel/src/data/schemas/cards.ts`).
// Karta panelda yoki kioskda Web NFC bilan o'qiladi: `uid` — chip seriya raqami,
// `url` — kartadagi NDEF manzil (NTAG 424 DNA bo'lsa imzolangan kod bilan).

import { z } from 'zod';
import { msg } from '../common/school-zod';

export const CARD_STATUSES = ['ACTIVE', 'LOST', 'BLOCKED'] as const;
export const CARD_BLOCK_REASONS = ['LOST', 'BLOCKED'] as const;

const idSchema = z.string({ error: msg.required }).trim().min(1, msg.required).max(64, msg.tooLong);
const uidSchema = z.string().trim().max(64, msg.tooLong).optional();
const urlSchema = z.string().trim().max(1024, msg.tooLong).optional();

/** Karta ma'lumoti: seriya raqami yoki kartadagi manzil (kamida bittasi). */
const hasCardData = (d: { uid?: string; url?: string }) => Boolean(d.uid || d.url);

export const cardAssignSchema = z
  .object({
    studentId: idSchema,
    uid: uidSchema,
    url: urlSchema,
    /** Kartaga bosilgan raqam; bo'sh bo'lsa — keyingi `K-000001` ko'rinishidagi raqam. */
    number: z.string().trim().min(1, msg.required).max(32, msg.tooLong).optional(),
  })
  .refine(hasCardData, { message: msg.cardUid, path: ['uid'] });

export const cardBlockSchema = z.object({
  reason: z.enum(CARD_BLOCK_REASONS, { error: msg.required }),
  note: z.string().trim().max(200, msg.tooLong).optional(),
});

export const cardTapSchema = z
  .object({
    uid: uidSchema,
    url: urlSchema,
    /** Kiosk qurilmasi belgisi (brauzerda saqlanadi) — "bir o'qigichda 3 soniyada 2 karta" qoidasi uchun. */
    kioskId: z.string().trim().max(64, msg.tooLong).optional(),
    /** Oflayn navbatdan kech yuborilgan tegishning asl vaqti. */
    tappedAt: z.iso.datetime({ error: msg.date }).optional(),
  })
  .refine(hasCardData, { message: msg.cardUid, path: ['uid'] });

export const cardListQuerySchema = z.object({
  status: z.enum(CARD_STATUSES).optional(),
});

export const cardTapsQuerySchema = z.object({
  suspicious: z.enum(['true', 'false']).optional(),
  limit: z.coerce.number().int().min(1).max(200).default(50),
});
