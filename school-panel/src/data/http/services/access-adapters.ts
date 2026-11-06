import type {
  ChildCredentials,
  CredentialIssuer,
  InviteCode,
  InviteSlot,
  IssuedCredentials,
  IssueCredentialsInput,
  LinkCorrectionReason,
  LinkRequest,
  LinkRequestKind,
  RecoveryChannel,
  RecoveryRequest,
} from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { isRecord, malformed, nullableString, requiredString, type Wire } from './care-adapters';

/**
 * Kirish (5-bosqich, kontrakt K1/K2): backend javoblarini panel turlariga keltiruvchi ADAPTERLAR. Har biri unit-test bilan
 * qoplangan (`__tests__/access.test.ts`). Qoida: ko'rsatiladigan FAKT (login, kod, o'rin holati, id) yo'q yoki turi noto'g'ri
 * bo'lsa — jim standart qiymat EMAS, aniq xato; faqat ixtiyoriy qo'shimchalar (`channel`, `reason`, `studentId`, `note`) yumshoq.
 * Xato xabarlariga qiymatlar yozilmaydi (parol xato matniga tushib qolmasin).
 *
 * Kontraktda ANIQ berilgan shakllar: `credentials` (K1), `POST credentials` natijasi, `POST invite-code` natijasi `{ code, expiresAt }`.
 * Kontrakt ANIQ bermagan, shuning uchun taxmin qilingan va hujjatlashtirilgan shakllar:
 *  - `GET /school/students/:id/invite-code` — `{ code, expiresAt }` + o'rin holatlari (quyida `inviteSlot`);
 *  - `GET /school/link-requests` — massiv yoki `{ items }` (har element `kind`/`type`), yoki `{ links, corrections }`;
 *  - o'quvchi kartasidagi `recoveryRequests` — `[{ id, createdAt, channel?, status? }]`.
 */

const ISSUERS: readonly CredentialIssuer[] = ['PARENT', 'SCHOOL'];
const CHANNELS: readonly RecoveryChannel[] = ['PARENT', 'SCHOOL'];
const RECOVERY_STATUSES = ['RECEIVED', 'RESTORED', 'REJECTED'] as const;
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

/** Backend `409 NOT_LINKED`: o'quvchi hali bola profiliga ulanmagan (xato emas — «avval ota-ona ulashi kerak»). Kod aniq — status qat'iy emas. */
export function isNotLinked(error: unknown): boolean {
  return error instanceof ServiceError && error.detail === 'NOT_LINKED';
}

// ── Kirish ma'lumotlari (K1) ─────────────────────────────────────────────

/** `GET /school/students/:id/credentials` → `{ login, issuedBy, issuedAt, mustChangePassword, lastLoginAt }` yoki `null`. */
export function toChildCredentials(raw: unknown): ChildCredentials | null {
  if (raw === null || raw === undefined) return null;
  if (!isRecord(raw)) throw malformed('credentials');
  return {
    login: requiredString(raw.login, 'credentials.login'),
    issuedBy: oneOf(raw.issuedBy, ISSUERS, 'credentials.issuedBy'),
    issuedAt: requiredString(raw.issuedAt, 'credentials.issuedAt'),
    mustChangePassword: requiredBool(raw.mustChangePassword, 'credentials.mustChangePassword'),
    lastLoginAt: nullableString(raw.lastLoginAt, 'credentials.lastLoginAt'),
  };
}

