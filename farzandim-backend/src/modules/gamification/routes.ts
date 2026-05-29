import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { authGuard } from '../../middleware/auth';
import { prisma } from '../../lib/prisma';
import { writeAudit } from '../../lib/audit';
import { emitToChild } from '../../lib/realtime';
import { statusForXp, levelForXp, calculateNewStreak } from '../../lib/gamification-rules';

// Gamification:
//   - ChildProfile (1:1 with Child): XP, DON, Level, Streak, Achievements
//   - XpEvent (append-only ledger): har bir XP/DON harakatining tarixi
//
// XP → level/status va streak hisoblash lib/gamification-rules.ts'da
// (DB'siz, test qilish oson).

const XP_EVENT_TYPES = [
  'BOOK_READ',
  'CONTEST_JOIN',
  'CONTEST_WIN',
  'CREATIVE_JOIN',
  'CREATIVE_WIN',
  'COURSE_LESSON',
  'DAILY_GOAL',
  'STREAK_WEEKLY',
  'CONTENT_POST',
  'OTHER',
] as const;

const xpEventCreateSchema = z.object({
  type: z.enum(XP_EVENT_TYPES),
  xpDelta: z.number().int().min(-1000).max(10000),
  donDelta: z.number().int().min(-1000).max(10000).default(0),
  relatedId: z.string().max(200).optional(),
  source: z.record(z.string(), z.unknown()).optional(),
});

const xpEventsListSchema = z.object({
  type: z.enum(XP_EVENT_TYPES).optional(),
  limit: z.coerce.number().int().min(1).max(500).default(100),
});

/**
 * Profile'ni topadi yoki yaratadi (har Child uchun 1 ta).
 */
async function getOrCreateProfile(childId: string) {
  const existing = await prisma.childProfile.findUnique({ where: { childId } });
  if (existing) return existing;
  return prisma.childProfile.create({ data: { childId } });
}

export const gamificationRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.addHook('preHandler', authGuard);

  /**
   * GET /api/children/:childId/profile — XP, DON, Level, Status, Streak, Achievements
   */
  fastify.get<{ Params: { childId: string } }>(
    '/children/:childId/profile',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.parentId !== userId && child.childUserId !== userId) {
        return reply.code(403).send({ error: 'Forbidden' });
      }

      const profile = await getOrCreateProfile(childId);
      return reply.send(profile);
    },
  );

  /**
   * POST /api/children/:childId/xp-events — XP/DON qo'shish (append-only)
   * Profile counter avtomatik yangilanadi. Streak avtomatik hisoblanadi.
   */
  fastify.post<{ Params: { childId: string } }>(
    '/children/:childId/xp-events',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.parentId !== userId && child.childUserId !== userId) {
        return reply.code(403).send({ error: 'Forbidden' });
      }

      const parsed = xpEventCreateSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
      }

      const profile = await getOrCreateProfile(childId);
      const { newStreak } = calculateNewStreak(profile.lastActivityDate, profile.streakDays);

      const newXp = profile.xp + parsed.data.xpDelta;
      const newDon = profile.donBalance + parsed.data.donDelta;
      const newLevel = levelForXp(newXp);
      const newStatus = statusForXp(newXp);

      // Transaction: event + profile update
      const [event, updatedProfile] = await prisma.$transaction([
        prisma.xpEvent.create({
          data: {
            childId,
            type: parsed.data.type,
            xpDelta: parsed.data.xpDelta,
            donDelta: parsed.data.donDelta,
            relatedId: parsed.data.relatedId,
            source: parsed.data.source as object | undefined,
          },
        }),
        prisma.childProfile.update({
          where: { childId },
          data: {
            xp: newXp,
            donBalance: newDon,
            level: newLevel,
            status: newStatus,
            streakDays: newStreak,
            lastActivityDate: new Date(),
          },
        }),
      ]);

      await writeAudit(request, 'xp_event', 'CREATE', event.id, parsed.data);
      emitToChild(childId, 'profile:updated', updatedProfile);

      return reply.code(201).send({ event, profile: updatedProfile });
    },
  );

  /**
   * GET /api/children/:childId/xp-events — history
   */
  fastify.get<{
    Params: { childId: string };
    Querystring: { type?: string; limit?: number };
  }>('/children/:childId/xp-events', async (request, reply) => {
    const userId = request.user!.userId;
    const { childId } = request.params;

    const child = await prisma.child.findUnique({ where: { id: childId } });
    if (!child) return reply.code(404).send({ error: 'Child not found' });
    if (child.parentId !== userId && child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    const parsed = xpEventsListSchema.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid query', details: parsed.error.format() });
    }

    const { type, limit } = parsed.data;

    const events = await prisma.xpEvent.findMany({
      where: { childId, ...(type && { type }) },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    return reply.send({ events, count: events.length });
  });
};
