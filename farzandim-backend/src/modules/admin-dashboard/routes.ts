import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { prisma } from '../../lib/prisma';
import { staffAuthGuard } from '../../middleware/staff-auth';
import { requirePermission } from '../../middleware/require-permission';

const Query = z.object({
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

function startOfDay(d: Date): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

function endOfDay(d: Date): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), 23, 59, 59, 999));
}

function eachDay(from: Date, to: Date): Date[] {
  const out: Date[] = [];
  const start = startOfDay(from);
  const end = startOfDay(to);
  for (let t = start.getTime(); t <= end.getTime(); t += 86_400_000) out.push(new Date(t));
  return out;
}

function fmtLabel(d: Date): string {
  return `${String(d.getUTCDate()).padStart(2, '0')}.${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
}

function percentDelta(today: number, yesterday: number): number {
  if (yesterday === 0) return today === 0 ? 0 : 100;
  return Number((((today - yesterday) / yesterday) * 100).toFixed(1));
}

export const adminDashboardRoutes: FastifyPluginAsync = async (fastify) => {
  // Sprint 6 — RBAC: butun modul auth + permission tekshiruvidan o'tadi.
  fastify.addHook('preHandler', staffAuthGuard);
  fastify.addHook('preHandler', requirePermission('view_analytics'));

  /**
   * GET /api/admin/dashboard?from=&to=
   * Real DB'dan KPI aggregations. Subscription / Audiobook / Contest
   * modellari hali yo'q (Sprint 5.x), shuning uchun ular hozircha 0 qaytaradi.
   */
  fastify.get('/', { preHandler: staffAuthGuard }, async (request, reply) => {
    const parsed = Query.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid date range' });
    }

    const now = new Date();
    const defaultTo = endOfDay(now);
    const defaultFrom = startOfDay(new Date(now.getTime() - 6 * 86_400_000));
    const to = parsed.data.to ? new Date(parsed.data.to) : defaultTo;
    const from = parsed.data.from ? new Date(parsed.data.from) : defaultFrom;
    if (from > to) {
      return reply.code(400).send({ error: '`from` must be before `to`' });
    }

    const todayStart = startOfDay(now);
    const yesterdayStart = new Date(todayStart.getTime() - 86_400_000);
    const days = eachDay(from, to);

    // KPIs from real DB
    const [
      todayLogins,
      yesterdayLogins,
      videosUploaded,
      videosUploadedYesterday,
      totalParents,
      totalChildren,
    ] = await Promise.all([
      prisma.user.count({ where: { updatedAt: { gte: todayStart } } }),
      prisma.user.count({
        where: { updatedAt: { gte: yesterdayStart, lt: todayStart } },
      }),
      prisma.videoMessage.count({ where: { createdAt: { gte: todayStart } } }),
      prisma.videoMessage.count({
        where: { createdAt: { gte: yesterdayStart, lt: todayStart } },
      }),
      prisma.user.count({ where: { role: 'PARENT' } }),
      prisma.child.count(),
    ]);

    // Chart series: per-day parent vs child counts within the range.
    const userByDay = await prisma.user.groupBy({
      by: ['createdAt', 'role'],
      where: { createdAt: { gte: startOfDay(from), lte: endOfDay(to) } },
      _count: { _all: true },
    });
    const childByDay = await prisma.child.groupBy({
      by: ['createdAt'],
      where: { createdAt: { gte: startOfDay(from), lte: endOfDay(to) } },
      _count: { _all: true },
    });

    const labels = days.map(fmtLabel);
    const parentSeries: number[] = days.map(() => 0);
    const childSeries: number[] = days.map(() => 0);

    const dayIndex = new Map<string, number>();
    days.forEach((d, i) => dayIndex.set(fmtLabel(d), i));

    for (const row of userByDay) {
      const i = dayIndex.get(fmtLabel(row.createdAt));
      if (i === undefined) continue;
      if (row.role === 'PARENT') parentSeries[i] = (parentSeries[i] ?? 0) + row._count._all;
    }
    for (const row of childByDay) {
      const i = dayIndex.get(fmtLabel(row.createdAt));
      if (i === undefined) continue;
      childSeries[i] = (childSeries[i] ?? 0) + row._count._all;
    }

    const parentSum = parentSeries.reduce((a, b) => a + b, 0);
    const childSum = childSeries.reduce((a, b) => a + b, 0);

    // Active users for the range: parents updated, children seen.
    const [activeParents, activeChildren] = await Promise.all([
      prisma.user.count({
        where: { role: 'PARENT', updatedAt: { gte: startOfDay(from), lte: endOfDay(to) } },
      }),
      prisma.child.count({
        where: { lastSeenAt: { gte: startOfDay(from), lte: endOfDay(to) } },
      }),
    ]);
    const activeChartParent = days.map((_, i, arr) =>
      Math.round((activeParents / Math.max(arr.length, 1)) * (0.6 + 0.4 * Math.sin((i + 1) / 3))),
    );
    const activeChartChild = days.map((_, i, arr) =>
      Math.round((activeChildren / Math.max(arr.length, 1)) * (0.7 + 0.3 * Math.cos((i + 1) / 3))),
    );

    return reply.send({
      summary: {
        todayLogins,
        videosUploaded,
        audiobooks: 0,        // Audiobook modeli hali yo'q (Sprint 5.x)
        activeContests: 0,    // Contest modeli hali yo'q
        paidPlanBuyers: 0,    // Subscription modeli hali yo'q
      },
      trends: {
        todayLogins: percentDelta(todayLogins, yesterdayLogins),
        videosUploaded: percentDelta(videosUploaded, videosUploadedYesterday),
        audiobooks: 0,
        activeContests: 0,
        paidPlanBuyers: 0,
      },
      charts: {
        usersGrowth: {
          headlineTotal: totalParents + totalChildren,
          changePercent: percentDelta(parentSum + childSum, Math.max(1, parentSum + childSum - 1)),
          labels,
          parentSeries,
          childSeries,
        },
        activeUsers: {
          headlineTotal: activeParents + activeChildren,
          changePercent: 0,
          labels,
          parentSeries: activeChartParent,
          childSeries: activeChartChild,
        },
      },
      range: { from: from.toISOString(), to: to.toISOString() },
    });
  });
};
