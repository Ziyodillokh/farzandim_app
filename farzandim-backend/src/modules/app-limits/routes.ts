import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { authGuard } from '../../middleware/auth';
import { prisma } from '../../lib/prisma';
import { writeAudit } from '../../lib/audit';
import { emitToChild } from '../../lib/realtime';

// AppLimit — per-package daily/weekly quota.
// Misol: com.youtube — 15 daqiqa/kun, 2 soat/hafta
// Window-based Schedule (BLOCK/ALLOW) bilan parallel ishlaydi.
//   Schedule = vaqt oraliq (21:00-07:00 BLOCK barcha)
//   AppLimit = per-package quota (YouTube/TikTok addiction)
//
// Enforcement Child App'da: AppUsage.foregroundMs >= AppLimit.dailyLimitMs → BLOCK.

const MAX_DAY_MS = 24 * 60 * 60 * 1000; // 86_400_000
const MAX_WEEK_MS = 7 * MAX_DAY_MS;

const limitMsSchema = z
  .union([z.number().int().nonnegative(), z.string().regex(/^\d+$/)])
  .transform((v) => (typeof v === 'string' ? BigInt(v) : BigInt(v)));

const createSchema = z.object({
  packageName: z.string().min(1).max(255),
  dailyLimitMs: limitMsSchema,
  weeklyLimitMs: limitMsSchema.optional(),
  isActive: z.boolean().default(true),
});

const updateSchema = z.object({
  dailyLimitMs: limitMsSchema.optional(),
  weeklyLimitMs: limitMsSchema.nullable().optional(),
  isActive: z.boolean().optional(),
});

// BigInt → number safe (Number.MAX_SAFE_INTEGER = 2^53; 1 hafta = ~6×10^8, juda xavfsiz)
function serialize(limit: {
  id: string;
  childId: string;
  packageName: string;
  dailyLimitMs: bigint;
  weeklyLimitMs: bigint | null;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    ...limit,
    dailyLimitMs: Number(limit.dailyLimitMs),
    weeklyLimitMs: limit.weeklyLimitMs === null ? null : Number(limit.weeklyLimitMs),
  };
}

function validateLimits(dailyMs: bigint, weeklyMs?: bigint | null): string | null {
  if (dailyMs < 0n || dailyMs > BigInt(MAX_DAY_MS)) {
    return `dailyLimitMs must be 0..${MAX_DAY_MS} (1 kun)`;
  }
  if (weeklyMs !== undefined && weeklyMs !== null) {
    if (weeklyMs < 0n || weeklyMs > BigInt(MAX_WEEK_MS)) {
      return `weeklyLimitMs must be 0..${MAX_WEEK_MS} (1 hafta)`;
    }
    if (weeklyMs < dailyMs) {
      return 'weeklyLimitMs cannot be less than dailyLimitMs';
    }
  }
  return null;
}

export const appLimitsRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.addHook('preHandler', authGuard);

  /**
   * GET /api/children/:childId/app-limits
   * Parent yoki paired CHILD ko'radi.
   */
  fastify.get<{ Params: { childId: string }; Querystring: { isActive?: string } }>(
    '/children/:childId/app-limits',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.parentId !== userId && child.childUserId !== userId) {
        return reply.code(403).send({ error: 'Forbidden' });
      }

      const isActiveFilter = request.query.isActive;
      const limits = await prisma.appLimit.findMany({
        where: {
          childId,
          ...(isActiveFilter !== undefined && { isActive: isActiveFilter === 'true' }),
        },
        orderBy: { packageName: 'asc' },
      });

      return reply.send({ limits: limits.map(serialize), count: limits.length });
    },
  );

  /**
   * POST /api/children/:childId/app-limits — parent only
   */
  fastify.post<{ Params: { childId: string } }>(
    '/children/:childId/app-limits',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.parentId !== userId) {
        return reply.code(403).send({ error: 'Only parent can create app limits' });
      }

      const parsed = createSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
      }

      const err = validateLimits(parsed.data.dailyLimitMs, parsed.data.weeklyLimitMs);
      if (err) return reply.code(400).send({ error: err });

      try {
        const limit = await prisma.appLimit.create({
          data: {
            childId,
            packageName: parsed.data.packageName,
            dailyLimitMs: parsed.data.dailyLimitMs,
            weeklyLimitMs: parsed.data.weeklyLimitMs ?? null,
            isActive: parsed.data.isActive,
          },
        });

        await writeAudit(request, 'app_limit', 'CREATE', limit.id, {
          packageName: limit.packageName,
        });
        emitToChild(childId, 'app_limit:created', serialize(limit));

        return reply.code(201).send(serialize(limit));
      } catch (e: unknown) {
        // Prisma unique constraint
        if (e && typeof e === 'object' && 'code' in e && e.code === 'P2002') {
          return reply.code(409).send({
            error: 'App limit already exists for this package',
            packageName: parsed.data.packageName,
          });
        }
        throw e;
      }
    },
  );

  /**
   * GET /api/app-limits/:id — single
   */
  fastify.get<{ Params: { id: string } }>('/app-limits/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const limit = await prisma.appLimit.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!limit) return reply.code(404).send({ error: 'App limit not found' });
    if (limit.child.parentId !== userId && limit.child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    const { child: _omit, ...rest } = limit;
    return reply.send(serialize(rest));
  });

  /**
   * PUT /api/app-limits/:id — parent only
   */
  fastify.put<{ Params: { id: string } }>('/app-limits/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const limit = await prisma.appLimit.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!limit) return reply.code(404).send({ error: 'App limit not found' });
    if (limit.child.parentId !== userId) {
      return reply.code(403).send({ error: 'Only parent can update' });
    }

    const parsed = updateSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
    }

    const nextDaily = parsed.data.dailyLimitMs ?? limit.dailyLimitMs;
    const nextWeekly =
      parsed.data.weeklyLimitMs === undefined ? limit.weeklyLimitMs : parsed.data.weeklyLimitMs;

    const err = validateLimits(nextDaily, nextWeekly);
    if (err) return reply.code(400).send({ error: err });

    const updated = await prisma.appLimit.update({
      where: { id },
      data: {
        ...(parsed.data.dailyLimitMs !== undefined && { dailyLimitMs: parsed.data.dailyLimitMs }),
        ...(parsed.data.weeklyLimitMs !== undefined && {
          weeklyLimitMs: parsed.data.weeklyLimitMs,
        }),
        ...(parsed.data.isActive !== undefined && { isActive: parsed.data.isActive }),
      },
    });

    await writeAudit(request, 'app_limit', 'UPDATE', id, parsed.data as object);
    emitToChild(updated.childId, 'app_limit:updated', serialize(updated));

    return reply.send(serialize(updated));
  });

  /**
   * DELETE /api/app-limits/:id — parent only
   */
  fastify.delete<{ Params: { id: string } }>('/app-limits/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const limit = await prisma.appLimit.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!limit) return reply.code(404).send({ error: 'App limit not found' });
    if (limit.child.parentId !== userId) {
      return reply.code(403).send({ error: 'Only parent can delete' });
    }

    const childIdForEmit = limit.childId;
    await prisma.appLimit.delete({ where: { id } });
    await writeAudit(request, 'app_limit', 'DELETE', id, { packageName: limit.packageName });
    emitToChild(childIdForEmit, 'app_limit:deleted', { id });

    return reply.send({ ok: true });
  });
};
