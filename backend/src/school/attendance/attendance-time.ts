// Davomat vaqti: Toshkent kuni / daqiqasi va o'quv kunlari. Soat (`AttendanceClock`)
// injektsiya qilinadi — e2e testlar `now()` ni almashtirib kechikish, kiosk
// oynasi va "kelmadi" cron'ini aniq vaqtda tekshiradi.

import { Injectable } from '@nestjs/common';
import { addDays, isoWeekday, TASHKENT_OFFSET_MS } from '../../common/time/tashkent';

@Injectable()
export class AttendanceClock {
  now(): Date {
    return new Date();
  }
}

/** Toshkent vaqti bo'yicha kun boshidan o'tgan daqiqalar (soniyalar — kasr qism). */
export function tashkentMinute(at: Date): number {
  const local = new Date(at.getTime() + TASHKENT_OFFSET_MS);
  return local.getUTCHours() * 60 + local.getUTCMinutes() + local.getUTCSeconds() / 60;
}

/** `"08:30"` → 510 (noto'g'ri format — NaN). */
export function hhmmToMinutes(value: string): number {
  const match = /^(\d{2}):(\d{2})$/.exec(value);
  return match ? Number(match[1]) * 60 + Number(match[2]) : Number.NaN;
}

/** 510 → `"08:30"`. */
export function minutesToHhmm(total: number): string {
  const safe = ((Math.round(total) % 1440) + 1440) % 1440;
  return `${String(Math.floor(safe / 60)).padStart(2, '0')}:${String(safe % 60).padStart(2, '0')}`;
}

/** Lahzaning Toshkent vaqti `"HH:MM"` (daqiqagacha qirqiladi). */
export function tashkentHhmm(at: Date): string {
  return minutesToHhmm(Math.floor(tashkentMinute(at)));
}

/** O'quv kuni: smena hafta kuni va bayram emas (panel `isSchoolDay`). */
export function isSchoolDay(
  date: string,
  shift: { weekdays: number[] } | null | undefined,
  holidays: ReadonlySet<string>,
): boolean {
  return Boolean(shift && shift.weekdays.includes(isoWeekday(date)) && !holidays.has(date));
}

/** [from, to] oralig'idagi kunlar (ikkala chegara ham). */
export function dateRange(from: string, to: string): string[] {
  const out: string[] = [];
  for (let d = from; d <= to; d = addDays(d, 1)) out.push(d);
  return out;
}

/** `"2026-10"` → oyning birinchi va oxirgi kuni. */
export function monthBounds(month: string): { first: string; last: string } {
  const [y, m] = month.split('-').map(Number);
  const lastDay = new Date(Date.UTC(y ?? 1970, m ?? 1, 0)).getUTCDate();
  return { first: `${month}-01`, last: `${month}-${String(lastDay).padStart(2, '0')}` };
}

/** Kechikish: smena boshlanishi + `lateAfterMinutes` dan keyin (panel kiosk qoidasi). */
export function isLateAt(minute: number, shiftStart: string, lateAfterMinutes: number): boolean {
  return minute > hhmmToMinutes(shiftStart) + lateAfterMinutes;
}

/**
 * Jonli taxta tartibi: hozir darsi ketayotgan smena — 0, bugun hali
 * boshlanmagan — 1, tugagan / dam olishdagi — 2 (panel `compareClassesByShiftNow`).
 */
export function shiftNowRank(
  shift: { start: string; end: string; weekdays: number[] },
  date: string,
  minute: number,
  holidays: ReadonlySet<string>,
): number {
  if (!isSchoolDay(date, shift, holidays) || minute >= hhmmToMinutes(shift.end)) return 2;
  return minute >= hhmmToMinutes(shift.start) ? 0 : 1;
}
