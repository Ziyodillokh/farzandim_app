import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { verifyTelegramAuth, isAuthDataFresh, TelegramAuthData } from './telegram';
import { signAccessToken, signRefreshToken, verifyRefreshToken } from './jwt';
import { prisma } from '../../lib/prisma';
import { writeAudit } from '../../lib/audit';
import { emitToUser } from '../../lib/realtime';
import { sendPushToUser } from '../../lib/fcm';
import { authGuard } from '../../middleware/auth';

const PAIR_REQUEST_TTL_MIN = 5;

const telegramAuthSchema = z.object({
  id: z.number(),
  first_name: z.string().optional(),
  last_name: z.string().optional(),
  username: z.string().optional(),
  photo_url: z.string().optional(),
  auth_date: z.number(),
  hash: z.string(),
});

const refreshSchema = z.object({
  refreshToken: z.string(),
});

const childPairSchema = z.object({
  familyCode: z.string().length(5),
  deviceInfo: z
    .object({
      model: z.string().max(100).optional(),
      os: z.string().max(50).optional(),
      batteryLevel: z.number().int().min(0).max(100).optional(),
      isCharging: z.boolean().optional(),
    })
    .optional(),
});

export const authRoutes: FastifyPluginAsync = async (fastify) => {
  /**
   * POST /api/auth/telegram
   * Telegram Login Widget callback
   */
  fastify.post('/telegram', async (request, reply) => {
    const parsed = telegramAuthSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
    }
    
    const data = parsed.data as TelegramAuthData;
    
    // Hash verify
    if (!verifyTelegramAuth(data)) {
      return reply.code(401).send({ error: 'Invalid Telegram hash' });
    }
    
    // Muddat tekshirish (24 soat)
    if (!isAuthDataFresh(data.auth_date)) {
      return reply.code(401).send({ error: 'Auth data expired' });
    }
    
    // Telegram'da phone yo'q (Login Widget bermaydi)
    // Phone keyin Profile screen'da so'raymiz
    const telegramId = String(data.id);
    const displayName = [data.first_name, data.last_name].filter(Boolean).join(' ') || data.username || `User${telegramId}`;
    
    // User upsert (telegramId bo'yicha). Yangi yaratilganmi tekshirish uchun
    // avval qidiramiz — audit log uchun.
    const existing = await prisma.user.findUnique({ where: { telegramId } });
    const user = await prisma.user.upsert({
      where: { telegramId },
      update: {
        avatarUrl: data.photo_url ?? undefined,
      },
      create: {
        telegramId,
        role: 'PARENT',
        name: displayName,
        avatarUrl: data.photo_url,
      },
    });

    await writeAudit(
      request,
      'auth',
      existing ? 'LOGIN' : 'CREATE',
      user.id,
      { telegramId, method: 'telegram' },
      { userId: user.id },
    );

    // JWT tokens
    const payload = { userId: user.id, role: user.role, tokenVersion: user.tokenVersion };
    const accessToken = signAccessToken(payload);
    const refreshToken = signRefreshToken(payload);

    return reply.send({
      user: {
        id: user.id,
        name: user.name,
        role: user.role,
        avatarUrl: user.avatarUrl,
        telegramId: user.telegramId,
        language: user.language,
      },
      accessToken,
      refreshToken,
    });
  });
  
  /**
   * POST /api/auth/refresh
   * Access token yangilash
   */
  fastify.post('/refresh', async (request, reply) => {
    const parsed = refreshSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid payload' });
    }
    
    try {
      const payload = verifyRefreshToken(parsed.data.refreshToken);
      
      const user = await prisma.user.findUnique({ where: { id: payload.userId } });
      if (!user || !user.isActive) {
        return reply.code(401).send({ error: 'User not found or inactive' });
      }
      
      // Sprint 6 P1 — logout'dan keyin tokenVersion mos kelmaydi → refresh rad etiladi.
      if ((payload.tokenVersion ?? 0) !== user.tokenVersion) {
        return reply.code(401).send({ error: 'Token bekor qilingan' });
      }

      const newAccessToken = signAccessToken({ userId: user.id, role: user.role });
      return reply.send({ accessToken: newAccessToken });
    } catch (err) {
      return reply.code(401).send({ error: 'Invalid refresh token' });
    }
  });

  /**
   * POST /api/auth/child-pair
   * Bola App birinchi marta family code bilan ulanadi — JWT pair qaytariladi.
   * Anonymous endpoint (auth header yo'q). Child uchun Telegram'siz auth flow.
   */
  fastify.post('/child-pair', async (request, reply) => {
    const parsed = childPairSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
    }

    const child = await prisma.child.findUnique({
      where: { familyCode: parsed.data.familyCode },
    });
    if (!child) {
      return reply.code(404).send({ error: 'Family code not found' });
    }

    // Re-pair flow: agar child allaqachon paired bo'lsa, Parent tasdiqi kerak.
    // Pair request yaratiladi (5 daqiqalik TTL), Parent push xabari oladi.
    // Bola GET /api/auth/child-pair-status/:id polling qiladi.
    if (child.childUserId) {
      // Eski PENDING request bo'lsa, EXPIRED qil va yangisini yarat
      await prisma.childPairRequest.updateMany({
        where: { childId: child.id, status: 'PENDING', expiresAt: { gt: new Date() } },
        data: { status: 'EXPIRED', decidedAt: new Date() },
      });

      const expiresAt = new Date(Date.now() + PAIR_REQUEST_TTL_MIN * 60 * 1000);
      const pairRequest = await prisma.childPairRequest.create({
        data: {
          childId: child.id,
          deviceInfo: parsed.data.deviceInfo as object | undefined,
          ipAddress: request.ip ?? null,
          userAgent: (request.headers['user-agent'] as string) ?? null,
          expiresAt,
        },
      });

      await writeAudit(
        request,
        'auth',
        'PAIR',
        pairRequest.id,
        {
          action: 'PAIR_REQUEST_CREATED',
          childId: child.id,
          familyCode: parsed.data.familyCode,
        },
      );

      // Parent'ga real-time + push
      emitToUser(child.parentId, 'pair_request:created', {
        id: pairRequest.id,
        childId: child.id,
        childName: child.name,
        deviceInfo: pairRequest.deviceInfo,
        ipAddress: pairRequest.ipAddress,
        expiresAt: pairRequest.expiresAt.toISOString(),
      });

      try {
        await sendPushToUser(prisma, child.parentId, {
          title: `${child.name} — yangi qurilma`,
          body: `Yangi qurilma family code bilan ulanmoqchi. Tasdiqlang.`,
          data: {
            type: 'pair_request',
            pairRequestId: pairRequest.id,
            childId: child.id,
          },
        });
      } catch (err) {
        request.log.warn({ err, pairRequestId: pairRequest.id }, 'pair_request push failed');
      }

      return reply.code(409).send({
        error: 'AWAITING_PARENT_CONFIRM',
        message: 'Bola allaqachon ulangan. Ota-onangiz yangi qurilmani tasdiqlashi kerak.',
        pairRequestId: pairRequest.id,
        expiresAt: pairRequest.expiresAt.toISOString(),
        pollIntervalSec: 3,
      });
    }

    // Yangi User yaratish (role: CHILD, name: child.name'dan olinadi)
    const user = await prisma.user.create({
      data: {
        role: 'CHILD',
        name: child.name,
      },
    });

    // Child'ni pair qilish + device info (ixtiyoriy)
    const deviceInfo = parsed.data.deviceInfo;
    const updatedChild = await prisma.child.update({
      where: { id: child.id },
      data: {
        childUserId: user.id,
        isConnected: true,
        pairedAt: new Date(),
        ...(deviceInfo?.model && { deviceModel: deviceInfo.model }),
        ...(deviceInfo?.batteryLevel !== undefined && { batteryLevel: deviceInfo.batteryLevel }),
        ...(deviceInfo?.isCharging !== undefined && { isCharging: deviceInfo.isCharging }),
      },
    });

    const payload = { userId: user.id, role: user.role, tokenVersion: user.tokenVersion };
    const accessToken = signAccessToken(payload);
    const refreshToken = signRefreshToken(payload);

    await writeAudit(
      request,
      'auth',
      'PAIR',
      user.id,
      { childId: updatedChild.id, familyCode: parsed.data.familyCode },
      { userId: user.id },
    );

    return reply.code(201).send({
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        name: user.name,
        role: user.role,
        avatarUrl: user.avatarUrl,
        telegramId: user.telegramId,
        language: user.language,
      },
      child: {
        id: updatedChild.id,
        parentId: updatedChild.parentId,
        name: updatedChild.name,
        age: updatedChild.age,
      },
    });
  });

  /**
   * POST /api/auth/logout
   * tokenVersion'ni increment qiladi — barcha refresh token'lar bekor bo'ladi.
   * Access token qisqa muddatli (15m) — o'zi tugaydi.
   */
  fastify.post('/logout', { preHandler: authGuard }, async (request, reply) => {
    await prisma.user.update({
      where: { id: request.user!.userId },
      data: { tokenVersion: { increment: 1 } },
    });
    return reply.send({ ok: true });
  });
};
