import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { NotificationType, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { tr } from '../../common/i18n/notification-i18n';
import { errorLabel } from '../../common/notification-prefs/error-label';
import {
  DEFAULT_REMINDER_TIME,
  dueReminderTimes,
  isQuietAt,
  isValidReminderTime,
  reminderDueNow,
  tashkentMinutesOfDay,
} from '../../common/notification-prefs/notification-prefs';
import { TASHKENT_OFFSET_MS } from '../../common/time/tashkent';

/**
 * Kunlik eslatma: belgilangan vaqtdan keyin shuncha daqiqagacha (server qisqa to'xtab qolgan bo'lsa ham)
 * yuboriladi; undan keyin o'sha kun uchun o'tkazib yuboriladi.
 */
export const DAILY_REMINDER_CATCH_UP_MINUTES = 5;

/** Health: shu qadamdan kam bo'lsa "harakat qil" eslatmasi (faol bo'lsa jim). */
const HEALTH_STEPS_THRESHOLD = 3000;

type NudgeKind = 'STUDY' | 'HEALTH' | 'CONTENT';

interface NudgeChild {
  id: string;
  name: string;
  childUserId: string | null;
  notificationPreference: {
    studyNudge: boolean;
    healthNudge: boolean;
    contentReminder: boolean;
    dailyReminder: boolean;
    dailyReminderTime: string;
    quietFrom: string | null;
    quietTo: string | null;
    lastStudyNudgeAt: Date | null;
    lastHealthNudgeAt: Date | null;
    lastContentReminderAt: Date | null;
  } | null;
}

const NUDGE_COPY: Record<
  NudgeKind,
  { type: string; notif: NotificationType; bodyKey: string; route: string }
> = {
  STUDY: {
    type: 'study_nudge',
    notif: NotificationType.STUDY_NUDGE,
    bodyKey: 'nudge.study',
    route: '/contests',
  },
  HEALTH: {
    type: 'health_nudge',
    notif: NotificationType.HEALTH_NUDGE,
    bodyKey: 'nudge.health',
    route: '/dashboard',
  },
  CONTENT: {
    type: 'content_reminder',
    notif: NotificationType.CONTENT_REMINDER,
    bodyKey: 'nudge.content',
    route: '/videos',
  },
};

const NUDGE_CHILD_SELECT = {
  id: true,
  name: true,
  childUserId: true,
  notificationPreference: {
    select: {
      studyNudge: true,
      healthNudge: true,
      contentReminder: true,
      dailyReminder: true,
      dailyReminderTime: true,
      quietFrom: true,
      quietTo: true,
      lastStudyNudgeAt: true,
      lastHealthNudgeAt: true,
      lastContentReminderAt: true,
    },
  },
} satisfies Prisma.ChildSelect;

@Injectable()
export class NudgeService {
  private readonly logger = new Logger(NudgeService.name);
  private dailyReminderRunning = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmService,
  ) {}

  /** Har soat boshida (00 daqiqa). Belgilangan soatlardagina ish bajaradi. */
  @Cron('0 0 * * * *', { name: 'nudges' })
  async cron(): Promise<void> {
    const res = await this.tick(new Date());
    if (res.kind) {
      this.logger.log(`nudge ${res.kind}: sent ${res.sent}`);
    }
  }

  /** Har daqiqada: kunlik o'qish eslatmasi vaqti (bola sozlagan, Toshkent) kelganlarga. */
  @Cron(CronExpression.EVERY_MINUTE, { name: 'daily-reminder' })
  async dailyReminderCron(): Promise<void> {
    if (this.dailyReminderRunning) return;
    this.dailyReminderRunning = true;
    try {
      const sent = await this.tickDailyReminder(new Date());
      if (sent > 0) this.logger.log(`daily reminder: sent ${sent}`);
    } catch (err) {
      this.logger.error(`daily reminder xatosi: ${errorLabel(err)}`);
    } finally {
      this.dailyReminderRunning = false;
    }
  }

  /**
   * Kunlik o'qish eslatmasi (STUDY): har bolaga o'zining `dailyReminderTime` (standart 18:00, Toshkent)
   * vaqtida; avvalgi "bugun test yechmagan bo'lsa" mantiqi o'zgarmagan. `studyNudge` (ota-ona) VA
   * `dailyReminder` (bola) ikkalasi yoqilgan bo'lsa yuboriladi. Test uchun `nowReal` beriladi.
   */
  async tickDailyReminder(nowReal: Date): Promise<number> {
    const t = new Date(nowReal.getTime() + TASHKENT_OFFSET_MS);
    const minutes = tashkentMinutesOfDay(nowReal);
    // Saqlanishi mumkin bo'lgan vaqtlar faqat 06:00–21:00 — tunda bazaga umuman murojaat qilinmaydi.
    const times = dueReminderTimes(minutes, DAILY_REMINDER_CATCH_UP_MINUTES).filter(isValidReminderTime);
    if (times.length === 0) return 0;
    // Yozuvi yo'q bolalar standart vaqtda (18:00) eslatma oladi.
    const includeDefault = times.includes(DEFAULT_REMINDER_TIME);
    const children = (await this.prisma.child.findMany({
      where: {
        childUserId: { not: null },
        OR: [
          {
            notificationPreference: {
              is: { studyNudge: true, dailyReminder: true, dailyReminderTime: { in: times } },
            },
          },
          ...(includeDefault ? [{ notificationPreference: { is: null } }] : []),
        ],
      },
      select: NUDGE_CHILD_SELECT,
    })) as NudgeChild[];

    let sent = 0;
    for (const child of children) {
      const at = child.notificationPreference?.dailyReminderTime ?? DEFAULT_REMINDER_TIME;
      if (!reminderDueNow(at, minutes, DAILY_REMINDER_CATCH_UP_MINUTES)) continue;
      try {
        if (await this.maybeSend('STUDY', child, t, nowReal)) sent++;
      } catch (err) {
        this.logger.warn(`daily reminder yuborilmadi: ${errorLabel(err)}`);
      }
    }
    return sent;
  }

  /**
   * Soatlik tekshiruv (test uchun `nowReal` beriladi). HEALTH 18:00, CONTENT shanba 11:00
   * (Tashkent). Boshqa soatlarda darhol chiqadi. STUDY — `tickDailyReminder` (bola belgilagan vaqtda).
   */
  async tick(nowReal: Date): Promise<{ kind: NudgeKind | null; sent: number }> {
    const t = new Date(nowReal.getTime() + TASHKENT_OFFSET_MS);
    const hour = t.getUTCHours();
    const weekday = t.getUTCDay(); // 0=Yakshanba .. 6=Shanba

    const kind: NudgeKind | null =
      hour === 18
        ? 'HEALTH'
        : hour === 11 && weekday === 6
          ? 'CONTENT'
          : null;
    if (!kind) return { kind: null, sent: 0 };

    const children = (await this.prisma.child.findMany({
      where: { childUserId: { not: null } },
      select: NUDGE_CHILD_SELECT,
    })) as NudgeChild[];

    let sent = 0;
    for (const child of children) {
      try {
        if (await this.maybeSend(kind, child, t, nowReal)) sent++;
      } catch (err) {
        this.logger.warn({ err }, `nudge failed for ${child.id}`);
      }
    }
    return { kind, sent };
  }

  /** Bitta bola uchun: preference + tinch soat + guard + kontekst → yuborish. */
  private async maybeSend(
    kind: NudgeKind,
    child: NudgeChild,
    tash: Date,
    nowReal: Date,
  ): Promise<boolean> {
    const pref = child.notificationPreference;

    // Preference (default true) — o'chirilgan bo'lsa jim.
    if (kind === 'STUDY' && pref && !(pref.studyNudge && pref.dailyReminder)) return false;
    if (kind === 'HEALTH' && pref && !pref.healthNudge) return false;
    if (kind === 'CONTENT' && pref && !pref.contentReminder) return false;

    // Tinch soatlar (tun) — hurmat qilinadi.
    if (this.isQuiet(pref, tash)) return false;

    // Kuniga/haftada bir marta (spam yo'q).
    if (kind === 'STUDY' && this.isSameTashDay(pref?.lastStudyNudgeAt, tash)) {
      return false;
    }
    if (kind === 'HEALTH' && this.isSameTashDay(pref?.lastHealthNudgeAt, tash)) {
      return false;
    }
    if (
      kind === 'CONTENT' &&
      pref?.lastContentReminderAt &&
      nowReal.getTime() - pref.lastContentReminderAt.getTime() <
        6 * 24 * 60 * 60 * 1000
    ) {
      return false;
    }

    // Kontekst — bola allaqachon faol bo'lsa bezovta qilmaymiz (ijobiy ohang).
    if (kind === 'STUDY' && (await this.studiedToday(child.id, tash))) {
      return false;
    }
    if (kind === 'HEALTH' && (await this.activeToday(child.id, tash))) {
      return false;
    }

    if (!child.childUserId) return false;

    const copy = NUDGE_COPY[kind];
    const lang = await this.fcm.getUserLang(child.childUserId);
    const nudgeBody = tr(lang, copy.bodyKey);
    try {
      await this.fcm.sendPushToUser(child.childUserId, {
        title: 'Parvoz',
        body: nudgeBody,
        data: {
          type: copy.type,
          childId: child.id,
          relatedRoute: copy.route,
        },
      });
    } catch (err) {
      this.logger.warn({ err }, `nudge push failed for ${child.id}`);
    }

    await this.prisma.notification.create({
      data: {
        childId: child.id,
        type: copy.notif,
        title: 'Parvoz',
        body: nudgeBody,
        data: { type: copy.type, relatedRoute: copy.route },
      },
    });

    // last*NudgeAt yangilash (yozuv yo'q bo'lsa yaratiladi).
    const stamp: Prisma.NotificationPreferenceUpsertArgs['create'] = {
      childId: child.id,
    };
    const update: Prisma.NotificationPreferenceUpdateInput = {};
    if (kind === 'STUDY') {
      stamp.lastStudyNudgeAt = nowReal;
      update.lastStudyNudgeAt = nowReal;
    } else if (kind === 'HEALTH') {
      stamp.lastHealthNudgeAt = nowReal;
      update.lastHealthNudgeAt = nowReal;
    } else {
      stamp.lastContentReminderAt = nowReal;
      update.lastContentReminderAt = nowReal;
    }
    await this.prisma.notificationPreference.upsert({
      where: { childId: child.id },
      create: stamp,
      update,
    });

    return true;
  }

  /** Tinch soat oynasi ichidami (wrap-around qo'llab-quvvatlanadi). */
  private isQuiet(
    pref: NudgeChild['notificationPreference'],
    tash: Date,
  ): boolean {
    const minutes = tash.getUTCHours() * 60 + tash.getUTCMinutes();
    return isQuietAt(pref?.quietFrom, pref?.quietTo, minutes);
  }

  /** `d` Tashkent kuni `tash` bilan bir xilmi (kuniga-bir guard). */
  private isSameTashDay(d: Date | null | undefined, tash: Date): boolean {
    if (!d) return false;
    const a = new Date(d.getTime() + TASHKENT_OFFSET_MS);
    return (
      a.getUTCFullYear() === tash.getUTCFullYear() &&
      a.getUTCMonth() === tash.getUTCMonth() &&
      a.getUTCDate() === tash.getUTCDate()
    );
  }

  /** Tashkent bugungi 00:00'ning real UTC instant'i. */
  private todayStartUtc(tash: Date): Date {
    const wall = Date.UTC(
      tash.getUTCFullYear(),
      tash.getUTCMonth(),
      tash.getUTCDate(),
    );
    return new Date(wall - TASHKENT_OFFSET_MS);
  }

  /** Bugun test yechganmi (olimpiada urinishi yoki yakunlangan kunlik o'qish testi). */
  private async studiedToday(childId: string, tash: Date): Promise<boolean> {
    const since = this.todayStartUtc(tash);
    const [olympiad, learning] = await Promise.all([
      this.prisma.olympiadAttempt.count({
        where: { childId, startedAt: { gte: since } },
      }),
      this.prisma.learningAttempt.count({
        where: { childId, status: 'COMPLETED', completedAt: { gte: since } },
      }),
    ]);
    return olympiad + learning > 0;
  }

  /** Bugun yetarli harakat qilganmi (qadam). */
  private async activeToday(childId: string, tash: Date): Promise<boolean> {
    const latest = await this.prisma.childStepDaily.findFirst({
      where: { childId },
      orderBy: { date: 'desc' },
      select: { date: true, steps: true },
    });
    if (!latest) return false;
    // Eng so'nggi yozuv bugungi (Tashkent) bo'lsa va qadam yetarli — faol.
    return (
      this.isSameTashDay(latest.date, tash) &&
      latest.steps >= HEALTH_STEPS_THRESHOLD
    );
  }
}
