import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  HOST: z.string().default('127.0.0.1'),
  LOG_LEVEL: z.string().default('info'),

  CORS_ORIGINS: z.string().default('https://farzandimedu.uz'),

  DATABASE_URL: z.string().url(),

  TELEGRAM_BOT_TOKEN: z.string().min(40),
  TELEGRAM_BOT_USERNAME: z.string().min(3),

  // Support chat → Telegram guruh ko'prigi (ixtiyoriy — yo'q bo'lsa bot
  // o'chiq, chat faqat saqlanadi). SUPPORT_CHAT_ID — operatorlar guruhi.
  TELEGRAM_BOT_TOKEN_SUPPORT: z.string().min(40).optional(),
  TELEGRAM_BOT_USERNAME_SUPPORT: z.string().min(3).optional(),
  SUPPORT_CHAT_ID: z.string().min(1).optional(),
  // Tashqaridan ochiladigan API bazasi (masalan https://test.farzandimedu.uz/api)
  // — Telegram'dagi biriktirma havolalari uchun. Yo'q bo'lsa havola qo'yilmaydi.
  PUBLIC_API_URL: z.string().url().optional(),

  JWT_ACCESS_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  JWT_ACCESS_EXPIRES: z.string().default('15m'),
  JWT_REFRESH_EXPIRES: z.string().default('30d'),

  ADMIN_JWT_ACCESS_SECRET: z.string().min(32),
  ADMIN_JWT_REFRESH_SECRET: z.string().min(32),
  ADMIN_JWT_ACCESS_EXPIRES: z.string().default('15m'),
  ADMIN_JWT_REFRESH_EXPIRES: z.string().default('30d'),

  MINIO_ENDPOINT: z.string().url(),
  MINIO_ACCESS_KEY: z.string().min(3),
  MINIO_SECRET_KEY: z.string().min(8),
  MINIO_PUBLIC_URL: z.string().url(),

  FIREBASE_SERVICE_ACCOUNT_BASE64: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),

  // AI hamroh (Faro) — Anthropic Claude API kaliti. Ixtiyoriy: yo'q bo'lsa
  // AI o'chiq (xavfsiz fallback), boshqa funksiyalar ishlayveradi. Kalit
  // FAQAT serverda — hech qachon client'ga yuborilmaydi (#64/#65).
  ANTHROPIC_API_KEY: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),

  PUBLIC_BASE_URL: z.string().url().default('https://farzandimedu.uz'),

  PAYME_MERCHANT_ID: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
  PAYME_MERCHANT_KEY: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
  PAYME_CHECKOUT_URL: z.string().url().default('https://checkout.paycom.uz'),

  CLICK_SERVICE_ID: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
  CLICK_MERCHANT_ID: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
  CLICK_SECRET_KEY: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
  CLICK_MERCHANT_USER_ID: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
  CLICK_CHECKOUT_URL: z
    .string()
    .url()
    .default('https://my.click.uz/services/pay'),

  UZUM_MERCHANT_SERVICE_ID: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
  UZUM_SECRET_KEY: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
  UZUM_API_BASE: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().url().optional(),
  ),

  PAYMENT_WEBHOOK_IPS: z.string().default(''),

  ESKIZ_EMAIL: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
  ESKIZ_PASSWORD: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
  ESKIZ_FROM: z.string().default('4546'),

  // ─── Google Sign In (ixtiyoriy) ────────────────────────────────────
  // Vergul bilan ajratilgan Google OAuth client ID'lar (Web/Android/iOS).
  // Backend `aud` (audience) shu ro'yxatdagi bittasi bo'lishini tekshiradi.
  // Bo'sh bo'lsa — /auth/google endpoint 503 qaytaradi (sozlanmagan).
  GOOGLE_CLIENT_IDS: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),

  // ─── Apple Sign In (ixtiyoriy) ─────────────────────────────────────
  // iOS bundle ID (com.farzandim.app) — bundle ID nativ Apple flow uchun aud bo'ladi.
  APPLE_BUNDLE_ID: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
  // Service ID (com.farzandim.web) — Android/web OAuth flow uchun aud.
  APPLE_SERVICE_ID: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
});

export type EnvConfig = z.infer<typeof envSchema>;

/**
 * Validate function for @nestjs/config ConfigModule.
 * Parses process.env through the Zod schema and returns the validated config.
 */
export function validate(config: Record<string, unknown>): EnvConfig {
  const parsed = envSchema.safeParse(config);

  if (!parsed.success) {
    const formatted = parsed.error.format();
    console.error('Invalid environment variables:', formatted);
    throw new Error('Environment validation failed');
  }

  return parsed.data;
}
