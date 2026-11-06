// Bola birinchi kirishidagi "parol o'rnatish" tokeni (setupToken): 15 daqiqa, BIR MARTALIK.
//
// Xavfsizlik:
//  - access/refresh tokenlari bilan aralashmaydi: alohida imzo kaliti (JWT_ACCESS_SECRET'dan maqsadli
//    HMAC bilan hosila) va alohida `aud` — bu token hech qachon Bearer yoki WebSocket tokeni sifatida o'tmaydi;
//  - bir martalik: tokenga joriy parol xeshining barmoq izi (HMAC) yoziladi; parol o'rnatilgach (yoki
//    qayta tiklansa) xesh o'zgaradi va eski token o'z-o'zidan yaroqsiz bo'ladi. Qayta ishlatish xesh bo'yicha
//    shartli UPDATE (compare-and-swap) bilan parallel so'rovlarda ham yagona yutuvchiga ega.

import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { createHmac, randomUUID } from 'node:crypto';
import { EnvConfig } from '../../common/config/env.schema';
import { SETUP_TOKEN_AUDIENCE, SETUP_TOKEN_PURPOSE, SETUP_TOKEN_TTL_SECONDS } from './child-auth.constants';

export interface SetupTokenClaims {
  childId: string;
  /** Token berilgan paytdagi parol xeshining barmoq izi. */
  fingerprint: string;
}

const ISSUER = 'farzandim-backend';

@Injectable()
export class ChildSetupTokens {
  private readonly secret: string;

  constructor(
    private readonly jwt: JwtService,
    config: ConfigService<EnvConfig, true>,
  ) {
    const base = config.get('JWT_ACCESS_SECRET', { infer: true });
    this.secret = createHmac('sha256', base).update('farzandim:child-setup-token:v1').digest('hex');
  }

  /** Parol xeshining barmoq izi (kalitli HMAC — xeshning o'zi tokenda ko'rinmaydi). */
  fingerprint(passwordHash: string): string {
    return createHmac('sha256', this.secret).update(passwordHash).digest('hex').slice(0, 32);
  }

  sign(childId: string, passwordHash: string): string {
    return this.jwt.sign(
      { purpose: SETUP_TOKEN_PURPOSE, cid: childId, fp: this.fingerprint(passwordHash), jti: randomUUID() },
      { secret: this.secret, audience: SETUP_TOKEN_AUDIENCE, issuer: ISSUER, expiresIn: SETUP_TOKEN_TTL_SECONDS },
    );
  }

  /** Yaroqli bo'lsa da'vo, aks holda `null` (imzo, muddat, `aud`, maqsad — barchasi tekshiriladi). */
  verify(token: string): SetupTokenClaims | null {
    try {
      const claims = this.jwt.verify<{ purpose?: unknown; cid?: unknown; fp?: unknown }>(token, {
        secret: this.secret,
        audience: SETUP_TOKEN_AUDIENCE,
        issuer: ISSUER,
      });
      if (claims.purpose !== SETUP_TOKEN_PURPOSE) return null;
      if (typeof claims.cid !== 'string' || typeof claims.fp !== 'string') return null;
      return { childId: claims.cid, fingerprint: claims.fp };
    } catch {
      return null;
    }
  }
}
