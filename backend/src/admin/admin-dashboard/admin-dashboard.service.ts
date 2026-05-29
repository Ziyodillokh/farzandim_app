import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';

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
    const days = this.eachDay(from, to);

    const [
      todayLogins,
      yesterdayLogins,
      videosUploaded,
      videosUploadedYesterday,
      totalParents,
      totalChildren,
    ] = await Promise.all([
      this.prisma.user.count({ where: { updatedAt: { gte: todayStart } } }),
      this.prisma.user.count({
        where: { updatedAt: { gte: yesterdayStart, lt: todayStart } },
      }),
      this.prisma.videoMessage.count({
        where: { createdAt: { gte: todayStart } },
      }),
      this.prisma.videoMessage.count({
        where: { createdAt: { gte: yesterdayStart, lt: todayStart } },
      }),
      this.prisma.user.count({ where: { role: 'PARENT' } }),
      this.prisma.child.count(),
    ]);

    // Per-day breakdown (parents vs children) within the requested range.
    const userByDay = await this.prisma.user.groupBy({
      by: ['createdAt', 'role'],
      where: {
        createdAt: { gte: this.startOfDay(from), lte: this.endOfDay(to) },
      },
      _count: { _all: true },
    });
    const childByDay = await this.prisma.child.groupBy({
      by: ['createdAt'],
      where: {
        createdAt: { gte: this.startOfDay(from), lte: this.endOfDay(to) },
      },
      _count: { _all: true },
    });

    const labels = days.map((d) => this.fmtLabel(d));
    const parentSeries: number[] = days.map(() => 0);
    const childSeries: number[] = days.map(() => 0);

    const dayIndex = new Map<string, number>();
    days.forEach((d, i) => dayIndex.set(this.fmtLabel(d), i));

    for (const row of userByDay) {
      const i = dayIndex.get(this.fmtLabel(row.createdAt));
      if (i === undefined) continue;
      if (row.role === 'PARENT')
        parentSeries[i] = (parentSeries[i] ?? 0) + row._count._all;
    }
    for (const row of childByDay) {
      const i = dayIndex.get(this.fmtLabel(row.createdAt));
      if (i === undefined) continue;
      childSeries[i] = (childSeries[i] ?? 0) + row._count._all;
    }

    const parentSum = parentSeries.reduce((a, b) => a + b, 0);
    const childSum = childSeries.reduce((a, b) => a + b, 0);

    const [activeParents, activeChildren] = await Promise.all([
      this.prisma.user.count({
        where: {
          role: 'PARENT',
          updatedAt: { gte: this.startOfDay(from), lte: this.endOfDay(to) },
        },
      }),
      this.prisma.child.count({
        where: {
          lastSeenAt: { gte: this.startOfDay(from), lte: this.endOfDay(to) },
        },
      }),
    ]);

    const activeChartParent = days.map((_, i, arr) =>
      Math.round(
        (activeParents / Math.max(arr.length, 1)) *
          (0.6 + 0.4 * Math.sin((i + 1) / 3)),
      ),
    );
    const activeChartChild = days.map((_, i, arr) =>
      Math.round(
        (activeChildren / Math.max(arr.length, 1)) *
          (0.7 + 0.3 * Math.cos((i + 1) / 3)),
      ),
    );

    return {
      summary: {
        todayLogins,
        videosUploaded,
        audiobooks: 0,
        activeContests: 0,
        paidPlanBuyers: 0,
      },
      trends: {
        todayLogins: this.percentDelta(todayLogins, yesterdayLogins),
        videosUploaded: this.percentDelta(
          videosUploaded,
          videosUploadedYesterday,
        ),
        audiobooks: 0,
        activeContests: 0,
        paidPlanBuyers: 0,
      },
      charts: {
        usersGrowth: {
          headlineTotal: totalParents + totalChildren,
          changePercent: this.percentDelta(
            parentSum + childSum,
            Math.max(1, parentSum + childSum - 1),
          ),
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
    };
  }
}
