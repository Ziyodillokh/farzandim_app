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

/** Bolaning ochiq (hali hal qilinmagan) parol tiklash so'rovi (K1: `{ id, channel, status: 'RECEIVED', createdAt }`). */
export type RecoveryRequest = { id: Id; channel: RecoveryChannel; createdAt: IsoDateTime };

/**
 * Kod o'rinlari (K2 §2). O'quvchi o'rni uch holatli: `FREE` — bola kiritmagan; `UNDER_REVIEW` — bola kiritdi, xodim (yoki
 * ota-ona) tasdig'i kutilmoqda; `CONFIRMED` — tasdiqlangan. Ota-ona o'rni: `FREE` | `USED`.
 */
export type InviteStudentStatus = 'FREE' | 'UNDER_REVIEW' | 'CONFIRMED';
export type InviteParentStatus = 'FREE' | 'USED';
export type InviteStudentSlot = { status: InviteStudentStatus; usedAt: IsoDateTime | null };
export type InviteParentSlot = { status: InviteParentStatus; usedAt: IsoDateTime | null };

/**
 * Faol 6 xonali maktab kodi va ikki o'rin (o'quvchi / ota-ona). Backend yana `id` va `createdAt` qaytaradi — panelga kerak emas.
 * Yangi yaratilgan kodda ikkala o'rin `FREE`.
 */
export type InviteCode = {
  code: string;
  expiresAt: IsoDateTime;
  student: InviteStudentSlot;
  parent: InviteParentSlot;
};

/** REVIEW — bola kodni kiritdi, xodim tasdig'ini kutmoqda; CORRECTION — bola maktab/sinf noto'g'riligini bildirdi. */
export type LinkRequestKind = 'REVIEW' | 'CORRECTION';
export type LinkCorrectionReason = 'WRONG_SCHOOL_OR_CLASS';

/**
 * Ulanish so'rovi (K2 §5). `id` SHAFFOF: REVIEW uchun `<kod yozuvi>:<bola>` — o'zgartirilmasdan `confirm` / `reject` ga beriladi
 * (yo'lda URL-kodlanadi). `student.classId` / `className`: sinfsiz o'quvchida `null` / `''`.
 */
export type LinkRequest = {
  id: string;
  kind: LinkRequestKind;
  createdAt: IsoDateTime;
  student: { id: Id; fullName: string; classId: Id | null; className: string };
  /** Ota-ona bolaga bergan ism — xodim qaror qilishi uchun. */
  child: { name: string };
  /** Bolaning O'Z ota-onasi o'quvchining ulangan vasiysi (ishonch belgisi). */
  parentLinked: boolean;
  /** CORRECTION: tuzatish sababi; REVIEW: `null`. */
  reason: LinkCorrectionReason | null;
  /** CORRECTION: bolaning izohi (≤ 300 belgi); aks holda `null`. */
  note: string | null;
};

/** Qaror natijasi (K2 §5): `confirm` → `CONFIRMED`, `reject` → `REJECTED`. CORRECTION uchun: tasdiq = ulanish SAQLANADI, rad = UZILADI. */
export type LinkDecisionStatus = 'CONFIRMED' | 'REJECTED';
export type LinkDecisionResult = { id: string; kind: LinkRequestKind; status: LinkDecisionStatus };
