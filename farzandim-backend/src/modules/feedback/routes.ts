import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { authGuard } from '../../middleware/auth';
import { prisma } from '../../lib/prisma';
import { writeAudit } from '../../lib/audit';
import { emitToUser, emitToChild } from '../../lib/realtime';

// Feedback = child → parent emoji + matn. Bolaning tezkor his-tuyg'u feedback'i.
// "Menga vaqt qo'shing", "xafa bo'ldim" va h.k. Parent dashboard'da ko'rinadi.

const FEEDBACK_EMOJIS = [
  'HAPPY',
  'EXCITED',
  'THINKING',
  'WINKING',
  'SAD',
  'ANGRY',
  'TIRED',
  'LOVE',
] as const;

const createSchema = z.object({
  emoji: z.enum(FEEDBACK_EMOJIS),
  message: z.string().max(500).optional(),
  context: z.string().max(100).optional(),
});

const listQuerySchema = z.object({
  isRead: z.enum(['true', 'false']).optional(),
  limit: z.coerce.number().int().min(1).max(200).default(100),
});

export const feedbackRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.addHook('preHandler', authGuard);

  /**
   * GET /api/children/:childId/feedback — list (parent reads, child o'zining feedback'larini ko'ra oladi)
   */
  fastify.get<{
    Params: { childId: string };
    Querystring: { isRead?: string; limit?: number };
  }>('/children/:childId/feedback', async (request, reply) => {
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

    const { isRead, limit } = parsed.data;

    const feedback = await prisma.feedback.findMany({
      where: {
        childId,
        ...(isRead !== undefined && { isRead: isRead === 'true' }),
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    return reply.send({ feedback, count: feedback.length });
  });

  /**
   * POST /api/children/:childId/feedback — child yozadi
   */
  fastify.post<{ Params: { childId: string } }>(
    '/children/:childId/feedback',
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

      const feedback = await prisma.feedback.create({
        data: {
          childId,
          emoji: parsed.data.emoji,
          message: parsed.data.message,
          context: parsed.data.context,
        },
      });

      await writeAudit(request, 'feedback', 'CREATE', feedback.id, parsed.data);

      // Real-time: parent'ga yangi feedback bor
      emitToUser(child.parentId, 'feedback:received', feedback);
      emitToChild(childId, 'feedback:created', feedback);

      return reply.code(201).send(feedback);
    },
  );

  /**
   * PUT /api/feedback/:id/read — parent o'qiganini belgilash
   */
  fastify.put<{ Params: { id: string } }>('/feedback/:id/read', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const feedback = await prisma.feedback.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!feedback) return reply.code(404).send({ error: 'Feedback not found' });
    if (feedback.child.parentId !== userId) {
      return reply.code(403).send({ error: 'Only parent can mark feedback as read' });
    }

    const updated = await prisma.feedback.update({
      where: { id },
      data: { isRead: true },
    });

    return reply.send(updated);
  });
};
