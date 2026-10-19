// E2E testlar muhiti — faqat test qiymatlari (haqiqiy kalit EMAS).
// Tashqi integratsiyalar (Telegram, FCM, to'lovlar, SMS, pochta, AI) ataylab
// bo'sh: `.env` fayl bo'lsa ham dotenv mavjud qiymatni almashtirmaydi.

const required: Record<string, string> = {
  NODE_ENV: 'development',
  DATABASE_URL:
    process.env.E2E_DATABASE_URL ??
    'postgresql://farzandim:farzandim@localhost:54329/farzandim_test',
  TELEGRAM_BOT_TOKEN: 'e2e-telegram-token-'.padEnd(48, 'x'),
  TELEGRAM_BOT_USERNAME: 'e2e_bot',
  JWT_ACCESS_SECRET: 'e2e-consumer-access-secret-'.padEnd(48, 'a'),
  JWT_REFRESH_SECRET: 'e2e-consumer-refresh-secret-'.padEnd(48, 'b'),
  ADMIN_JWT_ACCESS_SECRET: 'e2e-admin-access-secret-'.padEnd(48, 'c'),
  ADMIN_JWT_REFRESH_SECRET: 'e2e-admin-refresh-secret-'.padEnd(48, 'd'),
  MINIO_ENDPOINT: 'http://127.0.0.1:9',
  MINIO_ACCESS_KEY: 'e2e',
  MINIO_SECRET_KEY: 'e2e-secret',
  MINIO_PUBLIC_URL: 'http://127.0.0.1:9',
  CORS_ORIGINS: 'http://localhost',
};

import { existsSync } from 'node:fs';
import path from 'node:path';

// `.env` (haqiqiy kalitlar) bo'lsa ConfigModule undagi qiymatlarni ham
// yuklaydi — testlar tashqi xizmatlarga (Telegram support boti va h.k.)
// ulanib ketmasligi uchun bunday holatda ishlamaymiz.
if (existsSync(path.resolve(__dirname, '../../.env'))) {
  throw new Error(
    'E2E: backend/.env topildi — testlar haqiqiy kalitlar bilan ishlamasin. ' +
      'Uni vaqtincha olib qo\'ying yoki toza worktree\'da ishga tushiring.',
  );
}

// Bo'sh qiymatni qabul qilmaydigan ixtiyoriy kalitlar — umuman o'rnatilmaydi.
const unset = [
  'TELEGRAM_BOT_TOKEN_SUPPORT',
  'TELEGRAM_BOT_USERNAME_SUPPORT',
  'SUPPORT_CHAT_ID',
];

const disabled = [
  'FIREBASE_SERVICE_ACCOUNT_BASE64',
  'ANTHROPIC_API_KEY',
  'PAYME_MERCHANT_ID',
  'PAYME_MERCHANT_KEY',
  'CLICK_SERVICE_ID',
  'CLICK_MERCHANT_ID',
  'CLICK_SECRET_KEY',
  'UZUM_SECRET_KEY',
  'ESKIZ_EMAIL',
  'ESKIZ_PASSWORD',
  'SMTP_USER',
  'SMTP_PASS',
];

for (const [key, value] of Object.entries(required)) process.env[key] = value;
for (const key of disabled) process.env[key] = '';
for (const key of unset) delete process.env[key];
