import { roleHas } from '@/auth/permissions';
import type { Announcement, ListQuery, MessageStatus, Paginated } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { announcementInputSchema, localDateTimeSchema, type AnnouncementInput } from '@/data/schemas/comms';
import { parseOrThrow } from '@/data/schemas/validate';
import { matchesSearch } from '@/lib/normalize-search';
import { unitHash } from '@/lib/rng';
import { clockNow } from '../clock';
import { type Actor, allowedClassIds, assertCan, currentActor, latency, newId, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { paginate } from '../query';
import type { Tables } from '../tables';
import {
  assertAnySend,
  assertAudienceAllowed,
  type AudienceReach,
  audienceNames,
  audienceTouchesScope,
  canSendTo,
  compareTime,
  normalizeLocal,
  nowLocalIso,
  reachOf,
  staffName,
  timeOf,
} from './comms-shared';

export type AnnouncementRow = Announcement & { authorName: string; audienceNames: string[]; canManage: boolean };
export type AnnouncementDetail = AnnouncementRow & { reach: AudienceReach };
export type AnnouncementCounts = Record<'ALL' | MessageStatus, number>;
export type AnnouncementFilter = ListQuery & { status?: MessageStatus };
export type AnnouncementList = Paginated<AnnouncementRow> & { counts: AnnouncementCounts };
export type SendOptions = { id?: string; scheduledAt?: string | null };

/** O'qilganlar egri chizig'i: yuborilgandan keyin ~45 daqiqada ko'pchilik ochadi. */
const READ_TAU_MINUTES = 45;
const STATUS_ORDER: Record<MessageStatus, number> = { SCHEDULED: 0, DRAFT: 1, SENT: 2 };

/** Yuborish statistikasi (deterministik): push — ulanganlarga, SMS — qolganlarga (~90–98% yetadi). */
export function sendStats(t: Tables, a: Pick<Announcement, 'id' | 'audience'>): Announcement['stats'] {
  const reach = reachOf(t, a.audience);
  const smsRate = 0.9 + unitHash(a.id, 'sms') * 0.08;
  return { recipients: reach.guardians, delivered: reach.linked + Math.round(reach.sms * smsRate), read: 0 };
}

function liveRead(a: Announcement, now: Date): number {
  if (a.status !== 'SENT' || !a.sentAt) return a.stats.read;
  const sentMs = timeOf(a.sentAt);
  if (Number.isNaN(sentMs)) return a.stats.read;
  const minutes = Math.max(0, (now.getTime() - sentMs) / 60_000);
  const cap = Math.round(a.stats.delivered * (0.58 + unitHash(a.id, 'read') * 0.32));
  const grown = Math.round(cap * (1 - Math.exp(-minutes / READ_TAU_MINUTES)));
  return Math.min(a.stats.delivered, Math.max(a.stats.read, grown));
}

/** Vaqti kelgan rejalashtirilgan xabar — yuborilgan deb ko'rsatiladi; "o'qildi" vaqt bilan o'sadi. */
export function effective(t: Tables, a: Announcement, now: Date): Announcement {
  if (a.status === 'SCHEDULED' && timeOf(a.scheduledAt) <= now.getTime()) {
    const sent: Announcement = { ...a, status: 'SENT', sentAt: a.scheduledAt, stats: sendStats(t, a) };
    return { ...sent, stats: { ...sent.stats, read: liveRead(sent, now) } };
  }
  return { ...a, stats: { ...a.stats, read: liveRead(a, now) } };
}

function isOwnOrSchool(actor: Actor, a: Announcement): boolean {
  return roleHas(actor.role, 'messages.sendSchool') || a.byStaffId === actor.staffId;
}

function isVisible(actor: Actor, t: Tables, a: Announcement): boolean {
  if (!allowedClassIds(actor)) return true;
  if (a.byStaffId === actor.staffId) return true;
  return a.status !== 'DRAFT' && audienceTouchesScope(actor, t, a.audience);
}

function toRow(actor: Actor, t: Tables, a: Announcement): AnnouncementRow {
  return {
    ...a,
    authorName: staffName(t, a.byStaffId),
    audienceNames: audienceNames(t, a.audience),
    canManage: a.status !== 'SENT' && isOwnOrSchool(actor, a) && canSendTo(actor, t, a.audience),
  };
}

/** Ko'rinadigan xabarlar (doira bo'yicha), tartib: rejalashtirilgan → qoralama → yuborilgan. */
export function visibleAnnouncements(actor: Actor, t: Tables, now: Date): AnnouncementRow[] {
  const indexed = t.announcements.map((a, index) => ({ a: effective(t, a, now), index }));
  return indexed
    .filter(({ a }) => isVisible(actor, t, a))
    .sort((x, y) => {
      const byStatus = STATUS_ORDER[x.a.status] - STATUS_ORDER[y.a.status];
      if (byStatus) return byStatus;
      if (x.a.status === 'SCHEDULED') return compareTime(x.a.scheduledAt, y.a.scheduledAt);
      if (x.a.status === 'SENT') return compareTime(y.a.sentAt, x.a.sentAt);
      return y.index - x.index;
    })
    .map(({ a }) => toRow(actor, t, a));
}

/** O'zgartiriladigan (hali yuborilmagan) xabar. */
function editable(actor: Actor, t: Tables, id: string): { index: number; current: Announcement } {
  const index = t.announcements.findIndex((a) => a.id === id);
  const stored = t.announcements[index];
  if (!stored) throw new ServiceError('NOT_FOUND', id);
  const current = effective(t, stored, clockNow());
  if (current.status === 'SENT') throw new ServiceError('CONFLICT', 'already sent');
  if (!isOwnOrSchool(actor, current)) throw new ServiceError('FORBIDDEN', id);
  assertAudienceAllowed(actor, t, current.audience);
  return { index, current };
}

function parseSchedule(value: string | null | undefined): string | null {
  if (!value) return null;
  const at = normalizeLocal(parseOrThrow(localDateTimeSchema, value));
  if (!(timeOf(at) > clockNow().getTime())) throw new ServiceError('VALIDATION', 'scheduledAt: errors.form.invalidDate');
  return at;
}

function deliver(t: Tables, base: Announcement, scheduledAt: string | null): Announcement {
  if (scheduledAt) return { ...base, status: 'SCHEDULED', scheduledAt, sentAt: null, stats: { recipients: reachOf(t, base.audience).guardians, delivered: 0, read: 0 } };
  return { ...base, status: 'SENT', scheduledAt: null, sentAt: nowLocalIso(), stats: sendStats(t, base) };
}

function upsert(t: Tables, index: number, next: Announcement): void {
  if (index >= 0) t.announcements[index] = next;
  else t.announcements.push(next);
}

export const announcementsService = {
  async list(filter: AnnouncementFilter = {}): Promise<AnnouncementList> {
    await latency(80, 180);
    const actor = currentActor();
    assertCan(actor, 'messages.view');
    const rows = visibleAnnouncements(actor, getTables(), clockNow());
    const counts: AnnouncementCounts = { ALL: rows.length, SENT: 0, SCHEDULED: 0, DRAFT: 0 };
    for (const r of rows) counts[r.status] += 1;
    const filtered = rows.filter(
      (r) => (!filter.status || r.status === filter.status) && (!filter.search || matchesSearch(`${r.title} ${r.body} ${r.audienceNames.join(' ')}`, filter.search)),
    );
    return { ...paginate(filtered, filter.page, filter.limit ?? 12), counts };
  },

  async get(id: string): Promise<AnnouncementDetail> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'messages.view');
    const t = getTables();
    const stored = t.announcements.find((a) => a.id === id);
    if (!stored) throw new ServiceError('NOT_FOUND', id);
    const a = effective(t, stored, clockNow());
    if (!isVisible(actor, t, a)) throw new ServiceError('FORBIDDEN', id);
    return { ...toRow(actor, t, a), reach: reachOf(t, a.audience) };
  },

  /** Qoralama saqlash (yangi yoki mavjud qoralama/rejalashtirilgan xabarni qoralamaga qaytarish). */
  async saveDraft(input: AnnouncementInput, id?: string): Promise<Announcement> {
    await latency();
    const actor = currentActor();
    assertAnySend(actor);
    const data = parseOrThrow(announcementInputSchema, input);
    return transact((t) => {
      assertAudienceAllowed(actor, t, data.audience);
      const found = id ? editable(actor, t, id) : null;
      const base: Announcement = found?.current ?? { id: newId('ann'), ...data, status: 'DRAFT', scheduledAt: null, sentAt: null, byStaffId: actor.staffId, stats: { recipients: 0, delivered: 0, read: 0 } };
      const next: Announcement = { ...base, ...data, status: 'DRAFT', scheduledAt: null, sentAt: null, stats: { recipients: reachOf(t, data.audience).guardians, delivered: 0, read: 0 } };
      upsert(t, found?.index ?? -1, next);
      writeAudit(t, actor, 'MESSAGES', found ? 'announcement.update' : 'announcement.draft', `"${next.title}" qoralama sifatida saqlandi`, next.id, found?.current ?? null, next);
      return next;
    });
  },

  /** Darhol yuborish yoki `scheduledAt` bo'yicha rejalashtirish (`id` — mavjud qoralamani yuborish). */
  async send(input: AnnouncementInput, options: SendOptions = {}): Promise<Announcement> {
    await latency();
    const actor = currentActor();
    assertAnySend(actor);
    const data = parseOrThrow(announcementInputSchema, input);
    const scheduledAt = parseSchedule(options.scheduledAt);
    return transact((t) => {
      assertAudienceAllowed(actor, t, data.audience);
      const found = options.id ? editable(actor, t, options.id) : null;
      const base: Announcement = { ...(found?.current ?? { id: newId('ann'), byStaffId: actor.staffId, scheduledAt: null, sentAt: null, status: 'DRAFT', stats: { recipients: 0, delivered: 0, read: 0 } }), ...data };
      const next = deliver(t, base, scheduledAt);
      upsert(t, found?.index ?? -1, next);
      const summary = scheduledAt ? `"${next.title}" xabari ${scheduledAt.slice(0, 16).replace('T', ' ')} ga rejalashtirildi` : `"${next.title}" xabari yuborildi (${next.stats.recipients} ota-ona)`;
      writeAudit(t, actor, 'MESSAGES', scheduledAt ? 'announcement.schedule' : 'announcement.send', summary, next.id, found?.current ?? null, next);
      return next;
    });
  },

  /** Qoralama yoki rejalashtirilgan xabarni hozir yuborish. */
  async sendNow(id: string): Promise<Announcement> {
    await latency();
    const actor = currentActor();
    assertAnySend(actor);
    return transact((t) => {
      const { index, current } = editable(actor, t, id);
      const next = deliver(t, current, null);
      t.announcements[index] = next;
      writeAudit(t, actor, 'MESSAGES', 'announcement.send', `"${next.title}" xabari yuborildi (${next.stats.recipients} ota-ona)`, id, current, next);
      return next;
    });
  },

  /** Qoralama yoki rejalashtirilgan (hali yuborilmagan) xabarni o'chirish. */
  async remove(id: string): Promise<void> {
    await latency();
    const actor = currentActor();
    assertAnySend(actor);
    transact((t) => {
      const { index, current } = editable(actor, t, id);
      t.announcements.splice(index, 1);
      writeAudit(t, actor, 'MESSAGES', 'announcement.delete', `"${current.title}" ${current.status === 'DRAFT' ? 'qoralamasi' : 'rejalashtirilgan xabari'} o'chirildi`, id, current, null);
    });
  },

  /** Nusxa — yangi qoralama. Sinf rahbari maktab xabarini nusxalasa, auditoriya o'z sinfiga o'tadi. */
  async duplicate(id: string): Promise<Announcement> {
    await latency();
    const actor = currentActor();
    assertAnySend(actor);
    return transact((t) => {
      const source = t.announcements.find((a) => a.id === id);
      if (!source || !isVisible(actor, t, source)) throw new ServiceError('NOT_FOUND', id);
      const own = allowedClassIds(actor);
      const audience = canSendTo(actor, t, source.audience) ? source.audience : own?.length ? { kind: 'CLASSES' as const, classIds: own, guardianIds: [] } : null;
      if (!audience) throw new ServiceError('FORBIDDEN', id);
      const copy: Announcement = { ...source, id: newId('ann'), audience, status: 'DRAFT', scheduledAt: null, sentAt: null, byStaffId: actor.staffId, stats: { recipients: reachOf(t, audience).guardians, delivered: 0, read: 0 } };
      t.announcements.push(copy);
      writeAudit(t, actor, 'MESSAGES', 'announcement.duplicate', `"${source.title}" xabaridan nusxa olindi`, copy.id, null, copy);
      return copy;
    });
  },
};
