import type { Id, IsoDateTime } from './common';

/**
 * Kirish (5-bosqich): bola profili bilan bog'langan o'quvchiga kirish ma'lumotlari, 6 xonali maktab kodi
 * va ulanish so'rovlari. Bola profiliga ulanmagan o'quvchiga kirish ma'lumotlari BERILMAYDI (ota-ona roziligisiz hisob yo'q).
 */

/** Kirish ma'lumotlarini kim bergan. */
export type CredentialIssuer = 'PARENT' | 'SCHOOL';

/** Mavjud kirish ma'lumotlari (parol hech qachon qaytmaydi). */
export type ChildCredentials = {
  login: string;
  issuedBy: CredentialIssuer;
  issuedAt: IsoDateTime;
  /** Vaqtinchalik parol hali almashtirilmagan. */
  mustChangePassword: boolean;
  lastLoginAt: IsoDateTime | null;
};

/**
 * `linked: false` — o'quvchi hali Parvoz bola profiliga ulanmagan (ota-ona avval ulashi kerak): kirish ma'lumotlari berilmaydi.
 * `credentials: null` — ulangan, lekin hali berilmagan.
 */
export type CredentialsView = { linked: boolean; credentials: ChildCredentials | null };

/** Berish/tiklash natijasi. `temporaryPassword` FAQAT bir marta ko'rsatiladi va hech qayerda saqlanmaydi. */
export type IssuedCredentials = { login: string; temporaryPassword: string; issuedAt: IsoDateTime };

/** `login` — birinchi berishda ixtiyoriy (bo'sh bo'lsa tizim taklif qiladi); `signOutDevices` — standart `true`. */
export type IssueCredentialsInput = { login?: string; signOutDevices?: boolean };

export type RecoveryChannel = 'PARENT' | 'SCHOOL';

/** Bolaning ochiq (hali hal qilinmagan) parol tiklash so'rovi. */
export type RecoveryRequest = { id: Id; channel: RecoveryChannel | null; createdAt: IsoDateTime };

/** Kod o'rni: ishlatilganmi va (ma'lum bo'lsa) qachon. */
export type InviteSlot = { used: boolean; usedAt: IsoDateTime | null };

/** Faol 6 xonali maktab kodi va ikki o'rin (o'quvchi / ota-ona). */
export type InviteCode = {
  code: string;
  expiresAt: IsoDateTime;
  student: InviteSlot;
  parent: InviteSlot;
};

/** REVIEW — bola kodni kiritdi, xodim tasdig'ini kutmoqda; CORRECTION — bola maktab/sinf noto'g'riligini bildirdi. */
export type LinkRequestKind = 'REVIEW' | 'CORRECTION';
export type LinkCorrectionReason = 'WRONG_SCHOOL_OR_CLASS';

export type LinkRequest = {
  id: Id;
  kind: LinkRequestKind;
  /** Bo'lsa — o'quvchi kartasiga havola. */
  studentId: Id | null;
  studentName: string;
  className: string;
  createdAt: IsoDateTime;
  /** REVIEW: ota-ona o'rni (kod) ishlatilganmi. */
  parentUsed: boolean;
  /** CORRECTION: bolaning izohi (≤ 300 belgi). */
  note: string | null;
  reason: LinkCorrectionReason | null;
};
