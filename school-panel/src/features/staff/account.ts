import { roleHas } from '@/auth/permissions';
import { type RoleKey, ServiceError } from '@/data/contracts';
import type { StaffRow } from '@/data/mock/services/staff';
import type { TKey } from '@/i18n';
import { errorKey } from '@/lib/errors';

/**
 * Himoyalangan rol (psixolog) — bolaning maxfiy ma'lumotiga kiradi; haqiqiy
 * rejimda uni direktor bera olmaydi (server ham rad etadi), Parvoz operatori beradi.
 */
export const isProtectedRole = (role: RoleKey) => roleHas(role, 'care.individual') || roleHas(role, 'assessments.manage');

/** Qator menyusidagi panel hisobi amallari; `note` — nofaol amal ostidagi izoh. */
export type AccountMenu = { canSet: boolean; canRemove: boolean; note: 'self' | 'protected' | null };

/**
 * O'z qatorida panel hisobi amallari yo'q (server ham 409 'self' qaytaradi): o'z parolini xodim
 * "Profilim" oynasida, joriy parolni kiritib almashtiradi. Himoyalangan rol hisobini operator beradi.
 */
export function accountMenu(row: Pick<StaffRow, 'id' | 'role' | 'username'>, selfId: string | null): AccountMenu {
  const self = row.id === selfId;
  const protectedRole = isProtectedRole(row.role);
  return {
    canSet: !self && !protectedRole,
    canRemove: !self && Boolean(row.username),
    note: self ? 'self' : protectedRole ? 'protected' : null,
  };
}

/** Xodim amallari xatosi → tarjima kaliti: band login (409 'username') — aniq xabar, boshqa 409 — umumiy. */
export function staffErrorKey(error: unknown): TKey {
  if (!(error instanceof ServiceError) || error.code !== 'CONFLICT') return errorKey(error);
  return error.message === 'username' ? 'staff.account.usernameTaken' : 'staff.errors.conflict';
}

/** Server qoidasi bilan bir xil. */
export const USERNAME_PATTERN = /^[a-z0-9._-]{3,32}$/;

const PASSWORD_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
const TEMP_PASSWORD_LENGTH = 12;

/** Vaqtinchalik parol (kriptografik tasodif, chalkash belgilarsiz). */
export function generateTempPassword(): string {
  const bytes = new Uint32Array(TEMP_PASSWORD_LENGTH);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => PASSWORD_ALPHABET[b % PASSWORD_ALPHABET.length]).join('');
}

/** Ismdan login taklifi: "Saidova Gulnora" → "saidova". */
export function suggestUsername(fullName: string): string {
  const first = fullName.trim().split(/\s+/)[0] ?? '';
  const latin = first.toLowerCase().replace(/[ʻʼ’‘`´']/g, '').replace(/[^a-z0-9._-]/g, '');
  return USERNAME_PATTERN.test(latin) ? latin : '';
}
