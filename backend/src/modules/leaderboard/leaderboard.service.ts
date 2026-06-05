import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { LeaderboardPeriod } from './dto/leaderboard-query.dto';

export interface LeaderboardEntry {
  rank: number;
  childId: string;
  name: string;
  region: string;
  xp: number;
}

export interface LeaderboardResult {
  entries: LeaderboardEntry[];
  total: number;
  hasMore: boolean;
  currentChild: LeaderboardEntry | null;
  period: LeaderboardPeriod;
}

/**
 * XP reyting (leaderboard).
 *   - all       → ChildProfile.xp (jami) bo'yicha (samarali skip/take).
 *   - weekly/monthly → XpEvent.xpDelta yig'indisi (oxirgi 7/30 kun) bo'yicha.
 * Viloyat filtri (Child.region) + pagination + joriy bolaning o'rni ("Siz").
 * Reyting XP'dan hisoblanadi; XP test (olympiad) yechilganda beriladi.
 * Schema o'zgartirilmaydi — mavjud ChildProfile/XpEvent/Child modellaridan.
 */
@Injectable()
export class LeaderboardService {
  constructor(private readonly prisma: PrismaService) {}

  async getLeaderboard(opts: {
    period: LeaderboardPeriod;
    region?: string;
    page: number;
    limit: number;
    childId?: string;
  }): Promise<LeaderboardResult> {
    const { period, region, page, limit, childId } = opts;
    const skip = (page - 1) * limit;

    if (period === LeaderboardPeriod.all) {
      return this.allTime({ region, skip, limit, page, childId });
    }
    return this.periodRange({ period, region, skip, limit, page, childId });
  }

  /** Butun davr — ChildProfile.xp bo'yicha (samarali). */
  private async allTime(o: {
    region?: string;
    skip: number;
    limit: number;
    page: number;
    childId?: string;
  }): Promise<LeaderboardResult> {
    const { region, skip, limit, page, childId } = o;
    const childRel = region ? { child: { is: { region } } } : {};

    const total = await this.prisma.childProfile.count({ where: { ...childRel } });

    const profiles = await this.prisma.childProfile.findMany({
      where: { ...childRel },
      orderBy: [{ xp: 'desc' }, { childId: 'asc' }],
      skip,
      take: limit,
      include: { child: { select: { id: true, name: true, region: true } } },
    });

    const entries: LeaderboardEntry[] = profiles.map((p, i) => ({
      rank: skip + i + 1,
      childId: p.childId,
      name: p.child.name,
      region: p.child.region ?? '',
      xp: p.xp,
    }));

    let currentChild: LeaderboardEntry | null = null;
    if (childId) {
      const my = await this.prisma.childProfile.findUnique({
        where: { childId },
        include: { child: { select: { name: true, region: true } } },
      });
      // Region filtri faol bo'lsa va bola o'sha viloyatda bo'lmasa, "Siz"ni
      // ko'rsatmaymiz (uni o'zi tegishli bo'lmagan viloyat reytingida
      // joylashtirish noto'g'ri bo'lardi).
      const regionMismatch =
        region != null && (my?.child.region ?? '') !== region;
      if (my && !regionMismatch) {
        // List tartibiga mos ketma-ket o'rin (xp desc, childId asc tiebreaker).
        const before = await this.prisma.childProfile.count({
          where: {
            ...childRel,
            OR: [
              { xp: { gt: my.xp } },
              { xp: my.xp, childId: { lt: childId } },
            ],
          },
        });
        currentChild = {
          rank: before + 1,
          childId,
          name: my.child.name,
          region: my.child.region ?? '',
          xp: my.xp,
        };
      }
    }

    return {
      entries,
      total,
      hasMore: skip + entries.length < total,
      currentChild,
      period: LeaderboardPeriod.all,
    };
  }

  /** Haftalik/oylik — XpEvent yig'indisi (oxirgi 7/30 kun). */
  private async periodRange(o: {
    period: LeaderboardPeriod;
    region?: string;
    skip: number;
    limit: number;
    page: number;
    childId?: string;
  }): Promise<LeaderboardResult> {
    const { period, region, skip, limit, childId } = o;
    const days = period === LeaderboardPeriod.weekly ? 7 : 30;
    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

    const grouped = await this.prisma.xpEvent.groupBy({
      by: ['childId'],
      where: { createdAt: { gte: since } },
      _sum: { xpDelta: true },
      orderBy: { _sum: { xpDelta: 'desc' } },
    });

    const ids = grouped.map((g) => g.childId);
    const children = await this.prisma.child.findMany({
      where: { id: { in: ids }, ...(region ? { region } : {}) },
      select: { id: true, name: true, region: true },
    });
    const childMap = new Map(children.map((c) => [c.id, c]));

    // Region filtridan o'tgan bolalar, ketma-ket reyting.
    const ranked = grouped
      .filter((g) => childMap.has(g.childId))
      .map((g) => {
        const c = childMap.get(g.childId)!;
        return {
          childId: g.childId,
          name: c.name,
          region: c.region ?? '',
          xp: g._sum.xpDelta ?? 0,
        };
      });

    const total = ranked.length;
    const entries: LeaderboardEntry[] = ranked
      .slice(skip, skip + limit)
      .map((r, i) => ({ rank: skip + i + 1, ...r }));

    let currentChild: LeaderboardEntry | null = null;
    if (childId) {
      const idx = ranked.findIndex((r) => r.childId === childId);
      if (idx >= 0) {
        currentChild = { rank: idx + 1, ...ranked[idx] };
      } else {
        // Bu davrda XP yo'q — 0 bilan (faqat region mos kelsa; aks holda
        // boshqa viloyatda "Siz"ni ko'rsatmaymiz).
        const c = await this.prisma.child.findUnique({
          where: { id: childId },
          select: { name: true, region: true },
        });
        if (c && (!region || (c.region ?? '') === region)) {
          currentChild = {
            rank: 0,
            childId,
            name: c.name,
            region: c.region ?? '',
            xp: 0,
          };
        }
      }
    }

    return {
      entries,
      total,
      hasMore: skip + entries.length < total,
      currentChild,
      period,
    };
  }
}