/** `POST /school/students/:id/credentials` → `201 { login, temporaryPassword, issuedAt }` (parol FAQAT shu javobda). */
export function toIssuedCredentials(raw: unknown): IssuedCredentials {
  if (!isRecord(raw)) throw malformed('issued');
  return {
    login: requiredString(raw.login, 'issued.login'),
    temporaryPassword: requiredString(raw.temporaryPassword, 'issued.temporaryPassword'),
    issuedAt: requiredString(raw.issuedAt, 'issued.issuedAt'),
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

// ── Parol tiklash so'rovlari (K1) ────────────────────────────────────────

/**
 * O'quvchi kartasidagi `recoveryRequests` (kontrakt: «school student detail» ichida): `[{ id, createdAt, channel?, status? }]`.
 * Faqat OCHIQ (`status` yo'q yoki `RECEIVED`) so'rovlar, eng yangisi birinchi. Maydon yo'q — bo'sh ro'yxat.
 */
export function toRecoveryRequests(raw: unknown): RecoveryRequest[] {
  if (raw === undefined || raw === null) return [];
  if (!Array.isArray(raw)) throw malformed('recoveryRequests');
  return raw
    .map((item) => {
      if (!isRecord(item)) throw malformed('recoveryRequests');
      const status = item.status === undefined || item.status === null ? 'RECEIVED' : oneOf(item.status, RECOVERY_STATUSES, 'recoveryRequests.status');
      const channel = CHANNELS.find((c) => c === item.channel) ?? null;
      return { status, request: { id: requiredString(item.id, 'recoveryRequests.id'), channel, createdAt: requiredString(item.createdAt, 'recoveryRequests.createdAt') } };
    })
    .filter((x) => x.status === 'RECEIVED')
    .map((x) => x.request)
    .sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt));
}

// ── 6 xonali maktab kodi (K2) ────────────────────────────────────────────

function sixDigitCode(value: unknown): string {
  const code = requiredString(value, 'code');
  if (!SIX_DIGITS.test(code)) throw malformed('code');
  return code;
}

/**
 * Kod o'rni (`student` / `parent`). Qabul qilinadigan shakllar (kontrakt «slot states» ni aniq bermagan):
 *  1. model maydonlari: `studentUsedAt` / `parentUsedAt` (ISO yoki null);
 *  2. mantiqiy: `studentUsed` / `parentUsed` (+ ixtiyoriy `…UsedAt`);
 *  3. ichma-ich: `student: { used?, usedAt? }`, `parent: { … }`.
 */
function inviteSlot(raw: Wire, slot: 'student' | 'parent'): InviteSlot {
  const stamp = raw[`${slot}UsedAt`];
  if (stamp !== undefined) {
    const usedAt = nullableString(stamp, `${slot}UsedAt`);
    return { used: usedAt !== null, usedAt };
  }
  const flag = raw[`${slot}Used`];
  if (typeof flag === 'boolean') return { used: flag, usedAt: null };
  const nested = raw[slot];
  if (isRecord(nested)) {
    const usedAt = nullableString(nested.usedAt, `${slot}.usedAt`);
    if (typeof nested.used === 'boolean') return { used: nested.used, usedAt };
    if (nested.usedAt !== undefined) return { used: usedAt !== null, usedAt };
  }
  throw malformed(`${slot} o'rni`);
}

/** `GET /school/students/:id/invite-code` → faol kod yoki `null` (bo'sh javob ham «faol kod yo'q»). */
export function toInviteCode(raw: unknown): InviteCode | null {
  if (raw === null || raw === undefined) return null;
  if (!isRecord(raw)) throw malformed('inviteCode');
  return {
    code: sixDigitCode(raw.code),
    expiresAt: requiredString(raw.expiresAt, 'inviteCode.expiresAt'),
    student: inviteSlot(raw, 'student'),
    parent: inviteSlot(raw, 'parent'),
  };
}

/** `POST /school/students/:id/invite-code` → `{ code, expiresAt }`: yangi kodda ikkala o'rin bo'sh. */
export function toGeneratedInviteCode(raw: unknown): InviteCode {
  if (!isRecord(raw)) throw malformed('inviteCode');
  return {
    code: sixDigitCode(raw.code),
    expiresAt: requiredString(raw.expiresAt, 'inviteCode.expiresAt'),
    student: { used: false, usedAt: null },
    parent: { used: false, usedAt: null },
  };
}

