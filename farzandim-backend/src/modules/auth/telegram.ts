import { createHash, createHmac } from 'crypto';
import { env } from '../../config/env';

export interface TelegramAuthData {
  id: number;
  first_name?: string;
  last_name?: string;
  username?: string;
  photo_url?: string;
  auth_date: number;
  hash: string;
}

/**
 * Telegram Login Widget hash verify
 * https://core.telegram.org/widgets/login#checking-authorization
 */
export function verifyTelegramAuth(data: TelegramAuthData): boolean {
  const { hash, ...fields } = data;
  
  // Data check string yaratish
  const dataCheckString = Object.keys(fields)
    .sort()
    .filter((key) => fields[key as keyof typeof fields] !== undefined)
    .map((key) => `${key}=${fields[key as keyof typeof fields]}`)
    .join('\n');
  
  // Secret key = SHA256(bot_token)
  const secretKey = createHash('sha256')
    .update(env.TELEGRAM_BOT_TOKEN)
    .digest();
  
  // HMAC-SHA256(data_check_string)
  const computedHash = createHmac('sha256', secretKey)
    .update(dataCheckString)
    .digest('hex');
  
  return computedHash === hash;
}

/**
 * Auth data muddat tekshirish (24 soat ichida)
 */
export function isAuthDataFresh(authDate: number, maxAgeSeconds = 86400): boolean {
  const now = Math.floor(Date.now() / 1000);
  return now - authDate < maxAgeSeconds;
}
