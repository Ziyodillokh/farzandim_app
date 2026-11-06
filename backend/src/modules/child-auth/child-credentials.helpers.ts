// Bola login/parol qoidalari — sof funksiyalar (DB va Nest'siz, shuning uchun osongina sinaladi):
// login formati, ismdan login taklifi (transliteratsiya), vaqtinchalik parol, parol siyosati.

import { randomInt } from 'node:crypto';
import {
  CHILD_LOGIN_PATTERN,
  PASSWORD_MAX_BYTES,
  PASSWORD_MAX_LENGTH,
  PASSWORD_MIN_LENGTH,
  TEMP_PASSWORD_ALPHABET,
  TEMP_PASSWORD_LENGTH,
  TEMP_PASSWORD_TTL_DAYS,
} from './child-auth.constants';

type RandomInt = (max: number) => number;

/** Kiruvchi loginni solishtirish shakliga keltiradi (bo'shliqlarsiz, kichik harf). */
export function normalizeLogin(raw: unknown): string {
  return typeof raw === 'string' ? raw.trim().toLowerCase() : '';
}

export const isValidLogin = (login: string): boolean => CHILD_LOGIN_PATTERN.test(login);

// ── Transliteratsiya ────────────────────────────────────────────────

const CYRILLIC_TO_LATIN: Readonly<Record<string, string>> = {
  а: 'a', б: 'b', в: 'v', г: 'g', д: 'd', е: 'e', ё: 'yo', ж: 'j', з: 'z', и: 'i', й: 'y', к: 'k', л: 'l',
  м: 'm', н: 'n', о: 'o', п: 'p', р: 'r', с: 's', т: 't', у: 'u', ф: 'f', х: 'x', ц: 'ts', ч: 'ch', ш: 'sh',
  щ: 'sh', ъ: '', ы: 'i', ь: '', э: 'e', ю: 'yu', я: 'ya', ў: 'o', қ: 'q', ғ: 'g', ҳ: 'h', ә: 'a', ө: 'o', ң: 'n',
  ү: 'u', ұ: 'u', і: 'i', һ: 'h',
};

