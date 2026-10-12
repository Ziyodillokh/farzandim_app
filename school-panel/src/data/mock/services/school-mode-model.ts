import type {
  BellPeriod,
  DeviceModeStatus,
  DeviceOs,
  EmergencyState,
  Holiday,
  IsoDate,
  IsoDateTime,
  ListQuery,
  SchoolModeException,
  SchoolModePolicy,
  Shift,
  Student,
} from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { smMsg } from '@/data/schemas/school-mode';
import { hhmmToMinutes, percent } from '@/lib/utils';
import { isSchoolDay } from '../calendar';
import { assertCan, currentActor, type Actor } from '../context';
import { buildIndexes, compareClassesByShiftNow } from '../lookups';
import { classModeState, type ClassModeState } from '../school-mode-state';
import type { Tables } from '../tables';

/** School Mode servisining turlari va sof yordamchilari (servis fayllari shu yerdan oladi). */
export type { ClassModeState };
export type DeviceCounts = Record<DeviceModeStatus, number> & { total: number };
export type OsCounts = Record<DeviceOs, number>;
export type BellPhase =
  | { kind: 'LESSON' | 'BREAK'; periodNo: number; startsAt: string; endsAt: string }
  | { kind: 'BEFORE'; startsAt: string }
  | { kind: 'AFTER' | 'DAY_OFF' };

export type ClassModeRow = {
  classId: string;
  className: string;
  grade: number;
  shiftId: string;
  shiftName: string;
  homeroomName: string | null;
  state: ClassModeState;
  devices: DeviceCounts;
  os: OsCounts;
  /** Qo'llangan / telefoni borlar (%). */
  appliedRate: number;
  activeExceptions: number;
};

export type ShiftNow = { id: string; name: string; start: string; end: string; phase: BellPhase; classCount: number; restrictedClasses: number };
export type OverviewTotals = {
  classes: number;
  restrictedClasses: number;
  devices: DeviceCounts;
  os: OsCounts;
  appliedRate: number;
  activeExceptions: number;
};

export type SchoolModeOverview = {
  now: IsoDateTime;
  today: IsoDate;
  policyEnabled: boolean;
  holiday: Holiday | null;
  emergency: EmergencyState & { byName: string | null; classNames: string[] };
  shifts: ShiftNow[];
  totals: OverviewTotals;
  classes: ClassModeRow[];
};

export type DeviceRow = {
  studentId: string;
  studentName: string;
  studentCode: string;
  classId: string;
  className: string;
  os: DeviceOs;
  status: DeviceModeStatus;
  lastSeenAt: IsoDateTime | null;
  hasException: boolean;
};
export type DeviceFilter = ListQuery & { classId?: string; status?: DeviceModeStatus; os?: DeviceOs };

export type ShiftRow = Shift & { classes: Array<{ id: string; name: string }>; studentCount: number; lessonCount: number; phase: BellPhase };

/** SCHEDULED — hali boshlanmagan (from > hozir); faol hisoblanmaydi. */
export type ExceptionStatus = 'ACTIVE' | 'SCHEDULED' | 'EXPIRED' | 'REVOKED';
export type ExceptionRow = SchoolModeException & { studentName: string; className: string; byName: string; status: ExceptionStatus };
export type ExceptionFilter = { status?: ExceptionStatus | 'ALL'; search?: string };
export type ExceptionList = { items: ExceptionRow[]; counts: Record<ExceptionStatus, number> };
export type RemindResult = { sent: number; skipped: number };

/** Istisno kamida shuncha davom etadi (demo soati 60× tezlikda yursa ham zaxira qoladi). */
export const MIN_EXCEPTION_MS = 5 * 60_000;
/** Muammoli qurilmalar ro'yxat boshida. */
export const STATUS_RANK: Record<DeviceModeStatus, number> = { NO_PERMISSION: 0, OFFLINE: 1, NO_PHONE: 2, APPLIED: 3 };
const DEVICE_KEYS = ['APPLIED', 'NO_PERMISSION', 'NO_PHONE', 'OFFLINE', 'total'] as const;
const OS_KEYS = ['IOS', 'ANDROID', 'NONE'] as const;

const emptyCounts = (): DeviceCounts => ({ APPLIED: 0, NO_PERMISSION: 0, NO_PHONE: 0, OFFLINE: 0, total: 0 });
const emptyOs = (): OsCounts => ({ IOS: 0, ANDROID: 0, NONE: 0 });
const phoneRate = (c: DeviceCounts): number => percent(c.APPLIED, c.total - c.NO_PHONE);

export function viewer(): Actor {
  const actor = currentActor();
  assertCan(actor, 'schoolMode.view');
  return actor;
}

/**
 * Istisno holati. Vaqtlar faqat `Date.parse` bilan solishtiriladi: seed mahalliy
 * "YYYY-MM-DDTHH:MM:SS", yangi yozuvlar esa UTC "…Z" ko'rinishida saqlanadi.
 */
export function exceptionStatus(e: SchoolModeException, nowMs: number): ExceptionStatus {
  if (e.revokedAt) return 'REVOKED';
  const untilMs = Date.parse(e.until);
  if (!Number.isFinite(untilMs) || untilMs <= nowMs) return 'EXPIRED';
  const fromMs = Date.parse(e.from);
  return Number.isFinite(fromMs) && fromMs > nowMs ? 'SCHEDULED' : 'ACTIVE';
}

