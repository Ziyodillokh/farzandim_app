import Fastify, { type FastifyError } from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import cookie from '@fastify/cookie';
import rateLimit from '@fastify/rate-limit';
import { env, corsOrigins } from './config/env';
import { authRoutes } from './modules/auth/routes';
import { userRoutes } from './modules/users/routes';
import { childrenRoutes } from './modules/children/routes';
import { locationRoutes } from './modules/location/routes';
import { voiceMessagesRoutes } from './modules/voice-messages/routes';
import { scheduleRoutes } from './modules/schedules/routes';
import { routineRoutes } from './modules/routines/routes';
import { geoZoneRoutes } from './modules/geo-zones/routes';
import { fcmRoutes } from './modules/fcm/routes';
import { notificationRoutes } from './modules/notifications/routes';
import { feedbackRoutes } from './modules/feedback/routes';
import { gamificationRoutes } from './modules/gamification/routes';
import { videoMessagesRoutes } from './modules/video-messages/routes';
import { photoRequestRoutes } from './modules/photo-requests/routes';
import { sosAlertRoutes } from './modules/sos-alerts/routes';
import { installedAppsRoutes } from './modules/installed-apps/routes';
import { appLimitsRoutes } from './modules/app-limits/routes';
import { childPairRequestsRoutes } from './modules/child-pair-requests/routes';
import { appVersionRoutes } from './modules/app-version/routes';
import { adminAuthRoutes } from './modules/admin-auth/routes';
import { adminModeratorsRoutes } from './modules/admin-moderators/routes';
import { adminUsersRoutes } from './modules/admin-users/routes';
import { adminDashboardRoutes } from './modules/admin-dashboard/routes';
import { adminMonetizationRoutes } from './modules/admin-monetization/routes';
import { adminNotificationsRoutes } from './modules/admin-notifications/routes';
import { adminOlympiadsRoutes } from './modules/admin-olympiads/routes';
import { adminAnalyticsRoutes } from './modules/admin-analytics/routes';
import { adminCategoriesRoutes } from './modules/admin-content/categories';
import { adminVideosRoutes } from './modules/admin-content/videos';
import { adminAudiobooksRoutes } from './modules/admin-content/audiobooks';
import { adminBooksRoutes } from './modules/admin-content/books';
import { adminAuditLogRoutes } from './modules/admin-audit-log/routes';
import { consumerContentRoutes } from './modules/consumer-content/routes';
import { consumerOlympiadsRoutes } from './modules/consumer-olympiads/routes';
import { paymentRoutes } from './modules/payments/routes';
import { initRealtime, closeRealtime } from './lib/realtime';
import { ensureBuckets } from './lib/minio';
import { prisma } from './lib/prisma';

const fastify = Fastify({
  logger: {
    level: env.LOG_LEVEL,
  },
  // bodyLimit eng katta multipart upload'ga moslangan:
  //   - Voice messages: max 10 MB (audio)
  //   - Video messages: max 100 MB (Sprint 4.4.33 round video)
  //   - Installed apps icons batch: max ~25 MB (500 ta × 50 KB)
  // Multipart cap'i @fastify/multipart o'zining fileSize bilan boshqariladi,
  // lekin global bodyLimit butun raw request body (fayl + form fields + boundary)
  // dan o'tmasligi shart.
  bodyLimit: 100 * 1024 * 1024, // 100 MB
  // H10 — graceful shutdown'da osilgan keep-alive ulanishlarini majburan yopadi.
  forceCloseConnections: true,
});

// Sprint 6 — bo'sh body + Content-Type: application/json → {} deb qabul qilinadi.
// Ko'p "action" endpoint'lar (mark-read, approve, delete, start, increment)
// body talab qilmaydi, lekin mijozlar (Flutter app + admin panel) JSON
// content-type header yuboradi. Default Fastify parser bunda
// FST_ERR_CTP_EMPTY_JSON_BODY (400) tashlardi va o'sha endpoint'larni buzardi.
// Body kerak bo'lgan route'lar baribir Zod validatsiyada xato qaytaradi.
fastify.addContentTypeParser(
  'application/json',
  { parseAs: 'string' },
  (_req, body, done) => {
    const text = (body as string).trim();
    if (text.length === 0) {
      done(null, {});
      return;
    }
    try {
      done(null, JSON.parse(text));
    } catch (err) {
      (err as Error & { statusCode?: number }).statusCode = 400;
      done(err as Error, undefined);
    }
  },
);

