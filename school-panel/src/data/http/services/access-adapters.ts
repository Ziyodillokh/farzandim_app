import type {
  ChildCredentials,
  CredentialIssuer,
  InviteCode,
  InviteParentSlot,
  InviteParentStatus,
  InviteStudentSlot,
  InviteStudentStatus,
  IssuedCredentials,
  IssueCredentialsInput,
  LinkCorrectionReason,
  LinkDecisionResult,
  LinkDecisionStatus,
  LinkRequest,
  LinkRequestKind,
  RecoveryChannel,
  RecoveryRequest,
} from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { isRecord, malformed, nullableString, requiredString, type Wire } from './care-adapters';

/**
 * Kirish (5-bosqich, backend kontraktlari K1 `KIRISH-AUTH-API.md` va K2 `KIRISH-SCHOOL-API.md`): javoblarni panel turlariga
 * keltiruvchi ADAPTERLAR. Har biri hujjatdagi AYNAN shu JSON bilan unit-test qilingan (`__tests__/access.test.ts`).
 *
 * Qoida: ko'rsatiladigan FAKT (login, kod, o'rin holati, id, o'quvchi, qaror) yo'q yoki turi noto'g'ri bo'lsa — jim standart
 * qiymat EMAS, aniq xato (`kutilmagan javob shakli`); faqat ma'lumot beruvchi qo'shimcha (`reason` ning yangi qiymati) yumshoq.
 * Xato xabarlariga qiymatlar yozilmaydi (parol xato matniga tushib qolmasin).
 *
 * Eslatma: ba'zi javoblar `null` tana bilan keladi (K1 `GET credentials`, K2 `GET invite-code`: backend Fastify — `null` JSON
 * matni). Bo'sh tana (`undefined`) ham shu ma'noda («yo'q») qabul qilinadi.
 */

const ISSUERS: readonly CredentialIssuer[] = ['PARENT', 'SCHOOL'];
const CHANNELS: readonly RecoveryChannel[] = ['PARENT', 'SCHOOL'];
const RECOVERY_STATUSES = ['RECEIVED', 'RESTORED', 'REJECTED'] as const;
const STUDENT_SLOT_STATUSES: readonly InviteStudentStatus[] = ['FREE', 'UNDER_REVIEW', 'CONFIRMED'];
const PARENT_SLOT_STATUSES: readonly InviteParentStatus[] = ['FREE', 'USED'];
const LINK_KINDS: readonly LinkRequestKind[] = ['REVIEW', 'CORRECTION', 'GUARDIAN'];
const DECISION_STATUSES: readonly LinkDecisionStatus[] = ['CONFIRMED', 'REJECTED'];
const CORRECTION_REASONS: readonly LinkCorrectionReason[] = ['WRONG_SCHOOL_OR_CLASS'];
const SIX_DIGITS = /^\d{6}$/;

function oneOf<T extends string>(value: unknown, allowed: readonly T[], what: string): T {
  const found = allowed.find((a) => a === value);
  if (found === undefined) throw malformed(what);
  return found;
}

function requiredBool(value: unknown, what: string): boolean {
  if (typeof value === 'boolean') return value;
  throw malformed(what);
}

function requiredRecord(value: unknown, what: string): Wire {
  if (isRecord(value)) return value;
  throw malformed(what);
}

/** Backend `409 NOT_LINKED`: o'quvchi hali bola profiliga ulanmagan (xato emas — «avval ota-ona ulashi kerak»). Kod aniq — status qat'iy emas. */
export function isNotLinked(error: unknown): boolean {
  return error instanceof ServiceError && error.detail === 'NOT_LINKED';
}

/**
 * `POST /school/students/:id/invite-code` ning YAGONA `409`i — arxivdagi o'quvchi (K2 §2). Backend uni aniq kodsiz,
 * umumiy `{ code: 'CONFLICT', message: 'archived' }` bilan qaytaradi; panel `STUDENT_ARCHIVED` (K1 bilan bir xil) deb ko'rsatadi.
 * Boshqa xatolar o'zgarishsiz o'tadi.
 */
export function asStudentArchived(error: unknown): unknown {
  if (error instanceof ServiceError && error.code === 'CONFLICT' && (error.detail === null || error.detail === 'CONFLICT')) {
    return new ServiceError('CONFLICT', error.message, 'STUDENT_ARCHIVED');
  }
  return error;
}

// ── Kirish ma'lumotlari (K1 §2) ──────────────────────────────────────────