// ── Ulanish so'rovlari (K2) ──────────────────────────────────────────────

const KIND_ALIASES: Readonly<Record<string, LinkRequestKind>> = {
  REVIEW: 'REVIEW',
  LINK: 'REVIEW',
  LINK_REVIEW: 'REVIEW',
  UNDER_REVIEW: 'REVIEW',
  CORRECTION: 'CORRECTION',
  LINK_CORRECTION: 'CORRECTION',
};

function kindOf(raw: Wire, implied: LinkRequestKind | null): LinkRequestKind {
  const declared = raw.kind ?? raw.type;
  if (declared === undefined || declared === null) {
    if (implied) return implied;
    throw malformed('linkRequest.kind');
  }
  const kind = typeof declared === 'string' && Object.hasOwn(KIND_ALIASES, declared) ? KIND_ALIASES[declared] : undefined;
  if (!kind) throw malformed('linkRequest.kind');
  return kind;
}

/** Ota-ona o'rni ishlatilganmi: `parentUsed` (mantiqiy) yoki `parentUsedAt` (model maydoni). Tuzatishda ahamiyatsiz. */
function parentUsed(raw: Wire, kind: LinkRequestKind): boolean {
  if (typeof raw.parentUsed === 'boolean') return raw.parentUsed;
  if (raw.parentUsedAt !== undefined) return nullableString(raw.parentUsedAt, 'linkRequest.parentUsedAt') !== null;
  if (kind === 'CORRECTION') return false;
  throw malformed('linkRequest.parentUsed');
}

function toLinkRequest(raw: unknown, implied: LinkRequestKind | null): LinkRequest {
  if (!isRecord(raw)) throw malformed('linkRequest');
  const kind = kindOf(raw, implied);
  return {
    id: requiredString(raw.id, 'linkRequest.id'),
    kind,
    studentId: typeof raw.studentId === 'string' && raw.studentId !== '' ? raw.studentId : null,
    studentName: requiredString(raw.studentName, 'linkRequest.studentName'),
    className: typeof raw.className === 'string' && raw.className !== '' ? raw.className : '—',
    createdAt: requiredString(raw.createdAt, 'linkRequest.createdAt'),
    parentUsed: parentUsed(raw, kind),
    note: kind === 'CORRECTION' && typeof raw.note === 'string' && raw.note.trim() !== '' ? raw.note.trim() : null,
    reason: CORRECTION_REASONS.find((r) => r === raw.reason) ?? null,
  };
}

function listOf(value: unknown, what: string): unknown[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) throw malformed(what);
  return value;
}

/**
 * `GET /school/link-requests`: massiv, `{ items }` yoki `{ links, corrections }` — natija bir xil: eng yangisi birinchi.
 * Nom/sinf/vaqt/o'rin maydonlari — `studentName`, `className`, `createdAt`, `parentUsed|parentUsedAt`; tuzatishda `note`.
 */
export function toLinkRequests(raw: unknown): LinkRequest[] {
  let items: Array<{ item: unknown; implied: LinkRequestKind | null }>;
  if (Array.isArray(raw)) {
    items = raw.map((item) => ({ item, implied: null }));
  } else if (isRecord(raw) && Array.isArray(raw.items)) {
    items = raw.items.map((item) => ({ item, implied: null }));
  } else if (isRecord(raw) && (raw.links !== undefined || raw.corrections !== undefined)) {
    items = [
      ...listOf(raw.links, 'links').map((item) => ({ item, implied: 'REVIEW' as const })),
      ...listOf(raw.corrections, 'corrections').map((item) => ({ item, implied: 'CORRECTION' as const })),
    ];
  } else if (raw === undefined || raw === null) {
    items = [];
  } else {
    throw malformed('linkRequests');
  }
  return items
    .map(({ item, implied }) => toLinkRequest(item, implied))
    .sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt) || a.id.localeCompare(b.id));
}
