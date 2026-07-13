import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  PayloadTooLargeException,
  UnsupportedMediaTypeException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../common/database/prisma.service';
import { FcmService, PushPayload } from '../../common/fcm/fcm.service';
import { AdminAuditService } from '../../common/audit/admin-audit.service';
import { StorageService } from '../../common/storage/storage.service';
import { BUCKETS } from '../../common/storage/storage.constants';
import { CreateNotificationDto } from './dto/create-notification.dto';

const MAX_NOTIF_IMAGE_BYTES = 5 * 1024 * 1024;
const ALLOWED_IMAGE_MIMES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
];
const SIX_DAYS_SEC = 6 * 86_400;

const TARGET_TYPES = ['all', 'parents', 'children', 'premium', 'age_group'] as const;
const STATUSES = ['sent', 'scheduled', 'queued', 'sending', 'failed'] as const;
const FCM_BATCH_SIZE = 500;

interface RequestMeta {
  ip?: string;
  headers?: Record<string, string | string[] | undefined>;
}

@Injectable()
export class AdminNotificationsService {
  private readonly logger = new Logger(AdminNotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmService,
    private readonly audit: AdminAuditService,
    private readonly storage: StorageService,
  ) {}

  /**
   * Port of Fastify `POST /upload-image` handler. Validates size + mime, uploads
   * to MinIO `contentThumbnails` bucket, and returns a 6-day signed URL.
   */
  async uploadImage(file: {
    buffer: Buffer;
    mimetype: string;
    originalname: string;
  }): Promise<{
    url: string;
    storageKey: string;
    bucket: string;
    sizeBytes: number;
  }> {
    if (!file.buffer) {
      throw new BadRequestException('file field required');
    }
    if (file.buffer.length > MAX_NOTIF_IMAGE_BYTES) {
      throw new PayloadTooLargeException({
        error: 'Image too large',
        max: MAX_NOTIF_IMAGE_BYTES,
      });
    }
    if (!ALLOWED_IMAGE_MIMES.includes(file.mimetype)) {
      throw new UnsupportedMediaTypeException({
        error: 'Unsupported image format',
        mimetype: file.mimetype,
      });
    }
    const ext = file.originalname.includes('.')
      ? '.' + file.originalname.split('.').pop()
      : '.jpg';
    const key = `notifications/${randomUUID()}${ext}`;
    try {
      await this.storage.upload(
        BUCKETS.contentThumbnails,
        key,
        file.buffer,
        file.mimetype,
      );
    } catch (err) {
      this.logger.error(
        `notification upload-image: MinIO failed: ${(err as Error).message}`,
      );
      throw err;
    }
    const url = await this.storage.getSignedUrl(
      BUCKETS.contentThumbnails,
      key,
      SIX_DAYS_SEC,
    );
    return {
      url,
      storageKey: key,
      bucket: BUCKETS.contentThumbnails,
      sizeBytes: file.buffer.length,
    };
  }

  /**
   * Resolve target audience to Child id list (used for per-child in-app inbox
   * inserts so children also see the notification in-app).
   */
  private async resolveTargetChildIds(
    target: string,
    filters?: { ageFrom?: number; ageTo?: number },
  ): Promise<string[]> {
    if (target === 'age_group') {
      const af = filters?.ageFrom ?? 0;
      const at = filters?.ageTo ?? 25;
      const children = await this.prisma.child.findMany({
        where: { age: { gte: af, lte: at } },
        select: { id: true },
      });
      return children.map((c) => c.id);
    }
    if (target === 'premium') {
      const payments = await this.prisma.payment.findMany({
        where: { status: 'success', userId: { not: null } },
        select: { userId: true },
        distinct: ['userId'],
      });
      const parentIds = payments.map((p) => p.userId!).filter(Boolean);
      const children = await this.prisma.child.findMany({
        where: { parentId: { in: parentIds } },
        select: { id: true },
      });
      return children.map((c) => c.id);
    }
    const children = await this.prisma.child.findMany({
      select: { id: true },
    });
    return children.map((c) => c.id);
  }