/** [fromMs, untilMs) oralig'iga to'g'ri keladigan, bekor qilinmagan istisno bormi. */
export function overlapsException(e: SchoolModeException, fromMs: number, untilMs: number): boolean {
  if (e.revokedAt) return false;
  return Date.parse(e.from) < untilMs && Date.parse(e.until) > fromMs;
}

/** Smena qo'ng'iroq jadvali bo'yicha hozirgi bosqich (siyosat va favqulodda holatsiz). */
export function bellPhase(shift: Shift, date: IsoDate, minute: number, holidays: readonly Holiday[]): BellPhase {
  if (!isSchoolDay(date, shift, holidays)) return { kind: 'DAY_OFF' };
  if (minute < hhmmToMinutes(shift.start)) return { kind: 'BEFORE', startsAt: shift.start };
  const period = shift.periods.find((p) => minute >= hhmmToMinutes(p.start) && minute < hhmmToMinutes(p.end));
  return period ? { kind: period.kind, periodNo: period.no, startsAt: period.start, endsAt: period.end } : { kind: 'AFTER' };
}

/** Tanaffus raqami — oldingi dars raqami (seed bilan bir xil). */
export function numberPeriods(periods: ReadonlyArray<Omit<BellPeriod, 'no'>>): BellPeriod[] {
  let lesson = 0;
  return periods.map((p) => {
    if (p.kind === 'LESSON') lesson += 1;
    return { no: Math.max(1, lesson), start: p.start, end: p.end, kind: p.kind };
  });
}

export const statusMap = (t: Tables): Map<string, DeviceModeStatus> => new Map(t.devices.map((d) => [d.studentId, d.status]));

export function deviceStatusOf(statuses: ReadonlyMap<string, DeviceModeStatus>, student: Student): DeviceModeStatus {
  return statuses.get(student.id) ?? (student.device === 'NONE' ? 'NO_PHONE' : 'OFFLINE');
}

export function requirePolicy(t: Tables): SchoolModePolicy {
  const policy = t.policies[0];
  if (!policy) throw new ServiceError('NOT_FOUND', 'policy');
  return policy;
}

type Bucket = { devices: DeviceCounts; os: OsCounts };

function bucketsByClass(t: Tables): Map<string, Bucket> {
  const statuses = statusMap(t);
  const byClass = new Map<string, Bucket>();
  for (const s of t.students) {
    if (s.archived) continue;
    const bucket = byClass.get(s.classId) ?? { devices: emptyCounts(), os: emptyOs() };
    bucket.devices[deviceStatusOf(statuses, s)] += 1;
    bucket.devices.total += 1;
    bucket.os[s.device] += 1;
    byClass.set(s.classId, bucket);
  }
  return byClass;
}

export function buildClassRows(t: Tables, classIds: string[] | null, today: IsoDate, minute: number, nowMs: number): ClassModeRow[] {
  const idx = buildIndexes(t);
  const buckets = bucketsByClass(t);
  const activeByClass = new Map<string, number>();
  for (const e of t.exceptions) {
    if (exceptionStatus(e, nowMs) === 'ACTIVE') activeByClass.set(e.classId, (activeByClass.get(e.classId) ?? 0) + 1);
  }
  return t.classes
    .filter((c) => !classIds || classIds.includes(c.id))
    .sort(compareClassesByShiftNow(t, today, minute))
    .map((c) => {
      const bucket = buckets.get(c.id) ?? { devices: emptyCounts(), os: emptyOs() };
      return {
        classId: c.id,
        className: c.name,
        grade: c.grade,
        shiftId: c.shiftId,
        shiftName: idx.shifts.get(c.shiftId)?.name ?? '',
        homeroomName: c.homeroomStaffId ? (idx.staff.get(c.homeroomStaffId)?.fullName ?? null) : null,
        state: classModeState(t, c, today, minute),
        devices: bucket.devices,
        os: bucket.os,
        appliedRate: phoneRate(bucket.devices),
        activeExceptions: activeByClass.get(c.id) ?? 0,
      };
    });
}

export function sumTotals(rows: readonly ClassModeRow[]): OverviewTotals {
  const devices = emptyCounts();
  const os = emptyOs();
  let restrictedClasses = 0;
  let activeExceptions = 0;
  for (const r of rows) {
    for (const k of DEVICE_KEYS) devices[k] += r.devices[k];
    for (const k of OS_KEYS) os[k] += r.os[k];
    if (r.state.restricted) restrictedClasses += 1;
    activeExceptions += r.activeExceptions;
  }
  return { classes: rows.length, restrictedClasses, devices, os, appliedRate: phoneRate(devices), activeExceptions };
}

/** "HH:MM" — demo kunining shu vaqti; aks holda ISO sana-vaqt. */
export function resolveUntil(value: string, now: Date): Date {
  const match = /^(\d{2}):(\d{2})$/.exec(value);
  if (!match) return new Date(value);
  return new Date(now.getFullYear(), now.getMonth(), now.getDate(), Number(match[1]), Number(match[2]), 0, 0);
}

/** Muddat: kamida bir necha daqiqa, ko'pi bilan shu kun oxirigacha. */
export function assertUntilWindow(until: Date, now: Date): void {
  const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
  if (until.getTime() - now.getTime() < MIN_EXCEPTION_MS) throw new ServiceError('VALIDATION', `until: ${smMsg.untilPast}`);
  if (until.getTime() > endOfDay.getTime()) throw new ServiceError('VALIDATION', `until: ${smMsg.untilTooFar}`);
}
