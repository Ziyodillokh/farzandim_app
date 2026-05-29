import { FastifyPluginAsync } from 'fastify';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { staffAuthGuard } from '../../middleware/staff-auth';
import { requirePermission } from '../../middleware/require-permission';

// ─── Helpers ───────────────────────────────────────────────────────

const MONTH_LABELS_UZ = ['Yan', 'Fev', 'Mar', 'Apr', 'May', 'Iyn', 'Iyl', 'Avg', 'Sen', 'Okt', 'Noy', 'Dek'];

function startOfMonth(d: Date): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1));
}

function startOfNextMonth(d: Date): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1));
}

function lastNMonths(n: number, until: Date = new Date()): Date[] {
  const cur = startOfMonth(until);
  const out: Date[] = [];
  for (let i = n - 1; i >= 0; i -= 1) {
    out.push(new Date(Date.UTC(cur.getUTCFullYear(), cur.getUTCMonth() - i, 1)));
  }
  return out;
}

function fmtMonth(d: Date): string {
  return MONTH_LABELS_UZ[d.getUTCMonth()] ?? String(d.getUTCMonth() + 1);
}

function pct(part: number, whole: number): number {
  if (whole <= 0) return 0;
  return Number(((part / whole) * 100).toFixed(1));
}

// ─── Routes ────────────────────────────────────────────────────────

