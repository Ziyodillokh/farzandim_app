import type { ChildCredentials, Id, IsoDateTime, LinkCorrectionReason, LinkRequestKind, RecoveryChannel } from '@/data/contracts';

/** Mock bazadagi yozuvlar (parol HECH QACHON saqlanmaydi — faqat holat). */

export type MockCredential = ChildCredentials & { studentId: Id };

export type MockInviteCode = {
  id: Id;
  studentId: Id;
  code: string;
  createdAt: IsoDateTime;
  expiresAt: IsoDateTime;
  /** Bola kodni kiritgan payt (o'quvchi o'rni band). */
  studentUsedAt: IsoDateTime | null;
  /** Kiritilgan o'rin tasdiqlangan payt: `studentUsedAt` bor, bu yo'q — `UNDER_REVIEW` (K2 §1). */
  studentConfirmedAt: IsoDateTime | null;
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
  /** Shaffof id (backenddagidek): REVIEW — `<kod yozuvi>:<bola>`, CORRECTION — so'rov id'si. */
  id: string;
  kind: LinkRequestKind;
  studentId: Id;
  /** Ota-ona bolaga bergan ism. */
  childName: string;
  createdAt: IsoDateTime;
  /** Bolaning o'z ota-onasi o'quvchining ulangan vasiysi. */
  parentLinked: boolean;
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
