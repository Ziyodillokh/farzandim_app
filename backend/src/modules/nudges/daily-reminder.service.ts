// Kunlik o'qish eslatmasi (Men I07): har bolaga o'zining `dailyReminderTime` (standart 18:00, Toshkent) vaqtida
// "Bugun bitta test yechib ko'rchi" — bugun test yechmagan bo'lsa. `studyNudge` (ota-ona) VA `dailyReminder` (bola)
// ikkalasi yoqilgan, tinch soatda emas.
//
// Masshtab va bir martalik kafolat:
//  - har daqiqada faqat vaqti hozirgi oynaga (oxirgi 5 daqiqa) tushganlar tanlanadi (`daily_reminder_time` indeksi), bugun
//    allaqachon ko'rib chiqilganlar (`child_push_dedupe`: STUDY_NUDGE, Toshkent kuni) va bugun yuborilganlar so'rovdan chiqariladi;
//  - bola uchun kun bo'yicha qator ATOMIK egallanadi (bir nechta server / takroriy tick / xato bo'lsa ham bir marta);
//    egallangan, lekin bugun test yechgan bolaga push yuborilmaydi (qator qoladi — qayta ko'rib chiqilmaydi);
//  - "bugun test yechganmi" — partiyalab; push — cheklangan parallellik bilan.
// Logda bola / ism yo'q.

import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { NotificationType } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { chunk, mapLimit } from '../../common/helpers/map-limit';
import { tr } from '../../common/i18n/notification-i18n';
import { ChildPushDedupeService } from '../../common/notification-prefs/child-push-dedupe.service';
import { errorLabel } from '../../common/notification-prefs/error-label';
import {
  DEFAULT_REMINDER_TIME,
  dueReminderTimes,
  isQuietAt,
  isValidReminderTime,
  reminderDueNow,
  tashkentMinutesOfDay,
} from '../../common/notification-prefs/notification-prefs';
import { tashkentDay, tashkentDayStart } from '../../common/time/tashkent';

/** Eslatma vaqtidan keyin shuncha daqiqagacha (server qisqa to'xtab qolgan bo'lsa ham) yuboriladi, keyin — o'sha kun uchun o'tkaziladi. */
export const DAILY_REMINDER_CATCH_UP_MINUTES = 5;
/** `child_push_dedupe.kind` — kalit: Toshkent kuni (`YYYY-MM-DD`). */
export const STUDY_NUDGE_DEDUPE_KIND = 'STUDY_NUDGE';
export const STUDY_NUDGE_PUSH_TYPE = 'study_nudge';
const STUDY_NUDGE_ROUTE = '/contests';
const PUSH_CONCURRENCY = 8;
const LOOKUP_BATCH = 1000;

interface DueChild {
  id: string;
  childUserId: string;
}

