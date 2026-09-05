/**
 * Multipart yuklashda kelgan `metadata` ni xavfsizlashtirish.
 *
 * ⚠️ NEGA KERAK: `/admin/{audiobooks,books}/upload` multipart bo'lgani
 * uchun DTO va ValidationPipe'dan O'TMAYDI — `meta` oddiy `any`. Ya'ni
 * `planRequired` ga istalgan matn tushishi mumkin edi.
 *
 * Bu jimgina halokat: `PLAN_RANK` faqat free/standard/premium/vip ni
 * biladi. Boshqa qiymat (masalan `basic` — repo'ning O'Z seed skripti
 * shuni yozardi, yoki oddiy xato) `planRequired IN allowedPlans(...)`
 * filtriga HECH QACHON tushmaydi. Natijada kontent HAR QANDAY
 * foydalanuvchiga — hatto eng qimmat tarifdagisiga ham — ko'rinmaydi,
 * admin panelda esa "tasdiqlangan" bo'lib turadi. (2026-09-05 auditi)
 */

/** `PLAN_RANK` biladigan yagona qiymatlar. */
export const PLAN_REQUIRED_VALUES = [
  'free',
  'standard',
  'premium',
  'vip',
] as const;

export type PlanRequired = (typeof PLAN_REQUIRED_VALUES)[number];

/**
 * Tanilmagan/buzuq qiymatni `free` ga keltiradi.
 *
 * `free` ni tanlash ATAYLAB: noto'g'ri qiymat kontentni hammaga
 * ko'rinmas qilgandan ko'ra, hammaga ko'rinadigan qilgan xavfsizroq —
 * birinchi holat sezilmaydi, ikkinchisi darhol ko'rinadi va tuzatiladi.
 */
export function normalizePlanRequired(raw: unknown): PlanRequired {
  if (typeof raw !== 'string') return 'free';
  const v = raw.trim().toLowerCase();
  return (PLAN_REQUIRED_VALUES as readonly string[]).includes(v)
    ? (v as PlanRequired)
    : 'free';
}

/** Manfiy yoki son bo'lmagan DON ballni standart qiymatga keltiradi. */
export function normalizeXpReward(raw: unknown, fallback = 50): number {
  const n = typeof raw === 'number' ? raw : Number(raw);
  if (!Number.isFinite(n) || n < 0) return fallback;
  return Math.floor(n);
}
