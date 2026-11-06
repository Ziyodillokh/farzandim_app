/**
 * Kirish (5-bosqich) ko'rsatish yordamchilari: kodni 3+3 guruhlash, muddatgacha qolgan vaqt.
 */

const CODE_GROUP = 3;
const MINUTE_MS = 60_000;
const MINUTES_PER_HOUR = 60;

/** "123456" → "123 456" (3+3). Boshqa uzunlikdagi qiymat o'zgarishsiz qaytadi. */
export function groupCode(code: string): string {
  return /^\d{6}$/.test(code) ? `${code.slice(0, CODE_GROUP)} ${code.slice(CODE_GROUP)}` : code;
}

/** Ekran o'qish dasturi uchun: "1 2 3, 4 5 6". */
export function spokenCode(code: string): string {
  return /^\d{6}$/.test(code) ? `${[...code.slice(0, CODE_GROUP)].join(' ')}, ${[...code.slice(CODE_GROUP)].join(' ')}` : [...code].join(' ');
}

export type Remaining = { expired: true } | { expired: false; hours: number; minutes: number };

/** `expiresAt` gacha qolgan vaqt; o'tib ketgan (yoki noto'g'ri sana) — `expired`. 1 daqiqadan kam — `hours = minutes = 0`. */
export function remainingUntil(expiresAt: string, nowMs: number): Remaining {
  const left = Date.parse(expiresAt) - nowMs;
  if (!Number.isFinite(left) || left <= 0) return { expired: true };
  const total = Math.floor(left / MINUTE_MS);
  return { expired: false, hours: Math.floor(total / MINUTES_PER_HOUR), minutes: total % MINUTES_PER_HOUR };
}

/** Clipboard'ga nusxalash uchun qiymat: bo'shliqsiz raqamlar. */
export function plainCode(code: string): string {
  return code.replace(/\s+/g, '');
}
