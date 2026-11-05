// Bola ilovasi davomat tarixi: yozuv -> kun elementi. Sof funksiyalar (testlanadi).
// Qoida: tizim (cron) yozgan "kelmadi" bola uchun "Aniqlanmagan" (UNKNOWN) — skanerlanmagan
// kun "kelmadi" emas. Xodim tuzatgan yoki qo'lda belgilagan yozuv — `confirmed`.

import { AttendanceSource, AttendanceStatus } from '@prisma/client';
import { tashkentHhmm } from './attendance-time';
import { addCount, attendedRate, DayCounts, EMPTY_COUNTS, SYSTEM_STAFF_ID } from './attendance-view';

export type ChildDayStatus = AttendanceStatus | 'UNKNOWN';

export interface KioskTimes {
  inAt: string | null;
  outAt: string | null;
}

export interface ChildAttendanceDay {
  date: string;
  status: ChildDayStatus;
  inAt: string | null;
  outAt: string | null;
  source: AttendanceSource;
  confirmed: boolean;
  kiosk: KioskTimes | null;
}

export interface DayRecord {
  date: string;
  status: AttendanceStatus;
  inAt: string | null;
  outAt: string | null;
  source: AttendanceSource;
  corrections: { byStaffId: string }[];
}

export interface DayEvent {
  at: Date;
  date: string;
  kind: 'IN' | 'OUT';
}

/** Tuzatishlar ichida XODIM tuzatishi bormi (QR / cron yozgan `system` tuzatishlari emas). */
export const hasStaffCorrection = (corrections: readonly { byStaffId: string }[]): boolean =>
  corrections.some((c) => c.byStaffId !== SYSTEM_STAFF_ID);

export function toChildDay(record: DayRecord, kiosk: KioskTimes | null): ChildAttendanceDay {
  const staffTouched = record.source === 'MANUAL' || hasStaffCorrection(record.corrections);
  const unscanned = record.source === 'SYSTEM' && record.status === 'ABSENT' && !hasStaffCorrection(record.corrections);
  return {
    date: record.date,
    status: unscanned ? 'UNKNOWN' : record.status,
    inAt: record.inAt,
    outAt: record.outAt,
    source: record.source,
    confirmed: staffTouched,
    kiosk,
  };
}

/** Yozuvi yo'q o'quv kuni — "Aniqlanmagan". */
export const unknownDay = (date: string): ChildAttendanceDay => ({
  date,
  status: 'UNKNOWN',
  inAt: null,
  outAt: null,
  source: 'SYSTEM',
  confirmed: false,
  kiosk: null,
});

/** Kunlik birinchi kirish / oxirgi chiqish (QR va kiosk hodisalaridan), Toshkent "HH:MM". */
export function kioskTimesByDate(events: readonly DayEvent[]): Map<string, KioskTimes> {
  const byDate = new Map<string, DayEvent[]>();
  for (const e of events) byDate.set(e.date, [...(byDate.get(e.date) ?? []), e]);
  const out = new Map<string, KioskTimes>();
  for (const [date, list] of byDate) {
    const sorted = [...list].sort((a, b) => a.at.getTime() - b.at.getTime());
    const firstIn = sorted.find((e) => e.kind === 'IN');
    const lastOut = [...sorted].reverse().find((e) => e.kind === 'OUT');
    out.set(date, { inAt: firstIn ? tashkentHhmm(firstIn.at) : null, outAt: lastOut ? tashkentHhmm(lastOut.at) : null });
  }
  return out;
}

export interface ChildAttendanceSummary {
  present: number;
  late: number;
  absent: number;
  leftEarly: number;
  excused: number;
  unknown: number;
  total: number;
  rate: number;
}

/** O'quv kunlari bo'yicha jami; `UNKNOWN` — "belgilanmagan" (kelganlar ulushiga kirmaydi). */
export function summarize(days: readonly ChildAttendanceDay[]): ChildAttendanceSummary {
  const counts: DayCounts = days.reduce<DayCounts>(
    (acc, d) => addCount(acc, d.status === 'UNKNOWN' ? null : d.status),
    EMPTY_COUNTS,
  );
  const { pending, ...rest } = counts;
  return { present: rest.present, late: rest.late, absent: rest.absent, leftEarly: rest.leftEarly, excused: rest.excused, unknown: pending, total: rest.total, rate: attendedRate(counts) };
}
