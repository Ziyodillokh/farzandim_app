import type { Id, IsoDateTime } from './common';

export type AppCategory = 'GAME' | 'SOCIAL' | 'VIDEO' | 'EDU' | 'OTHER';
export type DeviceModeStatus = 'APPLIED' | 'NO_PERMISSION' | 'NO_PHONE' | 'OFFLINE';

export type AllowedApp = { id: Id; name: string; category: AppCategory };

export type SchoolModePolicy = {
  id: Id;
  name: string;
  blockedCategories: AppCategory[];
  allowedApps: AllowedApp[];
  /** Qo'ng'iroq, SMS va favqulodda aloqa har doim ochiq — o'zgartirib bo'lmaydi. */
  alwaysAllowCalls: true;
  shiftIds: Id[];
  enabled: boolean;
  /** Tanaffusda cheklovni vaqtincha ochish. */
  relaxDuringBreaks: boolean;
};

export type SchoolModeException = {
  id: Id;
  studentId: Id;
  classId: Id;
  from: IsoDateTime;
  until: IsoDateTime;
  reason: string;
  byStaffId: Id;
  revokedAt: IsoDateTime | null;
};

export type DeviceState = {
  studentId: Id;
  status: DeviceModeStatus;
  lastSeenAt: IsoDateTime | null;
};

export type EmergencyState = {
  active: boolean;
  scope: 'SCHOOL' | 'CLASS';
  classIds: Id[];
  reason: string;
  byStaffId: Id | null;
  at: IsoDateTime | null;
};
