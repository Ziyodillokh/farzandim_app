import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { ChildProfile, Prisma, XpEvent } from '@prisma/client';
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

    const result = await this.prisma.$transaction((tx) =>
      this.applyAward(tx, childId, {
        type: dto.type as XpEventType,
        xpDelta: dto.xpDelta,
        donDelta: dto.donDelta ?? 0,
        relatedId: dto.relatedId,
        source: dto.source as object | undefined,
        dedupe: false,
        touchStreak: true,
      }),
    );
    // dedupe=false — natija har doim bor va ledger yozuvi yaratiladi.
    const { event, profile: updatedProfile } = result!;

    await this.audit.log(userId, 'xp_event', 'CREATE', event!.id, dto, request);
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
    const result = await this.prisma.$transaction((tx) =>
      this.applyAward(tx, childId, {
        type: opts.type,
        xpDelta: opts.xpDelta,
        donDelta: opts.donDelta ?? 0,
        relatedId: opts.relatedId,
        dedupe: true,
        touchStreak: true,
      }),
    );
    if (result) this.notifyProfileUpdated(childId, result.profile);
  }

  /**
   * Tashqi tranzaksiya ICHIDA mukofot (masalan kunlik test yakuni bilan
   * birga — "test yakunlandi" va "DON berildi" bir butun). Idempotent:
   * `relatedId` bo'yicha bir marta; takror bo'lsa `null`. Tranzaksiya
   * commit bo'lgach chaqiruvchi `notifyProfileUpdated` ni chaqiradi.
   */
  async awardInTx(
    tx: Prisma.TransactionClient,
    childId: string,
    opts: {
      type: XpEventType;
      xpDelta: number;
      donDelta: number;
      relatedId: string;
    },
  ): Promise<AwardResult | null> {
    if (opts.xpDelta <= 0 && opts.donDelta <= 0) return null;
    return this.applyAward(tx, childId, {
      ...opts,
      dedupe: true,
      touchStreak: true,
    });
  }

  /** `profile:updated` — bola ilovasi balans / streakni darhol yangilaydi. */
  notifyProfileUpdated(childId: string, profile: ChildProfile): void {
    this.realtime.emitToChild(childId, 'profile:updated', profile);
  }

  /**
   * YAGONA mukofot yadrosi — barcha XP / DON yozuvlari shu yerdan o'tadi.
   *
   * - Bola bo'yicha tranzaksion advisory lock: parallel so'rovlar navbat
   *   bilan bajariladi → `relatedId` takror tekshiruvi ishonchli.
   * - Balans `increment` bilan (o'qib-yozish emas) — yo'qolgan yangilanish yo'q.
   * - Streak Toshkent kunida (`calculateNewStreak`).
   */
  private async applyAward(
    tx: Prisma.TransactionClient,
    childId: string,
    input: AwardInput,
  ): Promise<AwardResult | null> {
    await tx.$queryRaw`SELECT 1 AS locked FROM pg_advisory_xact_lock(hashtextextended(${`xp:${childId}`}, 0))`;

    if (input.dedupe && input.relatedId && input.type) {
      const existing = await tx.xpEvent.findFirst({
        where: { childId, type: input.type, relatedId: input.relatedId },
        select: { id: true },
      });
      if (existing) return null; // allaqachon berilgan — qayta bermaymiz
    }

    const now = new Date();
    const profile = await tx.childProfile.upsert({
      where: { childId },
      create: { childId },
      update: {},
    });
    const streak = input.touchStreak
      ? calculateNewStreak(profile.lastActivityDate, profile.streakDays, now)
      : null;

    const event =
      input.type && (input.xpDelta !== 0 || input.donDelta !== 0)
        ? await tx.xpEvent.create({
            data: {
              childId,
              type: input.type,
              xpDelta: input.xpDelta,
              donDelta: input.donDelta,
              relatedId: input.relatedId,
              source: input.source,
            },
          })
        : null;

    let updated = await tx.childProfile.update({
      where: { childId },
      data: {
        xp: { increment: input.xpDelta },
        donBalance: { increment: input.donDelta },
        ...(streak && {
          streakDays: streak.newStreak,
          lastActivityDate: now,
        }),
      },
    });
    const level = levelForXp(updated.xp);
    const status = statusForXp(updated.xp);
    if (level !== updated.level || status !== updated.status) {
      updated = await tx.childProfile.update({
        where: { childId },
        data: { level, status },
      });
    }
    return { event, profile: updated };
  }

  /**
   * Yutuq (achievement) berish — `ChildProfile.achievements` JSON massiviga
   * qo'shadi. IDEMPOTENT: allaqachon bor bo'lsa hech nima qilmaydi.
   *
   * Frontend `unlockedAchievements` shu ro'yxatni o'qiydi va tegishli badge'ni
   * ochadi. `profile:updated` real-time emit qilinadi — bola profil ekrani
   * ochiq bo'lsa darhol confetti + toast ko'rsatadi, aks holda keyingi
   * yuklashda ochilgan badge ko'rinadi.
   */
  async unlockAchievement(
    childId: string,
    achievementId: string,
  ): Promise<void> {
    const profile = await this.getOrCreateProfile(childId);
    const current = Array.isArray(profile.achievements)
      ? (profile.achievements as string[])
      : [];
    if (current.includes(achievementId)) return; // allaqachon bor

    const updated = await this.prisma.childProfile.update({
      where: { childId },
      data: { achievements: [...current, achievementId] },
    });
    this.realtime.emitToChild(childId, 'profile:updated', updated);
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

    const add = Math.max(0, donDelta);
    const result = await this.prisma.$transaction((tx) =>
      this.applyAward(tx, childId, {
        // Faqat haqiqiy don berilganda ledger yozuvi (audit izi).
        type: add > 0 ? XpEventType.DAILY_GOAL : null,
        xpDelta: 0,
        donDelta: add,
        dedupe: false,
        // Yurish = faollik: bugun 1000+ qadam bo'lsa streak yangilanadi.
        touchStreak: activeToday,
      }),
    );
    if (result) this.notifyProfileUpdated(childId, result.profile);
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

interface AwardInput {
  /** `null` — ledger yozuvisiz (faqat streak yangilanishi). */
  type: XpEventType | null;
  xpDelta: number;
  donDelta: number;
  relatedId?: string;
  source?: object;
  /** `relatedId` bo'yicha takroriy mukofotni o'tkazib yuborish. */
  dedupe: boolean;
  /** Faollik — streak va `lastActivityDate` yangilanadi. */
  touchStreak: boolean;
}

export interface AwardResult {
  event: XpEvent | null;
  profile: ChildProfile;
}
