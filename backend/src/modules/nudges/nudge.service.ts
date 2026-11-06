import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { NotificationType, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { tr } from '../../common/i18n/notification-i18n';
import { isQuietAt } from '../../common/notification-prefs/notification-prefs';
import { TASHKENT_OFFSET_MS } from '../../common/time/tashkent';

/** Health: shu qadamdan kam bo'lsa "harakat qil" eslatmasi (faol bo'lsa jim). */
const HEALTH_STEPS_THRESHOLD = 3000;

/** Soatlik nudge'lar. Kunlik o'qish eslatmasi (STUDY) — `DailyReminderService` (bola belgilagan vaqtda). */
type NudgeKind = 'HEALTH' | 'CONTENT';

interface NudgeChild {
  id: string;
  name: string;
  childUserId: string | null;
  notificationPreference: {
    healthNudge: boolean;
    contentReminder: boolean;
    quietFrom: string | null;
    quietTo: string | null;
    lastHealthNudgeAt: Date | null;
    lastContentReminderAt: Date | null;
  } | null;
}

const NUDGE_COPY: Record<
  NudgeKind,
  { type: string; notif: NotificationType; bodyKey: string; route: string }
> = {
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
   * Soatlik tekshiruv (test uchun `nowReal` beriladi). HEALTH 18:00, CONTENT
   * shanba 11:00 (Tashkent). Boshqa soatlarda darhol chiqadi.
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
      select: {
        id: true,
        name: true,
        childUserId: true,
        notificationPreference: {
          select: {
            healthNudge: true,
            contentReminder: true,
            quietFrom: true,
            quietTo: true,
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
    if (kind === 'HEALTH' && pref && !pref.healthNudge) return false;
    if (kind === 'CONTENT' && pref && !pref.contentReminder) return false;

    // Tinch soatlar (tun) — hurmat qilinadi.
    if (this.isQuiet(pref, tash)) return false;

    // Kuniga/haftada bir marta (spam yo'q).
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
    if (kind === 'HEALTH') {
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
