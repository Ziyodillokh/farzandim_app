// Davomat yozuvlari — panel kontraktlariga (`AttendanceRecord`, `AttendanceEvent`,
// `EarlyExitRequest`, `ParentNotification`) o'girish va kunlik hisoblagichlar.

import {
  AttendanceStatus,
  ParentNoticeKind,
  Prisma,
  SchoolAttendance,
  SchoolAttendanceCorrection,
  SchoolAttendanceEvent,
  SchoolEarlyExit,
  SchoolParentNotice,
} from '@prisma/client';

/** Yozuv + tuzatishlar tarixi (eng eskisi birinchi — panel massiv tartibi). */
export const recordInclude = {
  corrections: { orderBy: { at: 'asc' } },
} satisfies Prisma.SchoolAttendanceInclude;

export type RecordWithCorrections = SchoolAttendance & { corrections: SchoolAttendanceCorrection[] };

/** Tizim (QR / cron) tuzatishlari uchun — xodim emas. */
export const SYSTEM_STAFF_ID = 'system';

export const studentName = (s: { lastName: string; firstName: string }) => `${s.lastName} ${s.firstName}`;

export function toCorrectionView(c: SchoolAttendanceCorrection) {
  return { at: c.at.toISOString(), byStaffId: c.byStaffId, from: c.from, to: c.to, reason: c.reason };
}

export function toRecordView(r: RecordWithCorrections) {
  return {
    id: r.id,
    date: r.date,
    studentId: r.studentId,
    classId: r.classId ?? '',
    status: r.status,
    inAt: r.inAt,
    outAt: r.outAt,
    source: r.source,
    corrections: r.corrections.map(toCorrectionView),
    parentNotified: r.parentNotified,
  };
}

export type RecordView = ReturnType<typeof toRecordView>;

export function toEventView(e: SchoolAttendanceEvent) {
  return {
    id: e.id,
    at: e.at.toISOString(),
    studentId: e.studentId,
    classId: e.classId ?? '',
    kind: e.kind,
    source: e.source,
    late: e.late,
  };
}

export function toEarlyExitView(e: SchoolEarlyExit) {
  return {
    id: e.id,
    studentId: e.studentId,
    classId: e.classId ?? '',
    date: e.date,
    time: e.time,
    reason: e.reason,
    pickupBy: e.pickupBy,
    status: e.status,
    requestedAt: e.requestedAt.toISOString(),
    decidedByStaffId: e.decidedByStaffId,
    decidedAt: e.decidedAt?.toISOString() ?? null,
  };
}

export function toNoticeView(n: SchoolParentNotice) {
  return {
    id: n.id,
    at: n.at.toISOString(),
    studentId: n.studentId,
    guardianId: n.guardianId,
    kind: n.kind,
    delivered: n.delivered,
  };
}

/** Holat → ota-onaga xabar turi (EXCUSED — xabar yo'q). */
export function noticeKindFor(status: AttendanceStatus): ParentNoticeKind | null {
  if (status === 'PRESENT' || status === 'LATE') return 'ARRIVED';
  if (status === 'ABSENT') return 'ABSENT';
  if (status === 'LEFT_EARLY') return 'EARLY_EXIT';
  return null;
}

// ─── Kunlik hisoblagichlar (panel `DayCounts`) ─────────────────────

export interface DayCounts {
  present: number;
  late: number;
  absent: number;
  leftEarly: number;
  excused: number;
  pending: number;
  total: number;
}

export const EMPTY_COUNTS: DayCounts = { present: 0, late: 0, absent: 0, leftEarly: 0, excused: 0, pending: 0, total: 0 };

const COUNT_KEY: Record<AttendanceStatus, keyof DayCounts> = {
  PRESENT: 'present',
  LATE: 'late',
  ABSENT: 'absent',
  LEFT_EARLY: 'leftEarly',
  EXCUSED: 'excused',
};

/** Yangi nusxa: `null` — hali belgilanmagan (pending). */
export function addCount(counts: DayCounts, status: AttendanceStatus | null): DayCounts {
  const key = status ? COUNT_KEY[status] : 'pending';
  return { ...counts, [key]: counts[key] + 1, total: counts.total + 1 };
}

export function sumCounts(a: DayCounts, b: DayCounts): DayCounts {
  return {
    present: a.present + b.present,
    late: a.late + b.late,
    absent: a.absent + b.absent,
    leftEarly: a.leftEarly + b.leftEarly,
    excused: a.excused + b.excused,
    pending: a.pending + b.pending,
    total: a.total + b.total,
  };
}

export function percent(part: number, total: number): number {
  return total <= 0 ? 0 : Math.round((part / total) * 100);
}

/** Kelganlar ulushi (kelgan + kechikkan + erta ketgan) / belgilanganlar. */
export function attendedRate(c: DayCounts): number {
  return percent(c.present + c.late + c.leftEarly, c.total - c.pending);
}
