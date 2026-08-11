// Uzum Bank MERCHANT API — konstantalar.
//
// DIQQAT: bu integratsiya `providers/uzum.provider.ts` dan BOSHQA:
//   • provider (eski)  — BIZ Uzum'ga checkout URL yasaymiz (hozir o'chiq)
//   • merchant (bu)    — UZUM BIZGA so'rov yuboradi (check/create/confirm/
//                        reverse/status), foydalanuvchi Uzum ilovasi ichida
//                        to'laydi
//
// Manba: Uzum Merchant API (developer.uzumbank.uz/merchant). Xato kodlari va
// javob statuslari kanonik ro'yxat bo'yicha.

/** Uzum kutadigan xato kodlari. */
export const UzumErrorCode = {
  AuthorizationError: 10001,
  ErrorParsingJSON: 10002,
  UnknownOperation: 10003,
  NotEnoughParamsInRequest: 10005,
  InvalidServiceId: 10006,
  PaymentAlreadyProcessed: 10007,
  AdditionalPaymentPropertyNotFound: 10008,
  PaymentCancelled: 10009,
  ErrorCheckingPaymentData: 99999,
} as const;

/** Uzum kutadigan javob statuslari. */
export const UzumStatus = {
  Ok: 'OK',
  Failed: 'FAILED',
  Cancelled: 'CANCELLED',
  Created: 'CREATED',
  Confirmed: 'CONFIRMED',
  Reversed: 'REVERSED',
} as const;

export type UzumStatusValue = (typeof UzumStatus)[keyof typeof UzumStatus];

/**
 * Uzum summani TIYINDA yuboradi (1 so'm = 100 tiyin), bizning `Payment.amount`
 * esa SO'MDA. Konvertatsiya shu ikki funksiya orqali — qo'lda 100 ga bo'lish
 * kod bo'ylab tarqalib ketmasin.
 */
export const tiyinToSom = (tiyin: number): number => Math.round(tiyin / 100);
export const somToTiyin = (som: number): number => Math.round(som * 100);

/**
 * Abonent identifikatori sifatida qabul qilinadigan kalitlar (`params` ichida).
 * BIZ Uzum'ga `phone` ni tavsiya qilamiz, lekin ular boshqa nom ishlatishi
 * mumkin — birinchi test aylanishida "field name" tufayli yiqilmaslik uchun
 * keng qabul qilamiz. Aniq nom kelishilgach bu ro'yxat qisqartiriladi.
 */
export const ACCOUNT_PARAM_KEYS = [
  'phone',
  'account',
  'login',
  'userId',
  'user_id',
] as const;

/**
 * Tarif identifikatori sifatida qabul qilinadigan kalitlar (ixtiyoriy).
 * Berilmasa tarif SUMMA bo'yicha aniqlanadi.
 */
export const PLAN_PARAM_KEYS = [
  'planCode',
  'plan_code',
  'planId',
  'plan_id',
  'tariff',
] as const;
