// E'lon ko'rinishlari (panel `Announcement` / `AnnouncementRow`): ko'rinish va
// boshqarish huquqi, tartib (rejalashtirilgan → qoralama → yuborilgan).
// Statistika — haqiqiy yetkazish yozuvlaridan (yetkazildi / o'qildi).

import { Prisma, SchoolAnnouncement } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { actorCan, allowedClassIds, SchoolActor } from '../auth/school-actor';
import { Audience, MessagePriority, MessageStatus } from './comms.schemas';
import { audienceNames, audienceTouchesScope, canSendTo, loadRoster, Roster, toAudience } from './comms-roster';
import { toLocalDateTimeOrNull } from './comms-time';

type Db = Prisma.TransactionClient | PrismaService;

export interface AnnouncementStats {
  recipients: number;
  delivered: number;
  read: number;
}

export interface AnnouncementView {
  id: string;
  title: string;
  body: string;
  audience: Audience;
  priority: MessagePriority;
  status: MessageStatus;
  /** Toshkent devor soati "YYYY-MM-DDTHH:MM:SS" (panel formasi shuni kesadi). */
  scheduledAt: string | null;
  /** Haqiqiy yuborilgan lahza (ISO). */
  sentAt: string | null;
  byStaffId: string;
  stats: AnnouncementStats;
}

export interface AnnouncementRow extends AnnouncementView {
  authorName: string;
  audienceNames: string[];
  canManage: boolean;
}

export interface AnnouncementContext {
  roster: Roster;
  staffNames: Map<string, string>;
}

type Counts = { delivered: number; read: number };

const STATUS_ORDER: Record<MessageStatus, number> = { SCHEDULED: 0, DRAFT: 1, SENT: 2 };

export async function loadAnnouncementContext(db: Db, schoolId: string): Promise<AnnouncementContext> {
  const roster = await loadRoster(db, schoolId);
  const staff = await db.schoolStaff.findMany({ where: { schoolId }, select: { id: true, fullName: true } });
  return { roster, staffNames: new Map(staff.map((s) => [s.id, s.fullName])) };
}

export function toAnnouncementView(a: SchoolAnnouncement, counts?: Counts): AnnouncementView {
  return {
    id: a.id,
    title: a.title,
    body: a.body,
    audience: toAudience(a.audience),
    priority: a.priority === 'IMPORTANT' ? 'IMPORTANT' : 'NORMAL',
    status: a.status,
    scheduledAt: toLocalDateTimeOrNull(a.scheduledAt),
    sentAt: a.sentAt?.toISOString() ?? null,
    byStaffId: a.byStaffId,
    stats: { recipients: a.recipients, delivered: counts?.delivered ?? 0, read: counts?.read ?? 0 },
  };
}

/** Yuborilgan e'lonlar uchun yetkazildi / o'qildi soni. */
export async function deliveryCounts(db: Db, ids: readonly string[]): Promise<Map<string, Counts>> {
  if (ids.length === 0) return new Map();
  const where = { announcementId: { in: [...ids] } };
  const delivered = await db.schoolAnnouncementDelivery.groupBy({
    by: ['announcementId'],
    where: { ...where, deliveredAt: { not: null } },
    _count: { _all: true },
  });
  const read = await db.schoolAnnouncementDelivery.groupBy({
    by: ['announcementId'],
    where: { ...where, readAt: { not: null } },
    _count: { _all: true },
  });
  const readBy = new Map(read.map((r) => [r.announcementId, r._count._all]));
  const deliveredBy = new Map(delivered.map((d) => [d.announcementId, d._count._all]));
  return new Map(ids.map((id) => [id, { delivered: deliveredBy.get(id) ?? 0, read: readBy.get(id) ?? 0 }]));
}

/** Qatorlarga haqiqiy statistika (faqat yuborilganlar uchun so'rov). */
export async function withStats<T extends AnnouncementView>(db: Db, rows: readonly T[]): Promise<T[]> {
  const counts = await deliveryCounts(db, rows.filter((r) => r.status === 'SENT').map((r) => r.id));
  return rows.map((r) => {
    const c = counts.get(r.id);
    return c ? { ...r, stats: { ...r.stats, ...c } } : r;
  });
}

export function isOwnOrSchool(actor: SchoolActor, a: { byStaffId: string }): boolean {
  return actorCan(actor, 'messages.sendSchool') || a.byStaffId === actor.staffId;
}

/** Sinf rahbari: o'zi yozgan, butun maktab yoki o'z sinfiga tegishli (begona qoralamalarsiz). */
export function isVisible(actor: SchoolActor, roster: Roster, a: AnnouncementView): boolean {
  if (!allowedClassIds(actor)) return true;
  if (a.byStaffId === actor.staffId) return true;
  return a.status !== 'DRAFT' && audienceTouchesScope(actor, roster, a.audience);
}

export function toRow(actor: SchoolActor, ctx: AnnouncementContext, a: AnnouncementView): AnnouncementRow {
  return {
    ...a,
    authorName: ctx.staffNames.get(a.byStaffId) ?? '—',
    audienceNames: audienceNames(ctx.roster, a.audience),
    canManage: a.status !== 'SENT' && isOwnOrSchool(actor, a) && canSendTo(actor, ctx.roster, a.audience),
  };
}

const time = (d: Date | null): number | null => (d ? d.getTime() : null);

/** Kichik vaqt oldin; vaqtsiz — oxirida. */
function compareNullable(a: number | null, b: number | null): number {
  if (a === b) return 0;
  if (a === null) return 1;
  if (b === null) return -1;
  return a - b;
}

/** Rejalashtirilgan (yaqini oldin) → qoralama (yangisi oldin) → yuborilgan (yangisi oldin). */
export function compareAnnouncements(x: SchoolAnnouncement, y: SchoolAnnouncement): number {
  const byStatus = STATUS_ORDER[x.status] - STATUS_ORDER[y.status];
  if (byStatus) return byStatus;
  if (x.status === 'SCHEDULED') return compareNullable(time(x.scheduledAt), time(y.scheduledAt));
  if (x.status === 'SENT') return compareNullable(time(y.sentAt), time(x.sentAt));
  return y.createdAt.getTime() - x.createdAt.getTime();
}

/** Ko'rinadigan barcha e'lonlar (statistikasiz — sahifa uchun alohida). */
export async function visibleRows(db: Db, actor: SchoolActor, ctx: AnnouncementContext): Promise<AnnouncementRow[]> {
  const all = await db.schoolAnnouncement.findMany({ where: { schoolId: actor.schoolId } });
  return [...all]
    .sort(compareAnnouncements)
    .map((a) => toAnnouncementView(a))
    .filter((a) => isVisible(actor, ctx.roster, a))
    .map((a) => toRow(actor, ctx, a));
}
