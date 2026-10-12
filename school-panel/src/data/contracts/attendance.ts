import type { HhMm, Id, IsoDate, IsoDateTime } from './common';

export type AttendanceStatus = 'PRESENT' | 'LATE' | 'ABSENT' | 'LEFT_EARLY' | 'EXCUSED';
export type AttendanceSource = 'QR' | 'KIOSK' | 'MANUAL' | 'SYSTEM';

export type AttendanceCorrection = {
  at: IsoDateTime;
  byStaffId: Id;
  from: AttendanceStatus;
  to: AttendanceStatus;
  reason: string;
};

export type AttendanceRecord = {
  id: Id; // `${date}:${studentId}`
  date: IsoDate;
  studentId: Id;
  classId: Id;
  status: AttendanceStatus;
  inAt: HhMm | null;
  outAt: HhMm | null;
  source: AttendanceSource;
  corrections: AttendanceCorrection[];
  parentNotified: boolean;
};

export type AttendanceEventKind = 'IN' | 'OUT';
export type AttendanceEvent = {
  id: Id;
  at: IsoDateTime;
  studentId: Id;
  classId: Id;
  kind: AttendanceEventKind;
  source: AttendanceSource;
  late: boolean;
};

export type EarlyExitStatus = 'PENDING' | 'APPROVED' | 'REJECTED';
export type EarlyExitRequest = {
  id: Id;
  studentId: Id;
  classId: Id;
  date: IsoDate;
  time: HhMm;
  reason: string;
  pickupBy: string; // "Onasi — Karimova Malika"
  status: EarlyExitStatus;
  requestedAt: IsoDateTime;
  decidedByStaffId: Id | null;
  decidedAt: IsoDateTime | null;
};

/** Kiosk — 30 soniyada yangilanadigan bir martalik kod. */
export type EntryToken = { code: string; issuedAt: IsoDateTime; expiresAt: IsoDateTime };

export type ParentNotification = {
  id: Id;
  at: IsoDateTime;
  studentId: Id;
  guardianId: Id;
  kind: 'ARRIVED' | 'LEFT' | 'ABSENT' | 'EARLY_EXIT';
  delivered: boolean;
};
