// ─────────────────────────────────────────────────────────────────────
// Daily Learning — ota-ona uchun xulosa va haftalik hisobot
// ─────────────────────────────────────────────────────────────────────
//
// Xulosa natijalardan hisoblanadi (`learning-stats.ts`). Haftalik hisobot
// yakshanba 19:00 (Toshkent) — shu hafta test yechgan har bola uchun
// ota-onaga push + bildirishnoma (faqat ota-ona ko'radi). (bola, hafta)
// bo'yicha bir marta: avval yozuv "egallanadi", keyin yuboriladi.

import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import {
  LearningAttemptStatus,
  NotificationType,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { tr } from '../../common/i18n/notification-i18n';
import {
  addDays,
  DayKey,
  TASHKENT_TZ,
  tashkentDay,
} from '../../common/time/tashkent';
import { LearningSummary, StatResult, summarizeLearning } from './domain/learning-stats';

/** Streak hisobi uchun ko'rib chiqiladigan tarix. */
const HISTORY_DAYS = 120;
const REPORT_PERIOD_DAYS = 7;

export interface ChildLearningSummary extends LearningSummary {
  profile: { grade: number; subjects: string[] } | null;
}

@Injectable()
export class LearningInsightsService {
  private readonly logger = new Logger(LearningInsightsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmService,
  ) {}

  async summary(
    childId: string,
    periodDays: number,
    now: Date = new Date(),
  ): Promise<ChildLearningSummary> {
    const today = tashkentDay(now);
    const [profile, results] = await Promise.all([
      this.prisma.learningProfile.findUnique({ where: { childId } }),
      this.statResults(childId, addDays(today, -Math.max(HISTORY_DAYS, periodDays * 2))),
    ]);
    return {
      profile: profile
        ? {
            grade: profile.grade,
            subjects: profile.subjects.map((s) => s.toLowerCase()),
          }
        : null,
      ...summarizeLearning({
        results,
        today,
        periodDays,
        order: profile?.subjects ?? [],
      }),
    };
  }

  /** Yakshanba 19:00 Toshkent — shu hafta faol bolalar ota-onalariga. */
  @Cron('0 19 * * 0', { name: 'learning-weekly-report', timeZone: TASHKENT_TZ })
  async sendWeeklyReports(now: Date = new Date()): Promise<{ sent: number }> {
    const today = tashkentDay(now);
    const weekStart = addDays(today, -(REPORT_PERIOD_DAYS - 1));
    const active = await this.prisma.learningAttempt.groupBy({
      by: ['childId'],
      where: {
        status: LearningAttemptStatus.COMPLETED,
        day: { gte: weekStart, lte: today },
      },
    });

    let sent = 0;
    for (const { childId } of active) {
      try {
        if (await this.sendReport(childId, weekStart, now)) sent++;
      } catch (e) {
        this.logger.error(`haftalik hisobot yuborilmadi (child ${childId})`, e as Error);
      }
    }
    if (active.length > 0) {
      this.logger.log(`haftalik hisobot: ${sent}/${active.length} yuborildi`);
    }
    return { sent };
  }

  private async sendReport(childId: string, weekStart: DayKey, now: Date): Promise<boolean> {
    // (bola, hafta) ni egallash — parallel / qayta ishga tushishda takror yo'q.
    try {
      await this.prisma.learningReportDispatch.create({ data: { childId, weekStart } });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        return false;
      }
      throw e;
    }

    const child = await this.prisma.child.findUniqueOrThrow({
      where: { id: childId },
      select: { name: true, parentId: true },
    });
    const summary = await this.summary(childId, REPORT_PERIOD_DAYS, now);
    if (summary.testsCount === 0 || summary.overallPercent === null) return false;

    const lang = await this.fcm.getUserLang(child.parentId);
    const title = tr(lang, 'learningWeekly.title', { name: child.name });
    const body = [
      tr(lang, 'learningWeekly.body', {
        tests: summary.testsCount,
        percent: summary.overallPercent,
      }),
      summary.strongSubject &&
        tr(lang, 'learningWeekly.strong', {
          subject: tr(lang, `subject.${summary.strongSubject}`),
        }),
      summary.focusSubject &&
        tr(lang, 'learningWeekly.focus', {
          subject: tr(lang, `subject.${summary.focusSubject}`),
        }),
    ]
      .filter(Boolean)
      .join(' ');
    const data = { type: 'learning_weekly', childId, weekStart };

    await this.prisma.notification.create({
      data: {
        childId,
        type: NotificationType.LEARNING_REPORT,
        title,
        body,
        data: {
          ...data,
          testsCount: summary.testsCount,
          overallPercent: summary.overallPercent,
          growthPercent: summary.growthPercent,
          strongSubject: summary.strongSubject,
          focusSubject: summary.focusSubject,
        },
      },
    });
    await this.fcm.sendPushToUser(child.parentId, { title, body, data });
    return true;
  }

  private async statResults(childId: string, fromDay: DayKey): Promise<StatResult[]> {
    const rows = await this.prisma.learningAttempt.findMany({
      where: {
        childId,
        status: LearningAttemptStatus.COMPLETED,
        day: { gte: fromDay },
      },
      select: { subject: true, correct: true, total: true, day: true },
    });
    return rows;
  }
}
