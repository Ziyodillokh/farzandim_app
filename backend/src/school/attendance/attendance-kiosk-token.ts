// Kiosk QR tokeni: `base64url({ s: schoolId, t: 30-soniyalik oyna })` + "." +
// HMAC-SHA256(School.kioskSecret). Har 30 soniyada almashadi; joriy va oldingi
// oyna qabul qilinadi (tarmoq kechikishi), imzo — vaqtga chidamli solishtirish.

import { HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { z } from 'zod';
import { PrismaService } from '../../common/database/prisma.service';

export const KIOSK_SLOT_MS = 30_000;

export type CheckInErrorCode = 'KIOSK_TOKEN_INVALID' | 'KIOSK_TOKEN_EXPIRED' | 'NOT_ENROLLED' | 'OUTSIDE_SCHOOL_HOURS';

const CHECK_IN_STATUS: Record<CheckInErrorCode, HttpStatus> = {
  KIOSK_TOKEN_INVALID: HttpStatus.BAD_REQUEST,
  KIOSK_TOKEN_EXPIRED: HttpStatus.BAD_REQUEST,
  NOT_ENROLLED: HttpStatus.FORBIDDEN,
  OUTSIDE_SCHOOL_HOURS: HttpStatus.BAD_REQUEST,
};

/** Bola ilovasi uchun barqaror xato kodlari: javob `{ statusCode, code, message }`. */
export class CheckInError extends HttpException {
  constructor(
    readonly code: CheckInErrorCode,
    message: string = code,
  ) {
    super({ code, message }, CHECK_IN_STATUS[code]);
  }
}

export interface KioskTokenView {
  token: string;
  issuedAt: string;
  expiresAt: string;
  /** Keyingi almashishgacha (yuqoriga yaxlitlangan, kamida 1). */
  rotatesInSeconds: number;
}

const BASE64URL = /^[A-Za-z0-9_-]+$/;
const payloadSchema = z.object({ s: z.string().min(1).max(64), t: z.number().int().nonnegative() }).strict();

const slotOf = (now: Date) => Math.floor(now.getTime() / KIOSK_SLOT_MS);

function sign(secret: string, payload: string): string {
  return createHmac('sha256', secret).update(payload).digest('base64url');
}

function sameSignature(given: string, expected: string): boolean {
  const a = Buffer.from(given);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

function decodePayload(encoded: string): z.output<typeof payloadSchema> | null {
  try {
    const parsed = payloadSchema.safeParse(JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8')));
    return parsed.success ? parsed.data : null;
  } catch {
    return null;
  }
}

@Injectable()
export class KioskTokenService {
  constructor(private readonly prisma: PrismaService) {}

  issue(schoolId: string, secret: string, now: Date): KioskTokenView {
    const slot = slotOf(now);
    const payload = Buffer.from(JSON.stringify({ s: schoolId, t: slot })).toString('base64url');
    const expiresMs = (slot + 1) * KIOSK_SLOT_MS;
    return {
      token: `${payload}.${sign(secret, payload)}`,
      issuedAt: new Date(slot * KIOSK_SLOT_MS).toISOString(),
      expiresAt: new Date(expiresMs).toISOString(),
      rotatesInSeconds: Math.max(1, Math.ceil((expiresMs - now.getTime()) / 1000)),
    };
  }

  /** Imzo va oyna tekshiruvi — tokendagi maktab ID'sini qaytaradi. */
  async verify(token: string, now: Date): Promise<string> {
    const [encoded, signature, ...rest] = token.split('.');
    if (!encoded || !signature || rest.length > 0 || !BASE64URL.test(encoded) || !BASE64URL.test(signature)) {
      throw new CheckInError('KIOSK_TOKEN_INVALID');
    }
    const payload = decodePayload(encoded);
    if (!payload) throw new CheckInError('KIOSK_TOKEN_INVALID');
    const school = await this.prisma.school.findUnique({
      where: { id: payload.s },
      select: { kioskSecret: true, status: true },
    });
    if (!school || school.status !== 'ACTIVE' || !sameSignature(signature, sign(school.kioskSecret, encoded))) {
      throw new CheckInError('KIOSK_TOKEN_INVALID');
    }
    const current = slotOf(now);
    if (payload.t > current) throw new CheckInError('KIOSK_TOKEN_INVALID');
    if (payload.t < current - 1) throw new CheckInError('KIOSK_TOKEN_EXPIRED');
    return payload.s;
  }
}
