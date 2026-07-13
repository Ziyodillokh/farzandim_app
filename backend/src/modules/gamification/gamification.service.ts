import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import {
  levelForXp,
  statusForXp,
  calculateNewStreak,
} from '../../common/helpers/gamification-rules';
import {
  CreateXpEventDto,
  MAX_XP_DELTA,
  XpEventType,
} from './dto/create-xp-event.dto';
import { ListXpEventsDto } from './dto/list-xp-events.dto';

@Injectable()
export class GamificationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly realtime: RealtimeGateway,
  ) {}

  private async getOrCreateProfile(childId: string) {
    const existing = await this.prisma.childProfile.findUnique({
      where: { childId },
    });
    if (existing) return existing;
    return this.prisma.childProfile.create({ data: { childId } });
  }

  private async validateChildAccess(childId: string, userId: string) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }
    return child;
  }

  async getProfile(childId: string, userId: string) {
    await this.validateChildAccess(childId, userId);
    return this.getOrCreateProfile(childId);
  }

  async createXpEvent(
    childId: string,
    userId: string,
    dto: CreateXpEventDto,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    await this.validateChildAccess(childId, userId);

    // Server-side XP validation
    const maxDelta = MAX_XP_DELTA[dto.type as XpEventType];
    if (Math.abs(dto.xpDelta) > maxDelta) {
      throw new BadRequestException(
        `xpDelta for ${dto.type} must not exceed ${maxDelta} (got ${dto.xpDelta})`,
      );
    }

    const profile = await this.getOrCreateProfile(childId);
    const { newStreak } = calculateNewStreak(
      profile.lastActivityDate,
      profile.streakDays,
    );

    const donDelta = dto.donDelta ?? 0;
    const newXp = profile.xp + dto.xpDelta;
    const newDon = profile.donBalance + donDelta;
    const newLevel = levelForXp(newXp);
    const newStatus = statusForXp(newXp);

    const [event, updatedProfile] = await this.prisma.$transaction([
      this.prisma.xpEvent.create({
        data: {
          childId,
          type: dto.type,
          xpDelta: dto.xpDelta,
          donDelta,
          relatedId: dto.relatedId,
          source: dto.source as object | undefined,
        },
      }),
      this.prisma.childProfile.update({
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

    await this.audit.log(userId, 'xp_event', 'CREATE', event.id, dto, request);
    this.realtime.emitToChild(childId, 'profile:updated', updatedProfile);

    return { event, profile: updatedProfile };
  }

  /**
   * TIZIM tomonidan XP berish (egalik tekshiruvisiz) — bola olympiad/testni
   * tugatganda avtomatik chaqiriladi. Idempotent: bitta `relatedId`
   * (masalan attemptId) uchun bir martagina beriladi (qayta yuborilsa XP
   * ikki marta qo'shilmaydi).
   */
  async awardXp(
    childId: string,
    opts: {
      type: XpEventType;
      xpDelta: number;
      relatedId?: string;
      donDelta?: number;
    },
  ): Promise<void> {
    // Bo'sh chaqiruvni to'xtatamiz, lekin DON-only (xpDelta=0, donDelta>0)
    // ruxsat — video to'liq ko'rilganda XP bermay faqat don beramiz.
    if (opts.xpDelta <= 0 && (opts.donDelta ?? 0) <= 0) return;
    if (opts.relatedId) {
      const existing = await this.prisma.xpEvent.findFirst({
        where: { childId, type: opts.type, relatedId: opts.relatedId },
        select: { id: true },
      });
      if (existing) return; // allaqachon berilgan — qayta bermaymiz
    }

    const profile = await this.getOrCreateProfile(childId);
    const { newStreak } = calculateNewStreak(
      profile.lastActivityDate,
      profile.streakDays,
    );
    const donDelta = opts.donDelta ?? 0;
    const newXp = profile.xp + opts.xpDelta;
    const newDon = profile.donBalance + donDelta;
    const newLevel = levelForXp(newXp);
    const newStatus = statusForXp(newXp);

    const [, updatedProfile] = await this.prisma.$transaction([
      this.prisma.xpEvent.create({
        data: {
          childId,
          type: opts.type,
          xpDelta: opts.xpDelta,
          donDelta,
          relatedId: opts.relatedId,
        },
      }),
      this.prisma.childProfile.update({
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

    this.realtime.emitToChild(childId, 'profile:updated', updatedProfile);
  }

  /**
   * QADAM MUKOFOTI — bola pedometeridan don berish (har 1000 qadam = 5 don).
   *
   * `upsertSteps` chaqiradi: `donDelta` — shu sync'da yangi tegishli don
   * (idempotent hisoblangan). `activeToday` — bugun bola faol yurdimi
   * (qadam >= 1000) → yurish ham streak'ni oshiradi (real faollik).
   *
   * Idempotentlik chaqiruvchida (`ChildStepDaily.donAwarded`) — bu yerda
   * shunchaki delta qo'shiladi. donDelta=0 bo'lsa ham activeToday uchun
   * streak yangilanadi.
   */
  async awardStepDon(
    childId: string,
    donDelta: number,
    activeToday: boolean,
  ): Promise<void> {
    if (donDelta <= 0 && !activeToday) return;

    const profile = await this.getOrCreateProfile(childId);

    // Yurish = faollik: bugun 1000+ qadam bo'lsa streak yangilanadi.
    let streakDays = profile.streakDays;
    let lastActivityDate = profile.lastActivityDate;
    if (activeToday) {
      const { newStreak } = calculateNewStreak(
        profile.lastActivityDate,
        profile.streakDays,
      );
      streakDays = newStreak;
      lastActivityDate = new Date();
    }

    const add = Math.max(0, donDelta);
    const newDon = profile.donBalance + add;

    const ops: any[] = [];
    // Faqat haqiqiy don berilganda ledger yozuvi (audit izi).
    if (add > 0) {
      ops.push(
        this.prisma.xpEvent.create({
          data: { childId, type: 'DAILY_GOAL', xpDelta: 0, donDelta: add },
        }),
      );
    }
    ops.push(
      this.prisma.childProfile.update({
        where: { childId },
        data: { donBalance: newDon, streakDays, lastActivityDate },
      }),
    );

    const results = await this.prisma.$transaction(ops);
    const updatedProfile = results[results.length - 1];
    this.realtime.emitToChild(childId, 'profile:updated', updatedProfile);
  }

  async listXpEvents(
    childId: string,
    userId: string,
    query: ListXpEventsDto,
  ) {
    await this.validateChildAccess(childId, userId);

    const { type, limit } = query;
    const events = await this.prisma.xpEvent.findMany({
      where: { childId, ...(type && { type }) },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    return { events, count: events.length };
  }

  /* ------------------------------------------------------------------ */
  /*  #63 — Rivojlanish ko'rsatkichi (haftalik faollik indeksi)          */
  /* ------------------------------------------------------------------ */

  /**
   * Bolaning yaxlit rivojlanish ko'rsatkichi (bola + ota-ona ko'radi).
   *
   * `score` (0..100) — ijobiy, motivatsion vaznli formula (nazorat emas).
   * Komponentlar haftalik maqsadga normallashtiriladi (min(qiymat/maqsad, 1)):
   *   - Testlar  25%  (maqsad: 5 ta/hafta)
   *   - Kitoblar 20%  (maqsad: 5 ta/hafta — BOOK_READ XP eventlari)
   *   - Streak   25%  (maqsad: 7 kun ketma-ket)
   *   - Qadam    20%  (maqsad: 70 000/hafta ≈ 10k/kun)
   *   - XP       10%  (maqsad: 500 XP/hafta — umumiy faollik)
   *
   * `trend` — xpGained'ning oldingi davrga nisbatan o'zgarishi (%).
   *
   * Eslatma: videosWatched/articlesRead hozircha PER-CHILD kuzatilmaydi
   * (faqat global ko'rish hisoblagichi bor) → 0 qaytadi (kontrakt to'liqligi
   * uchun). Kitob o'qish XP event orqali per-child hisoblanadi.
   */
  async getDevelopmentSummary(
    childId: string,
    userId: string,
    range: 'weekly' | 'monthly' = 'weekly',
  ) {
    await this.validateChildAccess(childId, userId);

    const days = range === 'monthly' ? 30 : 7;
    const now = new Date();
    const periodMs = days * 24 * 60 * 60 * 1000;
    const start = new Date(now.getTime() - periodMs);
    const prevStart = new Date(now.getTime() - 2 * periodMs);

    const [xpAgg, prevXpAgg, booksRead, testsCompleted, stepsAgg, profile] =
      await Promise.all([
        this.prisma.xpEvent.aggregate({
          where: { childId, createdAt: { gte: start } },
          _sum: { xpDelta: true },
        }),
        this.prisma.xpEvent.aggregate({
          where: { childId, createdAt: { gte: prevStart, lt: start } },
          _sum: { xpDelta: true },
        }),
        this.prisma.xpEvent.count({
          where: { childId, type: 'BOOK_READ', createdAt: { gte: start } },
        }),
        this.prisma.olympiadAttempt.count({
          where: { childId, status: 'finished', finishedAt: { gte: start } },
        }),
        this.prisma.childStepDaily.aggregate({
          where: { childId, date: { gte: start } },
          _sum: { steps: true },
        }),
        this.getOrCreateProfile(childId),
      ]);

    const xpGained = xpAgg._sum.xpDelta ?? 0;
    const prevXp = prevXpAgg._sum.xpDelta ?? 0;
    const steps = stepsAgg._sum.steps ?? 0;
    const streakDays = profile.streakDays;

    // Haftalik maqsadlar (monthly'da f≈4.3x kattaroq).
    const f = days / 7;
    const clamp01 = (v: number) => Math.max(0, Math.min(1, v));
    const score = Math.round(
      clamp01(testsCompleted / (5 * f)) * 25 +
        clamp01(booksRead / (5 * f)) * 20 +
        clamp01(streakDays / 7) * 25 +
        clamp01(steps / (70_000 * f)) * 20 +
        clamp01(xpGained / (500 * f)) * 10,
    );

    const trend =
      prevXp > 0
        ? Math.round(((xpGained - prevXp) / prevXp) * 100)
        : xpGained > 0
          ? 100
          : 0;

    return {
      range,
      score,
      trend,
      xpGained,
      testsCompleted,
      booksRead,
      articlesRead: 0,
      videosWatched: 0,
      streakDays,
      steps,
    };
  }
}
