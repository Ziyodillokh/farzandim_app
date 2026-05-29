import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';

const MONTH_LABELS_UZ = [
  'Yan', 'Fev', 'Mar', 'Apr', 'May', 'Iyn',
  'Iyl', 'Avg', 'Sen', 'Okt', 'Noy', 'Dek',
];

@Injectable()
export class AdminAnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  private startOfMonth(d: Date): Date {
    return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1));
  }

  private startOfNextMonth(d: Date): Date {
    return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1));
  }

  private lastNMonths(n: number, until: Date = new Date()): Date[] {
    const cur = this.startOfMonth(until);
    const out: Date[] = [];
    for (let i = n - 1; i >= 0; i -= 1) {
      out.push(new Date(Date.UTC(cur.getUTCFullYear(), cur.getUTCMonth() - i, 1)));
    }
    return out;
  }

  private fmtMonth(d: Date): string {
    return MONTH_LABELS_UZ[d.getUTCMonth()] ?? String(d.getUTCMonth() + 1);
  }

  private pct(part: number, whole: number): number {
    if (whole <= 0) return 0;
    return Number(((part / whole) * 100).toFixed(1));
  }

  async getUserGrowth(query: { from?: string; to?: string; months?: number }) {
    const n = query.months ?? 6;
    const now = new Date();
    const months = this.lastNMonths(n, now);

    const monthlyData = await Promise.all(
      months.map(async (m) => {
        const nextMonth = this.startOfNextMonth(m);
        const [parents, children] = await Promise.all([
          this.prisma.user.count({
            where: { role: 'PARENT', createdAt: { gte: m, lt: nextMonth } },
          }),
          this.prisma.child.count({
            where: { createdAt: { gte: m, lt: nextMonth } },
          }),
        ]);
        return { label: this.fmtMonth(m), parents, children };
      }),
    );

    const [totalParents, totalChildren] = await Promise.all([
      this.prisma.user.count({ where: { role: 'PARENT' } }),
      this.prisma.child.count(),
    ]);

    return {
      totalUsers: totalParents + totalChildren,
      totalParents,
      totalChildren,
      monthly: monthlyData,
    };
  }

  async getEngagement(query: { from?: string; to?: string }) {
    const now = new Date();
    const weekAgo = new Date(now.getTime() - 7 * 86_400_000);
    const monthAgo = new Date(now.getTime() - 30 * 86_400_000);

    const [activeWeek, activeMonth, totalParents, totalChildren] =
      await Promise.all([
        this.prisma.user.count({
          where: { role: 'PARENT', updatedAt: { gte: weekAgo } },
        }),
        this.prisma.user.count({
          where: { role: 'PARENT', updatedAt: { gte: monthAgo } },
        }),
        this.prisma.user.count({ where: { role: 'PARENT' } }),
        this.prisma.child.count({ where: { lastSeenAt: { gte: weekAgo } } }),
      ]);

    return {
      activeParentsWeek: activeWeek,
      activeParentsMonth: activeMonth,
      activeChildrenWeek: totalChildren,
      weeklyRetentionRate: this.pct(activeWeek, totalParents),
      monthlyRetentionRate: this.pct(activeMonth, totalParents),
    };
  }

  /**
   * GET /admin/analytics — general snapshot.
   */
  async getOverview() {
    const [
      parents,
      children,
      moderators,
      plans,
      promocodes,
      paymentsAgg,
      broadcastsCount,
      olympiads,
      attempts,
    ] = await Promise.all([
      this.prisma.user.count({ where: { role: 'PARENT' } }),
      this.prisma.child.count(),
      this.prisma.moderator.count(),
      this.prisma.plan.count({ where: { isActive: true } }),
      this.prisma.promocode.count(),
      this.prisma.payment.aggregate({
        where: { status: 'success' },
        _sum: { amount: true },
        _count: { _all: true },
      }),
      this.prisma.adminNotification.count(),
      this.prisma.olympiad.count(),
      this.prisma.olympiadAttempt.count(),
    ]);

    return {
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
    };
  }

  /**
   * GET /admin/analytics/monetization — "Daromad tahlili" view.
   */
  async getMonetization() {
    const now = new Date();
    const months = this.lastNMonths(6, now);
    const firstMonth = months[0]!;

    const [allRevenueAgg, periodRevenueAgg, plans, parents, children] =
      await Promise.all([
        this.prisma.payment.aggregate({
          where: { status: 'success' },
          _sum: { amount: true },
        }),
        this.prisma.payment.aggregate({
          where: { status: 'success', createdAt: { gte: firstMonth } },
          _sum: { amount: true },
        }),
        this.prisma.plan.findMany({ orderBy: [{ sortOrder: 'asc' }] }),
        this.prisma.user.count({ where: { role: 'PARENT' } }),
        this.prisma.child.count(),
      ]);

    void allRevenueAgg; // total all-time not currently returned, parity with Fastify
    const totalRevenue = periodRevenueAgg._sum.amount ?? 0;
    const totalUsersAll = parents + children;
    const avgMonthlyRevenue = Math.round(totalRevenue / 6);

    const distinctPayingUsers = await this.prisma.payment.findMany({
      where: { status: 'success', userId: { not: null } },
      distinct: ['userId'],
      select: { userId: true },
    });
    const payingUsers = distinctPayingUsers.length;
    const payingPercent = this.pct(payingUsers, totalUsersAll);

    const monthAggs = await Promise.all(
      months.map((m) =>
        this.prisma.payment.aggregate({
          where: {
            status: 'success',
            createdAt: { gte: m, lt: this.startOfNextMonth(m) },
          },
          _sum: { amount: true },
        }),
      ),
    );
    const monthlyRevenue = months.map((m, i) => ({
      label: this.fmtMonth(m),
      amount: monthAggs[i]?._sum.amount ?? 0,
    }));

    const successPayments = await this.prisma.payment.findMany({
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
    plans.forEach((pl) =>
      planCounts.set(pl.id, paidUsersByPlan.get(pl.id)?.size ?? 0),
    );
    const paidUsersTotal = new Set<string>(
      successPayments
        .filter((p) => p.userId)
        .map((p) => p.userId as string),
    ).size;
    const bepulPlan =
      plans.find((p) => p.slug === 'bepul') ??
      plans.find((p) => p.priceUzs === 0);
    if (bepulPlan) {
      planCounts.set(
        bepulPlan.id,
        Math.max(0, totalUsersAll - paidUsersTotal),
      );
    }
    const planDistribution = plans.map((pl) => ({
      key: pl.slug,
      label: pl.name,
      count: planCounts.get(pl.id) ?? 0,
      percent: this.pct(planCounts.get(pl.id) ?? 0, totalUsersAll),
    }));

    const growthRows = await this.prisma.payment.findMany({
      where: {
        status: 'success',
        createdAt: { gte: firstMonth },
        userId: { not: null },
      },
      select: { userId: true, planId: true, createdAt: true },
      orderBy: { createdAt: 'asc' },
    });
    const slugOfPlan = new Map(plans.map((p) => [p.id, p.slug]));
    const seenUsers = new Set<string>();
    const monthBuckets = months.map((m) => ({
      label: this.fmtMonth(m),
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
        const next =
          i < months.length - 1 ? months[i + 1]! : this.startOfNextMonth(m);
        return r.createdAt >= m && r.createdAt < next;
      });
      if (idx === -1) continue;
      const bucket = monthBuckets[idx]!;
      if (slug === 'oylik') bucket.oylik += 1;
      else if (slug === 'yillik') bucket.yillik += 1;
      else if (slug === 'bepul') bucket.bepul += 1;
    }
    const monthlyNewUsersAgg = await Promise.all(
      months.map((m) =>
        this.prisma.user.count({
          where: {
            role: 'PARENT',
            createdAt: { gte: m, lt: this.startOfNextMonth(m) },
          },
        }),
      ),
    );
    monthBuckets.forEach((b, i) => {
      const newUsers = monthlyNewUsersAgg[i] ?? 0;
      const subsThisMonth = b.oylik + b.yillik;
      b.bepul = Math.max(b.bepul, newUsers - subsThisMonth);
    });
    const subscriptionGrowth = monthBuckets;

    const revenueByPlanAggs = await Promise.all(
      plans.map((pl) =>
        this.prisma.payment.aggregate({
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
    const revenueByPlanTotal = revenueByPlan.reduce(
      (a, b) => a + b.amount,
      0,
    );

    return {
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
    };
  }

  /**
   * GET /admin/analytics/videos — placeholder using VideoMessage table.
   */
  async getVideoStats() {
    const [totalSent, last7d, biggestSenders] = await Promise.all([
      this.prisma.videoMessage.count(),
      this.prisma.videoMessage.count({
        where: { createdAt: { gte: new Date(Date.now() - 7 * 86_400_000) } },
      }),
      this.prisma.videoMessage.groupBy({
        by: ['senderId'],
        _count: { _all: true },
        orderBy: { _count: { senderId: 'desc' } },
        take: 5,
      }),
    ]);

    return {
      totalSent,
      lastWeek: last7d,
      topSenders: biggestSenders.map((s) => ({
        userId: s.senderId,
        count: s._count._all,
      })),
      note: "Content video model not yet present. VideoMessage chat accelerator stats only.",
    };
  }

  async getContentStats() {
    const [
      totalVideos,
      totalAudiobooks,
      totalBooks,
      totalOlympiads,
      totalAttempts,
    ] = await Promise.all([
      this.prisma.videoMessage.count(),
      this.prisma.audiobook?.count().catch(() => 0) ?? Promise.resolve(0),
      this.prisma.book?.count().catch(() => 0) ?? Promise.resolve(0),
      this.prisma.olympiad.count(),
      this.prisma.olympiadAttempt.count(),
    ]);

    return {
      totalVideos,
      totalAudiobooks,
      totalBooks,
      totalOlympiads,
      totalAttempts,
    };
  }
}
