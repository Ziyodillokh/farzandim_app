// Xabarlar umumiy so'rovlari (panel `commsService.audienceSize / templates /
// overview`): auditoriya hajmi (push ulangan + SMS zaxira), tayyor shablonlar,
// bosh sahifa xulosasi (ruxsati yo'q bo'limlar — null). Ruxsat: messages.view.

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { actorCan, assertCan, SchoolActor } from '../auth/school-actor';
import { parseOrThrow } from '../common/school-zod';
import { loadAnnouncementContext, visibleRows, withStats } from './announcement-views';
import { audienceSchema, overviewQuerySchema } from './comms.schemas';
import { assertAudienceAllowed, AudienceReach, loadRoster, reachOf } from './comms-roster';
import { MESSAGE_TEMPLATES, MessageTemplate } from './comms-templates';
import { paymentStats } from './payment-views';
import { reminderRows } from './reminder-views';

const WEEK_MS = 7 * 24 * 60 * 60 * 1000;
const EMPTY_REACH: AudienceReach = { students: 0, guardians: 0, linked: 0, sms: 0 };

/** Hali tanlanmagan auditoriya (sinf / vasiy ro'yxati bo'sh) — xato emas, nol. */
function isEmptySelection(input: unknown): boolean {
  const v = (input && typeof input === 'object' ? input : {}) as Record<string, unknown>;
  const none = (x: unknown) => !Array.isArray(x) || x.length === 0;
  return (v.kind === 'CLASSES' && none(v.classIds)) || (v.kind === 'GUARDIANS' && none(v.guardianIds));
}

@Injectable()
export class CommsOverviewService {
  constructor(private readonly prisma: PrismaService) {}

  /** Auditoriya hajmi: o'quvchilar, vasiylar, shundan Parvoz'ga ulangan (push) va SMS zaxira. */
  async audienceSize(actor: SchoolActor, input: unknown): Promise<AudienceReach> {
    assertCan(actor, 'messages.view');
    if (isEmptySelection(input)) return EMPTY_REACH;
    const audience = parseOrThrow(audienceSchema, input);
    const roster = await loadRoster(this.prisma, actor.schoolId);
    assertAudienceAllowed(actor, roster, audience);
    return reachOf(roster, audience);
  }

  templates(actor: SchoolActor): readonly MessageTemplate[] {
    assertCan(actor, 'messages.view');
    return MESSAGE_TEMPLATES;
  }

  async overview(actor: SchoolActor, raw: Record<string, unknown>) {
    assertCan(actor, 'messages.view');
    const { limit } = parseOrThrow(overviewQuerySchema, raw);
    const now = new Date();
    const ctx = await loadAnnouncementContext(this.prisma, actor.schoolId);
    const rows = await visibleRows(this.prisma, actor, ctx);
    const sent = rows.filter((r) => r.status === 'SENT');
    const [lastSent] = await withStats(this.prisma, sent.slice(0, 1));
    return {
      scheduled: rows.filter((r) => r.status === 'SCHEDULED').length,
      sentLast7Days: sent.filter((r) => r.sentAt && now.getTime() - Date.parse(r.sentAt) <= WEEK_MS).length,
      lastSent: lastSent ?? null,
      upcomingReminders: actorCan(actor, 'reminders.manage') ? await this.upcoming(actor, ctx.roster, now, limit) : null,
      openVerifications: actorCan(actor, 'payments.manage')
        ? await this.prisma.schoolVerificationRequest.count({ where: { schoolId: actor.schoolId, status: 'OPEN' } })
        : null,
      payments: actorCan(actor, 'payments.manage') ? await this.paymentSummary(actor) : null,
    };
  }

  private async upcoming(actor: SchoolActor, roster: Awaited<ReturnType<typeof loadRoster>>, now: Date, limit: number) {
    const reminders = await this.prisma.schoolReminder.findMany({ where: { schoolId: actor.schoolId } });
    return reminderRows(roster, reminders, now)
      .filter((r) => !r.isPast && r.active)
      .slice(0, limit);
  }

  private async paymentSummary(actor: SchoolActor) {
    const payments = await this.prisma.schoolPaymentReminder.findMany({
      where: { schoolId: actor.schoolId },
      select: { paused: true, nextDate: true, prepaidMonths: true },
    });
    return paymentStats(payments, tashkentDay());
  }
}
