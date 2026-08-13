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

  // Google Play / App Store reviewer'i uchun maxsus oila kodi (ixtiyoriy).
  // Shu kodga ega bola profili uchun "bir bola = bir qurilma" bloki chetlab
  // o'tiladi — reviewer istalgan qurilmadan qayta-qayta ulanadi
  // (auth.service.ts childPair). Faqat bitta ataylab yaratilgan demo profil
  // uchun ishlating, real foydalanuvchi kodini qo'ymang.
  PLAY_REVIEW_FAMILY_CODE: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().min(5).optional(),
  ),

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

  // ── Payme fiskalizatsiya (soliq cheki) ────────────────────────────
  // Payme talabi: `CheckPerformTransaction` javobida `detail.items[]`
  // qaytarilishi kerak, aks holda chek soliq oborotida ko'rinmaydi.
  // MXIK (ИКПУ) kodi tasnif.soliq.uz dan olinadi; `package_code` MXIK'ga
  // bog'langan o'lchov birligi. Bo'sh bo'lsa `detail` UMUMAN qo'shilmaydi
  // (eski xatti-harakat) — noto'g'ri kod bilan chek yuborilmasin.
  PAYME_FISCAL_MXIK: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
  PAYME_FISCAL_PACKAGE_CODE: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
  // QQS foizi (0 = QQS to'lovchisi emas). Standart O'zbekistonda 12.
  PAYME_FISCAL_VAT_PERCENT: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.coerce.number().int().min(0).max(100).default(0),
  ),

  // ── Uzum MERCHANT API (yuqoridagi UZUM_* dan BOSHQA integratsiya) ──
  // Yuqoridagilar: biz Uzum'ga checkout URL yasaymiz (hozir o'chirilgan).
  // Quyidagilar: UZUM BIZGA so'rov yuboradi (check/create/confirm/reverse/
  // status). Login/parol BIZ tomonimizdan belgilanadi va Uzum'ga beriladi;
  // serviceId dastlab biz beramiz, test tugagach Uzum o'zinikini beradi.
  // Bo'sh bo'lsa endpointlar 401 qaytaradi (xavfsiz — hech kim kira olmaydi).
  UZUM_MERCHANT_USERNAME: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
  UZUM_MERCHANT_PASSWORD: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
  // Uzum `serviceId`ni RAQAM sifatida yuboradi — solishtirish raqamli.
  UZUM_MERCHANT_API_SERVICE_ID: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.coerce.number().int().positive().optional(),
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

  // ─── Email (nodemailer / SMTP) — ixtiyoriy ─────────────────────────
  // Email tasdiqlash kodi (SMS OTP'ning email varianti) shu SMTP orqali
  // yuboriladi. Gmail uchun: HOST=smtp.gmail.com, PORT=587, USER=<gmail>,
  // PASS=<16-belgili App Password>. Sozlanmagan bo'lsa email-OTP 503 beradi
  // (telefon orqali ro'yxatdan o'tish baribir ishlaydi).
  SMTP_HOST: z.string().default('smtp.gmail.com'),
  SMTP_PORT: z.coerce.number().int().positive().default(587),
  SMTP_USER: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
  SMTP_PASS: z.preprocess(
    (v) => (typeof v === 'string' && v.length === 0 ? undefined : v),
    z.string().optional(),
  ),
  // Brend "Parvoz" (SMS shablonlari bilan bir xil). DIQQAT: server `.env`da
  // MAIL_FROM aniq berilgan bo'lsa, bu default ISHLAMAYDI — u yerda ham
  // qo'lda yangilash kerak.
  MAIL_FROM: z.string().default('Parvoz <no-reply@farzandimedu.uz>'),

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
