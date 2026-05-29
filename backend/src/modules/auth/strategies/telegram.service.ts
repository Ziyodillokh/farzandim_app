import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash, createHmac } from 'crypto';
import { EnvConfig } from '../../../common/config/env.schema';

export interface TelegramAuthData {
  id: number;
  first_name?: string;
  last_name?: string;
  username?: string;
  photo_url?: string;
  auth_date: number;
  hash: string;
}

@Injectable()
export class TelegramService {
  constructor(private readonly config: ConfigService<EnvConfig, true>) {}

  /**
   * Verify Telegram Login Widget hash.
   * https://core.telegram.org/widgets/login#checking-authorization
   */
  verifyTelegramAuth(data: TelegramAuthData): boolean {
    const botToken = this.config.get('TELEGRAM_BOT_TOKEN', { infer: true });
    const { hash, ...fields } = data;

    // Build data-check-string: sorted key=value pairs joined by \n
    const dataCheckString = Object.keys(fields)
      .sort()
      .filter(
        (key) => fields[key as keyof typeof fields] !== undefined,
      )
      .map((key) => `${key}=${fields[key as keyof typeof fields]}`)
      .join('\n');

    // Secret key = SHA256(bot_token)
    const secretKey = createHash('sha256').update(botToken).digest();

    // HMAC-SHA256(data_check_string, secret_key)
    const computedHash = createHmac('sha256', secretKey)
      .update(dataCheckString)
      .digest('hex');

    return computedHash === hash;
  }

  /**
   * Check if auth data is fresh (within maxAgeSeconds, default 24h).
   */
  isAuthDataFresh(authDate: number, maxAgeSeconds = 86_400): boolean {
    const now = Math.floor(Date.now() / 1000);
    return now - authDate < maxAgeSeconds;
  }
}
