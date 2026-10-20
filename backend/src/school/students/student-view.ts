// O'quvchi va ota-ona — panel kontraktlariga (`Student`, `StudentRow`,
// `Guardian`) o'girish. Psixolog kabi ota-onaga ulash huquqi yo'q rollar
// uchun shaxsiy ma'lumotlar servisdan umuman chiqmaydi (`redact`).

import {
  AttendanceStatus,
  GuardianLinkStatus,
  Prisma,
  SchoolAttendance,
  SchoolAttendanceCorrection,
  SchoolGuardian,
  SchoolModeException,
  SchoolStudent,
} from '@prisma/client';
import { deviceChildSelect, DeviceModeStatus, deviceStateOf } from '../common/device-state';

export const studentInclude = {
  class: { select: { id: true, name: true, grade: true, letter: true, shiftId: true, homeroomStaffId: true } },
  guardians: {
    select: { guardian: { select: { id: true, fullName: true, linkStatus: true } } },
    orderBy: { guardian: { createdAt: 'asc' } },
  },
  child: { select: deviceChildSelect },
} satisfies Prisma.SchoolStudentInclude;

export type StudentWithLinks = Prisma.SchoolStudentGetPayload<{ include: typeof studentInclude }>;

type Names = Pick<SchoolStudent, 'lastName' | 'firstName' | 'middleName'>;

export const studentName = (s: Pick<Names, 'lastName' | 'firstName'>) => `${s.lastName} ${s.firstName}`;
export const studentFullName = (s: Names) => [s.lastName, s.firstName, s.middleName].filter(Boolean).join(' ');

/** O'quvchining eng yaxshi ota-ona ulanish holati. */
export function bestLink(guardians: Array<{ linkStatus: GuardianLinkStatus }>): GuardianLinkStatus {
  if (guardians.some((g) => g.linkStatus === 'LINKED')) return 'LINKED';
  if (guardians.some((g) => g.linkStatus === 'INVITED')) return 'INVITED';
  return 'NOT_INVITED';
}

export function toStudentView(s: SchoolStudent & { guardians: Array<{ guardian: { id: string } }> }) {
  return {
    id: s.id,
    lastName: s.lastName,
    firstName: s.firstName,
    middleName: s.middleName,
    gender: s.gender,
    birthDate: s.birthDate,
    classId: s.classId ?? '',
    device: s.device,
    guardianIds: s.guardians.map((g) => g.guardian.id),
    studentCode: s.studentCode,
    enrolledAt: s.enrolledAt,
    archived: s.archived,
  };
}

export type StudentRow = ReturnType<typeof toStudentView> & {
  fullName: string;
  className: string;
  grade: number;
  linkStatus: GuardianLinkStatus;
  guardianNames: string[];
  deviceStatus: DeviceModeStatus;
  todayStatus: AttendanceStatus | null;
};

export function toStudentRow(s: StudentWithLinks, todayStatus: AttendanceStatus | null, now: Date): StudentRow {
  const guardians = s.guardians.map((g) => g.guardian);
  return {
    ...toStudentView(s),
    fullName: studentFullName(s),
    className: s.class?.name ?? '—',
    grade: s.class?.grade ?? 0,
    linkStatus: bestLink(guardians),
    guardianNames: guardians.map((g) => g.fullName),
    deviceStatus: deviceStateOf(s, s.child, now).status,
    todayStatus,
  };
}

/** Ota-onaga ulash huquqi yo'q rol uchun: faqat ism va sinf. */
export function redact(row: StudentRow): StudentRow {
  return {
    ...row,
    birthDate: '',
    guardianIds: [],
    guardianNames: [],
    linkStatus: 'NOT_INVITED',
    device: 'NONE',
    deviceStatus: 'NO_PHONE',
    todayStatus: null,
  };
}

const iso = (d: Date | null) => d?.toISOString() ?? null;

export function toGuardianView(g: SchoolGuardian) {
  return {
    id: g.id,
    fullName: g.fullName,
    phone: g.phone,
    relation: g.relation,
    linkStatus: g.linkStatus,
    inviteCode: g.inviteCode,
    inviteExpiresAt: iso(g.inviteExpiresAt),
    linkedAt: iso(g.linkedAt),
  };
}

export function toAttendanceRecordView(r: SchoolAttendance & { corrections: SchoolAttendanceCorrection[] }) {
  return {
    id: r.id,
    date: r.date,
    studentId: r.studentId,
    classId: r.classId ?? '',
    status: r.status,
    inAt: r.inAt,
    outAt: r.outAt,
    source: r.source,
    corrections: r.corrections.map((c) => ({
      at: c.at.toISOString(),
      byStaffId: c.byStaffId,
      from: c.from,
      to: c.to,
      reason: c.reason,
    })),
    parentNotified: r.parentNotified,
  };
}

export function toExceptionView(e: SchoolModeException) {
  return {
    id: e.id,
    studentId: e.studentId,
    classId: e.classId ?? '',
    from: e.from.toISOString(),
    until: e.until.toISOString(),
    reason: e.reason,
    byStaffId: e.byStaffId,
    revokedAt: iso(e.revokedAt),
  };
}