  private rowOf(n: any) {
    const delivered = n.deliveredCount ?? 0;
    const opened = n.openedCount ?? 0;
    const clicked = n.clickedCount ?? 0;
    const openRate = delivered > 0 ? Number(((opened / delivered) * 100).toFixed(1)) : 0;
    const ctr = opened > 0 ? Number(((clicked / opened) * 100).toFixed(1)) : 0;
    return {
      id: n.id,
      title: n.title,
      message: n.message,
      targetType: n.targetType,
      filters: n.filters ?? {},
      imageUrl: n.imageUrl,
      deepLink: n.deepLink,
      status: n.status,
      scheduledAt: n.scheduledAt?.toISOString() ?? null,
      sentAt: n.sentAt?.toISOString() ?? null,
      deliveredCount: delivered,
      openedCount: opened,
      clickedCount: clicked,
      openRate,
      ctr,
      metrics: { delivered, opened, clicked, openRate, ctr },
      createdAt: n.createdAt.toISOString(),
      updatedAt: n.updatedAt.toISOString(),
    };
  }

  private async resolveTargetUserIds(target: string, filters?: any): Promise<string[]> {
    if (target === 'parents') {
      const rows = await this.prisma.user.findMany({ where: { role: 'PARENT' }, select: { id: true } });
      return rows.map((u) => u.id);
    }
    if (target === 'children') {
      const rows = await this.prisma.user.findMany({ where: { role: 'CHILD' }, select: { id: true } });
      return rows.map((u) => u.id);
    }
    if (target === 'premium') {
      const payments = await this.prisma.payment.findMany({
        where: { status: 'success', userId: { not: null } },
        select: { userId: true },
        distinct: ['userId'],
      });
      return payments.map((p) => p.userId!).filter(Boolean);
    }
    if (target === 'age_group') {
      const af = filters?.ageFrom ?? 0;
      const at = filters?.ageTo ?? 18;
      const children = await this.prisma.child.findMany({
        where: { age: { gte: af, lte: at }, childUserId: { not: null } },
        select: { childUserId: true },
      });
      return children.map((c) => c.childUserId!).filter(Boolean);
    }
    const [parents, children] = await Promise.all([
      this.prisma.user.findMany({ where: { role: 'PARENT' }, select: { id: true } }),
      this.prisma.user.findMany({ where: { role: 'CHILD' }, select: { id: true } }),
    ]);
    return [...parents.map((u) => u.id), ...children.map((u) => u.id)];
  }

  private async broadcastToAudience(target: string, filters: any, payload: PushPayload) {
    const userIds = await this.resolveTargetUserIds(target, filters);
    if (userIds.length === 0) return { delivered: 0, failed: 0, invalidTokensCleaned: 0 };

    const tokenRows = await this.prisma.fcmToken.findMany({
      where: { userId: { in: userIds } },
      select: { token: true },
    });
    const tokens = tokenRows.map((r) => r.token);
    if (tokens.length === 0) return { delivered: 0, failed: 0, invalidTokensCleaned: 0 };

    let totalDelivered = 0;
    let totalFailed = 0;
    const allInvalid: string[] = [];

    for (let i = 0; i < tokens.length; i += FCM_BATCH_SIZE) {
      const batch = tokens.slice(i, i + FCM_BATCH_SIZE);
      try {
        const result = await this.fcm.sendPush(batch, payload);
        totalDelivered += result.sent;
        totalFailed += result.failed;
        allInvalid.push(...result.invalidTokens);
      } catch {
        totalFailed += batch.length;
      }
    }

    let invalidCleaned = 0;
    if (allInvalid.length > 0) {
      const r = await this.prisma.fcmToken.deleteMany({ where: { token: { in: allInvalid } } });
      invalidCleaned = r.count;
    }

    return { delivered: totalDelivered, failed: totalFailed, invalidTokensCleaned: invalidCleaned };
  }

