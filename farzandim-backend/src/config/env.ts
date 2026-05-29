import { z } from 'zod';
import 'dotenv/config';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  HOST: z.string().default('127.0.0.1'),
  LOG_LEVEL: z.string().default('info'),

  // CORS — vergul bilan ajratilgan ruxsat etilgan origin'lar (Sprint 6 — P1)
  CORS_ORIGINS: z.string().default('https://farzandimedu.uz'),

  DATABASE_URL: z.string().url(),
  
  TELEGRAM_BOT_TOKEN: z.string().min(40),
  TELEGRAM_BOT_USERNAME: z.string().min(3),
  
  JWT_ACCESS_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  JWT_ACCESS_EXPIRES: z.string().default('15m'),
  JWT_REFRESH_EXPIRES: z.string().default('30d'),

  // Admin panel JWT — alohida secret (consumer JWT bilan to'qnashmaslik uchun).
  ADMIN_JWT_ACCESS_SECRET: z.string().min(32),
  ADMIN_JWT_REFRESH_SECRET: z.string().min(32),
  ADMIN_JWT_ACCESS_EXPIRES: z.string().default('15m'),
  ADMIN_JWT_REFRESH_EXPIRES: z.string().default('30d'),


  MINIO_ENDPOINT: z.string().url(),
  MINIO_ACCESS_KEY: z.string().min(3),
  MINIO_SECRET_KEY: z.string().min(8),
  MINIO_PUBLIC_URL: z.string().url(),

  // FCM service account (base64-encoded JSON). Optional — push send'siz token CRUD ishlaydi.
  FIREBASE_SERVICE_ACCOUNT_BASE64: z.string().optional(),

  // ============================================
  // To'lov provayderlari (Sprint 6 — P0 monetizatsiya)
  // Hammasi optional — kalit yo'q bo'lsa provayder "sozlanmagan" hisoblanadi,
  // checkout 503 qaytaradi (FCM bilan bir xil graceful-disable pattern).
  // ============================================
  PUBLIC_BASE_URL: z.string().url().default('https://farzandimedu.uz'),

  // Payme (Merchant API — JSON-RPC webhook)
  PAYME_MERCHANT_ID: z.string().optional(),
  PAYME_MERCHANT_KEY: z.string().optional(),
  PAYME_CHECKOUT_URL: z.string().url().default('https://checkout.paycom.uz'),

  // Click (Merchant SHOP API — prepare/complete callback)
  CLICK_SERVICE_ID: z.string().optional(),
  CLICK_MERCHANT_ID: z.string().optional(),
  CLICK_SECRET_KEY: z.string().optional(),
  CLICK_MERCHANT_USER_ID: z.string().optional(),
  CLICK_CHECKOUT_URL: z.string().url().default('https://my.click.uz/services/pay'),

  // Uzum Bank (Checkout API)
  UZUM_MERCHANT_SERVICE_ID: z.string().optional(),
  UZUM_SECRET_KEY: z.string().optional(),
  UZUM_API_BASE: z.string().url().optional(),

  // Webhook IP allowlist (H5) — vergul bilan ajratilgan IP'lar. Bo'sh bo'lsa
  // IP tekshiruvi o'chiq (imzo tekshiruvi baribir ishlaydi).
  PAYMENT_WEBHOOK_IPS: z.string().default(''),

  // SMS — Eskiz.uz (Sprint 6 — P1). Kalit yo'q bo'lsa SMS o'chiq (graceful-disable).
  ESKIZ_EMAIL: z.string().optional(),
  ESKIZ_PASSWORD: z.string().optional(),
  ESKIZ_FROM: z.string().default('4546'),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('❌ Invalid environment variables:');
  console.error(parsed.error.format());
  process.exit(1);
}

export const env = parsed.data;

/** Ruxsat etilgan CORS origin'lar — server.ts va realtime.ts ishlatadi. */
export const corsOrigins = env.CORS_ORIGINS.split(',')
  .map((o) => o.trim())
  .filter(Boolean);

/** To'lov webhook IP allowlist (H5). Bo'sh array = IP tekshiruvi o'chiq. */
export const paymentWebhookIps = env.PAYMENT_WEBHOOK_IPS.split(',')
  .map((ip) => ip.trim())
  .filter(Boolean);
