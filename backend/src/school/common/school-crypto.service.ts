// Bolaning maxfiy ma'lumoti (so'rovnoma / test javoblari, murojaat matni,
// psixolog eslatmalari) bazada AES-256-GCM bilan shifrlanadi: `v1.<iv>.<shifr+teg>`.
// Kalit — `SCHOOL_DATA_KEY` (boshqa kalitdan hosila olinmaydi). Versiya
// prefiksi keyin kalit almashtirishni (rotatsiya) qo'shishga imkon beradi.

import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
import { EnvConfig } from '../../common/config/env.schema';

const VERSION = 'v1';
const IV_BYTES = 12;
const TAG_BYTES = 16;

@Injectable()
export class SchoolCryptoService {
  private readonly key: Buffer | null;

  constructor(config: ConfigService<EnvConfig, true>) {
    const raw = config.get('SCHOOL_DATA_KEY', { infer: true });
    this.key = raw ? Buffer.from(raw, 'base64') : null;
  }

  /** Kalit sozlanganmi — yo'q bo'lsa shifrlash 503 NOT_CONFIGURED beradi. */
  isConfigured(): boolean {
    return this.key !== null;
  }

  encrypt(plain: string): string {
    const key = this.requireKey();
    const iv = randomBytes(IV_BYTES);
    const cipher = createCipheriv('aes-256-gcm', key, iv);
    const body = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final(), cipher.getAuthTag()]);
    return `${VERSION}.${iv.toString('base64url')}.${body.toString('base64url')}`;
  }

  decrypt(token: string): string {
    const key = this.requireKey();
    const [version, iv, body] = token.split('.');
    if (version !== VERSION || !iv || !body) throw new Error('school-crypto: unknown format');
    const data = Buffer.from(body, 'base64url');
    const decipher = createDecipheriv('aes-256-gcm', key, Buffer.from(iv, 'base64url'));
    decipher.setAuthTag(data.subarray(data.length - TAG_BYTES));
    return Buffer.concat([decipher.update(data.subarray(0, data.length - TAG_BYTES)), decipher.final()]).toString('utf8');
  }

  encryptJson(value: unknown): string {
    return this.encrypt(JSON.stringify(value));
  }

  decryptJson<T>(token: string): T {
    return JSON.parse(this.decrypt(token)) as T;
  }

  private requireKey(): Buffer {
    if (!this.key) {
      throw new ServiceUnavailableException({ code: 'NOT_CONFIGURED', message: 'School data key is not configured' });
    }
    return this.key;
  }
}
