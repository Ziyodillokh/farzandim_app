// E2E soxta tashqi xizmatlar: FCM yuborilgan pushlarni yozib boradi,
// MinIO esa hech qayerga ulanmaydi.

import type { PrismaService } from '../../src/common/database/prisma.service';
import type {
  PushPayload,
  PushResult,
} from '../../src/common/fcm/fcm.service';
import {
  NotifLang,
  toNotifLang,
} from '../../src/common/i18n/notification-i18n';

export interface SentPush {
  userId?: string;
  tokens?: string[];
  payload: PushPayload;
}

export class FakeFcm {
  readonly sent: SentPush[] = [];
  private prisma?: PrismaService;

  attachPrisma(prisma: PrismaService): void {
    this.prisma = prisma;
  }

  reset(): void {
    this.sent.length = 0;
  }

  async sendPush(tokens: string[], payload: PushPayload): Promise<PushResult> {
    this.sent.push({ tokens, payload });
    return { sent: tokens.length, failed: 0, invalidTokens: [] };
  }

  async sendPushToUser(
    userId: string,
    payload: PushPayload,
  ): Promise<PushResult> {
    this.sent.push({ userId, payload });
    return { sent: 1, failed: 0, invalidTokens: [] };
  }

  async pushChildResync(): Promise<void> {}

  async getUserLang(userId: string): Promise<NotifLang> {
    const user = await this.prisma?.user.findUnique({
      where: { id: userId },
      select: { language: true },
    });
    return toNotifLang(user?.language);
  }

  pushesTo(userId: string): PushPayload[] {
    return this.sent.filter((p) => p.userId === userId).map((p) => p.payload);
  }
}

export function fakeStorage(): Record<string, unknown> {
  const noop = async () => undefined;
  return {
    onModuleInit: noop,
    ensureBuckets: noop,
    upload: noop,
    delete: noop,
    getSignedUrl: async () => 'http://127.0.0.1:9/signed',
    getObject: async () => Buffer.alloc(0),
    getObjectStream: noop,
  };
}
