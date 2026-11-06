// Bola ovozi — ish vaqti hisobi (sof funksiyalar, Toshkent vaqti). Javob muddati
// (SLA) ish vaqtida o'lchanadi: dam olish kunlari, bayramlar (`SchoolHoliday`) va
// ish soatlaridan tashqari vaqt hisobga olinmaydi. Eskalatsiya cron'i va bola
// ilovasidagi "hozir ishlayaptimi" ko'rsatkichi shu yerdan foydalanadi.

import { addDays, isoWeekday, tashkentDay, tashkentDayStart } from '../../common/time/tashkent';

const MINUTE_MS = 60_000;
/** Ish kuni topilmasa (kunlar bo'sh, hamma kun bayram) shuncha kun oldinga qaraymiz. */
export const MAX_LOOKAHEAD_DAYS = 400;

export interface WorkingHours {
  /** ISO hafta kunlari: 1 = dushanba … 7 = yakshanba. */
  days: readonly number[];
  /** "HH:MM" (Toshkent). */
  start: string;
  end: string;
}

export type HolidaySet = ReadonlySet<string>;

/** "09:30" → 570; noto'g'ri format — NaN. */
export function hhmmToMinutes(value: string): number {
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(value);
  return match ? Number(match[1]) * 60 + Number(match[2]) : Number.NaN;
}

interface Window {
  start: number;
  end: number;
}

/** Kunning ish oynasi (ms) yoki dam olish / bayram / noto'g'ri soatlar bo'lsa `null`. */
function windowOf(day: string, hours: WorkingHours, holidays: HolidaySet): Window | null {
  if (!hours.days.includes(isoWeekday(day)) || holidays.has(day)) return null;
  const from = hhmmToMinutes(hours.start);
  const to = hhmmToMinutes(hours.end);
  if (!(from < to)) return null;
  const base = tashkentDayStart(day).getTime();
  return { start: base + from * MINUTE_MS, end: base + to * MINUTE_MS };
}

/** Lahza ish oynasi ichidami: `[start, end)`. */
export function isWorkingAt(at: Date, hours: WorkingHours, holidays: HolidaySet): boolean {
  const w = windowOf(tashkentDay(at), hours, holidays);
  return w !== null && at.getTime() >= w.start && at.getTime() < w.end;
}

/** `at` ish vaqtida bo'lsa — o'zi; aks holda keyingi ish oynasining boshi (topilmasa `null`). */
export function nextWorkingStart(at: Date, hours: WorkingHours, holidays: HolidaySet): Date | null {
  let day = tashkentDay(at);
  for (let i = 0; i < MAX_LOOKAHEAD_DAYS; i += 1) {
    const w = windowOf(day, hours, holidays);
    if (w && at.getTime() < w.end) return new Date(Math.max(at.getTime(), w.start));
    day = addDays(day, 1);
  }
  return null;
}

/**
 * `from` dan boshlab `minutes` daqiqa ISH VAQTI o'tgan lahza (muddat). `from` ish
 * vaqtidan tashqarida bo'lsa, hisob keyingi ish oynasi boshidan boshlanadi. Muddat
 * aniq ish kuni oxiriga to'g'ri kelsa — shu oxirgi lahza (oyna `[start, end)`).
 * Topilmasa (ish kuni yo'q) `null`.
 */
export function addWorkingMinutes(from: Date, minutes: number, hours: WorkingHours, holidays: HolidaySet): Date | null {
  let remaining = Math.max(0, minutes) * MINUTE_MS;
  let day = tashkentDay(from);
  for (let i = 0; i < MAX_LOOKAHEAD_DAYS; i += 1) {
    const w = windowOf(day, hours, holidays);
    if (w && from.getTime() < w.end) {
      const start = Math.max(from.getTime(), w.start);
      const available = w.end - start;
      if (remaining <= available) return new Date(start + remaining);
      remaining -= available;
    }
    day = addDays(day, 1);
  }
  return null;
}
