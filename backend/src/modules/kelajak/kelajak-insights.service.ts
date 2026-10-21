// ─────────────────────────────────────────────────────────────────────
// Parvoz Kelajak — overview, kumulyativ profil, progress, natijalar va
// ota-ona xulosasi (docs/KELAJAK-REJA.md §4–§5)
// ─────────────────────────────────────────────────────────────────────
//
// Profil — oxirgi 180 kundagi yakunlangan sessiyalarda har savolning eng
// so'nggi javobi. Bolaga ham, ota-onaga ham wellbeing / safety raqamlari
// chiqmaydi; ota-onaga savol darajasidagi javob va ochiq matn umuman
// o'qilmaydi (faqat ballar, kodlar va signal darajasi), `parent_communication`
// ko'rsatilmaydi va kategoriya kamida 2 javobdan iborat bo'lsagina chiqadi.

import { Injectable } from '@nestjs/common';
import { KelajakSession, KelajakSessionStatus } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { SchoolCryptoService } from '../../school/common/school-crypto.service';
import { KelajakAgeGroup, resolveKelajakAge } from './domain/age';
import { KELAJAK_TEST_TYPES, KELAJAK_TESTS, KelajakTestType, TEXT_ANSWER_TYPE } from './domain/catalog';
import { pickKelajakQuestions, PickerQuestion } from './domain/picker';
import { buildKelajakProgress, ProgressSession } from './domain/progress';
import { CategoryScore, PROFILE_WINDOW_DAYS } from './domain/scoring';
import { DISCLAIMERS, TEST_TEXTS } from './domain/texts';
import { DEFAULT_RESULTS_LIMIT, KelajakResultsQueryDto } from './dto/kelajak.dto';
import { loadActivityLabel, loadChildAge, loadKelajakProfile } from './kelajak.loader';
import {
  isParentVisibleScore,
  parseStoredResult,
  toAgeView,
  toCategoryScoreViews,
  toInterestsView,
  toOverviewCategories,
  toParentInsightsView,
  toParentSupportView,
  toProfileView,
  toProgressViews,
  toSessionSummaryView,
} from './kelajak.mapper';
import {
  OverviewTestView,
  OverviewView,
  ParentSummaryView,
  ProgressView,
  SessionSummaryView,
  TodayStatus,
} from './kelajak.views';

const DAY_MS = 24 * 60 * 60 * 1000;
/** Progress tarixida ko'rsatiladigan oxirgi sessiyalar. */
const PROGRESS_HISTORY = 20;
const NO_HISTORY: ReadonlyMap<string, number> = new Map();
const KEEP_ALL = () => true;

type SessionWithCount = KelajakSession & { _count: { answers: number } };

const summaryOf = (s: SessionWithCount): SessionSummaryView =>
  toSessionSummaryView({ ...s, answered: s._count.answers });

