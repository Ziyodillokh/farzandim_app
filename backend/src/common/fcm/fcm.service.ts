import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import admin from 'firebase-admin';
import { PrismaService } from '../database/prisma.service';
import { EnvConfig } from '../config/env.schema';

export interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
  /**
   * `true` bo'lsa `notification` bloki yuborilmaydi — sof DATA xabar.
   * Bu Android'da ilova fonda/yopiq bo'lsa ham `onBackgroundMessage`
   * handlerini ishga tushiradi (masalan "ring" buyrug'i uchun zarur).
   */
  dataOnly?: boolean;
}

export interface PushResult {
  sent: number;
  failed: number;
  invalidTokens: string[];
}

@Injectable()
export class FcmService {
  private readonly logger = new Logger(FcmService.name);
  private initialized = false;
  private initFailed = false;

  constructor(
    private readonly config: ConfigService<EnvConfig, true>,
    private readonly prisma: PrismaService,
  ) {}

  private tryInit(): boolean {
    if (this.initialized) return true;
    if (this.initFailed) return false;

    const b64 = this.config.get('FIREBASE_SERVICE_ACCOUNT_BASE64', {
      infer: true,
    });
    if (!b64) {
      this.initFailed = true;
      return false;
    }

    try {
      const json = JSON.parse(Buffer.from(b64, 'base64').toString('utf8'));
      admin.initializeApp({
        credential: admin.credential.cert(json),
      });
      this.initialized = true;
      return true;
    } catch (err) {
      this.initFailed = true;
      this.logger.error('Failed to initialize firebase-admin', err);
      return false;
    }
  }

  /**
   * Send push notification to a list of FCM tokens.
   * Returns which tokens were invalid (UNREGISTERED / INVALID_ARGUMENT).
   */
  async sendPush(tokens: string[], payload: PushPayload): Promise<PushResult> {
    if (tokens.length === 0) {
      return { sent: 0, failed: 0, invalidTokens: [] };
    }

    if (!this.tryInit()) {
      this.logger.warn(
        'Push not sent - FIREBASE_SERVICE_ACCOUNT_BASE64 missing or invalid',
      );
      return { sent: 0, failed: tokens.length, invalidTokens: [] };
    }

    const message: admin.messaging.MulticastMessage = payload.dataOnly
      ? {
          tokens,
          data: payload.data,
          // ttl 60s — "ring/find device" real-time buyruq. Qurilma offline/Doze
          // bo'lsa FCM uni 60s'dan keyin tashlaydi (soatlardan keyin kutilmaganda
          // jiringlamasin). priority 'high' — Doze'dan uyg'otadi (load-bearing).
          android: { priority: 'high', ttl: 60_000 },
          apns: {
            headers: { 'apns-priority': '10', 'apns-expiration': '0' },
            payload: { aps: { 'content-available': 1 } },
          },
        }
      : {
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
   * Send push to all devices of a user, auto-cleaning invalid tokens.
   */
  async sendPushToUser(
    userId: string,
    payload: PushPayload,
  ): Promise<PushResult> {
    const tokenRows = await this.prisma.fcmToken.findMany({
      where: { userId },
      select: { token: true },
    });
    const tokens = tokenRows.map((r) => r.token);

    const result = await this.sendPush(tokens, payload);

    // Diagnostika (PII YO'Q — userId/ism/token qiymati log qilinmaydi).
    // `tokens=0`  → foydalanuvchida ro'yxatdan o'tgan token yo'q (registratsiya muammosi).
    // `sent=0,failed>0` → Firebase yubora olmadi (init xato yoki token yaroqsiz).
    // `sent>0`    → FCM'ga yetkazildi (telefon tomonda ko'rsatish/permission muammosi).
    this.logger.log(
      `push type=${payload.data?.type ?? (payload.dataOnly ? 'data' : 'notif')} ` +
        `tokens=${tokens.length} sent=${result.sent} ` +
        `failed=${result.failed} invalid=${result.invalidTokens.length}`,
    );

    if (result.invalidTokens.length > 0) {
      await this.prisma.fcmToken.deleteMany({
        where: { token: { in: result.invalidTokens } },
      });
    }

    return result;
  }
}
