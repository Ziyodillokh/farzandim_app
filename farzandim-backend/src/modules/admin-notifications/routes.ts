import { FastifyPluginAsync } from 'fastify';
import multipart from '@fastify/multipart';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { randomUUID } from 'crypto';
import { prisma } from '../../lib/prisma';
import { staffAuthGuard } from '../../middleware/staff-auth';
import { requirePermission } from '../../middleware/require-permission';
import { sendPush, type PushPayload } from '../../lib/fcm';
import { logAudit } from '../../lib/audit-log';
import { BUCKETS, uploadFile, getDownloadUrl } from '../../lib/minio';
import { ALLOWED_IMAGE_MIMES } from '../../lib/admin-content-upload';

const MAX_NOTIF_IMAGE_BYTES = 5 * 1024 * 1024; // 5 MB

const TARGET_TYPES = ['all', 'parents', 'children', 'premium', 'age_group'] as const;
const STATUSES = ['sent', 'scheduled', 'queued', 'sending', 'failed'] as const;

const FiltersSchema = z
  .object({
    activeOnly: z.boolean().optional(),
    premiumOnly: z.boolean().optional(),
    ageFrom: z.coerce.number().int().min(0).max(25).optional(),
    ageTo: z.coerce.number().int().min(0).max(25).optional(),
  })
  .partial()
  .optional();

const CreateBody = z.object({
  title: z.string().trim().min(1).max(120),
  message: z.string().trim().min(1).max(500),
  targetType: z.enum(TARGET_TYPES),
  filters: FiltersSchema,
  imageUrl: z.union([z.string().url(), z.null()]).optional(),
  deepLink: z.union([z.string().trim().max(500), z.null()]).optional(),
  scheduledAt: z.union([z.string().datetime(), z.null()]).optional(),
});

const SimpleSendBody = z.object({
  title: z.string().trim().min(1),
  message: z.string().trim().min(1),
  target: z.enum(TARGET_TYPES),
});

const ScheduleBody = SimpleSendBody.extend({
  scheduledAt: z.string().datetime(),
});

