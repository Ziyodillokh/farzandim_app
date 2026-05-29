import admin from 'firebase-admin';
import { env } from '../config/env';

// FCM proxy — backend Google FCM API'ga push forward qiladi.
// Service account JSON .env'da base64-encoded saqlanadi (FIREBASE_SERVICE_ACCOUNT_BASE64).
// Agar setup qilinmagan bo'lsa, sendPush warning log'ladi va silently no-op.

let initialized = false;
let initFailed = false;

function tryInit(): boolean {
  if (initialized) return true;
  if (initFailed) return false;

  const b64 = env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  if (!b64) {
    initFailed = true;
    return false;
  }

  try {
    const json = JSON.parse(Buffer.from(b64, 'base64').toString('utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(json),
    });
    initialized = true;
    return true;
  } catch (err) {
    initFailed = true;
    console.error('[fcm] Failed to initialize firebase-admin:', err);
    return false;
  }
}

export interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface PushResult {
  sent: number;
  failed: number;
  invalidTokens: string[];
}

/**
 * FCM token(lar)ga push yuborish.
 * `invalidTokens` — Google qaytargan UNREGISTERED yoki INVALID_ARGUMENT token'lar
 * (mobile app uninstall yoki token o'zgargan). Caller ularni DB'dan o'chirishi tavsiya etiladi.
 */
export async function sendPush(
  tokens: string[],
  payload: PushPayload,
): Promise<PushResult> {
  if (tokens.length === 0) {
    return { sent: 0, failed: 0, invalidTokens: [] };
  }

  if (!tryInit()) {
    console.warn('[fcm] Push not sent — FIREBASE_SERVICE_ACCOUNT_BASE64 yo\'q yoki noto\'g\'ri');
    return { sent: 0, failed: tokens.length, invalidTokens: [] };
  }

  const message: admin.messaging.MulticastMessage = {
    tokens,
    notification: { title: payload.title, body: payload.body },
    data: payload.data,
    android: { priority: 'high' },
    apns: { payload: { aps: { sound: 'default' } } },
  };

  const response = await admin.messaging().sendEachForMulticast(message);

  const invalidTokens: string[] = [];
  response.responses.forEach((r, idx) => {
    if (!r.success && r.error) {
      const code = r.error.code;
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token' ||
        code === 'messaging/invalid-argument'
      ) {
        invalidTokens.push(tokens[idx]);
      }
    }
  });

  return {
    sent: response.successCount,
    failed: response.failureCount,
    invalidTokens,
  };
}

/**
 * Bitta foydalanuvchining barcha tokenlariga push yuborish + invalid'larni avtomatik tozalash.
 * `prisma` parametr — caller PrismaClient'ni uzatadi (circular import oldini olish uchun).
 */
export async function sendPushToUser(
  prismaClient: typeof import('./prisma').prisma,
  userId: string,
  payload: PushPayload,
): Promise<PushResult> {
  const tokenRows = await prismaClient.fcmToken.findMany({
    where: { userId },
    select: { token: true },
  });
  const tokens = tokenRows.map((r) => r.token);

  const result = await sendPush(tokens, payload);

  if (result.invalidTokens.length > 0) {
    await prismaClient.fcmToken.deleteMany({
      where: { token: { in: result.invalidTokens } },
    });
  }

  return result;
}