@Injectable()
export class DailyReminderService {
  private readonly logger = new Logger(DailyReminderService.name);
  private running = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmService,
    private readonly dedupe: ChildPushDedupeService,
  ) {}

  @Cron(CronExpression.EVERY_MINUTE, { name: 'daily-reminder' })
  async tick(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      const sent = await this.run(new Date());
      if (sent > 0) this.logger.log(`daily reminder: ${sent} ta push`);
    } catch (err) {
      this.logger.error(`daily reminder xatosi: ${errorLabel(err)}`);
    } finally {
      this.running = false;
    }
  }

  /** `nowReal` (Toshkent vaqti bo'yicha) uchun eslatmalarni yuborish; yuborilganlar soni. */
  async run(nowReal: Date): Promise<number> {
    const minutes = tashkentMinutesOfDay(nowReal);
    // Saqlanishi mumkin bo'lgan vaqtlar faqat 06:00–21:00 — tunda bazaga umuman murojaat qilinmaydi.
    const times = dueReminderTimes(minutes, DAILY_REMINDER_CATCH_UP_MINUTES).filter(isValidReminderTime);
    if (times.length === 0) return 0;
    const day = tashkentDay(nowReal);
    const dayStart = tashkentDayStart(day);

    const due = await this.dueChildren({ times, minutes, day, dayStart });
    if (due.length === 0) return 0;
    const claimed = new Set(await this.dedupe.claim(due.map((c) => c.id), STUDY_NUDGE_DEDUPE_KIND, day));
    const won = due.filter((c) => claimed.has(c.id));
    const studied = await this.studiedToday(won.map((c) => c.id), dayStart);
    const targets = won.filter((c) => !studied.has(c.id));
    const results = await mapLimit(targets, PUSH_CONCURRENCY, (c) => this.remind(c, nowReal));
    return results.filter(Boolean).length;
  }

  /** Vaqti kelgan, bugun ko'rib chiqilmagan/yuborilmagan, tinch soatda bo'lmagan bolalar. */
  private async dueChildren(q: { times: string[]; minutes: number; day: string; dayStart: Date }): Promise<DueChild[]> {
    // Sozlamasi yo'q bolalar standart vaqtda (18:00) eslatma oladi.
    const includeDefault = q.times.includes(DEFAULT_REMINDER_TIME);
    const rows = await this.prisma.child.findMany({
      where: {
        childUserId: { not: null },
        pushDedupe: { none: { kind: STUDY_NUDGE_DEDUPE_KIND, refKey: q.day } },
        OR: [
          {
            notificationPreference: {
              is: {
                studyNudge: true,
                dailyReminder: true,
                dailyReminderTime: { in: q.times },
                OR: [{ lastStudyNudgeAt: null }, { lastStudyNudgeAt: { lt: q.dayStart } }],
              },
            },
          },
          ...(includeDefault ? [{ notificationPreference: { is: null } }] : []),
        ],
      },
      select: { id: true, childUserId: true, notificationPreference: { select: { dailyReminderTime: true, quietFrom: true, quietTo: true } } },
    });
    return rows.flatMap((r): DueChild[] => {
      const pref = r.notificationPreference;
      const at = pref?.dailyReminderTime ?? DEFAULT_REMINDER_TIME;
      if (!r.childUserId || !reminderDueNow(at, q.minutes, DAILY_REMINDER_CATCH_UP_MINUTES)) return [];
      if (isQuietAt(pref?.quietFrom, pref?.quietTo, q.minutes)) return [];
      return [{ id: r.id, childUserId: r.childUserId }];
    });
  }

  /** Bugun test yechgan bolalar: olimpiada urinishi yoki yakunlangan kunlik o'qish testi (partiyalab). */
  private async studiedToday(childIds: readonly string[], since: Date): Promise<Set<string>> {
    const studied = new Set<string>();
    for (const batch of chunk(childIds, LOOKUP_BATCH)) {
      const [olympiad, learning] = await Promise.all([
        this.prisma.olympiadAttempt.findMany({
          where: { childId: { in: batch }, startedAt: { gte: since } },
          distinct: ['childId'],
          select: { childId: true },
        }),
        this.prisma.learningAttempt.findMany({
          where: { childId: { in: batch }, status: 'COMPLETED', completedAt: { gte: since } },
          distinct: ['childId'],
          select: { childId: true },
        }),
      ]);
      for (const row of [...olympiad, ...learning]) studied.add(row.childId);
    }
    return studied;
  }

  /** Bitta bolaga push + bildirishnomalar ro'yxatiga yozuv + oxirgi yuborilgan vaqt; `true` — jarayon tugadi. */
  private async remind(child: DueChild, nowReal: Date): Promise<boolean> {
    try {
      const lang = await this.fcm.getUserLang(child.childUserId);
      const body = tr(lang, 'nudge.study');
      try {
        await this.fcm.sendPushToUser(child.childUserId, {
          title: 'Parvoz',
          body,
          data: { type: STUDY_NUDGE_PUSH_TYPE, childId: child.id, relatedRoute: STUDY_NUDGE_ROUTE },
        });
      } catch (err) {
        this.logger.warn(`daily reminder push yuborilmadi: ${errorLabel(err)}`);
      }
      await this.prisma.notification.create({
        data: {
          childId: child.id,
          type: NotificationType.STUDY_NUDGE,
          title: 'Parvoz',
          body,
          data: { type: STUDY_NUDGE_PUSH_TYPE, relatedRoute: STUDY_NUDGE_ROUTE },
        },
      });
      await this.prisma.notificationPreference.upsert({
        where: { childId: child.id },
        create: { childId: child.id, lastStudyNudgeAt: nowReal },
        update: { lastStudyNudgeAt: nowReal },
      });
      return true;
    } catch (err) {
      this.logger.warn(`daily reminder bajarilmadi: ${errorLabel(err)}`);
      return false;
    }
  }
}
