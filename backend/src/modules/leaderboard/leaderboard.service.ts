import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { LeaderboardPeriod } from './dto/leaderboard-query.dto';
import {
  maskChildName,
  visibleChildId,
} from '../../common/helpers/leaderboard-privacy';

/** `region=me` — joriy bolaning O'Z viloyati bo'yicha filtr. */
export const LEADERBOARD_REGION_ME = 'me';

/**
 * Reytingda ko'rsatiladigan eng ko'p qator (top-N). Undan chuqurroq
 * sahifalab barcha bolalarni sanab chiqish mumkin bo'lmasin (App Store
 * audit F17). Joriy bolaning o'z o'rni ("Siz") baribir qaytariladi.
 */
export const LEADERBOARD_MAX_ROWS = 100;

/** So'rovchi (JWT) — "o'z oilasi" bolalarini aniqlash uchun. */
export interface LeaderboardViewer {
  userId: string;
  role: 'PARENT' | 'CHILD';
}

export interface LeaderboardEntry {
  rank: number;
  childId: string;
  name: string;
  region: string;
  /** Yosh — bola ilovasidagi "Yosh guruhi" filtri uchun. */
  age: number | null;
  /** Jinsi ('male'|'female'|null) — default avatar (jinsi+yosh) uchun. */
  gender: string | null;
  /** Reyting SONI — DON. Ekranlarda ko'rsatiladigan yagona qiymat. */
  don: number;
  /**
   * ESKIRGAN — `don` ning eski nomi, qiymati AYNAN `don` bilan bir xil.
   *
   * Bu endpoint faqat DON reytingini beradi; haqiqiy XP (daraja/status uchun)
   * `/children/:id/profile` dan keladi. Eski APK'lar reyting sonini shu `xp`
   * maydonidan o'qiydi — bu yerga haqiqiy XP qo'yilsa, ular yana XP ko'rsatib
   * (Ali 260), panel'dagi DON (210) bilan mos kelmasdi. Alias qilib qo'ysak
   * eski APK'lar ham to'g'ri DON ko'rsatadi.
   *
   * Barcha klientlar `don` ga o'tgach olib tashlansin.
   */
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
 * DON reyting (leaderboard) — barcha ekranlar uchun YAGONA manba.
 *   - all              → ChildProfile.donBalance (jami) bo'yicha (samarali).
 *   - daily/weekly/monthly → XpEvent.donDelta yig'indisi (1/7/30 kun).
 * Viloyat filtri (Child.region) + pagination + joriy bolaning o'rni ("Siz").
 *
 * MUHIM: avval reyting XP bo'yicha saralanib, UI'da esa "DON" deb yozilardi.
 * Natijada bitta bola ota-ona panelida "210 DON" (ChildProfile.donBalance),
 * reyting ekranida esa "260 DON" (aslida XP) bo'lib ko'rinardi. XP va DON
 * mustaqil beriladi (`XpEvent.xpDelta` / `donDelta`) — ya'ni ular hech qachon
 * teng bo'lmaydi. Endi reyting ham DON'dan hisoblanadi → hamma joyda bir xil.
 *
 * DON hech qayerda kamaymaydi (sarflanmaydi), shuning uchun `donBalance` =
 * jami yig'ilgan DON va u bo'yicha saralash adolatli.
 *
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
    viewer: LeaderboardViewer;
  }): Promise<LeaderboardResult> {
    const { period, page, limit } = opts;
    const skip = (page - 1) * limit;
    const ownChildIds = await this.resolveOwnChildIds(opts.viewer);
    // `childId` faqat so'rovchining O'Z oilasidagi bola bo'lsa qabul qilinadi —
    // aks holda istalgan bolaning viloyati/o'rni so'rab bilinardi.
    const childId =
      opts.childId && ownChildIds.has(opts.childId) ? opts.childId : undefined;
    const region = await this.resolveRegion(opts.region, childId);
    const ctx = { region, skip, limit, page, childId, ownChildIds };

    if (period === LeaderboardPeriod.all) {
      return this.allTime(ctx);
    }
    return this.periodRange({ ...ctx, period });
  }

  /**
   * So'rovchi oilasining bolalari: bola uchun — o'zi, ota-ona uchun — uning
   * barcha bolalari. Faqat shular uchun reytingda haqiqiy `childId` beriladi.
   */
  private async resolveOwnChildIds(
    viewer: LeaderboardViewer,
  ): Promise<ReadonlySet<string>> {
    const where =
      viewer.role === 'CHILD'
        ? { childUserId: viewer.userId }
        : { parentId: viewer.userId };
    const rows = await this.prisma.child.findMany({
      where,
      select: { id: true },
    });
    return new Set(rows.map((r) => r.id));
  }

  /** `skip`/`limit` ni top-N chegarasiga moslaydi (chegaradan keyin — bo'sh). */
  private visibleWindow(skip: number, limit: number): number {
    return Math.max(0, Math.min(limit, LEADERBOARD_MAX_ROWS - skip));
  }

  /**
   * `region=me` → joriy bolaning O'Z viloyati.
   *
   * Bola ilovasi o'z viloyatini mustaqil bilmaydi (u faqat reyting javobidan
   * keladi), shuning uchun "Hudud" tab'i `me` yuboradi. Olympiad reytingida
   * ham aynan shu kelishuv ishlatiladi.
   */
  private async resolveRegion(
    region: string | undefined,
    childId: string | undefined,
  ): Promise<string | undefined> {
    if (region !== LEADERBOARD_REGION_ME) return region;
    if (!childId) return undefined;
    const me = await this.prisma.child.findUnique({
      where: { id: childId },
      select: { region: true },
    });
    return me?.region ?? undefined;
  }

  /** Butun davr — ChildProfile.donBalance bo'yicha (samarali). */
  private async allTime(o: {
    region?: string;
    skip: number;
    limit: number;
    page: number;
    childId?: string;
    ownChildIds: ReadonlySet<string>;
  }): Promise<LeaderboardResult> {
    const { region, skip, limit, childId, ownChildIds } = o;
    const childRel = region ? { child: { is: { region } } } : {};

    const total = await this.prisma.childProfile.count({ where: { ...childRel } });

    const take = this.visibleWindow(skip, limit);
    const profiles =
      take === 0
        ? []
        : await this.prisma.childProfile.findMany({
            where: { ...childRel },
            orderBy: [{ donBalance: 'desc' }, { childId: 'asc' }],
            skip,
            take,
            include: {
              child: {
                select: { id: true, name: true, region: true, age: true, gender: true },
              },
            },
          });

    const entries: LeaderboardEntry[] = profiles.map((p, i) => ({
      rank: skip + i + 1,
      childId: visibleChildId(p.childId, ownChildIds),
      name: maskChildName(p.child.name),
      region: p.child.region ?? '',
      age: p.child.age,
      gender: p.child.gender ?? null,
      don: p.donBalance,
      xp: p.donBalance, // eskirgan alias — `don` bilan bir xil
    }));

    let currentChild: LeaderboardEntry | null = null;
    if (childId) {
      const my = await this.prisma.childProfile.findUnique({
        where: { childId },
        include: { child: { select: { name: true, region: true, age: true, gender: true } } },
      });
      // Region filtri faol bo'lsa va bola o'sha viloyatda bo'lmasa, "Siz"ni
      // ko'rsatmaymiz (uni o'zi tegishli bo'lmagan viloyat reytingida
      // joylashtirish noto'g'ri bo'lardi).
      const regionMismatch =
        region != null && (my?.child.region ?? '') !== region;
      if (my && !regionMismatch) {
        // List tartibiga mos ketma-ket o'rin (don desc, childId asc tiebreaker).
        const before = await this.prisma.childProfile.count({
          where: {
            ...childRel,
            OR: [
              { donBalance: { gt: my.donBalance } },
              { donBalance: my.donBalance, childId: { lt: childId } },
            ],
          },
        });
        currentChild = {
          rank: before + 1,
          childId,
          name: maskChildName(my.child.name),
          region: my.child.region ?? '',
          age: my.child.age,
          gender: my.child.gender ?? null,
          don: my.donBalance,
          xp: my.donBalance, // eskirgan alias — `don` bilan bir xil
        };
      }
    }

    return {
      entries,
      total,
      hasMore: skip + entries.length < Math.min(total, LEADERBOARD_MAX_ROWS),
      currentChild,
      period: LeaderboardPeriod.all,
    };
  }

  /** Kunlik/haftalik/oylik — XpEvent.donDelta yig'indisi (oxirgi 1/7/30 kun). */
  private async periodRange(o: {
    period: LeaderboardPeriod;
    region?: string;
    skip: number;
    limit: number;
    page: number;
    childId?: string;
    ownChildIds: ReadonlySet<string>;
  }): Promise<LeaderboardResult> {
    const { period, region, skip, limit, childId, ownChildIds } = o;
    const days =
      period === LeaderboardPeriod.daily
        ? 1
        : period === LeaderboardPeriod.weekly
          ? 7
          : 30;
    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

    const grouped = await this.prisma.xpEvent.groupBy({
      by: ['childId'],
      where: { createdAt: { gte: since } },
      _sum: { donDelta: true },
      orderBy: { _sum: { donDelta: 'desc' } },
    });

    const ids = grouped.map((g) => g.childId);
    const children = await this.prisma.child.findMany({
      where: { id: { in: ids }, ...(region ? { region } : {}) },
      select: { id: true, name: true, region: true, age: true, gender: true },
    });
    const childMap = new Map(children.map((c) => [c.id, c]));

    // Region filtridan o'tgan bolalar, ketma-ket reyting.
    const ranked = grouped
      .filter((g) => childMap.has(g.childId))
      .map((g) => {
        const c = childMap.get(g.childId)!;
        return {
          childId: g.childId,
          name: maskChildName(c.name),
          region: c.region ?? '',
          age: c.age,
          gender: c.gender ?? null,
          don: g._sum.donDelta ?? 0,
          xp: g._sum.donDelta ?? 0, // eskirgan alias — `don` bilan bir xil
        };
      });

    const total = ranked.length;
    const entries: LeaderboardEntry[] = ranked
      .slice(skip, skip + this.visibleWindow(skip, limit))
      .map((r, i) => ({
        rank: skip + i + 1,
        ...r,
        childId: visibleChildId(r.childId, ownChildIds),
      }));

    let currentChild: LeaderboardEntry | null = null;
    if (childId) {
      const idx = ranked.findIndex((r) => r.childId === childId);
      if (idx >= 0) {
        currentChild = { rank: idx + 1, ...ranked[idx] };
      } else {
        // Bu davrda DON yo'q — 0 bilan (faqat region mos kelsa; aks holda
        // boshqa viloyatda "Siz"ni ko'rsatmaymiz).
        const c = await this.prisma.child.findUnique({
          where: { id: childId },
          select: { name: true, region: true, age: true, gender: true },
        });
        if (c && (!region || (c.region ?? '') === region)) {
          currentChild = {
            rank: 0,
            childId,
            name: maskChildName(c.name),
            region: c.region ?? '',
            age: c.age,
            gender: c.gender ?? null,
            don: 0,
            xp: 0,
          };
        }
      }
    }

    return {
      entries,
      total,
      hasMore: skip + entries.length < Math.min(total, LEADERBOARD_MAX_ROWS),
      currentChild,
      period,
    };
  }
}
