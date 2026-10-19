// Toshkent vaqti (Asia/Tashkent, UTC+5, yozgi vaqt yo'q) — kunlik mantiq
// (kunlik testlar, streak, davomat) uchun YAGONA manba. Server UTC'da
// ishlaydi, shuning uchun `new Date().getDate()` kabi lokal hisoblar
// 00:00–05:00 oralig'ida noto'g'ri kun beradi.

export const TASHKENT_TZ = 'Asia/Tashkent';
export const TASHKENT_OFFSET_MS = 5 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

/** Kun kaliti: `YYYY-MM-DD` (Toshkent). */
export type DayKey = string;

const DAY_KEY = /^\d{4}-\d{2}-\d{2}$/;

/** Berilgan lahzaning Toshkent kuni. */
export function tashkentDay(at: Date = new Date()): DayKey {
  return new Date(at.getTime() + TASHKENT_OFFSET_MS).toISOString().slice(0, 10);
}

export function isDayKey(value: string): value is DayKey {
  if (!DAY_KEY.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().startsWith(value);
}

/** Toshkent kunining boshlanishi (UTC lahza). */
export function tashkentDayStart(day: DayKey): Date {
  return new Date(Date.parse(`${day}T00:00:00Z`) - TASHKENT_OFFSET_MS);
}

/** `[boshlanish, tugash)` — kun bo'yicha so'rovlar uchun. */
export function tashkentDayRange(day: DayKey): { gte: Date; lt: Date } {
  const gte = tashkentDayStart(day);
  return { gte, lt: new Date(gte.getTime() + DAY_MS) };
}

/** Kunga `n` kun qo'shish (manfiy — orqaga). */
export function addDays(day: DayKey, n: number): DayKey {
  return new Date(Date.parse(`${day}T00:00:00Z`) + n * DAY_MS)
    .toISOString()
    .slice(0, 10);
}

/** `b - a` kunlarda. */
export function daysBetween(a: DayKey, b: DayKey): number {
  return Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / DAY_MS);
}

/** ISO hafta kuni (1 = dushanba … 7 = yakshanba). */
export function isoWeekday(day: DayKey): number {
  const weekday = new Date(`${day}T00:00:00Z`).getUTCDay();
  return weekday === 0 ? 7 : weekday;
}
