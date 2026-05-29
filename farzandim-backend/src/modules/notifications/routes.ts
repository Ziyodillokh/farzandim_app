import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { authGuard } from '../../middleware/auth';
import { prisma } from '../../lib/prisma';
import { writeAudit } from '../../lib/audit';
import { emitToChild } from '../../lib/realtime';

// Notification = bola hisobiga keladigan ichki xabar.
// 7 ta tip: ACHIEVEMENT, CONTEST, SCHEDULE, PARENT_REQUEST, VOICE, GEO_ZONE, SYSTEM
// Parent ko'rmaydi (faqat parent push qiladi). Child o'qiydi.

const NOTIFICATION_TYPES = [
  'ACHIEVEMENT',
  'CONTEST',
  'SCHEDULE',
  'PARENT_REQUEST',
  'VOICE',
  'GEO_ZONE',
  'SYSTEM',
] as const;

const createSchema = z.object({
  type: z.enum(NOTIFICATION_TYPES),
  title: z.string().min(1).max(200),
  body: z.string().min(1).max(1000),
  data: z.record(z.string(), z.unknown()).optional(),
});

const listQuerySchema = z.object({
  type: z.enum(NOTIFICATION_TYPES).optional(),
  isRead: z.enum(['true', 'false']).optional(),
  limit: z.coerce.number().int().min(1).max(200).default(100),
});

export const notificationRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.addHook('preHandler', authGuard);

  /**
   * GET /api/children/:childId/notifications
   * Filter: type, isRead, limit
   */
  fastify.get<{
    Params: { childId: string };
    Querystring: { type?: string; isRead?: string; limit?: number };
  }>('/children/:childId/notifications', async (request, reply) => {
    const userId = request.user!.userId;
    const { childId } = request.params;

    const child = await prisma.child.findUnique({ where: { id: childId } });
    if (!child) return reply.code(404).send({ error: 'Child not found' });
    if (child.parentId !== userId && child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    const parsed = listQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid query', details: parsed.error.format() });
    }

    const { type, isRead, limit } = parsed.data;

    const notifications = await prisma.notification.findMany({
      where: {
        childId,
        ...(type && { type }),
        ...(isRead !== undefined && { isRead: isRead === 'true' }),
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    const unreadCount = await prisma.notification.count({
      where: { childId, isRead: false },
    });

    return reply.send({ notifications, count: notifications.length, unreadCount });
  });

  /**
   * POST /api/children/:childId/notifications
   * (Parent yoki tizim yaratishi mumkin — server-side trigger uchun ham foydali)
   */
  fastify.post<{ Params: { childId: string } }>(
    '/children/:childId/notifications',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.parentId !== userId) {
        return reply.code(403).send({ error: 'Only parent can create notifications' });
      }

      const parsed = createSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
      }

      const notification = await prisma.notification.create({
        data: {
          childId,
          type: parsed.data.type,
          title: parsed.data.title,
          body: parsed.data.body,
          data: parsed.data.data as object | undefined,
        },
      });

      await writeAudit(request, 'notification', 'CREATE', notification.id, parsed.data);
      emitToChild(childId, 'notification:created', notification);

      return reply.code(201).send(notification);
    },
  );

  /**
   * PUT /api/notifications/:id/read — mark as read
   */
  fastify.put<{ Params: { id: string } }>('/notifications/:id/read', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const notification = await prisma.notification.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!notification) return reply.code(404).send({ error: 'Notification not found' });
    if (notification.child.parentId !== userId && notification.child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    const updated = await prisma.notification.update({
      where: { id },
      data: { isRead: true },
    });

    // Sprint 6 P2 — admin broadcast bo'lsa, birinchi o'qishda openedCount++.
    if (notification.adminNotificationId && !notification.isRead) {
      await prisma.adminNotification
        .update({
          where: { id: notification.adminNotificationId },
          data: { openedCount: { increment: 1 } },
        })
        .catch(() => {
          /* admin broadcast o'chirilgan bo'lishi mumkin */
        });
    }

    emitToChild(notification.childId, 'notification:read', { id });

    return reply.send(updated);
  });

  /**
   * POST /api/notifications/:id/click — deep-link bosildi (admin broadcast tracking).
   * Faqat birinchi bosishda hisoblanadi (clickedAt bo'sh bo'lsa).
   */
  fastify.post<{ Params: { id: string } }>('/notifications/:id/click', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const notification = await prisma.notification.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!notification) return reply.code(404).send({ error: 'Notification not found' });
    if (notification.child.parentId !== userId && notification.child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    if (notification.clickedAt === null) {
      await prisma.notification.update({
        where: { id },
        data: { clickedAt: new Date() },
      });
      if (notification.adminNotificationId) {
        await prisma.adminNotification
          .update({
            where: { id: notification.adminNotificationId },
            data: { clickedCount: { increment: 1 } },
          })
          .catch(() => {
            /* admin broadcast o'chirilgan bo'lishi mumkin */
          });
      }
    }

    return reply.send({ ok: true });
  });

  /**
   * PUT /api/children/:childId/notifications/read-all — mark all as read
   */
  fastify.put<{ Params: { childId: string } }>(
    '/children/:childId/notifications/read-all',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.parentId !== userId && child.childUserId !== userId) {
        return reply.code(403).send({ error: 'Forbidden' });
      }

      const result = await prisma.notification.updateMany({
        where: { childId, isRead: false },
        data: { isRead: true },
      });

      emitToChild(childId, 'notification:read-all', { count: result.count });

      return reply.send({ ok: true, updated: result.count });
    },
  );

  /**
   * DELETE /api/notifications/:id
   */
  fastify.delete<{ Params: { id: string } }>('/notifications/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const notification = await prisma.notification.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!notification) return reply.code(404).send({ error: 'Notification not found' });
    if (notification.child.parentId !== userId && notification.child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    await prisma.notification.delete({ where: { id } });
    await writeAudit(request, 'notification', 'DELETE', id);
    emitToChild(notification.childId, 'notification:deleted', { id });

    return reply.send({ ok: true });
  });
};
