import { FastifyPluginAsync } from 'fastify';
import { authGuard } from '../../middleware/auth';
import { prisma } from '../../lib/prisma';
import { signAccessToken, signRefreshToken } from '../auth/jwt';
import { writeAudit } from '../../lib/audit';
import { emitToUser } from '../../lib/realtime';

// Child re-pair flow (Sprint 5.0):
//   1. Bola App reinstall qildi → POST /auth/child-pair → 409 + pairRequestId
//   2. Parent FCM push + WS pair_request:created
//   3. Parent App approve/reject tugma:
//      - POST /api/children/:childId/pair-requests/:id/approve
//        → Eski User isActive=false, yangi User yaratiladi, child.childUserId yangilanadi
//      - POST .../reject → status=REJECTED
//   4. Bola GET /auth/child-pair-status/:id polling qiladi (har 3 sek)
//   5. APPROVED bo'lganda JWT pair beriladi

// Lazy expiration: agar request PENDING va expiresAt o'tgan bo'lsa, EXPIRED qaytaradi.
async function checkExpiration(
  reqRow: { id: string; status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'EXPIRED'; expiresAt: Date },
): Promise<typeof reqRow.status> {
  if (reqRow.status === 'PENDING' && reqRow.expiresAt < new Date()) {
    await prisma.childPairRequest.update({
      where: { id: reqRow.id },
      data: { status: 'EXPIRED', decidedAt: new Date() },
    });
    return 'EXPIRED';
  }
  return reqRow.status;
}