/** `oʻ`, `gʻ` va boshqa tutuq belgilari: ularning o'zi tushib qoladi (`oʻ` -> `o`). */
const APOSTROPHES = /[ʻʼ‘’`´']/g;

/**
 * Ismni login uchun ASCII qismga aylantiradi: kirill va o'zbek lotin harflari transliteratsiya qilinadi,
 * diakritiklar olib tashlanadi, faqat `a-z0-9` qoladi.
 */
export function toAsciiSlug(raw: string, maxLength = 12): string {
  const lower = raw.toLowerCase().replace(APOSTROPHES, '');
  let out = '';
  for (const ch of lower) out += CYRILLIC_TO_LATIN[ch] ?? ch;
  return out
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .replace(/[^a-z0-9]/g, '')
    .slice(0, maxLength);
}

/** Bola ismi ("Aziza Karimova") -> birinchi ism va familiyaning bosh harfi uchun manba. */
export function splitChildName(name: string): { firstName: string; lastName: string } {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  return { firstName: parts[0] ?? '', lastName: parts.length > 1 ? (parts[parts.length - 1] ?? '') : '' };
}

const pad = (n: number, width: number) => String(n).padStart(width, '0');

/**
 * Login nomzodlari: `aziza.k24` (ism + "." + familiya bosh harfi + 2 raqam), keyin zaxira `parvoz1234`.
 * Familiya yo'q bo'lsa `aziza.24`. Hammasi {@link isValidLogin} dan o'tadi, takrorlanmaydi.
 */
export function suggestLoginCandidates(
  names: { firstName?: string; lastName?: string },
  random: RandomInt = randomInt,
  perPattern = 8,
): string[] {
  const out = new Set<string>();
  const first = toAsciiSlug(names.firstName ?? '', 12);
  const initial = toAsciiSlug(names.lastName ?? '', 1);
  if (first) {
    const base = `${first}.${initial}`;
    for (let i = 0; i < perPattern; i++) out.add(`${base}${pad(random(100), 2)}`);
  }
  for (let i = 0; i < perPattern; i++) out.add(`parvoz${pad(random(10_000), 4)}`);
  return [...out].filter(isValidLogin);
}

// ── Vaqtinchalik parol ──────────────────────────────────────────────

export function generateTemporaryPassword(random: RandomInt = randomInt): string {
  let out = '';
  for (let i = 0; i < TEMP_PASSWORD_LENGTH; i++) out += TEMP_PASSWORD_ALPHABET[random(TEMP_PASSWORD_ALPHABET.length)];
  return out;
}

/** Vaqtinchalik parol amal qilish muddati (berilgan vaqt + 14 kun). */
export const tempPasswordExpiresAt = (issuedAt: Date): Date =>
  new Date(issuedAt.getTime() + TEMP_PASSWORD_TTL_DAYS * 24 * 60 * 60 * 1000);

/** Muddat tugagan lahzada ham (>=) eskirgan hisoblanadi. */
export const isTempPasswordExpired = (issuedAt: Date, now: Date): boolean =>
  now.getTime() >= tempPasswordExpiresAt(issuedAt).getTime();

// ── Parol siyosati ──────────────────────────────────────────────────

export type PasswordIssue =
  | 'TOO_SHORT'
  | 'TOO_LONG'
  | 'NEEDS_LETTER'
  | 'NEEDS_DIGIT'
  | 'SAME_AS_LOGIN'
  | 'TOO_COMMON'
  | 'SAME_AS_CURRENT';

/** Eng ko'p uchraydigan zaif parollar (kichik harf). Harf + raqam talabidan o'tadiganlari muhim. */
const COMMON_PASSWORDS: ReadonlySet<string> = new Set([
  'password1', 'password12', 'password123', 'passw0rd', 'qwerty123', 'qwerty1234', 'qwertyuiop1', 'qwer1234',
  'abc12345', 'abcd1234', 'abcd12345', 'abc123456', 'a1234567', 'a12345678', '12345678a', '123456789a',
  'asdf1234', 'zxcv1234', 'qazwsx123', '1q2w3e4r', '1qaz2wsx', 'q1w2e3r4', 'iloveyou1', 'welcome1',
  'welcome123', 'admin123', 'admin1234', 'test1234', 'user1234', 'pass1234', 'pass12345', 'letmein123',
  'football1', 'monkey123', 'dragon123', 'master123', 'sunshine1', 'princess1', 'trustno1', 'changeme1',
  'parol123', 'parol1234', 'parolparol1', 'salom123', 'salom1234', 'parvoz123', 'parvoz1234', 'farzandim1',
  'farzandim123', 'school123', 'maktab123',
]);

/**
 * Bola tanlagan parol siyosati: 8–64 belgi (bcrypt 72 bayt), kamida 1 harf va 1 raqam,
 * loginning o'zi emas, kichik taqiqlangan ro'yxatda yo'q. Birinchi topilgan muammo qaytadi.
 */
export function checkNewPassword(password: string, login: string): PasswordIssue | null {
  const length = [...password].length;
  if (length < PASSWORD_MIN_LENGTH) return 'TOO_SHORT';
  if (length > PASSWORD_MAX_LENGTH || Buffer.byteLength(password, 'utf8') > PASSWORD_MAX_BYTES) return 'TOO_LONG';
  if (!/\p{L}/u.test(password)) return 'NEEDS_LETTER';
  if (!/\d/.test(password)) return 'NEEDS_DIGIT';
  const lower = password.toLowerCase();
  if (lower === login.toLowerCase()) return 'SAME_AS_LOGIN';
  if (COMMON_PASSWORDS.has(lower)) return 'TOO_COMMON';
  return null;
}
