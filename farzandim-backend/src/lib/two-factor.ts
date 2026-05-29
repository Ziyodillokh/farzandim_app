// ─────────────────────────────────────────────────────────────────────
// Admin 2FA — TOTP (Time-based One-Time Password)
// ─────────────────────────────────────────────────────────────────────
//
// Standart: RFC 6238 (TOTP), RFC 4226 (HOTP). otplib library Google
// Authenticator, Authy, 1Password va boshqa standart TOTP klientlar
// bilan mos. otpauth:// URI orqali QR code generatsiya qilinadi.
//
// Backup kodlar:
//   - 8 ta 8-character hex code (40 bit entropiya har biri)
//   - bcrypt hashed DB'da saqlanadi
//   - Single-use: ishlatilgan ko'paytirilgan ro'yxatdan o'chiriladi
//   - QR yo'qotgan admin login qila olishi uchun

import speakeasy from 'speakeasy';
import { randomBytes, timingSafeEqual } from 'crypto';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { env } from '../config/env';

const ISSUER = 'Farzandim Admin';
const CHALLENGE_TTL_SEC = 5 * 60; // 5 minut
const CHALLENGE_AUDIENCE = 'admin-2fa-challenge';

const TWO_FA_SECRET = (() => {
  // Challenge tokenlar uchun alohida secret — access token secret'dan farqli
  // ishlash uchun. ADMIN_2FA_CHALLENGE_SECRET env'da bo'lsa o'shani ishlatamiz;
  // bo'lmasa ADMIN_JWT_ACCESS_SECRET + suffix.
  const explicit = process.env.ADMIN_2FA_CHALLENGE_SECRET;
  if (explicit && explicit.length > 16) return explicit;
  return env.ADMIN_JWT_ACCESS_SECRET + ':2fa-challenge';
})();

/**
 * Yangi TOTP secret generatsiya qilish. Base32 formatda.
 */
export function generateSecret(accountLabel: string): { secret: string; otpauthUri: string } {
  const s = speakeasy.generateSecret({
    name: `${ISSUER} (${accountLabel})`,
    issuer: ISSUER,
    length: 20,
  });
  return {
    secret: s.base32,
    otpauthUri: s.otpauth_url ?? '',
  };
}

/**
 * Foydalanuvchi kiritgan 6-raqamli kodni TOTP secret bilan tekshirish.
 * Window=1 — oldingi/keyingi 30s oraliqlar ham qabul qilinadi (clock skew tolerance).
 */
export function verifyTotpCode(token: string, secret: string): boolean {
  if (!token || !secret) return false;
  const clean = token.replace(/\s+/g, '').trim();
  if (!/^\d{6}$/.test(clean)) return false;
  try {
    return speakeasy.totp.verify({
      secret,
      encoding: 'base32',
      token: clean,
      window: 1,
    });
  } catch {
    return false;
  }
}

/**
 * 8 ta backup code generatsiya qilish. Foydalanuvchiga ko'rsatish uchun
 * plaintext, DB'da hashed saqlanadi.
 */
export function generateBackupCodes(count = 8): string[] {
  const codes: string[] = [];
  for (let i = 0; i < count; i++) {
    const buf = randomBytes(4); // 32 bit → 8 hex char
    codes.push(buf.toString('hex').toUpperCase());
  }
  return codes;
}

/**
 * Backup kodlar massivini bcrypt bilan hash qilish.
 */
export async function hashBackupCodes(codes: readonly string[]): Promise<string[]> {
  return Promise.all(codes.map((c) => bcrypt.hash(c, 8)));
}

/**
 * Backup kod kiritilgan bo'lsa, ro'yxatdan moslikni topish.
 * Topilsa, hashlangan kod'ning indexini qaytaradi (caller'ga o'chirish uchun).
 * Topilmasa -1.
 */
export async function findMatchingBackupCode(
  inputCode: string,
  hashedCodes: readonly string[],
): Promise<number> {
  const clean = inputCode.replace(/\s+/g, '').trim().toUpperCase();
  if (!/^[0-9A-F]{8}$/.test(clean)) return -1;
  for (let i = 0; i < hashedCodes.length; i++) {
    try {
      if (await bcrypt.compare(clean, hashedCodes[i]!)) return i;
    } catch {
      continue;
    }
  }
  return -1;
}

// ─── Challenge tokens (2FA pending state, JWT-based stateless) ──────

export interface ChallengePayload {
  sub: string; // moderator id
  jti: string; // unique nonce — replay attack himoyasi
}

/**
 * Login muvaffaqiyatli (password OK), lekin 2FA kerak — short-lived JWT.
 * Frontend buni `challengeId` sifatida saqlaydi va /2fa/verify ga yuboradi.
 */
export function signChallenge(moderatorId: string): string {
  const payload: ChallengePayload = {
    sub: moderatorId,
    jti: randomBytes(16).toString('hex'),
  };
  return jwt.sign(payload, TWO_FA_SECRET, {
    expiresIn: CHALLENGE_TTL_SEC,
    audience: CHALLENGE_AUDIENCE,
    issuer: 'farzandim-backend',
  });
}

export function verifyChallenge(token: string): ChallengePayload | null {
  try {
    const decoded = jwt.verify(token, TWO_FA_SECRET, {
      audience: CHALLENGE_AUDIENCE,
      issuer: 'farzandim-backend',
    });
    if (typeof decoded !== 'object' || decoded === null) return null;
    const obj = decoded as Record<string, unknown>;
    if (typeof obj.sub !== 'string' || typeof obj.jti !== 'string') return null;
    return { sub: obj.sub, jti: obj.jti };
  } catch {
    return null;
  }
}

// Constant-time string compare (utility)
export function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  const ba = Buffer.from(a);
  const bb = Buffer.from(b);
  return timingSafeEqual(ba, bb);
}