const ListQuery = z.object({
  q: z.string().trim().optional(),
  status: z.string().trim().optional(),
  audience: z.string().trim().optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

interface AdminNotificationRow {
  id: string;
  title: string;
  message: string;
  targetType: string;
  filters: Prisma.JsonValue;
  imageUrl: string | null;
  deepLink: string | null;
  status: string;
  scheduledAt: Date | null;
  sentAt: Date | null;
  deliveredCount: number;
  openedCount: number;
  clickedCount: number;
  createdAt: Date;
  updatedAt: Date;
}

function rowOf(n: AdminNotificationRow) {
  const delivered = n.deliveredCount;
  const opened = n.openedCount;
  const clicked = n.clickedCount;
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

/**
 * Audience size estimator. Hozirgi DB'da real foydalanuvchilar soni juda
 * kichik (5), shuning uchun delivered/opened/clicked sintetik. Real bulk
 * push fan-out keyingi sprint'da (Sprint 5.4+).
 */
async function estimateAudienceSize(target: string): Promise<number> {
  if (target === 'parents') {
    return prisma.user.count({ where: { role: 'PARENT' } });
  }
  if (target === 'children') {
    return prisma.child.count();
  }
  if (target === 'premium') {
    return prisma.user.count({ where: { role: 'PARENT', isActive: true } });
  }
  // 'all', 'age_group' → all parents + children
  const [p, c] = await Promise.all([
    prisma.user.count({ where: { role: 'PARENT' } }),
    prisma.child.count(),
  ]);
  return p + c;
}

function syntheticMetrics(size: number) {
  if (size === 0) return { delivered: 0, opened: 0, clicked: 0 };
  const delivered = Math.max(0, Math.round(size * 0.97));
  const opened = Math.max(0, Math.round(delivered * (0.45 + Math.random() * 0.3)));
  const clicked = Math.max(0, Math.round(opened * (0.18 + Math.random() * 0.2)));
  return { delivered, opened, clicked };
}

// Sprint 5.x — real FCM bulk push.
// Auidence → user IDs → FCM tokens → batch (500/multicast) → sendPush.

const FCM_BATCH_SIZE = 500; // firebase-admin sendEachForMulticast hard cap

/**
 * Sprint 5.x — Audience → Child id ro'yxati. Per-Child `Notification`
 * rowlari yaratish uchun ishlatiladi (in-app inbox uchun).
 *
 * Eslatma: `parents`, `children`, `all` auditoriyalarining barchasida
 * Child rowlari qaytariladi (parent app ham per-child ko'radi).
 */
async function resolveTargetChildIds(
  target: string,
  filters?: { ageFrom?: number; ageTo?: number },
): Promise<string[]> {
  if (target === 'age_group') {
    const af = filters?.ageFrom ?? 0;
    const at = filters?.ageTo ?? 25;
    const children = await prisma.child.findMany({
      where: { age: { gte: af, lte: at } },
      select: { id: true },
    });
    return children.map((c) => c.id);
  }
  if (target === 'premium') {
    const payments = await prisma.payment.findMany({
      where: { status: 'success', userId: { not: null } },
      select: { userId: true },
      distinct: ['userId'],
    });
    const parentIds = payments.map((p) => p.userId!).filter(Boolean);
    const children = await prisma.child.findMany({
      where: { parentId: { in: parentIds } },
      select: { id: true },
    });
    return children.map((c) => c.id);
  }
  // 'all' | 'parents' | 'children' — barchasi: barcha child rowlari
  const children = await prisma.child.findMany({ select: { id: true } });
  return children.map((c) => c.id);
}

async function resolveTargetUserIds(
  target: string,
  filters?: { ageFrom?: number; ageTo?: number; activeOnly?: boolean; premiumOnly?: boolean },
): Promise<string[]> {
  if (target === 'parents') {
    const rows = await prisma.user.findMany({ where: { role: 'PARENT' }, select: { id: true } });
    return rows.map((u) => u.id);
  }
  if (target === 'children') {
    const rows = await prisma.user.findMany({ where: { role: 'CHILD' }, select: { id: true } });
    return rows.map((u) => u.id);
  }
  if (target === 'premium') {
    // Subscription modeli yo'q — Payment.status='success' bo'lgan parent'larni olamiz
    const payments = await prisma.payment.findMany({
      where: { status: 'success', userId: { not: null } },
      select: { userId: true },
      distinct: ['userId'],
    });
    return payments.map((p) => p.userId!).filter(Boolean);
  }
  if (target === 'age_group') {
    const af = filters?.ageFrom ?? 0;
    const at = filters?.ageTo ?? 18;
    const children = await prisma.child.findMany({
      where: { age: { gte: af, lte: at }, childUserId: { not: null } },
      select: { childUserId: true },
    });
    return children.map((c) => c.childUserId!).filter(Boolean);
  }
  // 'all' → parents + children
  const [parents, children] = await Promise.all([
    prisma.user.findMany({ where: { role: 'PARENT' }, select: { id: true } }),
    prisma.user.findMany({ where: { role: 'CHILD' }, select: { id: true } }),
  ]);
  return [...parents.map((u) => u.id), ...children.map((u) => u.id)];
}

interface BulkPushResult {
  attempted: number;
  delivered: number;
  failed: number;
  invalidTokensCleaned: number;
}

async function broadcastToAudience(
  target: string,
  filters: { ageFrom?: number; ageTo?: number; activeOnly?: boolean; premiumOnly?: boolean } | undefined,
  payload: PushPayload,
): Promise<BulkPushResult> {
  const userIds = await resolveTargetUserIds(target, filters);
  if (userIds.length === 0) {
    return { attempted: 0, delivered: 0, failed: 0, invalidTokensCleaned: 0 };
  }

  const tokenRows = await prisma.fcmToken.findMany({
    where: { userId: { in: userIds } },
    select: { token: true },
  });
  const tokens = tokenRows.map((r) => r.token);
  if (tokens.length === 0) {
    return { attempted: 0, delivered: 0, failed: 0, invalidTokensCleaned: 0 };
  }

  let totalDelivered = 0;
  let totalFailed = 0;
  const allInvalid: string[] = [];

  for (let i = 0; i < tokens.length; i += FCM_BATCH_SIZE) {
    const batch = tokens.slice(i, i + FCM_BATCH_SIZE);
    try {
      const result = await sendPush(batch, payload);
      totalDelivered += result.sent;
      totalFailed += result.failed;
      allInvalid.push(...result.invalidTokens);
    } catch (err) {
      // Batch chunki bir butun muvaffaqiyatsiz bo'lsa, hammasi failed deb hisoblaymiz.
      totalFailed += batch.length;
      console.warn('[admin-notifications] batch sendPush failed:', (err as Error).message);
    }
  }

  // Invalid tokenlarni auto-cleanup
  let invalidCleaned = 0;
  if (allInvalid.length > 0) {
    const r = await prisma.fcmToken.deleteMany({ where: { token: { in: allInvalid } } });
    invalidCleaned = r.count;
  }

  return {
    attempted: tokens.length,
    delivered: totalDelivered,
    failed: totalFailed,
    invalidTokensCleaned: invalidCleaned,
  };
}

async function createBroadcast(
  payload: z.infer<typeof CreateBody>,
  staffId: string | undefined,
) {
  const scheduled = payload.scheduledAt ? new Date(payload.scheduledAt) : null;
  const willSchedule = scheduled !== null && scheduled.getTime() > Date.now();

  let deliveredCount = 0;
  let failedCount = 0;
  let invalidCleaned = 0;
  const status = willSchedule ? 'scheduled' : 'sent';

  if (!willSchedule) {
    // Sprint 5.x — REAL FCM fan-out (system tray push)
    const result = await broadcastToAudience(
      payload.targetType,
      payload.filters as { ageFrom?: number; ageTo?: number } | undefined,
      {
        title: payload.title,
        body: payload.message,
        data: payload.deepLink ? { deepLink: payload.deepLink } : undefined,
      },
    );
    deliveredCount = result.delivered;
    failedCount = result.failed;
    invalidCleaned = result.invalidTokensCleaned;
  }

  const created = await prisma.adminNotification.create({
    data: {
      title: payload.title,
      message: payload.message,
      targetType: payload.targetType,
      filters: (payload.filters ?? {}) as Prisma.InputJsonValue,
      imageUrl: payload.imageUrl ?? null,
      deepLink: payload.deepLink ?? null,
      status,
      scheduledAt: scheduled,
      sentAt: willSchedule ? null : new Date(),
      deliveredCount,
      openedCount: 0, // Sprint 6 P2 — real tracking: read event'da increment
      clickedCount: 0, // Sprint 6 P2 — real tracking: click event'da increment
      createdById: staffId ?? null,
    },
  });

  if (!willSchedule) {
    // Sprint 5.x — per-Child `Notification` rowlari (in-app inbox uchun).
    // adminNotificationId bilan bog'lanadi — open/click tracking uchun.
    try {
      const childIds = await resolveTargetChildIds(
        payload.targetType,
        payload.filters as { ageFrom?: number; ageTo?: number } | undefined,
      );
      if (childIds.length > 0) {
        await prisma.notification.createMany({
          data: childIds.map((childId) => ({
            childId,
            adminNotificationId: created.id,
            type: 'SYSTEM' as const,
            title: payload.title,
            body: payload.message,
            data: payload.deepLink
              ? ({ deepLink: payload.deepLink } as Prisma.InputJsonValue)
              : Prisma.JsonNull,
          })),
        });
      }
    } catch (err) {
      // Per-child insert silent-fail — FCM push allaqachon yuborilgan.
      console.warn('[admin-notifications] in-app inbox insert failed:', (err as Error).message);
    }

    console.log(
      `[admin-notifications] broadcast ${created.id}: delivered=${deliveredCount}, failed=${failedCount}, invalidCleaned=${invalidCleaned}`,
    );
  }

  return created;
}

export const adminNotificationsRoutes: FastifyPluginAsync = async (fastify) => {
  // Sprint 6 — RBAC: butun modul auth + permission tekshiruvidan o'tadi.
  fastify.addHook('preHandler', staffAuthGuard);
  fastify.addHook('preHandler', requirePermission('send_notifications'));

  // Sprint 5.x — notification rasm uchun multipart upload.
  await fastify.register(multipart, {
    limits: { fileSize: MAX_NOTIF_IMAGE_BYTES, files: 1 },
  });

  /**
   * POST /api/admin/notifications/upload-image
   * Bitta `file` (jpg/png/webp/gif, maks 5 MB) — MinIO content-thumbs
   * bucket'iga yuklaydi va signed URL qaytaradi. Frontend qaytgan URL'ni
   * notification create body'sida `imageUrl` sifatida ishlatadi.
   */
  fastify.post('/upload-image', { preHandler: staffAuthGuard }, async (request, reply) => {
    if (!request.isMultipart()) {
      return reply.code(400).send({ error: 'multipart/form-data required' });
    }
    let buf: Buffer | null = null;
    let filename = 'image.jpg';
    let mime = 'image/jpeg';
    try {
      for await (const part of request.parts()) {
        if (part.type === 'file' && part.fieldname === 'file') {
          buf = await part.toBuffer();
          filename = part.filename;
          mime = part.mimetype;
        }
      }
    } catch (err) {
      fastify.log.warn({ err }, 'notification upload-image: parts failed');
      return reply.code(400).send({ error: 'Failed to parse multipart' });
    }
    if (!buf) return reply.code(400).send({ error: 'file field required' });
    if (buf.length > MAX_NOTIF_IMAGE_BYTES) {
      return reply.code(413).send({ error: 'Image too large', max: MAX_NOTIF_IMAGE_BYTES });
    }
    if (!ALLOWED_IMAGE_MIMES.includes(mime)) {
      return reply.code(415).send({ error: 'Unsupported image format', mimetype: mime });
    }
    const ext = filename.includes('.') ? '.' + filename.split('.').pop() : '.jpg';
    const key = `notifications/${randomUUID()}${ext}`;
    try {
      await uploadFile(BUCKETS.contentThumbnails, key, buf, mime);
    } catch (err) {
      fastify.log.error({ err }, 'notification upload-image: MinIO failed');
      return reply.code(500).send({ error: 'Storage upload failed' });
    }
    const url = await getDownloadUrl(BUCKETS.contentThumbnails, key, 6 * 86_400);
    return reply.send({
      url,
      storageKey: key,
      bucket: BUCKETS.contentThumbnails,
      sizeBytes: buf.length,
    });
  });

  // ────────────────────────────────────────────────────────────────
  // List + filters
  // GET /api/admin/notifications?q=&status=&audience=&from=&to=
  // ────────────────────────────────────────────────────────────────
  fastify.get('/', { preHandler: staffAuthGuard }, async (request, reply) => {
    const parsed = ListQuery.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid query', details: parsed.error.flatten() });
    }
    const { q, status, audience, from, to } = parsed.data;

    const where: Prisma.AdminNotificationWhereInput = {};
    if (status && (STATUSES as readonly string[]).includes(status)) where.status = status;
    if (audience && (TARGET_TYPES as readonly string[]).includes(audience)) where.targetType = audience;
    if (q && q.trim().length > 0) {
      where.OR = [
        { title: { contains: q.trim(), mode: 'insensitive' } },
        { message: { contains: q.trim(), mode: 'insensitive' } },
      ];
    }
    if (from || to) {
      where.createdAt = {};
      if (from) where.createdAt.gte = new Date(from);
      if (to) where.createdAt.lte = new Date(to);
    }

    const rows = await prisma.adminNotification.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }],
      take: 200,
    });
    return reply.send(rows.map(rowOf));
  });

  // ────────────────────────────────────────────────────────────────
  // History (synonym for list, returns array — used by Bildirishnomalar tarixi widget)
  // ────────────────────────────────────────────────────────────────
  fastify.get('/history', { preHandler: staffAuthGuard }, async (_request, reply) => {
    const rows = await prisma.adminNotification.findMany({
      orderBy: [{ createdAt: 'desc' }],
      take: 50,
    });
    return reply.send(rows.map(rowOf));
  });

  // ────────────────────────────────────────────────────────────────
  // Top stat cards: bugungi yuborilgan, deliveryRate, openRate, jami
  // ────────────────────────────────────────────────────────────────
  fastify.get('/stats', { preHandler: staffAuthGuard }, async (_request, reply) => {
    const now = new Date();
    const todayStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));

    const [todaySentAgg, allSentAgg, totalCount, todayCount] = await Promise.all([
      prisma.adminNotification.aggregate({
        where: { status: 'sent', sentAt: { gte: todayStart } },
        _sum: { deliveredCount: true, openedCount: true, clickedCount: true },
      }),
      prisma.adminNotification.aggregate({
        where: { status: 'sent' },
        _sum: { deliveredCount: true, openedCount: true, clickedCount: true },
      }),
      prisma.adminNotification.count(),
      prisma.adminNotification.count({
        where: { status: 'sent', sentAt: { gte: todayStart } },
      }),
    ]);

    const todayDelivered = todaySentAgg._sum.deliveredCount ?? 0;
    const allDelivered = allSentAgg._sum.deliveredCount ?? 0;
    const allOpened = allSentAgg._sum.openedCount ?? 0;
    const allClicked = allSentAgg._sum.clickedCount ?? 0;

    const deliveryRate = allDelivered > 0 ? Number(((allDelivered / Math.max(allDelivered, 1)) * 100).toFixed(1)) : 0;
    const openRate = allDelivered > 0 ? Number(((allOpened / allDelivered) * 100).toFixed(1)) : 0;
    const ctr = allOpened > 0 ? Number(((allClicked / allOpened) * 100).toFixed(1)) : 0;

    return reply.send({
      todaySent: todayDelivered,
      todayCount,
      deliveryRate,
      openRate,
      ctr,
      totalNotifications: totalCount,
      totalDelivered: allDelivered,
      totalOpened: allOpened,
      totalClicked: allClicked,
    });
  });

  // ────────────────────────────────────────────────────────────────
  // AI suggestions stub (canned templates)
  // ────────────────────────────────────────────────────────────────
  fastify.post('/ai-generate', { preHandler: staffAuthGuard }, async (_request, reply) => {
    const now = new Date();
    const inHours = (h: number) => new Date(now.getTime() + h * 3_600_000).toISOString();
    return reply.send({
      suggestions: [
        {
          title: 'Yangi audiokitob: Sarguzashtlar kutmoqda',
          message: 'Hozir tinglang — yangi sarguzasht audiokitobi yuklandi. Bolangiz albatta yoqtiradi.',
          targetType: 'all',
          suggestedSendTime: inHours(2),
        },
        {
          title: "Tanlov haqida ogohlantirish: Ajoyib sovg'alarni yutib oling",
          message: "Yangi konkurs ochildi — eng ko'p ball to'plagan farzandlar sovg'a oladi.",
          targetType: 'premium',
          suggestedSendTime: inHours(6),
        },
        {
          title: 'Yangilangan dastur: Harakatlanuvchi interfeys bilan',
          message: 'Yangi versiya 2.0 tayyor — yangi dizayn va tezroq tezlik. Hozir yangilang.',
          targetType: 'parents',
          suggestedSendTime: inHours(12),
        },
        {
          title: "Maxsus taklif: Xarid qiling va bonuslar oling",
          message: "Bir oylik tarif sotib oling — 1 oylik bepul kuni qo'shamiz.",
          targetType: 'parents',
          suggestedSendTime: inHours(24),
        },
      ],
    });
  });

  // ────────────────────────────────────────────────────────────────
  // Get by id
  // ────────────────────────────────────────────────────────────────
  fastify.get('/:id', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const n = await prisma.adminNotification.findUnique({ where: { id } });
    if (!n) return reply.code(404).send({ error: 'Notification not found' });

    // Sintetik engagement curve (Sprint 5.4 da real time-series qo'shiladi)
    const total = n.deliveredCount;
    const peakSlot = 6; // 18:00 atrofida
    const engagement = Array.from({ length: 9 }, (_, i) => {
      const t = i * 3; // 0, 3, 6, ..., 24
      const distance = Math.abs(i - peakSlot);
      const factor = Math.max(0, 1 - distance / 9);
      return { time: `${String(t).padStart(2, '0')}:00`, count: Math.round(total * factor * 0.35) };
    });
    return reply.send({ ...rowOf(n), engagement });
  });

  // ────────────────────────────────────────────────────────────────
  // Create / Send / Schedule
  // ────────────────────────────────────────────────────────────────
  fastify.post('/', { preHandler: staffAuthGuard }, async (request, reply) => {
    const parsed = CreateBody.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid notification payload', details: parsed.error.flatten() });
    }
    const created = await createBroadcast(parsed.data, request.staff?.sub);
    void logAudit(request, {
      action: created.status === 'scheduled' ? 'notification.schedule' : 'notification.send',
      moderatorId: request.staff?.sub ?? null,
      email: request.staff?.email ?? null,
      resourceType: 'admin_notification',
      resourceId: created.id,
      details: {
        target: parsed.data.targetType,
        scheduled: created.status === 'scheduled',
        delivered: created.deliveredCount,
      },
    });
    return reply.code(201).send(rowOf(created));
  });

  fastify.post('/send', { preHandler: staffAuthGuard }, async (request, reply) => {
    const parsed = SimpleSendBody.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid send payload', details: parsed.error.flatten() });
    }
    const created = await createBroadcast(
      {
        title: parsed.data.title,
        message: parsed.data.message,
        targetType: parsed.data.target,
      },
      request.staff?.sub,
    );
    void logAudit(request, {
      action: 'notification.send',
      moderatorId: request.staff?.sub ?? null,
      email: request.staff?.email ?? null,
      resourceType: 'admin_notification',
      resourceId: created.id,
      details: { target: parsed.data.target, delivered: created.deliveredCount },
    });
    return reply.code(201).send(rowOf(created));
  });

  fastify.post('/schedule', { preHandler: staffAuthGuard }, async (request, reply) => {
    const parsed = ScheduleBody.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid schedule payload', details: parsed.error.flatten() });
    }
    const created = await createBroadcast(
      {
        title: parsed.data.title,
        message: parsed.data.message,
        targetType: parsed.data.target,
        scheduledAt: parsed.data.scheduledAt,
      },
      request.staff?.sub,
    );
    return reply.code(201).send(rowOf(created));
  });

  // ────────────────────────────────────────────────────────────────
  // Delete
  // ────────────────────────────────────────────────────────────────
  fastify.delete('/:id', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      const existing = await prisma.adminNotification.findUnique({ where: { id } });
      if (!existing) {
        return reply.code(404).send({ error: 'Notification not found' });
      }

      // App ichidagi per-child nusxalarni ham o'chiramiz (in-app inbox).
      // createBroadcast SYSTEM tipidagi Notification'ni title + body bilan yozadi.
      const inApp = await prisma.notification.deleteMany({
        where: {
          type: 'SYSTEM',
          title: existing.title,
          body: existing.message,
        },
      });

      await prisma.adminNotification.delete({ where: { id } });

      void logAudit(request, {
        action: 'notification.delete',
        moderatorId: request.staff?.sub ?? null,
        email: request.staff?.email ?? null,
        resourceType: 'admin_notification',
        resourceId: id,
        details: { inAppRowsRemoved: inApp.count },
      });

      return reply.code(200).send({ success: true, inAppRowsRemoved: inApp.count });
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Notification not found' });
      }
      throw err;
    }
  });
};
