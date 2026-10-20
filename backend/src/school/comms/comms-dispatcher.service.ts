// Har daqiqada (Asia/Tashkent): vaqti kelgan rejali e'lonlar, Smart Reminder
// va to'lov eslatmalari yuboriladi. Har element avval SHARTLI yangilanish bilan
// "egallanadi" (status / lastSentAt) — ikki server nusxasi yoki takroriy ishga
// tushirish bir xabarni ikki marta yubormaydi. `dispatchDue(now)` — testlar uchun.

import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { SchoolPaymentReminder, SchoolReminder } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { addDays, TASHKENT_TZ, tashkentDay, tashkentDayStart } from '../../common/time/tashkent';
import { AnnouncementDeliveryService } from './announcement-delivery.service';
import { paymentPush, reminderPush } from './comms.i18n';
import { CommsPushService, mapLimit } from './comms-push.service';
import { audienceGuardians, loadRoster, toAudience } from './comms-roster';
import { latestOccurrence, tashkentHour } from './comms-time';
import { toReminderKind, toRepeat } from './reminder-views';

/** Bitta aylanishda ko'pi bilan nechta rejali e'lon (qolgani — keyingi daqiqada). */
const ANNOUNCEMENT_BATCH = 50;
/** Eslatma shuncha kechiksa (server o'chiq bo'lgan) — eskirgan, yuborilmaydi. */
const MAX_REMINDER_LATENESS_MS = 30 * 60 * 1000;
/** To'lov eslatmasi keyingi sanadan necha kun oldin keladi. */
export const PAYMENT_NOTICE_DAYS = 3;
/** To'lov eslatmalari Toshkent vaqti bilan shu soatdan keyin (tunda emas). */
export const PAYMENT_SEND_HOUR = 9;
const PAYMENT_CONCURRENCY = 8;

export interface DispatchSummary {
  announcements: number;
  reminders: number;
  payments: number;
}

