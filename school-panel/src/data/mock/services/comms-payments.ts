import type { IsoDate, ListQuery, Paginated, ParentLinkStatus, PaymentReminder, PaymentReminderEntry } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import {
  paymentBulkShiftSchema,
  paymentPauseSchema,
  paymentShiftSchema,
  type PaymentBulkShiftInput,
  type PaymentShiftInput,
} from '@/data/schemas/comms';
import { parseOrThrow } from '@/data/schemas/validate';
import { addDays, fromIsoDate, toIsoDate } from '../calendar';
import { clockToday } from '../clock';
import { type Actor, assertCan, currentActor, latency, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { runListQuery } from '../query';
import type { Tables } from '../tables';
import { type ChildRef, childrenByGuardian, nowLocalIso, staffName } from './comms-shared';

/**
 * To'lov ESLATMALARI. Platforma to'lov qabul qilmaydi va qarz hisoblamaydi —
 * faqat maktab tasdiqlagan keyingi eslatma sanasi saqlanadi (TZ 4.5).
 */
export type PaymentFilterKind = 'ALL' | 'DUE_SOON' | 'PREPAID' | 'PAUSED';
export type PaymentFilter = ListQuery & { filter?: PaymentFilterKind };
export type PaymentRow = PaymentReminder & {
  guardianName: string;
  phone: string;
  linkStatus: ParentLinkStatus;
  children: ChildRef[];
  dueSoon: boolean;
  openVerifications: number;
  lastEntry: PaymentReminderEntry | null;
};
export type PaymentStats = { families: number; dueSoon: number; prepaid: number; paused: number; nearestDate: IsoDate | null; dueSoonDays: number };
export type PaymentHistoryEntry = PaymentReminderEntry & { byName: string };

/** "Yaqin" eslatmalar oynasi (kun). */
export const DUE_SOON_DAYS = 30;

export function addMonthsIso(iso: IsoDate, months: number): IsoDate {
  const date = fromIsoDate(iso);
  const day = date.getDate();
  date.setDate(1);
  date.setMonth(date.getMonth() + months);
  const lastDay = new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
  date.setDate(Math.min(day, lastDay));
  return toIsoDate(date);
}

function isDueSoon(p: PaymentReminder, today: IsoDate): boolean {
  return !p.paused && p.nextDate >= today && p.nextDate <= addDays(today, DUE_SOON_DAYS);
}

export function paymentRows(t: Tables, today: IsoDate): PaymentRow[] {
  const guardians = new Map(t.guardians.map((g) => [g.id, g]));
  const children = childrenByGuardian(t);
  const open = new Map<string, number>();
  for (const v of t.verifications) if (v.status === 'OPEN') open.set(v.paymentReminderId, (open.get(v.paymentReminderId) ?? 0) + 1);
  return t.payments.map((p) => {
    const g = guardians.get(p.guardianId);
    const kids = children.get(p.guardianId) ?? [];
    return {
      ...p,
      guardianName: g?.fullName ?? '—',
      phone: g?.phone ?? '',
      linkStatus: g?.linkStatus ?? 'NOT_INVITED',
      children: kids.filter((c) => p.studentIds.includes(c.id)),
      dueSoon: isDueSoon(p, today),
      openVerifications: open.get(p.id) ?? 0,
      lastEntry: p.history.at(-1) ?? null,
    };
  });
}

export function paymentStats(t: Tables, today: IsoDate): PaymentStats {
  const active = t.payments.filter((p) => !p.paused && p.nextDate >= today);
  const nearestDate = active.reduce<IsoDate | null>((min, p) => (!min || p.nextDate < min ? p.nextDate : min), null);
  return {
    families: t.payments.length,
    dueSoon: t.payments.filter((p) => isDueSoon(p, today)).length,
    prepaid: t.payments.filter((p) => p.prepaidMonths > 0).length,
    paused: t.payments.filter((p) => p.paused).length,
    nearestDate,
    dueSoonDays: DUE_SOON_DAYS,
  };
}

function matchesFilter(r: PaymentRow, kind: PaymentFilterKind | undefined): boolean {
  if (kind === 'DUE_SOON') return r.dueSoon;
  if (kind === 'PREPAID') return r.prepaidMonths > 0;
  if (kind === 'PAUSED') return r.paused;
  return true;
}

function entry(actor: Actor, action: PaymentReminderEntry['action'], note: string): PaymentReminderEntry {
  return { at: nowLocalIso(), byStaffId: actor.staffId, action, note };
}

function findPayment(t: Tables, id: string): PaymentReminder {
  const payment = t.payments.find((p) => p.id === id);
  if (!payment) throw new ServiceError('NOT_FOUND', id);
  return payment;
}

function guardianLabel(t: Tables, p: PaymentReminder): string {
  return t.guardians.find((g) => g.id === p.guardianId)?.fullName ?? p.guardianId;
}

/** Bitta oila uchun keyingi sanani o'zgartirish (transact ichida). */
export function applyShift(t: Tables, actor: Actor, id: string, nextDate: IsoDate, note: string, action: PaymentReminderEntry['action']): PaymentReminder {
  const payment = findPayment(t, id);
  const before = { nextDate: payment.nextDate, prepaidMonths: payment.prepaidMonths };
  payment.nextDate = nextDate;
  payment.history = [...payment.history, entry(actor, action, note)];
  writeAudit(t, actor, 'PAYMENTS', 'payment.shift', `${guardianLabel(t, payment)}: eslatma sanasi ${before.nextDate} → ${nextDate}`, id, before, { nextDate });
  return payment;
}

async function setPaused(id: string, paused: boolean, input: { note: string }): Promise<PaymentReminder> {
  await latency();
  const actor = currentActor();
  assertCan(actor, 'payments.manage');
  const { note } = parseOrThrow(paymentPauseSchema, input);
  return transact((t) => {
    const payment = findPayment(t, id);
    if (payment.paused === paused) throw new ServiceError('CONFLICT', id);
    payment.paused = paused;
    payment.history = [...payment.history, entry(actor, paused ? 'PAUSED' : 'RESUMED', note)];
    writeAudit(t, actor, 'PAYMENTS', paused ? 'payment.pause' : 'payment.resume', `${guardianLabel(t, payment)}: eslatma ${paused ? 'to\'xtatildi' : 'qayta yoqildi'} — ${note}`, id, { paused: !paused }, { paused });
    return payment;
  });
}

export const paymentsService = {
  async list(filter: PaymentFilter = {}): Promise<Paginated<PaymentRow>> {
    await latency(80, 180);
    const actor = currentActor();
    assertCan(actor, 'payments.manage');
    const rows = paymentRows(getTables(), clockToday()).filter((r) => matchesFilter(r, filter.filter));
    return runListQuery(rows, filter, {
      searchText: (r) => `${r.guardianName} ${r.phone} ${r.children.map((c) => `${c.name} ${c.className}`).join(' ')}`,
      sorters: { name: (r) => r.guardianName, nextDate: (r) => r.nextDate, prepaid: (r) => r.prepaidMonths },
      defaultSort: 'nextDate',
    });
  },

  async stats(): Promise<PaymentStats> {
    await latency(60, 120);
    assertCan(currentActor(), 'payments.manage');
    return paymentStats(getTables(), clockToday());
  },

  /** CSV uchun — filtr bo'yicha barcha qatorlar. */
  async exportRows(filter: PaymentFilter = {}): Promise<PaymentRow[]> {
    const page = await paymentsService.list({ ...filter, page: 1, limit: 5000 });
    return page.items;
  },

  async shift(id: string, input: PaymentShiftInput): Promise<PaymentReminder> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'payments.manage');
    const data = parseOrThrow(paymentShiftSchema, input);
    return transact((t) => applyShift(t, actor, id, data.nextDate, data.note, 'SHIFTED'));
  },

  pause: (id: string, input: { note: string }) => setPaused(id, true, input),
  resume: (id: string, input: { note: string }) => setPaused(id, false, input),

  /** Ommaviy yangilash: N oyga surish (ixtiyoriy "oldindan to'langan") yoki aniq sana. */
  async bulkShift(input: PaymentBulkShiftInput): Promise<{ updated: number }> {
    await latency(200, 400);
    const actor = currentActor();
    assertCan(actor, 'payments.manage');
    const data = parseOrThrow(paymentBulkShiftSchema, input);
    return transact((t) => {
      const ids = [...new Set(data.ids)];
      const targets = ids.map((id) => findPayment(t, id));
      const before = targets.map((p) => ({ id: p.id, nextDate: p.nextDate, prepaidMonths: p.prepaidMonths }));
      for (const p of targets) {
        p.nextDate = data.months ? addMonthsIso(p.nextDate, data.months) : (data.date ?? p.nextDate);
        if (data.months && data.markPrepaid) p.prepaidMonths += data.months;
        p.history = [...p.history, entry(actor, 'BULK_SHIFT', data.note)];
      }
      const how = data.months ? `${data.months} oyga surildi` : `${data.date} ga o'zgartirildi`;
      const after = targets.map((p) => ({ id: p.id, nextDate: p.nextDate, prepaidMonths: p.prepaidMonths }));
      writeAudit(t, actor, 'PAYMENTS', 'payment.bulkShift', `${targets.length} oila uchun eslatma sanasi ${how} — ${data.note}`, null, before, after);
      return { updated: targets.length };
    });
  },

  async history(id: string): Promise<PaymentHistoryEntry[]> {
    await latency(60, 140);
    assertCan(currentActor(), 'payments.manage');
    const t = getTables();
    return [...findPayment(t, id).history].reverse().map((e) => ({ ...e, byName: staffName(t, e.byStaffId) }));
  },
};
