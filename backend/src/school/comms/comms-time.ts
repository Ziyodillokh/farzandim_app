// Xabarlar uchun vaqt: panel `datetime-local` qiymatlari Toshkent devor soati
// ("2026-10-14T08:00"), bazada — lahza (DateTime). Toshkentda yozgi vaqt yo'q,
// shuning uchun +5 soat siljitish aniq. Takrorlanuvchi eslatmalar ham Toshkent
// kalendari bo'yicha (oylik — oy qisqa bo'lsa oxirgi kuni, keyin asl kunga qaytadi).

import { DayKey, TASHKENT_OFFSET_MS } from '../../common/time/tashkent';

export type RepeatKind = 'NONE' | 'WEEKLY' | 'MONTHLY';

const LOCAL_DATE_TIME = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$/;
const WEEK_MS = 7 * 24 * 60 * 60 * 1000;
/** Takrorlanish qadamlari chegarasi (600 hafta ≈ 11 yil, 600 oy = 50 yil). */
const MAX_REPEAT_STEPS = 600;

/** "2026-10-14T08:00(:00)" (Toshkent) → lahza; noto'g'ri qiymat → null. */
export function parseLocalDateTime(value: string): Date | null {
  const m = LOCAL_DATE_TIME.exec(value);
  if (!m) return null;
  const [y, mo, d, h, mi, s] = m.slice(1).map((part) => (part === undefined ? 0 : Number(part)));
  const utc = Date.UTC(y!, mo! - 1, d!, h!, mi!, s!);
  const check = new Date(utc);
  const valid =
    check.getUTCFullYear() === y &&
    check.getUTCMonth() === mo! - 1 &&
    check.getUTCDate() === d &&
    check.getUTCHours() === h &&
    check.getUTCMinutes() === mi &&
    check.getUTCSeconds() === s;
  return valid ? new Date(utc - TASHKENT_OFFSET_MS) : null;
}

/** Lahza → Toshkent devor soati "YYYY-MM-DDTHH:MM:SS" (panel shu shaklni kesib ishlatadi). */
export function toLocalDateTime(at: Date): string {
  return new Date(at.getTime() + TASHKENT_OFFSET_MS).toISOString().slice(0, 19);
}

export const toLocalDateTimeOrNull = (at: Date | null): string | null => (at ? toLocalDateTime(at) : null);

/** "2026-10-14 08:00" — audit xulosasi va parametrlari uchun. */
export const localStamp = (at: Date): string => toLocalDateTime(at).slice(0, 16).replace('T', ' ');

/** Toshkent soati (0–23). */
export function tashkentHour(at: Date): number {
  return new Date(at.getTime() + TASHKENT_OFFSET_MS).getUTCHours();
}

/** Boshlang'ich vaqtdan `n` qadam keyin (Toshkent kalendari bo'yicha). */
export function occurrenceAt(anchor: Date, repeat: Exclude<RepeatKind, 'NONE'>, n: number): Date {
  if (repeat === 'WEEKLY') return new Date(anchor.getTime() + n * WEEK_MS);
  const local = new Date(anchor.getTime() + TASHKENT_OFFSET_MS);
  const year = local.getUTCFullYear();
  const month = local.getUTCMonth() + n;
  const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  const utc = Date.UTC(
    year,
    month,
    Math.min(local.getUTCDate(), lastDay),
    local.getUTCHours(),
    local.getUTCMinutes(),
    local.getUTCSeconds(),
  );
  return new Date(utc - TASHKENT_OFFSET_MS);
}

/** Keyingi (`now` dan keyingi) yuborilish; bir martalik o'tgan bo'lsa — null. */
export function nextOccurrence(sendAt: Date, repeat: RepeatKind, now: Date): Date | null {
  if (sendAt.getTime() > now.getTime()) return sendAt;
  if (repeat === 'NONE') return null;
  for (let n = 1; n <= MAX_REPEAT_STEPS; n++) {
    const at = occurrenceAt(sendAt, repeat, n);
    if (at.getTime() > now.getTime()) return at;
  }
  return null;
}

/** Oxirgi (`now` gacha bo'lgan) yuborilish vaqti; hali boshlanmagan bo'lsa — null. */
export function latestOccurrence(sendAt: Date, repeat: RepeatKind, now: Date): Date | null {
  if (sendAt.getTime() > now.getTime()) return null;
  if (repeat === 'NONE') return sendAt;
  let latest = sendAt;
  for (let n = 1; n <= MAX_REPEAT_STEPS; n++) {
    const at = occurrenceAt(sendAt, repeat, n);
    if (at.getTime() > now.getTime()) return latest;
    latest = at;
  }
  return latest;
}

/** Sanaga `months` oy qo'shish (31-yanvar + 1 → 28/29-fevral). */
export function addMonthsDay(day: DayKey, months: number): DayKey {
  const [y, m, d] = day.split('-').map(Number);
  const lastDay = new Date(Date.UTC(y!, m! - 1 + months + 1, 0)).getUTCDate();
  return new Date(Date.UTC(y!, m! - 1 + months, Math.min(d!, lastDay))).toISOString().slice(0, 10);
}
