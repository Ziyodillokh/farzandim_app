// Smart Reminder ko'rinishlari (panel `Reminder` / `ReminderRow`): keyingi
// yuborilish vaqti, o'tganmi, auditoriya nomlari va hajmi. Vaqtlar — Toshkent
// devor soati "YYYY-MM-DDTHH:MM:SS" (panel formasi shuni kesib ishlatadi).

import { SchoolReminder } from '@prisma/client';
import { Audience, REMINDER_KINDS, REMINDER_REPEATS, ReminderKind, ReminderRepeat } from './comms.schemas';
import { audienceNames, reachOf, Roster, toAudience } from './comms-roster';
import { nextOccurrence, toLocalDateTime } from './comms-time';

export interface ReminderView {
  id: string;
  kind: ReminderKind;
  title: string;
  body: string;
  audience: Audience;
  sendAt: string;
  repeat: ReminderRepeat;
  active: boolean;
  byStaffId: string;
}

export interface ReminderRow extends ReminderView {
  /** Keyingi yuborilish (takrorlanuvchida — navbatdagisi); o'tgan bo'lsa null. */
  nextAt: string | null;
  isPast: boolean;
  audienceNames: string[];
  recipients: number;
}

export const toReminderKind = (v: string): ReminderKind => REMINDER_KINDS.find((k) => k === v) ?? 'ANNOUNCEMENT';
export const toRepeat = (v: string): ReminderRepeat => REMINDER_REPEATS.find((k) => k === v) ?? 'NONE';

export function toReminderView(r: SchoolReminder): ReminderView {
  return {
    id: r.id,
    kind: toReminderKind(r.kind),
    title: r.title,
    body: r.body,
    audience: toAudience(r.audience),
    sendAt: toLocalDateTime(r.sendAt),
    repeat: toRepeat(r.repeat),
    active: r.active,
    byStaffId: r.byStaffId,
  };
}

/** Yaqin → uzoq (kelgusi), yangi → eski (o'tgan). */
export function reminderRows(roster: Roster, reminders: readonly SchoolReminder[], now: Date): ReminderRow[] {
  const rows = reminders.map((r) => {
    const view = toReminderView(r);
    const next = nextOccurrence(r.sendAt, view.repeat, now);
    const row: ReminderRow = {
      ...view,
      nextAt: next ? toLocalDateTime(next) : null,
      isPast: next === null,
      audienceNames: audienceNames(roster, view.audience),
      recipients: reachOf(roster, view.audience).guardians,
    };
    return { row, nextMs: next?.getTime() ?? 0, sendMs: r.sendAt.getTime() };
  });
  const upcoming = rows.filter((x) => !x.row.isPast).sort((a, b) => a.nextMs - b.nextMs);
  const past = rows.filter((x) => x.row.isPast).sort((a, b) => b.sendMs - a.sendMs);
  return [...upcoming, ...past].map((x) => x.row);
}
