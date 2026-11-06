import { type Permission, ROLES, roleHas } from '@/auth/permissions';
import type { InviteCode, RecoveryRequest, RoleKey, Staff, Student } from '@/data/contracts';
import { LOGIN_PATTERN } from '@/data/schemas/access';
import { hashString } from '@/lib/rng';
import type { AccessTables, MockInviteCode } from './access-tables';

/**
 * Kirish (5-bosqich) sof yordamchilari: login taklifi, vaqtinchalik parol, 6 xonali kod. Backend (K1/K2) bilan bir xil qoidalar:
 * parol — 8 belgi, o'xshash belgilarsiz alifbo (kripto-tasodifiy); kod — 6 raqam, bosh nollar mumkin.
 */

export const TEMP_PASSWORD_ALPHABET = 'abcdefghjkmnpqrstuvwxyz23456789';
export const TEMP_PASSWORD_LENGTH = 8;
export const INVITE_CODE_LENGTH = 6;
/** Kod amal qilish muddati (soat). */
export const INVITE_TTL_HOURS = 24;

const UINT32_RANGE = 2 ** 32;

/** Bir tekis taqsimlangan tasodifiy butun son [0, max) — kripto manbadan (rad etish usuli). */
function secureInt(max: number): number {
  const limit = UINT32_RANGE - (UINT32_RANGE % max);
  const buffer = new Uint32Array(1);
  for (;;) {
    crypto.getRandomValues(buffer);
    const value = buffer[0] ?? 0;
    if (value < limit) return value % max;
  }
}

/** 8 belgili vaqtinchalik parol (`abcdefghjkmnpqrstuvwxyz23456789`). Hech qayerda saqlanmaydi va log qilinmaydi. */
export function generateTemporaryPassword(): string {
  return Array.from({ length: TEMP_PASSWORD_LENGTH }, () => TEMP_PASSWORD_ALPHABET[secureInt(TEMP_PASSWORD_ALPHABET.length)]).join('');
}

/** 6 xonali raqamli kod (bosh nollar bilan). */
export function generateInviteCodeDigits(): string {
  return String(secureInt(10 ** INVITE_CODE_LENGTH)).padStart(INVITE_CODE_LENGTH, '0');
}

const CYRILLIC: Readonly<Record<string, string>> = {
  а: 'a', б: 'b', в: 'v', г: 'g', д: 'd', е: 'e', ё: 'yo', ж: 'j', з: 'z', и: 'i', й: 'y', к: 'k', л: 'l', м: 'm', н: 'n', о: 'o',
  п: 'p', р: 'r', с: 's', т: 't', у: 'u', ф: 'f', х: 'x', ц: 'ts', ч: 'ch', ш: 'sh', щ: 'sh', ъ: '', ы: 'i', ь: '', э: 'e', ю: 'yu',
  я: 'ya', қ: 'q', ғ: 'g', ў: 'o', ҳ: 'h',
};

/** "G'ayrat" → "gayrat", "Ўктам" → "oktam": faqat kichik lotin harflari va raqamlar. */
export function toAsciiSlug(value: string): string {
  // Kirill AVVAL (NFKD `ў` ni `у` + belgiga ajratib yuboradi), keyin lotin diakritikasi olib tashlanadi.
  let out = '';
  for (const ch of value.toLowerCase()) out += CYRILLIC[ch] ?? ch;
  return out.normalize('NFKD').replace(/[^a-z0-9]/g, '');
}

const SUGGEST_ATTEMPTS = 100;
const FIRST_NAME_MAX = 16;

/**
 * Login taklifi (kontrakt K1): ism (ASCII) + "." + familiya bosh harfi + 2 raqam (`aziza.k24`), band bo'lsa — boshqa raqamlar;
 * ism ishlatib bo'lmasa yoki raqamlar tugasa — `parvoz` + 4 raqam. `salt` raqamlarni barqaror qiladi (testlar uchun).
 */
export function suggestLogin(student: Pick<Student, 'firstName' | 'lastName'>, taken: ReadonlySet<string>, salt: string): string {
  const first = toAsciiSlug(student.firstName).slice(0, FIRST_NAME_MAX);
  const initial = toAsciiSlug(student.lastName).slice(0, 1);
  if (first && initial) {
    for (let attempt = 0; attempt < SUGGEST_ATTEMPTS; attempt++) {
      const digits = String(hashString(`${salt}|${attempt}`) % 100).padStart(2, '0');
      const login = `${first}.${initial}${digits}`;
      if (LOGIN_PATTERN.test(login) && !taken.has(login)) return login;
    }
  }
  for (let attempt = 0; ; attempt++) {
    const login = `parvoz${String(hashString(`${salt}|fallback|${attempt}`) % 10_000).padStart(4, '0')}`;
    if (!taken.has(login)) return login;
  }
}

/** Faol kod: yopilmagan va muddati o'tmagan. */
export function isActiveInvite(invite: MockInviteCode, nowMs: number): boolean {
  return invite.closedAt === null && Date.parse(invite.expiresAt) > nowMs;
}

/** O'quvchining eng yangi faol kodi (bo'lsa). */
export function activeInviteOf(invites: readonly MockInviteCode[], studentId: string, nowMs: number): MockInviteCode | null {
  const active = invites.filter((i) => i.studentId === studentId && isActiveInvite(i, nowMs));
  active.sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt));
  return active[0] ?? null;
}

