// Maktab paneli tokenlari: qisqa access JWT (audience `school-panel`) va
// refresh — tasodifiy sir, bazada faqat SHA-256 xeshi (sessiya bo'yicha).

import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { EnvConfig } from '../../common/config/env.schema';

export const SCHOOL_JWT_AUDIENCE = 'school-panel';
export const SCHOOL_ACCESS_TTL_SECONDS = 15 * 60;
export const SCHOOL_REFRESH_TTL_MS = 14 * 24 * 60 * 60 * 1000;

export interface SchoolAccessPayload {
  sub: string;
  sch: string;
  sid: string;
  tv: number;
}

@Injectable()
export class SchoolTokensService {
  private readonly jwt: JwtService;

  constructor(config: ConfigService<EnvConfig, true>) {
    const secret =
      config.get('SCHOOL_JWT_SECRET', { infer: true }) ??
      createHash('sha256')
        .update(`${config.get('JWT_ACCESS_SECRET', { infer: true })}:school-panel`)
        .digest('hex');
    this.jwt = new JwtService({
      secret,
      signOptions: {
        audience: SCHOOL_JWT_AUDIENCE,
        issuer: 'farzandim-backend',
        expiresIn: SCHOOL_ACCESS_TTL_SECONDS,
      },
      verifyOptions: { audience: SCHOOL_JWT_AUDIENCE, issuer: 'farzandim-backend' },
    });
  }

  signAccess(payload: SchoolAccessPayload): string {
    return this.jwt.sign(payload);
  }

  verifyAccess(token: string): SchoolAccessPayload {
    try {
      return this.jwt.verify<SchoolAccessPayload>(token);
    } catch {
      throw new UnauthorizedException({ code: 'TOKEN_INVALID', message: 'Invalid token' });
    }
  }

  /** Yangi refresh sir (cookie'ga) va uning xeshi (bazaga). */
  newRefreshSecret(): { secret: string; hash: string } {
    const secret = randomBytes(32).toString('base64url');
    return { secret, hash: hashSecret(secret) };
  }

  matches(secret: string, hash: string): boolean {
    const a = Buffer.from(hashSecret(secret), 'hex');
    const b = Buffer.from(hash, 'hex');
    return a.length === b.length && timingSafeEqual(a, b);
  }
}

function hashSecret(secret: string): string {
  return createHash('sha256').update(secret).digest('hex');
}