/** `GET /school/students/:id/credentials` → `{ login, issuedBy, issuedAt, mustChangePassword, lastLoginAt }` yoki `null`. */
export function toChildCredentials(raw: unknown): ChildCredentials | null {
  if (raw === null || raw === undefined) return null;
  const body = requiredRecord(raw, 'credentials');
  return {
    login: requiredString(body.login, 'credentials.login'),
    issuedBy: oneOf(body.issuedBy, ISSUERS, 'credentials.issuedBy'),
    issuedAt: requiredString(body.issuedAt, 'credentials.issuedAt'),
    mustChangePassword: requiredBool(body.mustChangePassword, 'credentials.mustChangePassword'),
    lastLoginAt: nullableString(body.lastLoginAt, 'credentials.lastLoginAt'),
  };
}

/** `POST /school/students/:id/credentials` → `201 { login, temporaryPassword, issuedAt }` (parol FAQAT shu javobda). */
export function toIssuedCredentials(raw: unknown): IssuedCredentials {
  const body = requiredRecord(raw, 'issued');
  return {
    login: requiredString(body.login, 'issued.login'),
    temporaryPassword: requiredString(body.temporaryPassword, 'issued.temporaryPassword'),
    issuedAt: requiredString(body.issuedAt, 'issued.issuedAt'),
  };
}

/** POST tanasi: `{ login?, signOutDevices? }` — faqat berilganlari (bo'sh login tushirib qoldiriladi: tizim o'zi taklif qiladi). */
export function toIssueBody(input: IssueCredentialsInput): Wire {
  const body: Wire = {};
  const login = input.login?.trim().toLowerCase();
  if (login) body.login = login;
  if (typeof input.signOutDevices === 'boolean') body.signOutDevices = input.signOutDevices;
  return body;
}

// ── Parol tiklash so'rovlari (K1 §5) ─────────────────────────────────────

/**
 * `GET /school/students/:id` ichidagi `recoveryRequests: [{ id, channel: 'SCHOOL', status: 'RECEIVED', createdAt }]`
 * (maktab kanaliga tushgan OCHIQ so'rovlar; `students.manage` bo'lmagan rol uchun `[]`). Faqat `RECEIVED`, eng yangisi birinchi.
 */
export function toRecoveryRequests(raw: unknown): RecoveryRequest[] {
  if (!Array.isArray(raw)) throw malformed('recoveryRequests');
  return raw
    .map((item) => {
      const row = requiredRecord(item, 'recoveryRequests');
      return {
        id: requiredString(row.id, 'recoveryRequests.id'),
        channel: oneOf(row.channel, CHANNELS, 'recoveryRequests.channel'),
        status: oneOf(row.status, RECOVERY_STATUSES, 'recoveryRequests.status'),
        createdAt: requiredString(row.createdAt, 'recoveryRequests.createdAt'),
      };
    })
    .filter((row) => row.status === 'RECEIVED')
    .map(({ id, channel, createdAt }) => ({ id, channel, createdAt }))
    .sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt));
}

/** O'quvchi kartasi (`GET /school/students/:id`) javobidan `recoveryRequests`. */
export function toStudentRecoveryRequests(detail: unknown): RecoveryRequest[] {
  return toRecoveryRequests(requiredRecord(detail, 'student').recoveryRequests);
}

// ── 6 xonali maktab kodi (K2 §2) ─────────────────────────────────────────

function sixDigitCode(value: unknown): string {
  const code = requiredString(value, 'inviteCode.code');
  if (!SIX_DIGITS.test(code)) throw malformed('inviteCode.code');
  return code;
}

function studentSlot(raw: unknown): InviteStudentSlot {
  const slot = requiredRecord(raw, 'inviteCode.student');
  return {
    status: oneOf(slot.status, STUDENT_SLOT_STATUSES, 'inviteCode.student.status'),
    usedAt: nullableString(slot.usedAt, 'inviteCode.student.usedAt'),
  };
}

function parentSlot(raw: unknown): InviteParentSlot {
  const slot = requiredRecord(raw, 'inviteCode.parent');
  return {
    status: oneOf(slot.status, PARENT_SLOT_STATUSES, 'inviteCode.parent.status'),
    usedAt: nullableString(slot.usedAt, 'inviteCode.parent.usedAt'),
  };
}

/**
 * `GET /school/students/:id/invite-code` → faol kod yoki `null` (faol kod yo'q: hech qachon yaratilmagan, muddati o'tgan,
 * yopilgan yoki ikkala o'rin band). Backend yana `id` va `createdAt` beradi — panelga kerak emas.
 */