/** K2 §2: o'quvchi o'rni `FREE` | `UNDER_REVIEW` (bola kiritdi, tasdiq kutilmoqda) | `CONFIRMED`; ota-ona o'rni `FREE` | `USED`. */
export function toInviteCodeView(invite: MockInviteCode): InviteCode {
  const studentStatus = invite.studentUsedAt === null ? 'FREE' : invite.studentConfirmedAt === null ? 'UNDER_REVIEW' : 'CONFIRMED';
  return {
    code: invite.code,
    expiresAt: invite.expiresAt,
    student: { status: studentStatus, usedAt: invite.studentUsedAt },
    parent: { status: invite.parentUsedAt === null ? 'FREE' : 'USED', usedAt: invite.parentUsedAt },
  };
}

/** Faol kodlar orasida takrorlanmaydigan yangi kod. */
export function uniqueInviteCode(invites: readonly MockInviteCode[], nowMs: number): string {
  const used = new Set(invites.filter((i) => isActiveInvite(i, nowMs)).map((i) => i.code));
  for (;;) {
    const code = generateInviteCodeDigits();
    if (!used.has(code)) return code;
  }
}

/** O'quvchining ochiq (hal qilinmagan) parol tiklash so'rovlari, eng yangisi birinchi. */
export function openRecoveryOf(access: AccessTables, studentId: string): RecoveryRequest[] {
  return access.recoveryRequests
    .filter((r) => r.studentId === studentId && r.status === 'RECEIVED')
    .sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt))
    .map((r) => ({ id: r.id, channel: r.channel, createdAt: r.createdAt }));
}

export type AccessNotificationKind = 'CHILD_RECOVERY_REQUEST' | 'LINK_REVIEW' | 'LINK_CORRECTION';

/** Bildirishnoma id'si so'rov id'siga bog'langan (backend: `link-review:<id>`, `link-correction:<id>`, `child-recovery:<id>`): so'rov hal bo'lganda o'chiriladi. */
export function accessNotificationId(kind: AccessNotificationKind, requestId: string): string {
  return `ntf-${kind.toLowerCase().replace(/_/g, '-')}-${requestId}`;
}

/** Bildirishnoma ko'rsatadigan amalni bajarish uchun kerak bo'lgan ruxsat (amal endpoint'lari talab qiladigani). */
export const ACTION_PERMISSION: Readonly<Record<AccessNotificationKind, Permission>> = {
  CHILD_RECOVERY_REQUEST: 'students.manage',
  LINK_REVIEW: 'guardians.link',
  LINK_CORRECTION: 'guardians.link',
};

/** Xodim bildirishnomasining qabul qiluvchilari: `staffIds` (aniq xodimlar) va ularning rollari. */
export type NotificationAudience = { staffIds: string[]; roles: RoleKey[] };

type Recipient = Pick<Staff, 'id' | 'role' | 'active' | 'classIds'>;

/** Rol doirasi o'quvchi sinfini qamraydimi: `SCHOOL` — hammasi; sinf doirali rol — faqat o'z sinflari (sinfsiz o'quvchi — yo'q). */
function coversClass(staff: Recipient, classId: string | null): boolean {
  if (ROLES[staff.role].scope === 'SCHOOL') return true;
  return classId !== null && staff.classIds.includes(classId);
}

const ROLE_ORDER = Object.keys(ROLES) as RoleKey[];

/**
 * Xodim bildirishnomasi FAQAT uni hal qila oladigan xodimlarga yuboriladi (backend `school/common/staff-recipients.ts`, K1 §5 va K2 §7):
 * maktabning FAOL xodimlari, amal endpoint'i talab qiladigan ruxsatga ega (`ACTION_PERMISSION`; rol/ruxsat jadvali bo'yicha — rol
 * nomlari qattiq yozilmagan) va o'quvchi sinfi ularning doirasida. Hozirgi jadvalda: `students.manage` — direktor va administrator;
 * `guardians.link` — direktor, administrator va O'QUVCHI SINFINING sinf rahbari. Sinf rahbariga `students.manage` berilsa — u ham
 * (faqat o'z sinfi uchun) tiklash so'rovini oladi.
 * Hech kim mos kelmasa — maktabning faol direktorlari (ruxsati bo'lmasa ham: e'tiborsiz qolmasin); faol direktor ham yo'q — `null`
 * (bildirishnoma yozilmaydi, so'rovning o'zi saqlanadi).
 */
export function notificationAudience(
  staff: readonly Recipient[],
  kind: AccessNotificationKind,
  classId: string | null,
  can: (role: RoleKey, permission: Permission) => boolean = roleHas,
): NotificationAudience | null {
  const permission = ACTION_PERMISSION[kind];
  const recipients = staff.filter((s) => s.active && can(s.role, permission) && coversClass(s, classId));
  if (recipients.length > 0) {
    const roles = new Set(recipients.map((s) => s.role));
    return { staffIds: recipients.map((s) => s.id), roles: ROLE_ORDER.filter((role) => roles.has(role)) };
  }
  return staff.some((s) => s.active && s.role === 'DIRECTOR') ? { staffIds: [], roles: ['DIRECTOR'] } : null;
}
