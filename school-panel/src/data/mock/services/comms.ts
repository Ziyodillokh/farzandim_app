import { roleHas } from '@/auth/permissions';
import type { Audience } from '@/data/contracts';
import { audienceSchema, type AudienceInput } from '@/data/schemas/comms';
import { parseOrThrow } from '@/data/schemas/validate';
import { clockNow, clockToday } from '../clock';
import { assertCan, currentActor, latency } from '../context';
import { getTables } from '../db';
import { announcementsService, type AnnouncementRow, visibleAnnouncements } from './comms-announcements';
import { paymentStats, paymentsService, type PaymentStats } from './comms-payments';
import { reminderRows, type ReminderRow, remindersService } from './comms-reminders';
import { assertAudienceAllowed, type AudienceReach, reachOf, timeOf } from './comms-shared';
import { MESSAGE_TEMPLATES, type MessageTemplate } from './comms-templates';
import { verificationCounts, verificationsService } from './comms-verifications';

export type { AnnouncementCounts, AnnouncementDetail, AnnouncementFilter, AnnouncementList, AnnouncementRow, SendOptions } from './comms-announcements';
export type { PaymentFilter, PaymentFilterKind, PaymentHistoryEntry, PaymentRow, PaymentStats } from './comms-payments';
export { addMonthsIso } from './comms-payments';
export type { ReminderFilter, ReminderList, ReminderRow, ReminderStats, ReminderWhen } from './comms-reminders';
export type { AudienceReach, ChildRef } from './comms-shared';
export type { MessageTemplate, TemplateId } from './comms-templates';
export type { VerificationCounts, VerificationFilter, VerificationList, VerificationRow } from './comms-verifications';

/** Bosh sahifa uchun qisqa xulosa (rolga qarab: ruxsat yo'q bo'limlar — null). */
export type CommsOverview = {
  scheduled: number;
  sentLast7Days: number;
  lastSent: AnnouncementRow | null;
  upcomingReminders: ReminderRow[] | null;
  openVerifications: number | null;
  payments: PaymentStats | null;
};

const WEEK_MS = 7 * 86_400_000;

/**
 * Xabarlar, Smart Reminder, to'lov eslatmalari va tekshiruv so'rovlari (TZ 4.5).
 * Ruxsatlar: messages.view / sendSchool / sendClass, reminders.manage, payments.manage.
 */
export const commsService = {
  announcements: announcementsService,
  reminders: remindersService,
  payments: paymentsService,
  verifications: verificationsService,

  /** Auditoriya hajmi: o'quvchilar, ota-onalar, shundan Parvoz'ga ulangan (push) va SMS zaxira. */
  async audienceSize(input: AudienceInput): Promise<AudienceReach> {
    await latency(40, 100);
    const actor = currentActor();
    assertCan(actor, 'messages.view');
    const empty = (input.kind === 'CLASSES' && !input.classIds?.length) || (input.kind === 'GUARDIANS' && !input.guardianIds?.length);
    if (empty) return { students: 0, guardians: 0, linked: 0, sms: 0 };
    const audience: Audience = parseOrThrow(audienceSchema, input);
    const t = getTables();
    assertAudienceAllowed(actor, t, audience);
    return reachOf(t, audience);
  },

  async templates(): Promise<readonly MessageTemplate[]> {
    await latency(30, 80);
    assertCan(currentActor(), 'messages.view');
    return MESSAGE_TEMPLATES;
  },

  async overview(limit = 3): Promise<CommsOverview> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'messages.view');
    const t = getTables();
    const now = clockNow();
    const rows = visibleAnnouncements(actor, t, now);
    const sent = rows.filter((r) => r.status === 'SENT');
    return {
      scheduled: rows.filter((r) => r.status === 'SCHEDULED').length,
      sentLast7Days: sent.filter((r) => now.getTime() - timeOf(r.sentAt) <= WEEK_MS).length,
      lastSent: sent[0] ?? null,
      upcomingReminders: roleHas(actor.role, 'reminders.manage')
        ? reminderRows(t, now)
            .filter((r) => !r.isPast && r.active)
            .slice(0, limit)
        : null,
      openVerifications: roleHas(actor.role, 'payments.manage') ? verificationCounts(t).OPEN : null,
      payments: roleHas(actor.role, 'payments.manage') ? paymentStats(t, clockToday()) : null,
    };
  },
};
