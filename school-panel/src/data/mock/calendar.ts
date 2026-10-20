import type { Holiday, IsoDate, IsoWeekday, Shift } from '@/data/contracts';

/** Mahalliy sana → "YYYY-MM-DD" (UTC ga o'tkazmasdan). */
export function toIsoDate(date: Date): IsoDate {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/**
 * Mahalliy vaqt "YYYY-MM-DDTHH:MM:SS" (UTC'siz) — seed bilan bir xil format.
 * Vaqtlarni solishtirishda doim `Date.parse` ishlatiladi (eski yozuvlarda `…Z` ham bor).
 */
export function toLocalIso(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${toIsoDate(date)}T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

/** "YYYY-MM-DD" → mahalliy yarim tun. */
export function fromIsoDate(value: IsoDate): Date {
  const [y, m, d] = value.split('-').map(Number);
  return new Date(y ?? 1970, (m ?? 1) - 1, d ?? 1);
}

export function addDays(value: IsoDate, days: number): IsoDate {
  const date = fromIsoDate(value);
  date.setDate(date.getDate() + days);
  return toIsoDate(date);
}

/** ISO hafta kuni: dushanba = 1 … yakshanba = 7. */
export function isoWeekday(value: IsoDate): IsoWeekday {
  const day = fromIsoDate(value).getDay();
  return (day === 0 ? 7 : day) as IsoWeekday;
}

/** Hafta boshi (dushanba). */
export function weekStart(value: IsoDate): IsoDate {
  return addDays(value, 1 - isoWeekday(value));
}

export function isHoliday(value: IsoDate, holidays: readonly Holiday[]): boolean {
  return holidays.some((h) => h.date === value);
}

export function isSchoolDay(value: IsoDate, shift: Pick<Shift, 'weekdays'>, holidays: readonly Holiday[]): boolean {
  return shift.weekdays.includes(isoWeekday(value)) && !isHoliday(value, holidays);
}

/** [from, to] oralig'idagi sanalar (ikkala chegara ham). */
export function dateRange(from: IsoDate, to: IsoDate): IsoDate[] {
  const out: IsoDate[] = [];
  for (let d = from; d <= to; d = addDays(d, 1)) out.push(d);
  return out;
}