// CORS — allowlist (Sprint 6 P1). Origin headersiz so'rovlar (mobil app,
// server-to-server) ta'sirlanmaydi — faqat brauzer cross-origin tekshiriladi.
fastify.register(cors, {
  origin: corsOrigins,
  credentials: true,
});

// H2 — Security headers (HSTS, X-Frame-Options, X-Content-Type-Options,
// Referrer-Policy, ...). CSP o'chirilgan — bu JSON API; brauzerga ko'rinadigan
// sahifalar (admin SPA, login.html) Nginx orqali beriladi, CSP o'sha yerga mos.
fastify.register(helmet, { contentSecurityPolicy: false });

// H7 — cookie o'qish/o'rnatish (admin refresh token HttpOnly cookie uchun).
fastify.register(cookie);

// Sprint 5.x — Global rate limit (brute-force protection).
//
// In-memory store: single-server deploy uchun yetarli. Multi-server kerak
// bo'lganda Redis adapter qo'shamiz (Redis allaqachon server'da tirik).
//
// Global default: 300 req/min/IP — oddiy admin/consumer traffic uchun keng.
// Strict limits per-route'da `config: { rateLimit: { max: N, timeWindow: ... } }`
// orqali override qilinadi (admin-auth/routes.ts'da).
//
// Trusted proxies (Nginx) — `X-Forwarded-For` headerdan IP olamiz.
fastify.register(rateLimit, {
  global: true,
  max: 300,
  timeWindow: '1 minute',
  // Nginx orqasida turibmiz, real IP `X-Forwarded-For`'dan keladi
  hook: 'preHandler',
  keyGenerator: (request) => {
    const fwd = request.headers['x-forwarded-for'];
    if (typeof fwd === 'string' && fwd.length > 0) {
      const first = fwd.split(',')[0]?.trim();
      if (first) return first;
    }
    return request.ip;
  },
  errorResponseBuilder: (_request, context) => ({
    statusCode: 429,
    error: 'Too Many Requests',
    message: `Juda ko'p so'rov. ${context.after} dan keyin qayta urinib ko'ring.`,
    retryAfterMs: context.ttl,
  }),
});

// H3 — Global error handler. Server tomonda to'liq xato logga yoziladi,
// mijozga 5xx uchun umumiy xabar qaytadi (stack trace / ichki tafsilot
// oshkor qilinmaydi). 4xx (validatsiya va h.k.) xabari xavfsiz — uzatiladi.
fastify.setErrorHandler((error: FastifyError, request, reply) => {
  const statusCode = error.statusCode ?? 500;
  if (statusCode >= 500) {
    request.log.error({ err: error, reqId: request.id }, 'Kutilmagan server xatosi');
    return reply.code(500).send({ error: 'Server xatosi. Keyinroq urinib koʻring.' });
  }
  request.log.warn({ err: error.message, reqId: request.id }, 'Soʻrov rad etildi');
  return reply.code(statusCode).send({ error: error.message || 'Soʻrov rad etildi' });
});

// Health
fastify.get('/api/health', async () => ({
  status: 'ok',
  service: 'Farzandim Backend',
  version: '0.7.2',
  timestamp: new Date().toISOString(),
}));

// Root
fastify.get('/api', async () => ({
  message: 'Farzandim API ishlaydi! 🇺🇿',
}));

