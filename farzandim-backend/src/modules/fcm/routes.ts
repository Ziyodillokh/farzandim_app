import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { authGuard } from '../../middleware/auth';
import { prisma } from '../../lib/prisma';

const registerSchema = z.object({
  token: z.string().min(20).max(4096), // FCM tokens typically 152+ chars
  deviceType: z.enum(['android', 'ios']).optional(),
  deviceId: z.string().max(200).optional(),
});

export const fcmRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.addHook('preHandler', authGuard);

  /**
   * POST /api/fcm/tokens
   * Mobile app device token'ni ro'yxatdan o'tkazadi (yoki yangilaydi).
   * Token unique — agar boshqa user'ga tegishli bo'lsa, egasi yangi user'ga o'tadi
   * (qurilma boshqa hisobga login qilingan vaqt). deviceId/deviceType yangilanadi.
   */
  fastify.post('/tokens', async (request, reply) => {
    const userId = request.user!.userId;

    const parsed = registerSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
    }

    const row = await prisma.fcmToken.upsert({
      where: { token: parsed.data.token },
      update: {
        userId,
        deviceType: parsed.data.deviceType ?? null,
        deviceId: parsed.data.deviceId ?? null,
      },
      create: {
        userId,
        token: parsed.data.token,
        deviceType: parsed.data.deviceType ?? null,
        deviceId: parsed.data.deviceId ?? null,
      },
    });

    return reply.code(201).send({
      id: row.id,
      deviceType: row.deviceType,
      deviceId: row.deviceId,
      createdAt: row.createdAt,
    });
  });

  /**
   * GET /api/fcm/tokens
   * Foydalanuvchining ro'yxatdan o'tgan tokenlari (token qiymatisiz — xavfsizlik uchun).
   */
  fastify.get('/tokens', async (request, reply) => {
    const userId = request.user!.userId;

    const tokens = await prisma.fcmToken.findMany({
      where: { userId },
      select: {
        id: true,
        deviceType: true,
        deviceId: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    return reply.send({ tokens, count: tokens.length });
  });

  /**
   * DELETE /api/fcm/tokens/:id
   * Bitta token o'chirish (qurilma logout vaqti).
   */
  fastify.delete<{ Params: { id: string } }>('/tokens/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const row = await prisma.fcmToken.findUnique({ where: { id } });
    if (!row) return reply.code(404).send({ error: 'Token not found' });
    if (row.userId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    await prisma.fcmToken.delete({ where: { id } });
    return reply.send({ ok: true });
  });

  /**
   * DELETE /api/fcm/tokens
   * Foydalanuvchining barcha tokenlari (full logout, hisobni o'chirish).
   */
  fastify.delete('/tokens', async (request, reply) => {
    const userId = request.user!.userId;

    const result = await prisma.fcmToken.deleteMany({ where: { userId } });
    return reply.send({ ok: true, deleted: result.count });
  });
};
