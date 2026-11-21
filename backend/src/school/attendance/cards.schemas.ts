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
    // Kartaga bosiladigan raqamni har doim tizim beradi (`card-number.ts`), qo'lda kiritilmaydi.
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

/** Karta partiyasi: tanlangan sinflardagi kartasiz o'quvchilarga raqam ajratish. */
export const cardReserveSchema = z.object({
  classIds: z.array(idSchema).min(1, msg.required).max(500, msg.tooLong),
});

/** Partiyadagi raqamga chipni bog'lash (ketma-ket biriktirish). */
export const cardBindSchema = z
  .object({ uid: uidSchema, url: urlSchema })
  .refine(hasCardData, { message: msg.cardUid, path: ['uid'] });

/** Ta'minotchi fayli: kartaga bosilgan raqam ↔ chip UID (bir yo'la ko'p karta). */
export const MAX_IMPORT_ROWS = 2_000;
export const cardImportSchema = z.object({
  rows: z
    .array(
      z.object({
        number: z.string().trim().min(1, msg.required).max(32, msg.tooLong),
        uid: z.string().trim().min(1, msg.required).max(64, msg.tooLong),
      }),
    )
    .min(1, msg.required)
    .max(MAX_IMPORT_ROWS, msg.tooLong),
});
