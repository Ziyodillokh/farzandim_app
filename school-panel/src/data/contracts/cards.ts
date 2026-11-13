import type { AttendanceStatus } from './attendance';
import type { Id, IsoDateTime } from './common';

/** UID — oddiy NFC karta (seriya raqami, nusxalanishi mumkin); SUN — NTAG 424 DNA (imzolangan kod). */
export type CardKind = 'UID' | 'SUN';
export type CardStatus = 'ACTIVE' | 'LOST' | 'BLOCKED';
export type CardTapResult = 'IN' | 'OUT' | 'NONE' | 'UNKNOWN' | 'BLOCKED' | 'INVALID' | 'OUTSIDE';

export type SchoolCard = {
  id: Id;
  /** Kartaga bosilgan raqam (K-000124). */
  number: string;
  /** Chip seriya raqami — 14 ta katta hex belgi. */
  uid: string;
  kind: CardKind;
  status: CardStatus;
  studentId: Id;
  studentName: string;
  studentCode: string;
  classId: Id | null;
  className: string;
  issuedAt: IsoDateTime;
  lastTapAt: IsoDateTime | null;
  blockedAt: IsoDateTime | null;
  /** `LOST`, `BLOCKED`, `REPLACED` yoki xodim izohi. */
  blockedReason: string | null;
};

/** Biriktirish natijasi: o'quvchining eski faol kartasi bloklangan bo'lsa — uning raqami. */
export type AssignedCard = SchoolCard & { replacedNumber: string | null };

/** Kiosk tegishi natijasi (ekranda rang va ovoz bilan). */
export type CardTapView = {
  result: CardTapResult;
  time: string;
  suspicious: boolean;
  cardNumber: string | null;
  student: { id: Id; firstName: string; lastName: string; studentCode: string } | null;
  className: string;
  status: AttendanceStatus | null;
};

export type CardTapLog = {
  id: Id;
  tappedAt: IsoDateTime;
  result: CardTapResult;
  suspicious: boolean;
  uid: string | null;
  cardNumber: string | null;
  studentId: Id | null;
  studentName: string | null;
  className: string;
};
