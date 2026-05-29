import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { authGuard } from '../../middleware/auth';
import { prisma } from '../../lib/prisma';
import { writeAudit } from '../../lib/audit';
import { emitToUser, emitToChild } from '../../lib/realtime';
import { sendPushToUser } from '../../lib/fcm';

// SOS alert — bola tezkor parental yordam so'rashi. Push HIGH PRIORITY
// (FCM critical, ringtone, vibration). Status: ACTIVE → RESOLVED.

const createSchema = z.object({
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  accuracy: z.number().min(0).optional(),
  deviceInfo: z.record(z.string(), z.unknown()).optional(),
});

const listQuerySchema = z.object({
  status: z.enum(['ACTIVE', 'RESOLVED']).optional(),
  limit: z.coerce.number().int().min(1).max(200).default(100),
});

export const sosAlertRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.addHook('preHandler', authGuard);

  /**
   * POST /api/children/:childId/sos-alerts — child triggers SOS
   */
  fastify.post<{ Params: { childId: string } }>(
    '/children/:childId/sos-alerts',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.childUserId !== userId && child.parentId !== userId) {
        return reply.code(403).send({ error: 'Forbidden' });
      }

      const parsed = createSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
      }

      const alert = await prisma.sosAlert.create({
        data: {
          childId,
          latitude: parsed.data.latitude,
          longitude: parsed.data.longitude,
          accuracy: parsed.data.accuracy,
          deviceInfo: parsed.data.deviceInfo as object | undefined,
        },
      });

      await writeAudit(request, 'sos_alert', 'CREATE', alert.id, parsed.data);

      // Real-time + push — kritik
      emitToUser(child.parentId, 'sos:received', { alert, childId, childName: child.name });
      emitToChild(childId, 'sos:received', { alert });

      try {
        await sendPushToUser(prisma, child.parentId, {
          title: `🆘 ${child.name} — yordam kerak!`,
          body: alert.latitude
            ? 'Bola SOS bosgan. Lokatsiya birga keldi.'
            : 'Bola SOS bosgan. Tezda javob bering.',
          data: {
            type: 'sos',
            alertId: alert.id,
            childId,
            priority: 'high',
          },
        });
      } catch (err) {
        request.log.warn({ err, alertId: alert.id }, 'SOS push failed (Firebase setup?)');
      }

      return reply.code(201).send(alert);
    },
  );

  /**
   * GET /api/sos-alerts — parent ko'radi (o'z bolalari)
   */
  fastify.get<{ Querystring: { status?: string; limit?: number } }>(
    '/sos-alerts',
    async (request, reply) => {
      const userId = request.user!.userId;

      const parsed = listQuerySchema.safeParse(request.query);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid query', details: parsed.error.format() });
      }

      const { status, limit } = parsed.data;

      const alerts = await prisma.sosAlert.findMany({
        where: {
          ...(status && { status }),
          child: {
            OR: [{ parentId: userId }, { childUserId: userId }],
          },
        },
        include: {
          child: {
            select: { id: true, name: true, parentId: true, childUserId: true },
          },
        },
        orderBy: { createdAt: 'desc' },
        take: limit,
      });

      return reply.send({ alerts, count: alerts.length });
    },
  );

  /**
   * PUT /api/sos-alerts/:id/resolve — parent resolves
   */
  fastify.put<{ Params: { id: string } }>('/sos-alerts/:id/resolve', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const alert = await prisma.sosAlert.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!alert) return reply.code(404).send({ error: 'SOS alert not found' });
    if (alert.child.parentId !== userId) {
      return reply.code(403).send({ error: 'Only parent can resolve' });
    }
    if (alert.status === 'RESOLVED') {
      return reply.send(alert);
    }

    const updated = await prisma.sosAlert.update({
      where: { id },
      data: {
        status: 'RESOLVED',
        resolvedAt: new Date(),
        resolvedBy: userId,
      },
    });

    await writeAudit(request, 'sos_alert', 'RESOLVE', id);

    if (alert.child.childUserId) {
      emitToUser(alert.child.childUserId, 'sos:resolved', updated);
    }
    emitToChild(alert.childId, 'sos:resolved', updated);

    return reply.send(updated);
  });
};