@Injectable()
export class CommsDispatcherService {
  private readonly logger = new Logger(CommsDispatcherService.name);
  private running = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly delivery: AnnouncementDeliveryService,
    private readonly push: CommsPushService,
  ) {}

  @Cron(CronExpression.EVERY_MINUTE, { name: 'school-comms-dispatch', timeZone: TASHKENT_TZ })
  async tick(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      await this.dispatchDue(new Date());
    } catch (err) {
      this.logger.error(`maktab xabarlari dispatch xatosi: ${String(err)}`);
    } finally {
      this.running = false;
    }
  }

  async dispatchDue(now: Date = new Date()): Promise<DispatchSummary> {
    return {
      announcements: await this.dispatchAnnouncements(now),
      reminders: await this.dispatchReminders(now),
      payments: await this.dispatchPayments(now),
    };
  }

  private async dispatchAnnouncements(now: Date): Promise<number> {
    const due = await this.prisma.schoolAnnouncement.findMany({
      where: { status: 'SCHEDULED', scheduledAt: { lte: now }, school: { status: 'ACTIVE' } },
      select: { id: true, schoolId: true },
      orderBy: { scheduledAt: 'asc' },
      take: ANNOUNCEMENT_BATCH,
    });
    const sent = await mapLimit(due, 1, (a) => this.sendScheduled(a.id, a.schoolId, now));
    return sent.filter(Boolean).length;
  }

  private async sendScheduled(id: string, schoolId: string, now: Date): Promise<boolean> {
    try {
      const claimed = await this.prisma.$transaction(async (tx) => {
        const current = await tx.schoolAnnouncement.findUnique({ where: { id }, select: { audience: true } });
        if (!current) return null;
        const roster = await loadRoster(tx, schoolId);
        const guardians = audienceGuardians(roster, toAudience(current.audience));
        return this.delivery.claim(tx, { id, schoolId, from: ['SCHEDULED'], dueBy: now, keepSchedule: true, guardians, now });
      });
      if (!claimed) return false;
      await this.delivery.pushPending(id, now);
      return true;
    } catch (err) {
      this.logger.error(`rejali e'lon yuborilmadi (${id}): ${String(err)}`);
      return false;
    }
  }

  private async dispatchReminders(now: Date): Promise<number> {
    const candidates = await this.prisma.schoolReminder.findMany({
      where: {
        active: true,
        school: { status: 'ACTIVE' },
        OR: [
          { repeat: 'NONE', sendAt: { gte: new Date(now.getTime() - MAX_REMINDER_LATENESS_MS), lte: now } },
          { repeat: { not: 'NONE' }, sendAt: { lte: now } },
        ],
      },
    });
    const sent = await mapLimit(candidates, 1, (r) => this.sendReminder(r, now));
    return sent.filter(Boolean).length;
  }

  /** Oxirgi (≤ now) navbat hali yuborilmagan va eskirmagan bo'lsa — egallab yuborish. */
  private async sendReminder(r: SchoolReminder, now: Date): Promise<boolean> {
    const occurrence = latestOccurrence(r.sendAt, toRepeat(r.repeat), now);
    if (!occurrence || now.getTime() - occurrence.getTime() > MAX_REMINDER_LATENESS_MS) return false;
    if (r.lastSentAt && r.lastSentAt.getTime() >= occurrence.getTime()) return false;
    try {
      const claimed = await this.prisma.schoolReminder.updateMany({
        where: { id: r.id, active: true, OR: [{ lastSentAt: null }, { lastSentAt: { lt: occurrence } }] },
        data: { lastSentAt: now },
      });
      if (claimed.count !== 1) return false;
      const roster = await loadRoster(this.prisma, r.schoolId);
      const userIds = audienceGuardians(roster, toAudience(r.audience))
        .map((g) => g.userId)
        .filter((u): u is string => u !== null);
      const school = await this.push.schoolLabel(r.schoolId);
      const kind = toReminderKind(r.kind);
      await this.push.sendToUsers(userIds, (lang) =>
        reminderPush(lang, { id: r.id, school, kind, title: r.title, body: r.body }),
      );
      return true;
    } catch (err) {
      this.logger.error(`eslatma yuborilmadi (${r.id}): ${String(err)}`);
      return false;
    }
  }

  /** Keyingi sanadan PAYMENT_NOTICE_DAYS kun oldin (09:00 dan keyin) — har davrda bir marta. */
  private async dispatchPayments(now: Date): Promise<number> {
    if (tashkentHour(now) < PAYMENT_SEND_HOUR) return 0;
    const today = tashkentDay(now);
    const candidates = await this.prisma.schoolPaymentReminder.findMany({
      where: {
        paused: false,
        nextDate: { gte: today, lte: addDays(today, PAYMENT_NOTICE_DAYS) },
        school: { status: 'ACTIVE' },
      },
    });
    if (candidates.length === 0) return 0;
    const guardians = await this.prisma.schoolGuardian.findMany({
      where: { id: { in: candidates.map((p) => p.guardianId) }, userId: { not: null }, linkStatus: 'LINKED' },
      select: { id: true, schoolId: true, userId: true },
    });
    const users = new Map(guardians.map((g) => [`${g.schoolId}:${g.id}`, g.userId]));
    const sent = await mapLimit(candidates, PAYMENT_CONCURRENCY, (p) =>
      this.sendPayment(p, users.get(`${p.schoolId}:${p.guardianId}`) ?? null, now),
    );
    return sent.filter(Boolean).length;
  }

  private async sendPayment(p: SchoolPaymentReminder, userId: string | null, now: Date): Promise<boolean> {
    if (!userId) return false;
    const cycleStart = tashkentDayStart(addDays(p.nextDate, -PAYMENT_NOTICE_DAYS));
    if (p.lastSentAt && p.lastSentAt.getTime() >= cycleStart.getTime()) return false;
    try {
      const claimed = await this.prisma.schoolPaymentReminder.updateMany({
        where: {
          id: p.id,
          paused: false,
          nextDate: p.nextDate,
          OR: [{ lastSentAt: null }, { lastSentAt: { lt: cycleStart } }],
        },
        data: { lastSentAt: now },
      });
      if (claimed.count !== 1) return false;
      const school = await this.push.schoolLabel(p.schoolId);
      return this.push.sendOne(userId, (lang) => paymentPush(lang, { id: p.id, school, nextDate: p.nextDate }));
    } catch (err) {
      this.logger.error(`to'lov eslatmasi yuborilmadi (${p.id}): ${String(err)}`);
      return false;
    }
  }
}