@Injectable()
export class KelajakInsightsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: SchoolCryptoService,
  ) {}

  /** Test uchun almashtiriladi. */
  protected now(): Date {
    return new Date();
  }

  async overview(childId: string): Promise<OverviewView> {
    const now = this.now();
    const age = resolveKelajakAge(await loadChildAge(this.prisma, childId), tashkentDay(now));
    const loaded = await loadKelajakProfile(this.prisma, { childId, ageGroup: age.ageGroup, now });
    const label = await loadActivityLabel(this.prisma, [loaded.profile.insightCodes]);
    return {
      age: toAgeView(age),
      tests: age.status === 'OK' && age.ageGroup ? await this.overviewTests(childId, age.ageGroup, now) : [],
      categories: toOverviewCategories(),
      profile: toProfileView(loaded.profile, loaded.available.scaleIds.length, label),
    };
  }

  async progress(childId: string): Promise<ProgressView> {
    const now = this.now();
    const [totals, progress, history] = await Promise.all([
      this.completedTotals(childId),
      this.progressData(childId, now),
      this.prisma.kelajakSession.findMany({
        where: { childId, status: KelajakSessionStatus.COMPLETED },
        orderBy: { completedAt: 'desc' },
        take: PROGRESS_HISTORY,
        include: { _count: { select: { answers: true } } },
      }),
    ]);
    return {
      ...totals,
      ...toProgressViews(progress),
      improved: progress.improved,
      interestsRising: progress.interestsRising,
      history: history.map(summaryOf),
    };
  }

  /** Yakunlangan sessiyalar — yangisi birinchi, `before` kursori bilan. */
  async results(
    childId: string,
    query: KelajakResultsQueryDto,
  ): Promise<{ items: SessionSummaryView[]; nextBefore: string | null }> {
    const limit = query.limit ?? DEFAULT_RESULTS_LIMIT;
    const rows = await this.prisma.kelajakSession.findMany({
      where: {
        childId,
        status: KelajakSessionStatus.COMPLETED,
        ...(query.before && { completedAt: { lt: query.before } }),
      },
      orderBy: { completedAt: 'desc' },
      take: limit + 1,
      include: { _count: { select: { answers: true } } },
    });
    const items = rows.slice(0, limit).map(summaryOf);
    const last = items[items.length - 1];
    return { items, nextBefore: rows.length > limit && last.completedAt ? last.completedAt.toISOString() : null };
  }

  /**
   * Ota-ona xulosasi — javoblar, ochiq matn, wellbeing/safety raqamlari va
   * `parent_communication`siz; kategoriya va progress nuqtasi kamida 2 javobdan.
   */
  async parentSummary(childId: string): Promise<ParentSummaryView> {
    const now = this.now();
    const age = resolveKelajakAge(await loadChildAge(this.prisma, childId), tashkentDay(now));
    const [loaded, totals, progress] = await Promise.all([
      loadKelajakProfile(this.prisma, { childId, ageGroup: age.ageGroup, now }),
      this.completedTotals(childId),
      this.progressData(childId, now, isParentVisibleScore),
    ]);
    const { profile } = loaded;
    const label = await loadActivityLabel(this.prisma, [profile.insightCodes]);
    return {
      age: toAgeView(age),
      sessionsCompleted: totals.sessionsCompleted,
      lastCompletedAt: totals.lastCompletedAt,
      categories: toCategoryScoreViews(profile.categories.filter(isParentVisibleScore)),
      interests: toInterestsView(profile.interests),
      insights: toParentInsightsView(profile.insightCodes, label),
      support: toParentSupportView(profile.support),
      progress: toProgressViews(progress),
      disclaimer: DISCLAIMERS.parent,
    };
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  /**
   * Har tur: bugungi holat va savollar soni (savoli yo'q tur ko'rsatilmaydi).
   * Shifrlash kaliti yo'q bo'lsa ochiq savollar hisobga olinmaydi — `voice` chiqmaydi.
   */
  private async overviewTests(childId: string, ageGroup: KelajakAgeGroup, now: Date): Promise<OverviewTestView[]> {
    const textFilter = this.crypto.isConfigured() ? {} : { answerType: { not: TEXT_ANSWER_TYPE } };
    const [todays, pool] = await Promise.all([
      this.prisma.kelajakSession.findMany({
        where: { childId, day: tashkentDay(now), status: { not: KelajakSessionStatus.ABANDONED } },
        orderBy: { startedAt: 'desc' },
        select: { id: true, type: true, status: true, total: true },
      }),
      this.prisma.kelajakQuestion.findMany({
        where: { ageGroup, active: true, ...textFilter },
        select: { id: true, category: true, ageGroup: true, answerType: true, active: true },
      }),
    ]);
    return KELAJAK_TEST_TYPES.flatMap((type) => {
      const config = KELAJAK_TESTS[type];
      const session = todays.find((s) => s.type === type) ?? null;
      const questionCount = session?.total ?? availableCount(pool, type, ageGroup);
      if (questionCount === 0) return [];
      return [
        {
          type,
          title: TEST_TEXTS[type].title,
          description: TEST_TEXTS[type].description,
          questionCount,
          estimatedMinutes: config.estimatedMinutes,
          today: { status: todayStatus(session?.status ?? null), sessionId: session?.id ?? null },
        } satisfies OverviewTestView,
      ];
    });
  }

  private async completedTotals(childId: string): Promise<{
    sessionsCompleted: number;
    firstCompletedAt: Date | null;
    lastCompletedAt: Date | null;
  }> {
    const agg = await this.prisma.kelajakSession.aggregate({
      where: { childId, status: KelajakSessionStatus.COMPLETED },
      _count: { _all: true },
      _min: { completedAt: true },
      _max: { completedAt: true },
    });
    return {
      sessionsCompleted: agg._count._all,
      firstCompletedAt: agg._min.completedAt,
      lastCompletedAt: agg._max.completedAt,
    };
  }

  /** Profil oynasidagi yakunlangan sessiyalar natijalaridan progress (`keep` — kategoriya filtri). */
  private async progressData(childId: string, now: Date, keep: (c: CategoryScore) => boolean = KEEP_ALL) {
    const rows = await this.prisma.kelajakSession.findMany({
      where: {
        childId,
        status: KelajakSessionStatus.COMPLETED,
        completedAt: { gte: new Date(now.getTime() - (PROFILE_WINDOW_DAYS + 1) * DAY_MS) },
      },
      select: { day: true, result: true },
    });
    const sessions = rows.flatMap((row): ProgressSession[] => {
      const result = parseStoredResult(row.result);
      if (!result) return [];
      return [
        {
          day: row.day,
          categories: result.scores.categories.filter(keep),
          interests: result.scores.interests?.dimensions ?? [],
        },
      ];
    });
    return buildKelajakProgress(sessions);
  }
}

/** ABANDONED bugungi ro'yxatga kirmaydi — xavfsizlik uchun NEW deb olinadi. */
function todayStatus(status: KelajakSessionStatus | null): TodayStatus {
  return status === null || status === KelajakSessionStatus.ABANDONED ? 'NEW' : status;
}

/** Bugun boshlansa nechta savol tushadi (tanlov soni tarixga bog'liq emas). */
function availableCount(pool: readonly PickerQuestion[], type: KelajakTestType, ageGroup: KelajakAgeGroup): number {
  const config = KELAJAK_TESTS[type];
  return pickKelajakQuestions({ config, ageGroup, pool, lastAnsweredAt: NO_HISTORY, seed: 0 }).length;
}