  async list(query: { q?: string; status?: string; audience?: string; from?: string; to?: string }) {
    const where: Prisma.AdminNotificationWhereInput = {};
    if (query.status && (STATUSES as readonly string[]).includes(query.status))
      where.status = query.status;
    if (query.audience && (TARGET_TYPES as readonly string[]).includes(query.audience))
      where.targetType = query.audience;
    if (query.q && query.q.trim().length > 0) {
      where.OR = [
        { title: { contains: query.q.trim(), mode: 'insensitive' } },
        { message: { contains: query.q.trim(), mode: 'insensitive' } },
      ];
    }
    if (query.from || query.to) {
      where.createdAt = {};
      if (query.from) where.createdAt.gte = new Date(query.from);
      if (query.to) where.createdAt.lte = new Date(query.to);
    }
    const rows = await this.prisma.adminNotification.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }],
      take: 200,
    });
    return rows.map((r) => this.rowOf(r));
  }

  async findOne(id: string) {
    const n = await this.prisma.adminNotification.findUnique({ where: { id } });
    if (!n) throw new NotFoundException('Notification not found');
    return { ...this.rowOf(n) };
  }

  async create(dto: CreateNotificationDto, staffId: string | undefined, req: RequestMeta) {
    const scheduled = dto.scheduledAt ? new Date(dto.scheduledAt) : null;
    const willSchedule = scheduled !== null && scheduled.getTime() > Date.now();

    let deliveredCount = 0;
    if (!willSchedule) {
      const result = await this.broadcastToAudience(
        dto.targetType,
        dto.filters,
        {
          title: dto.title,
          body: dto.message,
          image: dto.imageUrl ?? undefined,
          data: dto.deepLink ? { deepLink: dto.deepLink } : undefined,
        },
      );
      deliveredCount = result.delivered;
    }

    const created = await this.prisma.adminNotification.create({
      data: {
        title: dto.title,
        message: dto.message,
        targetType: dto.targetType,
        filters: (dto.filters ?? {}) as Prisma.InputJsonValue,
        imageUrl: dto.imageUrl ?? null,
        deepLink: dto.deepLink ?? null,
        status: willSchedule ? 'scheduled' : 'sent',
        scheduledAt: scheduled,
        sentAt: willSchedule ? null : new Date(),
        deliveredCount,
        openedCount: 0,
        clickedCount: 0,
        createdById: staffId ?? null,
      },
    });

    if (!willSchedule) {
      // Per-Child Notification rows for the in-app inbox.
      try {
        const childIds = await this.resolveTargetChildIds(
          dto.targetType,
          dto.filters as { ageFrom?: number; ageTo?: number } | undefined,
        );
        if (childIds.length > 0) {
          await this.prisma.notification.createMany({
            data: childIds.map((childId) => ({
              childId,
              adminNotificationId: created.id,
              type: 'SYSTEM' as const,
              title: dto.title,
              body: dto.message,
              // In-app inbox: rasm (imageUrl) + deepLink saqlaymiz — bola/ota-ona
              // ilova ichida xabar ustiga bosganda rasm ko'rinsin.
              data:
                dto.imageUrl || dto.deepLink
                  ? ({
                      ...(dto.imageUrl ? { imageUrl: dto.imageUrl } : {}),
                      ...(dto.deepLink ? { deepLink: dto.deepLink } : {}),
                    } as Prisma.InputJsonValue)
                  : Prisma.JsonNull,
            })),
          });
        }
      } catch (err) {
        this.logger.warn(
          `in-app inbox insert failed: ${(err as Error).message}`,
        );
      }
    }

    void this.audit.log(req, {
      action: willSchedule ? 'notification.schedule' : 'notification.send',
      moderatorId: staffId,
      resourceType: 'admin_notification',
      resourceId: created.id,
      details: { target: dto.targetType, delivered: deliveredCount },
    });

    return this.rowOf(created);
  }

  /**
   * GET /admin/notifications/history — latest 50 (synonym for list, no filters).
   */
  async history() {
    const rows = await this.prisma.adminNotification.findMany({
      orderBy: [{ createdAt: 'desc' }],
      take: 50,
    });
    return rows.map((r) => this.rowOf(r));
  }

  /**
   * Top stat cards: today sent, deliveryRate, openRate, totals.
   */
  async stats() {
    const now = new Date();
    const todayStart = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
    );

    const [todaySentAgg, allSentAgg, totalCount, todayCount] =
      await Promise.all([
        this.prisma.adminNotification.aggregate({
          where: { status: 'sent', sentAt: { gte: todayStart } },
          _sum: {
            deliveredCount: true,
            openedCount: true,
            clickedCount: true,
          },
        }),
        this.prisma.adminNotification.aggregate({
          where: { status: 'sent' },
          _sum: {
            deliveredCount: true,
            openedCount: true,
            clickedCount: true,
          },
        }),
        this.prisma.adminNotification.count(),
        this.prisma.adminNotification.count({
          where: { status: 'sent', sentAt: { gte: todayStart } },
        }),
      ]);

    const todayDelivered = todaySentAgg._sum.deliveredCount ?? 0;
    const allDelivered = allSentAgg._sum.deliveredCount ?? 0;
    const allOpened = allSentAgg._sum.openedCount ?? 0;
    const allClicked = allSentAgg._sum.clickedCount ?? 0;

    const deliveryRate =
      allDelivered > 0
        ? Number(((allDelivered / Math.max(allDelivered, 1)) * 100).toFixed(1))
        : 0;
    const openRate =
      allDelivered > 0
        ? Number(((allOpened / allDelivered) * 100).toFixed(1))
        : 0;
    const ctr =
      allOpened > 0
        ? Number(((allClicked / allOpened) * 100).toFixed(1))
        : 0;

    return {
      todaySent: todayDelivered,
      todayCount,
      deliveryRate,
      openRate,
      ctr,
      totalNotifications: totalCount,
      totalDelivered: allDelivered,
      totalOpened: allOpened,
      totalClicked: allClicked,
    };
  }

  /**
   * AI suggestion stub — canned templates for the admin UI.
   */
  aiGenerate() {
    const now = new Date();
    const inHours = (h: number) =>
      new Date(now.getTime() + h * 3_600_000).toISOString();
    return {
      suggestions: [
        {
          title: 'Yangi audiokitob: Sarguzashtlar kutmoqda',
          message:
            'Hozir tinglang — yangi sarguzasht audiokitobi yuklandi. Bolangiz albatta yoqtiradi.',
          targetType: 'all',
          suggestedSendTime: inHours(2),
        },
        {
          title:
            "Tanlov haqida ogohlantirish: Ajoyib sovg'alarni yutib oling",
          message:
            "Yangi konkurs ochildi — eng ko'p ball to'plagan farzandlar sovg'a oladi.",
          targetType: 'premium',
          suggestedSendTime: inHours(6),
        },
        {
          title: 'Yangilangan dastur: Harakatlanuvchi interfeys bilan',
          message:
            'Yangi versiya 2.0 tayyor — yangi dizayn va tezroq tezlik. Hozir yangilang.',
          targetType: 'parents',
          suggestedSendTime: inHours(12),
        },
        {
          title: 'Maxsus taklif: Xarid qiling va bonuslar oling',
          message:
            "Bir oylik tarif sotib oling — 1 oylik bepul kuni qo'shamiz.",
          targetType: 'parents',
          suggestedSendTime: inHours(24),
        },
      ],
    };
  }

  /**
   * GET /admin/notifications/:id — detail with synthetic engagement curve.
   */
  async findOneWithEngagement(id: string) {
    const n = await this.prisma.adminNotification.findUnique({ where: { id } });
    if (!n) throw new NotFoundException('Notification not found');

    const total = n.deliveredCount;
    const peakSlot = 6; // ~18:00
    const engagement = Array.from({ length: 9 }, (_, i) => {
      const t = i * 3;
      const distance = Math.abs(i - peakSlot);
      const factor = Math.max(0, 1 - distance / 9);
      return {
        time: `${String(t).padStart(2, '0')}:00`,
        count: Math.round(total * factor * 0.35),
      };
    });

    return { ...this.rowOf(n), engagement };
  }

  /**
   * DELETE /admin/notifications/:id — also deletes in-app per-child copies.
   */
  async remove(id: string, staffId: string | undefined, req: RequestMeta) {
    const existing = await this.prisma.adminNotification.findUnique({
      where: { id },
    });
    if (!existing) throw new NotFoundException('Notification not found');

    // Remove per-child in-app copies that this broadcast created.
    const inApp = await this.prisma.notification.deleteMany({
      where: {
        type: 'SYSTEM',
        title: existing.title,
        body: existing.message,
      },
    });

    await this.prisma.adminNotification.delete({ where: { id } });

    void this.audit.log(req, {
      action: 'notification.delete',
      moderatorId: staffId,
      resourceType: 'admin_notification',
      resourceId: id,
      details: { inAppRowsRemoved: inApp.count },
    });

    return { success: true, inAppRowsRemoved: inApp.count };
  }
}
