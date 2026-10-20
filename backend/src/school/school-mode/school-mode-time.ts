// School Mode vaqt mantig'i (sof funksiyalar, Toshkent vaqti): smena
// bosqichi, sinf holati, istisno holati, cheklov oynalari. Xavfsizlik
// qoidasi: jadval tugashi bilan cheklov avtomatik tugaydi.

import { isoWeekday, TASHKENT_OFFSET_MS, tashkentDayStart } from '../../common/time/tashkent';

export type PeriodKind = 'LESSON' | 'BREAK';
export interface BellPeriod {
  no: number;
  start: string;
  end: string;
  kind: PeriodKind;
}
export interface ShiftLike {
  id: string;
  start: string;
  end: string;
  weekdays: number[];
  periods: BellPeriod[];
}
export interface PolicyLike {
  enabled: boolean;
  shiftIds: string[];
  relaxDuringBreaks: boolean;
}
export interface EmergencyLike {
  active: boolean;
  scope: string;
  classIds: string[];
}

export type BellPhase =
  | { kind: PeriodKind; periodNo: number; startsAt: string; endsAt: string }
  | { kind: 'BEFORE'; startsAt: string }
  | { kind: 'AFTER' | 'DAY_OFF' };

export type ClassModeState =
  | { kind: PeriodKind; periodNo: number; endsAt: string; restricted: boolean }
  | { kind: 'BEFORE'; startsAt: string; restricted: false }
  | { kind: 'AFTER' | 'DAY_OFF' | 'EMERGENCY_OFF' | 'DISABLED'; restricted: false };

export type ExceptionStatus = 'ACTIVE' | 'SCHEDULED' | 'EXPIRED' | 'REVOKED';

const DAY_MINUTES = 1440;

export const hhmmToMinutes = (hhmm: string): number => {
  const [h = 0, m = 0] = hhmm.split(':').map(Number);
  return h * 60 + m;
};

export const minutesToHhmm = (minutes: number): string =>
  `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`;

/** Toshkent kunining boshidan o'tgan daqiqa (0..1439). */
export function tashkentMinute(now: Date): number {
  const local = new Date(now.getTime() + TASHKENT_OFFSET_MS);
  return local.getUTCHours() * 60 + local.getUTCMinutes();
}

/** Toshkent kunidagi daqiqa → mutlaq vaqt. */
export function tashkentInstant(day: string, minutes: number): Date {
  return new Date(tashkentDayStart(day).getTime() + minutes * 60_000);
}

export function isSchoolDay(day: string, shift: Pick<ShiftLike, 'weekdays'>, holidays: ReadonlyArray<{ date: string }>): boolean {
  return shift.weekdays.includes(isoWeekday(day)) && !holidays.some((h) => h.date === day);
}

/** Smena qo'ng'iroq jadvali bo'yicha hozirgi bosqich (siyosat va favqulodda holatsiz). */
export function bellPhase(shift: ShiftLike, day: string, minute: number, holidays: ReadonlyArray<{ date: string }>): BellPhase {
  if (!isSchoolDay(day, shift, holidays)) return { kind: 'DAY_OFF' };
  if (minute < hhmmToMinutes(shift.start)) return { kind: 'BEFORE', startsAt: shift.start };
  const period = shift.periods.find((p) => minute >= hhmmToMinutes(p.start) && minute < hhmmToMinutes(p.end));
  return period ? { kind: period.kind, periodNo: period.no, startsAt: period.start, endsAt: period.end } : { kind: 'AFTER' };
}

/** Siyosat shu smenaga qo'llanadimi. */
export const policyCovers = (policy: PolicyLike, shiftId: string) => policy.enabled && policy.shiftIds.includes(shiftId);

export const emergencyCovers = (emergency: EmergencyLike, classId: string) =>
  emergency.active && (emergency.scope === 'SCHOOL' || emergency.classIds.includes(classId));

export function classModeState(
  input: { classId: string; shift: ShiftLike | null; policy: PolicyLike; emergency: EmergencyLike; holidays: ReadonlyArray<{ date: string }> },
  day: string,
  minute: number,
): ClassModeState {
  const { shift, policy, emergency } = input;
  if (!shift || !isSchoolDay(day, shift, input.holidays)) return { kind: 'DAY_OFF', restricted: false };
  if (!policyCovers(policy, shift.id)) return { kind: 'DISABLED', restricted: false };
  if (emergencyCovers(emergency, input.classId)) return { kind: 'EMERGENCY_OFF', restricted: false };
  if (minute < hhmmToMinutes(shift.start)) return { kind: 'BEFORE', startsAt: shift.start, restricted: false };
  if (minute >= hhmmToMinutes(shift.end)) return { kind: 'AFTER', restricted: false };
  const period = shift.periods.find((p) => minute >= hhmmToMinutes(p.start) && minute < hhmmToMinutes(p.end));
  if (!period) return { kind: 'AFTER', restricted: false };
  const restricted = period.kind === 'LESSON' || !policy.relaxDuringBreaks;
  return { kind: period.kind, periodNo: period.no, endsAt: period.end, restricted };
}

export function exceptionStatus(e: { from: Date; until: Date; revokedAt: Date | null }, now: Date): ExceptionStatus {
  if (e.revokedAt) return 'REVOKED';
  if (e.until.getTime() <= now.getTime()) return 'EXPIRED';
  return e.from.getTime() > now.getTime() ? 'SCHEDULED' : 'ACTIVE';
}

/** Tanaffus raqami — oldingi dars raqami. */
export function numberPeriods(periods: ReadonlyArray<Omit<BellPeriod, 'no'>>): BellPeriod[] {
  let lesson = 0;
  return periods.map((p) => {
    if (p.kind === 'LESSON') lesson += 1;
    return { no: Math.max(1, lesson), start: p.start, end: p.end, kind: p.kind };
  });
}

export type Window = { start: number; end: number };

/** Kun davomidagi cheklov oynalari (daqiqalarda): tanaffusda yumshatish — faqat darslar. */
export function restrictedWindows(shift: ShiftLike, policy: PolicyLike): Window[] {
  if (!policy.relaxDuringBreaks) return [{ start: hhmmToMinutes(shift.start), end: hhmmToMinutes(shift.end) }];
  return shift.periods
    .filter((p) => p.kind === 'LESSON')
    .map((p) => ({ start: hhmmToMinutes(p.start), end: hhmmToMinutes(p.end) }));
}

/** Oynalardan [cut.start, cut.end) oralig'ini olib tashlash. */
export function subtractWindow(windows: readonly Window[], cut: Window): Window[] {
  return windows.flatMap((w) => {
    if (cut.end <= w.start || cut.start >= w.end) return [w];
    return [
      ...(cut.start > w.start ? [{ start: w.start, end: cut.start }] : []),
      ...(cut.end < w.end ? [{ start: cut.end, end: w.end }] : []),
    ];
  });
}

/** Mutlaq [from, until) — shu Toshkent kunining daqiqalariga (kun chegarasida kesiladi). */
export function dayWindowOf(day: string, from: Date, until: Date): Window | null {
  const dayStart = tashkentInstant(day, 0).getTime();
  const start = Math.max(0, Math.floor((from.getTime() - dayStart) / 60_000));
  const end = Math.min(DAY_MINUTES, Math.ceil((until.getTime() - dayStart) / 60_000));
  return end > start ? { start, end } : null;
}
