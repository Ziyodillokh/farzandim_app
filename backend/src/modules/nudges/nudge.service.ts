import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { NotificationType, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { FcmService } from '../../common/fcm/fcm.service';

/** Asia/Tashkent (UTC+5, DST yo'q) — barcha vaqtlar shu mintaqada hisoblanadi. */
const TASHKENT_OFFSET_MS = 5 * 60 * 60 * 1000;

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
    quietFrom: string | null;
    quietTo: string | null;
    lastStudyNudgeAt: Date | null;
    lastHealthNudgeAt: Date | null;
    lastContentReminderAt: Date | null;
  } | null;
}

const NUDGE_COPY: Record<
  NudgeKind,
  { type: string; notif: NotificationType; body: string; route: string }
> = {
  STUDY: {
    type: 'study_nudge',
    notif: NotificationType.STUDY_NUDGE,
    body: "Bugun bitta test yechib ko'rchi 📚",
    route: '/contests',
  },
  HEALTH: {
    type: 'health_nudge',
    notif: NotificationType.HEALTH_NUDGE,
    body: 'Biroz harakat qilsang-chi 🏃',
    route: '/dashboard',
  },
  CONTENT: {
    type: 'content_reminder',
    notif: NotificationType.CONTENT_REMINDER,
    body: 'Yangi videolar seni kutyapti 🎬',
    route: '/videos',
  },
};

@Injectable()
export class NudgeService {
  private readonly logger = new Logger(NudgeService.name);

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

  /**
   * Soatlik tekshiruv (test uchun `nowReal` beriladi). STUDY 16:00, HEALTH
   * 18:00, CONTENT shanba 11:00 (Tashkent). Boshqa soatlarda darhol chiqadi.
   */
  async tick(nowReal: Date): Promise<{ kind: NudgeKind | null; sent: number }> {
    const t = new Date(nowReal.getTime() + TASHKENT_OFFSET_MS);
    const hour = t.getUTCHours();
    const weekday = t.getUTCDay(); // 0=Yakshanba .. 6=Shanba

    const kind: NudgeKind | null =
      hour === 16
        ? 'STUDY'
        : hour === 18
          ? 'HEALTH'
          : hour === 11 && weekday === 6
            ? 'CONTENT'
            : null;
    if (!kind) return { kind: null, sent: 0 };

    const children = (await this.prisma.child.findMany({
      where: { childUserId: { not: null } },
      select: {
        id: true,
        name: true,
        childUserId: true,
        notificationPreference: {
          select: {
            studyNudge: true,
            healthNudge: true,
            contentReminder: true,
            quietFrom: true,
            quietTo: true,
            lastStudyNudgeAt: true,
            lastHealthNudgeAt: true,
            lastContentReminderAt: true,
          },
        },
      },
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
    if (kind === 'STUDY' && pref && !pref.studyNudge) return false;
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
    try {
      await this.fcm.sendPushToUser(child.childUserId, {
        title: 'Parvoz',
        body: copy.body,
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
        body: copy.body,
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
    const from = this.parseHhMm(pref?.quietFrom);
    const to = this.parseHhMm(pref?.quietTo);
    if (from === null || to === null || from === to) return false;
    const cur = tash.getUTCHours() * 60 + tash.getUTCMinutes();
    return from < to
      ? cur >= from && cur < to
      : cur >= from || cur < to; // tun (22:00–08:00) wrap
  }

  private parseHhMm(v: string | null | undefined): number | null {
    if (!v) return null;
    const m = /^(\d{1,2}):(\d{2})$/.exec(v);
    if (!m) return null;
    const h = Number(m[1]);
    const min = Number(m[2]);
    if (h > 23 || min > 59) return null;
    return h * 60 + min;
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

  /** Bugun test yechganmi (olimpiada urinishi). */
  private async studiedToday(childId: string, tash: Date): Promise<boolean> {
    const n = await this.prisma.olympiadAttempt.count({
      where: { childId, startedAt: { gte: this.todayStartUtc(tash) } },
    });
    return n > 0;
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
