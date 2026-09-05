import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { activeSubscriptionWhere } from '../../common/subscription/active-subscription';

@Injectable()
export class AdminDashboardService {
  constructor(private readonly prisma: PrismaService) {}

  private startOfDay(d: Date): Date {
    return new Date(
      Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()),
    );
  }

  private endOfDay(d: Date): Date {
    return new Date(
      Date.UTC(
        d.getUTCFullYear(),
        d.getUTCMonth(),
        d.getUTCDate(),
        23,
        59,
        59,
        999,
      ),
    );
  }

  private eachDay(from: Date, to: Date): Date[] {
    const out: Date[] = [];
    const start = this.startOfDay(from);
    const end = this.startOfDay(to);
    for (let t = start.getTime(); t <= end.getTime(); t += 86_400_000)
      out.push(new Date(t));
    return out;
  }

  private fmtLabel(d: Date): string {
    return `${String(d.getUTCDate()).padStart(2, '0')}.${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
  }

  private percentDelta(today: number, yesterday: number): number {
    if (yesterday === 0) return today === 0 ? 0 : 100;
    return Number((((today - yesterday) / yesterday) * 100).toFixed(1));
  }

  async getStats(fromParam?: string, toParam?: string) {
    const now = new Date();
    const defaultTo = this.endOfDay(now);
    const defaultFrom = this.startOfDay(
      new Date(now.getTime() - 6 * 86_400_000),
    );
    const to = toParam ? new Date(toParam) : defaultTo;
    const from = fromParam ? new Date(fromParam) : defaultFrom;

    const todayStart = this.startOfDay(now);
    const yesterdayStart = new Date(todayStart.getTime() - 86_400_000);
    const weekAgoStart = new Date(todayStart.getTime() - 7 * 86_400_000);
    const days = this.eachDay(from, to);

    const rangeStart = this.startOfDay(from);
    const rangeEnd = this.endOfDay(to);
    const labels = days.map((d) => this.fmtLabel(d));
    const dayIndex = new Map<string, number>();
    days.forEach((d, i) => dayIndex.set(this.fmtLabel(d), i));

    const [
      todayLogins,
      yesterdayLogins,
      videosUploaded,
      videosBeforeWeek,
      totalParents,
      totalChildren,
      audiobooksCount,
      activeContests,
      paidPlanBuyers,
      userByDay,
      childByDay,
      sessions,
    ] = await Promise.all([
      // Bugun/kecha kirgan foydalanuvchilar (sessiyalar bo'yicha — real login).
      this.prisma.userSession.count({ where: { createdAt: { gte: todayStart } } }),
      this.prisma.userSession.count({
        where: { createdAt: { gte: yesterdayStart, lt: todayStart } },
      }),
      // Yuklangan videolar — JAMI son (audiobooks/konkurslar bilan izchil).
      // Avval faqat bugun yuklangan (createdAt >= todayStart) sanalardi →
      // eski videolar 0 ko'rinardi (kecha yuklangan 3 video → 0).
      this.prisma.video.count(),
      // Trend uchun — 7 kun oldingacha mavjud videolar soni (haftalik o'sish %).
      this.prisma.video.count({ where: { createdAt: { lt: weekAgoStart } } }),
      this.prisma.user.count({ where: { role: 'PARENT' } }),
      this.prisma.child.count(),
      // KPI — real qiymatlar.
      this.prisma.audiobook.count(),
      this.prisma.olympiad.count({
        where: {
          status: 'published',
          startTime: { lte: now },
          endTime: { gte: now },
        },
      }),
      this.prisma.subscription.count({ where: activeSubscriptionWhere() }),
      // Kunlik ro'yxatdan o'tish (ota-ona/bola).
      this.prisma.user.groupBy({
        by: ['createdAt', 'role'],
        where: { createdAt: { gte: rangeStart, lte: rangeEnd } },
        _count: { _all: true },
      }),
      this.prisma.child.groupBy({
        by: ['createdAt'],
        where: { createdAt: { gte: rangeStart, lte: rangeEnd } },
        _count: { _all: true },
      }),
      // Kunlik faol foydalanuvchilar (login sessiyalari + rol).
      this.prisma.userSession.findMany({
        where: { createdAt: { gte: rangeStart, lte: rangeEnd } },
        select: { createdAt: true, user: { select: { role: true } } },
      }),
    ]);

    // ─── usersGrowth: real kunlik ro'yxatdan o'tish ───
    const regParent: number[] = days.map(() => 0);
    const regChild: number[] = days.map(() => 0);
    for (const row of userByDay) {
      const i = dayIndex.get(this.fmtLabel(row.createdAt));
      if (i === undefined) continue;
      if (row.role === 'PARENT') regParent[i] += row._count._all;
      else regChild[i] += row._count._all;
    }
    for (const row of childByDay) {
      const i = dayIndex.get(this.fmtLabel(row.createdAt));
      if (i === undefined) continue;
      regChild[i] += row._count._all;
    }

    // ─── activeUsers: real kunlik login sessiyalari ───
    const actParent: number[] = days.map(() => 0);
    const actChild: number[] = days.map(() => 0);
    for (const s of sessions) {
      const i = dayIndex.get(this.fmtLabel(s.createdAt));
      if (i === undefined) continue;
      if (s.user?.role === 'PARENT') actParent[i] += 1;
      else actChild[i] += 1;
    }

    const totalUsers = totalParents + totalChildren;
    const newInRange =
      regParent.reduce((a, b) => a + b, 0) + regChild.reduce((a, b) => a + b, 0);
    const actTotals = days.map((_, i) => actParent[i]! + actChild[i]!);

    return {
      summary: {
        todayLogins,
        videosUploaded,
        audiobooks: audiobooksCount,
        activeContests,
        paidPlanBuyers,
      },
      trends: {
        todayLogins: this.percentDelta(todayLogins, yesterdayLogins),
        videosUploaded: this.percentDelta(videosUploaded, videosBeforeWeek),
        audiobooks: 0,
        activeContests: 0,
        paidPlanBuyers: 0,
      },
      charts: {
        usersGrowth: {
          headlineTotal: totalUsers,
          changePercent: this.percentDelta(
            totalUsers,
            Math.max(1, totalUsers - newInRange),
          ),
          labels,
          series: [
            { name: 'Ota-onalar', data: regParent },
            { name: 'Bolalar', data: regChild },
          ],
        },
        activeUsers: {
          headlineTotal: sessions.length,
          changePercent: this.percentDelta(
            actTotals[actTotals.length - 1] ?? 0,
            actTotals[actTotals.length - 2] ?? 0,
          ),
          labels,
          series: [
            { name: 'Ota-onalar', data: actParent },
            { name: 'Bolalar', data: actChild },
          ],
        },
      },
      range: { from: from.toISOString(), to: to.toISOString() },
    };
  }
}
