import * as speakeasy from 'speakeasy';
import { randomBytes } from 'crypto';
import * as jwt from 'jsonwebtoken';
import * as bcrypt from 'bcryptjs';

const ISSUER = 'Farzandim Admin';
const CHALLENGE_TTL_SEC = 5 * 60; // 5 minutes
const CHALLENGE_AUDIENCE = 'admin-2fa-challenge';

export interface ChallengePayload {
  sub: string;
  jti: string;
}

/**
 * Generate a new TOTP secret in base32 format.
 */
export function generateSecret(
  accountLabel: string,
): { secret: string; otpauthUri: string } {
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
 * Verify a 6-digit TOTP code against a base32 secret.
 * Window=1 allows the previous/next 30s interval (clock skew tolerance).
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
 * Generate backup codes (8 hex codes of 8 characters each).
 */
export function generateBackupCodes(count = 8): string[] {
  const codes: string[] = [];
  for (let i = 0; i < count; i++) {
    const buf = randomBytes(4);
    codes.push(buf.toString('hex').toUpperCase());
  }
  return codes;
}

/**
 * Hash backup codes with bcrypt.
 */
export async function hashBackupCodes(
  codes: readonly string[],
): Promise<string[]> {
  return Promise.all(codes.map((c) => bcrypt.hash(c, 8)));
}

/**
 * Find a matching backup code from the hashed list.
 * Returns the index if found, -1 otherwise.
 */
export async function findMatchingBackupCode(
  inputCode: string,
  hashedCodes: readonly string[],
): Promise<number> {
  const clean = inputCode.replace(/\s+/g, '').trim().toUpperCase();
  if (!/^[0-9A-F]{8}$/.test(clean)) return -1;
  for (let i = 0; i < hashedCodes.length; i++) {
    try {
      if (await bcrypt.compare(clean, hashedCodes[i])) return i;
    } catch {
      continue;
    }
  }
  return -1;
}

/**
 * Sign a short-lived challenge JWT after password verification
 * when 2FA is required.
 */
export function signChallenge(
  moderatorId: string,
  challengeSecret: string,
): string {
  const payload: ChallengePayload = {
    sub: moderatorId,
    jti: randomBytes(16).toString('hex'),
  };
  return jwt.sign(payload, challengeSecret, {
    expiresIn: CHALLENGE_TTL_SEC,
    audience: CHALLENGE_AUDIENCE,
    issuer: 'farzandim-backend',
  });
}

/**
 * Verify a challenge JWT. Returns the payload or null.
 */
export function verifyChallenge(
  token: string,
  challengeSecret: string,
): ChallengePayload | null {
  try {
    const decoded = jwt.verify(token, challengeSecret, {
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