export function toInviteCode(raw: unknown): InviteCode | null {
  if (raw === null || raw === undefined) return null;
  const body = requiredRecord(raw, 'inviteCode');
  return {
    code: sixDigitCode(body.code),
    expiresAt: requiredString(body.expiresAt, 'inviteCode.expiresAt'),
    student: studentSlot(body.student),
    parent: parentSlot(body.parent),
  };
}

/** `POST /school/students/:id/invite-code` → `201 { code, expiresAt }`: yangi kodda ikkala o'rin bo'sh. */
export function toGeneratedInviteCode(raw: unknown): InviteCode {
  const body = requiredRecord(raw, 'inviteCode');
  return {
    code: sixDigitCode(body.code),
    expiresAt: requiredString(body.expiresAt, 'inviteCode.expiresAt'),
    student: { status: 'FREE', usedAt: null },
    parent: { status: 'FREE', usedAt: null },
  };
}

// ── Ulanish so'rovlari (K2 §5) ───────────────────────────────────────────

function toLinkRequest(raw: unknown): LinkRequest {
  const body = requiredRecord(raw, 'linkRequest');
  const student = requiredRecord(body.student, 'linkRequest.student');
  const kind = oneOf(body.kind, LINK_KINDS, 'linkRequest.kind');
  // Bola faqat GUARDIAN'da bo'lmasligi mumkin (ota-onaning kutayotgan farzandi yo'q).
  const child = kind === 'GUARDIAN' && body.child == null ? null : requiredRecord(body.child, 'linkRequest.child');
  const parent = body.parent == null ? null : requiredRecord(body.parent, 'linkRequest.parent');
  const note = nullableString(body.note, 'linkRequest.note')?.trim();
  return {
    // Shaffof id: o'zgartirilmaydi (REVIEW: `<kod yozuvi>:<bola>`).
    id: requiredString(body.id, 'linkRequest.id'),
    kind,
    createdAt: requiredString(body.createdAt, 'linkRequest.createdAt'),
    student: {
      id: requiredString(student.id, 'linkRequest.student.id'),
      fullName: requiredString(student.fullName, 'linkRequest.student.fullName'),
      classId: nullableString(student.classId, 'linkRequest.student.classId'),
      // Sinfsiz o'quvchida backend bo'sh satr beradi.
      className: nullableString(student.className, 'linkRequest.student.className') ?? '',
    },
    child: child ? { name: requiredString(child.name, 'linkRequest.child.name') } : null,
    parent: parent
      ? {
          name: requiredString(parent.name, 'linkRequest.parent.name'),
          maskedPhone: nullableString(parent.maskedPhone, 'linkRequest.parent.maskedPhone'),
        }
      : null,
    parentLinked: requiredBool(body.parentLinked, 'linkRequest.parentLinked'),
    // Sabab — faqat ko'rsatma: kelajakdagi yangi qiymat butun ro'yxatni buzmasin.
    reason: CORRECTION_REASONS.find((r) => r === body.reason) ?? null,
    note: note ? note : null,
  };
}

/**
 * `GET /school/link-requests` → massiv (≤ 200), ENG ESKILARI BIRINCHI — tartib o'zgartirilmaydi (navbat: eng uzoq kutayotgani tepada).
 */
export function toLinkRequests(raw: unknown): LinkRequest[] {
  if (!Array.isArray(raw)) throw malformed('linkRequests');
  return raw.map(toLinkRequest);
}

export type LinkDecisionAction = 'confirm' | 'reject';

const DECISION_OF: Readonly<Record<LinkDecisionAction, LinkDecisionStatus>> = { confirm: 'CONFIRMED', reject: 'REJECTED' };

/**
 * `POST /school/link-requests/:id/(confirm|reject)` → `200 { id, kind, status }`. `status` so'ralgan amalga mos bo'lishi shart
 * (`confirm` → `CONFIRMED`, `reject` → `REJECTED`); aks holda — shakl xatosi (UI noto'g'ri natijani «bajarildi» deb ko'rsatmasin).
 */
export function toLinkDecision(raw: unknown, action: LinkDecisionAction): LinkDecisionResult {
  const body = requiredRecord(raw, 'linkDecision');
  const status = oneOf(body.status, DECISION_STATUSES, 'linkDecision.status');
  if (status !== DECISION_OF[action]) throw malformed('linkDecision.status');
  return { id: requiredString(body.id, 'linkDecision.id'), kind: oneOf(body.kind, LINK_KINDS, 'linkDecision.kind'), status };
}