export const adminAnalyticsRoutes: FastifyPluginAsync = async (fastify) => {
  // Sprint 6 — RBAC: butun modul auth + permission tekshiruvidan o'tadi.
  fastify.addHook('preHandler', staffAuthGuard);
  fastify.addHook('preHandler', requirePermission('view_analytics'));

  // ─── GET /admin/analytics — umumiy snapshot ─────────────────────
  fastify.get('/', { preHandler: staffAuthGuard }, async (_request, reply) => {
    const [parents, children, moderators, plans, promocodes, paymentsAgg, broadcastsCount, olympiads, attempts] =
      await Promise.all([
        prisma.user.count({ where: { role: 'PARENT' } }),
        prisma.child.count(),
        prisma.moderator.count(),
        prisma.plan.count({ where: { isActive: true } }),
        prisma.promocode.count(),
        prisma.payment.aggregate({
          where: { status: 'success' },
          _sum: { amount: true },
          _count: { _all: true },
        }),
        prisma.adminNotification.count(),
        prisma.olympiad.count(),
        prisma.olympiadAttempt.count(),
      ]);

    return reply.send({
      users: { parents, children, total: parents + children },
      moderators,
      plans,
      promocodes,
      payments: {
        total: paymentsAgg._count._all,
        revenue: paymentsAgg._sum.amount ?? 0,
      },
      notifications: { broadcasts: broadcastsCount },
      olympiads: { total: olympiads, attempts },
    });
  });

  // ─── GET /admin/analytics/monetization — Analitika sahifa ───────
  // PDF "Daromad tahlili" shaklida MonetizationVm qaytaradi.
  fastify.get('/monetization', { preHandler: staffAuthGuard }, async (_request, reply) => {
    const now = new Date();
    const months = lastNMonths(6, now);
    const firstMonth = months[0]!;

    // 1) Total / avg revenue + paying users
    const [allRevenueAgg, periodRevenueAgg, plans, parents, children] = await Promise.all([
      prisma.payment.aggregate({
        where: { status: 'success' },
        _sum: { amount: true },
      }),
      prisma.payment.aggregate({
        where: { status: 'success', createdAt: { gte: firstMonth } },
        _sum: { amount: true },
      }),
      prisma.plan.findMany({
        orderBy: [{ sortOrder: 'asc' }],
      }),
      prisma.user.count({ where: { role: 'PARENT' } }),
      prisma.child.count(),
    ]);

    const totalRevenue = periodRevenueAgg._sum.amount ?? 0; // 6-oy davri
    const totalUsersAll = parents + children;
    const avgMonthlyRevenue = Math.round(totalRevenue / 6);

    // 2) Distinct paying users (status=success) — payingPercent uchun
    const distinctPayingUsers = await prisma.payment.findMany({
      where: { status: 'success', userId: { not: null } },
      distinct: ['userId'],
      select: { userId: true },
    });
    const payingUsers = distinctPayingUsers.length;
    const payingPercent = pct(payingUsers, totalUsersAll);

    // 3) Monthly revenue (last 6 months)
    const monthAggs = await Promise.all(
      months.map((m) =>
        prisma.payment.aggregate({
          where: {
            status: 'success',
            createdAt: { gte: m, lt: startOfNextMonth(m) },
          },
          _sum: { amount: true },
        }),
      ),
    );
    const monthlyRevenue = months.map((m, i) => ({
      label: fmtMonth(m),
      amount: monthAggs[i]?._sum.amount ?? 0,
    }));

    // 4) Plan distribution (paying-user count per plan + non-paying as Bepul)
    const successPayments = await prisma.payment.findMany({
      where: { status: 'success' },
      select: { userId: true, planId: true },
    });
    const paidUsersByPlan = new Map<string, Set<string>>();
    for (const p of successPayments) {
      if (!p.planId || !p.userId) continue;
      const set = paidUsersByPlan.get(p.planId) ?? new Set<string>();
      set.add(p.userId);
      paidUsersByPlan.set(p.planId, set);
    }
    const planCounts = new Map<string, number>();
    plans.forEach((pl) => planCounts.set(pl.id, paidUsersByPlan.get(pl.id)?.size ?? 0));
    const paidUsersTotal = new Set<string>(
      successPayments.filter((p) => p.userId).map((p) => p.userId as string),
    ).size;
    const bepulPlan = plans.find((p) => p.slug === 'bepul') ?? plans.find((p) => p.priceUzs === 0);
    if (bepulPlan) {
      planCounts.set(bepulPlan.id, Math.max(0, totalUsersAll - paidUsersTotal));
    }
    const planDistribution = plans.map((pl) => ({
      key: pl.slug,
      label: pl.name,
      count: planCounts.get(pl.id) ?? 0,
      percent: pct(planCounts.get(pl.id) ?? 0, totalUsersAll),
    }));

    // 5) Subscription growth (last 6 months) — new paying users per plan per month
    const growthRows = await prisma.payment.findMany({
      where: { status: 'success', createdAt: { gte: firstMonth }, userId: { not: null } },
      select: { userId: true, planId: true, createdAt: true },
      orderBy: { createdAt: 'asc' },
    });
    const slugOfPlan = new Map(plans.map((p) => [p.id, p.slug]));
    const seenUsers = new Set<string>();
    const monthBuckets = months.map((m) => ({
      label: fmtMonth(m),
      bepul: 0,
      oylik: 0,
      yillik: 0,
    }));
    for (const r of growthRows) {
      if (!r.userId || !r.planId) continue;
      if (seenUsers.has(r.userId)) continue;
      seenUsers.add(r.userId);
      const slug = slugOfPlan.get(r.planId);
      const idx = months.findIndex((m, i) => {
        const next = i < months.length - 1 ? months[i + 1]! : startOfNextMonth(m);
        return r.createdAt >= m && r.createdAt < next;
      });
      if (idx === -1) continue;
      const bucket = monthBuckets[idx]!;
      if (slug === 'oylik') bucket.oylik += 1;
      else if (slug === 'yillik') bucket.yillik += 1;
      else if (slug === 'bepul') bucket.bepul += 1;
    }
    // "Bepul" tarifga o'tgan yangi user'lar (hech qanday to'lov qilmaganlar)
    const monthlyNewUsersAgg = await Promise.all(
      months.map((m) =>
        prisma.user.count({
          where: { role: 'PARENT', createdAt: { gte: m, lt: startOfNextMonth(m) } },
        }),
      ),
    );
    monthBuckets.forEach((b, i) => {
      const newUsers = monthlyNewUsersAgg[i] ?? 0;
      const subsThisMonth = b.oylik + b.yillik;
      b.bepul = Math.max(b.bepul, newUsers - subsThisMonth);
    });
    const subscriptionGrowth = monthBuckets;

    // 6) Revenue by plan (horizontal bar)
    const revenueByPlanAggs = await Promise.all(
      plans.map((pl) =>
        prisma.payment.aggregate({
          where: { status: 'success', planId: pl.id },
          _sum: { amount: true },
        }),
      ),
    );
    const revenueByPlan = plans.map((pl, i) => ({
      key: pl.slug,
      label: pl.name,
      amount: revenueByPlanAggs[i]?._sum.amount ?? 0,
    }));
    const revenueByPlanTotal = revenueByPlan.reduce((a, b) => a + b.amount, 0);

    return reply.send({
      totalRevenue,
      totalUsers: totalUsersAll,
      avgMonthlyRevenue,
      payingPercent,
      monthlyRevenue,
      planDistribution,
      subscriptionGrowth,
      revenueByPlan,
      revenueByPlanTotal,
      lastUpdated: now.toISOString(),
    });
  });

  // ─── GET /admin/analytics/videos — content stats (placeholder) ──
  // Video content modeli hali yo'q (Sprint 5.6+). Hozircha VideoMessage'lar
  // bo'yicha sodda aggregatsiya qaytaradi.
  fastify.get('/videos', { preHandler: staffAuthGuard }, async (_request, reply) => {
    const [totalSent, last7d, biggestSenders] = await Promise.all([
      prisma.videoMessage.count(),
      prisma.videoMessage.count({
        where: { createdAt: { gte: new Date(Date.now() - 7 * 86_400_000) } },
      }),
      prisma.videoMessage.groupBy({
        by: ['senderId'],
        _count: { _all: true },
        orderBy: { _count: { senderId: 'desc' } },
        take: 5,
      }),
    ]);

    return reply.send({
      totalSent,
      lastWeek: last7d,
      topSenders: biggestSenders.map((s) => ({ userId: s.senderId, count: s._count._all })),
      note: 'Content video modeli hali yo\'q (Sprint 5.6+). Hozir VideoMessage chat akselleratori.',
    });
  });
};