// Modules
fastify.register(authRoutes, { prefix: '/api/auth' });
fastify.register(userRoutes, { prefix: '/api/users' });
fastify.register(childrenRoutes, { prefix: '/api/children' });
fastify.register(locationRoutes, { prefix: '/api' });
fastify.register(voiceMessagesRoutes, { prefix: '/api/voice-messages' });
fastify.register(scheduleRoutes, { prefix: '/api' });
fastify.register(routineRoutes, { prefix: '/api' });
fastify.register(geoZoneRoutes, { prefix: '/api' });
fastify.register(fcmRoutes, { prefix: '/api/fcm' });
// Sprint 4.4 modullari
fastify.register(notificationRoutes, { prefix: '/api' });
fastify.register(feedbackRoutes, { prefix: '/api' });
fastify.register(gamificationRoutes, { prefix: '/api' });
fastify.register(videoMessagesRoutes, { prefix: '/api/video-messages' });
fastify.register(photoRequestRoutes, { prefix: '/api' });
fastify.register(sosAlertRoutes, { prefix: '/api' });
fastify.register(installedAppsRoutes, { prefix: '/api' });
fastify.register(appLimitsRoutes, { prefix: '/api' });
fastify.register(childPairRequestsRoutes, { prefix: '/api' });
fastify.register(appVersionRoutes, { prefix: '/api/app' });

// Sprint 5.1 — Admin panel modullari (alohida JWT audience)
fastify.register(adminAuthRoutes, { prefix: '/api/admin/auth' });
fastify.register(adminModeratorsRoutes, { prefix: '/api/admin/moderators' });
fastify.register(adminUsersRoutes, { prefix: '/api/admin/users' });
fastify.register(adminDashboardRoutes, { prefix: '/api/admin/dashboard' });
fastify.register(adminMonetizationRoutes, { prefix: '/api/admin/monetization' });
fastify.register(adminNotificationsRoutes, { prefix: '/api/admin/notifications' });
fastify.register(adminOlympiadsRoutes, { prefix: '/api/admin/olympiads' });
fastify.register(adminAnalyticsRoutes, { prefix: '/api/admin/analytics' });
fastify.register(adminCategoriesRoutes, { prefix: '/api/admin/categories' });
fastify.register(adminVideosRoutes, { prefix: '/api/admin/videos' });
fastify.register(adminAudiobooksRoutes, { prefix: '/api/admin/audiobooks' });
fastify.register(adminBooksRoutes, { prefix: '/api/admin/books' });
fastify.register(adminAuditLogRoutes, { prefix: '/api/admin/audit-log' });

// Consumer-side content API — Child App video/audiobook/book feed
fastify.register(consumerContentRoutes, { prefix: '/api/content' });
fastify.register(consumerOlympiadsRoutes, { prefix: '/api/content/olympiads' });

// Sprint 6 — P0 monetizatsiya: to'lov (Payme/Click/Uzum) + obuna
fastify.register(paymentRoutes, { prefix: '/api/payments' });

// Boot
const start = async () => {
  try {
    // MinIO bucket'larni avtomatik yaratish (mavjud bo'lsa skip)
    await ensureBuckets();

    await fastify.listen({ port: env.PORT, host: env.HOST });
    // Socket.io HTTP server'ga attach qilish — listen'dan keyin (fastify.server tayyor)
    initRealtime(fastify);
    fastify.log.info(`Backend ${env.HOST}:${env.PORT} da ishlaydi`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

// Sprint 6 P2 — graceful shutdown: SIGTERM/SIGINT da ulanishlarni drain qilamiz.
// H10 — socket.io ulanishlari uziladi + 10s safety timeout: systemd
// force-kill (timeout bilan) holatini oldini oladi.
const shutdown = async (signal: string): Promise<void> => {
  fastify.log.info(`${signal} qabul qilindi — graceful shutdown boshlandi`);
  const forceExit = setTimeout(() => {
    fastify.log.error('Shutdown 10s ichida tugamadi — majburan chiqish');
    process.exit(1);
  }, 10_000);
  forceExit.unref();
  try {
    closeRealtime();        // socket.io ulanishlarini uzadi (aks holda close osiladi)
    await fastify.close();  // yangi so'rovlarni to'xtatadi, mavjudlarini tugatadi
    await prisma.$disconnect();
    clearTimeout(forceExit);
    fastify.log.info('Graceful shutdown yakunlandi');
    process.exit(0);
  } catch (err) {
    clearTimeout(forceExit);
    fastify.log.error({ err }, 'Shutdown xatosi');
    process.exit(1);
  }
};
process.on('SIGTERM', () => void shutdown('SIGTERM'));
process.on('SIGINT', () => void shutdown('SIGINT'));

start();
