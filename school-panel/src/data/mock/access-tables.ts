import type { ChildCredentials, Id, IsoDateTime, LinkCorrectionReason, LinkRequestKind, RecoveryChannel } from '@/data/contracts';

/** Mock bazadagi yozuvlar (parol HECH QACHON saqlanmaydi — faqat holat). */

export type MockCredential = ChildCredentials & { studentId: Id };

export type MockInviteCode = {
  id: Id;
  studentId: Id;
  code: string;
  createdAt: IsoDateTime;
  expiresAt: IsoDateTime;
  studentUsedAt: IsoDateTime | null;
  parentUsedAt: IsoDateTime | null;
  /** Yangi kod yaratilganda yoki ikkala o'rin ishlatilganda to'ldiriladi. */
  closedAt: IsoDateTime | null;
  createdByStaffId: Id;
};

export type RecoveryState = 'RECEIVED' | 'RESTORED' | 'REJECTED';

export type MockRecoveryRequest = {
  id: Id;
  studentId: Id;
  channel: RecoveryChannel;
  status: RecoveryState;
  createdAt: IsoDateTime;
  resolvedAt: IsoDateTime | null;
};

export type LinkRequestState = 'OPEN' | 'CONFIRMED' | 'REJECTED';

export type MockLinkRequest = {
  id: Id;
  kind: LinkRequestKind;
  studentId: Id;
  createdAt: IsoDateTime;
  parentUsed: boolean;
  note: string | null;
  reason: LinkCorrectionReason | null;
  status: LinkRequestState;
  resolvedAt: IsoDateTime | null;
};

/** Kirish (5-bosqich) jadvallari. */
export type AccessTables = {
  /** Parvoz bola profiliga ulangan o'quvchilar (backend'da `SchoolStudent.childId` o'rnatilgan). */
  linkedStudentIds: Id[];
  credentials: MockCredential[];
  inviteCodes: MockInviteCode[];
  recoveryRequests: MockRecoveryRequest[];
  linkRequests: MockLinkRequest[];
};
