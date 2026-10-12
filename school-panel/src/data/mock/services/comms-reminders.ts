import type { ListQuery, Paginated, Reminder, ReminderKind } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { reminderInputSchema, type ReminderInput } from '@/data/schemas/comms';
import { parseOrThrow } from '@/data/schemas/validate';
import { matchesSearch } from '@/lib/normalize-search';
import { clockNow } from '../clock';
import { type Actor, assertCan, currentActor, latency, newId, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { paginate } from '../query';
import type { Tables } from '../tables';
import { assertAudienceAllowed, audienceNames, localIso, normalizeLocal, reachOf } from './comms-shared';

export type ReminderWhen = 'UPCOMING' | 'PAST';
export type ReminderRow = Reminder & {
  /** Keyingi yuborilish vaqti (takrorlanuvchida — navbatdagisi); o'tgan bo'lsa null. */
  nextAt: string | null;
  isPast: boolean;
  audienceNames: string[];
  recipients: number;
};
export type ReminderFilter = ListQuery & { when?: ReminderWhen; kind?: ReminderKind };
export type ReminderList = Paginated<ReminderRow> & { counts: Record<ReminderWhen, number> };

const MAX_REPEAT_STEPS = 600;

function step(date: Date, repeat: Reminder['repeat']): Date {
  const next = new Date(date);
  if (repeat === 'WEEKLY') next.setDate(next.getDate() + 7);
  else next.setMonth(next.getMonth() + 1);
  return next;
}

/** Keyingi yuborilish: bir martalik o'tgan bo'lsa — null. */
export function nextOccurrence(r: Pick<Reminder, 'sendAt' | 'repeat'>, now: Date): Date | null {
  let at = new Date(r.sendAt);
  if (at > now) return at;
  if (r.repeat === 'NONE') return null;
  for (let i = 0; i < MAX_REPEAT_STEPS && at <= now; i++) at = step(at, r.repeat);
  return at > now ? at : null;
}

function toRow(t: Tables, r: Reminder, now: Date): ReminderRow {
  const next = nextOccurrence(r, now);
  return {
    ...r,
    nextAt: next ? localIso(next) : null,
    isPast: next === null,
    audienceNames: audienceNames(t, r.audience),
    recipients: reachOf(t, r.audience).guardians,
  };
}

/** Yaqin → uzoq (kelgusi), yangi → eski (o'tgan). */
export function reminderRows(t: Tables, now: Date): ReminderRow[] {
  const rows = t.reminders.map((r) => toRow(t, r, now));
  const upcoming = rows.filter((r) => !r.isPast).sort((a, b) => (a.nextAt ?? '').localeCompare(b.nextAt ?? ''));
  const past = rows.filter((r) => r.isPast).sort((a, b) => b.sendAt.localeCompare(a.sendAt));
  return [...upcoming, ...past];
}

function parseInput(actor: Actor, t: Tables, input: ReminderInput): Omit<Reminder, 'id' | 'byStaffId'> {
  const data = parseOrThrow(reminderInputSchema, input);
  assertAudienceAllowed(actor, t, data.audience);
  return { ...data, sendAt: normalizeLocal(data.sendAt) };
}

function assertFuture(sendAt: string): void {
  if (new Date(sendAt) <= clockNow()) throw new ServiceError('VALIDATION', 'sendAt: errors.form.invalidDate');
}

function find(t: Tables, id: string): { index: number; current: Reminder } {
  const index = t.reminders.findIndex((r) => r.id === id);
  const current = t.reminders[index];
  if (!current) throw new ServiceError('NOT_FOUND', id);
  return { index, current };
}

export const remindersService = {
  async list(filter: ReminderFilter = {}): Promise<ReminderList> {
    await latency(80, 180);
    const actor = currentActor();
    assertCan(actor, 'reminders.manage');
    const rows = reminderRows(getTables(), clockNow());
    const counts = { UPCOMING: rows.filter((r) => !r.isPast).length, PAST: rows.filter((r) => r.isPast).length };
    const filtered = rows.filter(
      (r) =>
        (!filter.when || (filter.when === 'PAST') === r.isPast) &&
        (!filter.kind || r.kind === filter.kind) &&
        (!filter.search || matchesSearch(`${r.title} ${r.body} ${r.audienceNames.join(' ')}`, filter.search)),
    );
    return { ...paginate(filtered, filter.page, filter.limit ?? 50), counts };
  },

  async create(input: ReminderInput): Promise<Reminder> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'reminders.manage');
    return transact((t) => {
      const data = parseInput(actor, t, input);
      assertFuture(data.sendAt);
      const reminder: Reminder = { id: newId('rem'), ...data, byStaffId: actor.staffId };
      t.reminders.push(reminder);
      writeAudit(t, actor, 'REMINDERS', 'reminder.create', `"${reminder.title}" eslatmasi yaratildi`, reminder.id, null, reminder);
      return reminder;
    });
  },

  async update(id: string, input: ReminderInput): Promise<Reminder> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'reminders.manage');
    return transact((t) => {
      const { index, current } = find(t, id);
      const data = parseInput(actor, t, input);
      if (data.sendAt !== current.sendAt) assertFuture(data.sendAt);
      const next: Reminder = { ...current, ...data };
      t.reminders[index] = next;
      writeAudit(t, actor, 'REMINDERS', 'reminder.update', `"${next.title}" eslatmasi tahrirlandi`, id, current, next);
      return next;
    });
  },

  async remove(id: string): Promise<void> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'reminders.manage');
    transact((t) => {
      const { index, current } = find(t, id);
      t.reminders.splice(index, 1);
      writeAudit(t, actor, 'REMINDERS', 'reminder.delete', `"${current.title}" eslatmasi o'chirildi`, id, current, null);
    });
  },

  async setActive(id: string, active: boolean): Promise<Reminder> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'reminders.manage');
    return transact((t) => {
      const { index, current } = find(t, id);
      const next: Reminder = { ...current, active };
      t.reminders[index] = next;
      writeAudit(t, actor, 'REMINDERS', 'reminder.toggle', `"${next.title}" eslatmasi ${active ? 'yoqildi' : 'to\'xtatildi'}`, id, { active: current.active }, { active });
      return next;
    });
  },
};