export const childPairRequestsRoutes: FastifyPluginAsync = async (fastify) => {
  /**
   * GET /api/auth/child-pair-status/:id — NO AUTH (bola polling qiladi)
   * 200 statuses:
   *   PENDING — kuting
   *   APPROVED + tokens — bola App JWT saqlaydi va davom etadi
   *   REJECTED — parent rad qildi
   *   EXPIRED — TTL o'tdi (5 daq)
   */
  fastify.get<{ Params: { id: string } }>(
    '/auth/child-pair-status/:id',
    async (request, reply) => {
      const { id } = request.params;

      const pairReq = await prisma.childPairRequest.findUnique({
        where: { id },
        include: { child: true },
      });
      if (!pairReq) {
        return reply.code(404).send({ error: 'Pair request not found' });
      }

      const status = await checkExpiration(pairReq);

      if (status === 'PENDING') {
        return reply.send({
          status,
          expiresAt: pairReq.expiresAt.toISOString(),
          pollIntervalSec: 3,
        });
      }

      if (status === 'REJECTED' || status === 'EXPIRED') {
        return reply.send({ status });
      }

      // APPROVED — JWT pair qaytarish
      if (!pairReq.newUserId) {
        return reply.code(500).send({ error: 'Approved request missing newUserId' });
      }
      const user = await prisma.user.findUnique({ where: { id: pairReq.newUserId } });
      if (!user || !user.isActive) {
        return reply.code(500).send({ error: 'New user not active' });
      }

      const payload = { userId: user.id, role: user.role as 'PARENT' | 'CHILD' };
      const accessToken = signAccessToken(payload);
      const refreshToken = signRefreshToken(payload);

      return reply.send({
        status,
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
          id: pairReq.child.id,
          parentId: pairReq.child.parentId,
          name: pairReq.child.name,
          age: pairReq.child.age,
        },
      });
    },
  );

  // Parent endpoint'lari (auth required)
  fastify.register(async (parent) => {
    parent.addHook('preHandler', authGuard);

    /**
     * GET /api/children/:childId/pair-requests?status=PENDING
     */
    parent.get<{
      Params: { childId: string };
      Querystring: { status?: string };
    }>('/children/:childId/pair-requests', async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.parentId !== userId) {
        return reply.code(403).send({ error: 'Only parent can view pair requests' });
      }

      const statusFilter = request.query.status as
        | 'PENDING'
        | 'APPROVED'
        | 'REJECTED'
        | 'EXPIRED'
        | undefined;

      const requests = await prisma.childPairRequest.findMany({
        where: { childId, ...(statusFilter && { status: statusFilter }) },
        orderBy: { createdAt: 'desc' },
        take: 50,
      });

      return reply.send({ requests, count: requests.length });
    });

    /**
     * POST /api/children/:childId/pair-requests/:id/approve
     * Transactional: eski User isActive=false, yangi User, child.childUserId yangilanadi.
     */
    parent.post<{ Params: { childId: string; id: string } }>(
      '/children/:childId/pair-requests/:id/approve',
      async (request, reply) => {
        const userId = request.user!.userId;
        const { childId, id } = request.params;

        const pairReq = await prisma.childPairRequest.findUnique({
          where: { id },
          include: { child: true },
        });
        if (!pairReq || pairReq.childId !== childId) {
          return reply.code(404).send({ error: 'Pair request not found' });
        }
        if (pairReq.child.parentId !== userId) {
          return reply.code(403).send({ error: 'Only parent can approve' });
        }

        const status = await checkExpiration(pairReq);
        if (status !== 'PENDING') {
          return reply.code(409).send({ error: `Pair request is ${status}`, status });
        }

        // Transactional re-pair
        const result = await prisma.$transaction(async (tx) => {
          const oldChildUserId = pairReq.child.childUserId;

          // Eski User soft-delete + FCM cleanup
          if (oldChildUserId) {
            await tx.user.update({
              where: { id: oldChildUserId },
              data: { isActive: false },
            });
            await tx.fcmToken.deleteMany({ where: { userId: oldChildUserId } });
          }

          // Yangi User
          const newUser = await tx.user.create({
            data: { role: 'CHILD', name: pairReq.child.name },
          });

          // Device info pair request'dan
          const deviceInfo = (pairReq.deviceInfo ?? {}) as {
            model?: string;
            batteryLevel?: number;
            isCharging?: boolean;
          };

          const updatedChild = await tx.child.update({
            where: { id: childId },
            data: {
              childUserId: newUser.id,
              isConnected: true,
              pairedAt: new Date(),
              ...(deviceInfo.model && { deviceModel: deviceInfo.model }),
              ...(deviceInfo.batteryLevel !== undefined && {
                batteryLevel: deviceInfo.batteryLevel,
              }),
              ...(deviceInfo.isCharging !== undefined && { isCharging: deviceInfo.isCharging }),
            },
          });

          await tx.childPairRequest.update({
            where: { id },
            data: {
              status: 'APPROVED',
              decidedAt: new Date(),
              newUserId: newUser.id,
            },
          });

          return { newUser, updatedChild, oldChildUserId };
        });

        await writeAudit(request, 'auth', 'PAIR', id, {
          action: 'PAIR_REQUEST_APPROVED',
          childId,
          newUserId: result.newUser.id,
          oldChildUserId: result.oldChildUserId,
        });

        // Real-time: parent boshqa qurilmasiga ham
        emitToUser(userId, 'pair_request:approved', {
          id,
          childId,
          newUserId: result.newUser.id,
        });

        return reply.send({
          ok: true,
          status: 'APPROVED',
          pairRequestId: id,
          newUserId: result.newUser.id,
        });
      },
    );

    /**
     * POST /api/children/:childId/pair-requests/:id/reject
     */
    parent.post<{ Params: { childId: string; id: string } }>(
      '/children/:childId/pair-requests/:id/reject',
      async (request, reply) => {
        const userId = request.user!.userId;
        const { childId, id } = request.params;

        const pairReq = await prisma.childPairRequest.findUnique({
          where: { id },
          include: { child: true },
        });
        if (!pairReq || pairReq.childId !== childId) {
          return reply.code(404).send({ error: 'Pair request not found' });
        }
        if (pairReq.child.parentId !== userId) {
          return reply.code(403).send({ error: 'Only parent can reject' });
        }

        const status = await checkExpiration(pairReq);
        if (status !== 'PENDING') {
          return reply.code(409).send({ error: `Pair request is ${status}`, status });
        }

        await prisma.childPairRequest.update({
          where: { id },
          data: { status: 'REJECTED', decidedAt: new Date() },
        });

        await writeAudit(request, 'auth', 'PAIR', id, {
          action: 'PAIR_REQUEST_REJECTED',
          childId,
        });

        emitToUser(userId, 'pair_request:rejected', { id, childId });

        return reply.send({ ok: true, status: 'REJECTED' });
      },
    );
  });
};
