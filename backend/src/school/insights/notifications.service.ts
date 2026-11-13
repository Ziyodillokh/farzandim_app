// Bildirishnomalar markazi: saqlangan signallar (xavfsizlik, test yakunlandi)
// + jadvallardan hisoblanadigan ochiq holatlar (erta ketish, to'lov
// tekshiruvi, Bola ovozi, yuborilgan xabar, favqulodda rejim). Id'lar
// barqaror — "o'qildi" holati qayta hisoblashda ham saqlanadi.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { actorCan, allowedClassIds, assertCan, classScopeWhere, SchoolActor } from '../auth/school-actor';
import { DATA_DELETION_NOTIFICATION_KIND } from '../../modules/data-deletion/data-deletion-purge';
import { CHILD_RECOVERY_NOTIFICATION_KIND } from '../../modules/child-auth/child-auth.constants';
import { CARE_TOPIC_LABELS } from '../care/care-labels';
import { topicLabel } from '../parent-connect/parent-connect.labels';
import { audienceTouchesScope, loadRoster, toAudience } from '../comms/comms-roster';
import { GUARDIAN_REVIEW_KIND, LINK_CORRECTION_KIND, LINK_REQUESTS_HREF, LINK_REVIEW_KIND } from '../students/link-notification-ids';
import { emergencyLive } from '../school-mode/school-mode-store';

export const FEED_LIMIT = 30;
/**
 * Ulanish so'rovlari ommaviy bo'lishi mumkin (birinchi kunlar): lentani to'ldirib, erta ketish va favqulodda
 * rejimni siqib chiqarmasligi uchun har tur bo'yicha eng yangi shuncha tasi ko'rsatiladi (to'liq navbat — so'rovlar sahifasida).
 */
export const LINK_FEED_PER_KIND = 10;
const LINK_KINDS: ReadonlySet<string> = new Set([LINK_REVIEW_KIND, LINK_CORRECTION_KIND, GUARDIAN_REVIEW_KIND]);
const MESSAGE_WINDOW_MS = 3 * 24 * 3_600_000;
const SUBJECT_MAX = 90;
const STORED_LIMIT = 200;

export type NotificationKind =
  | 'SAFETY_SIGNAL'
  | 'TEST_COMPLETED'
  | 'LINK_REVIEW'
  | 'LINK_CORRECTION'
  | 'GUARDIAN_REVIEW'
  | 'EARLY_EXIT_PENDING'
  | 'VERIFICATION_OPEN'
  | 'CARE_NEW'
  | 'CARE_URGENT'
  | 'MESSAGE_SENT'
  | 'EMERGENCY'
  | 'DATA_DELETION_REQUEST'
  | 'CHILD_RECOVERY_REQUEST'
  | 'PARENT_MESSAGE';
type Localized = { uz: string; ru: string };

export interface NotificationItem {
  id: string;
  kind: NotificationKind;
  at: string;
  tone: 'destructive' | 'warning' | 'info' | 'success';
  params: Record<string, string | number>;
  subject: Localized | null;
  href: string | null;
}

export const NOTIFICATION_TONES: Record<NotificationKind, NotificationItem['tone']> = {
  SAFETY_SIGNAL: 'destructive',
  TEST_COMPLETED: 'success',
  LINK_REVIEW: 'warning',
  LINK_CORRECTION: 'warning',
  GUARDIAN_REVIEW: 'warning',
  EARLY_EXIT_PENDING: 'warning',
  VERIFICATION_OPEN: 'info',
  CARE_NEW: 'info',
  CARE_URGENT: 'destructive',
  MESSAGE_SENT: 'success',
  EMERGENCY: 'destructive',
  DATA_DELETION_REQUEST: 'warning',
  CHILD_RECOVERY_REQUEST: 'warning',
  PARENT_MESSAGE: 'info',
};

/** Erkin matn (sabab, xabar) — ikkala tilda bir xil, qisqartirilgan. */
function plain(text: string | null | undefined): Localized | null {
  const value = text?.trim();
  if (!value) return null;
  const short = value.length > SUBJECT_MAX ? `${value.slice(0, SUBJECT_MAX - 1)}…` : value;
  return { uz: short, ru: short };
}

const item = (kind: NotificationKind, id: string, at: Date, rest: Partial<NotificationItem> = {}): NotificationItem => ({
  id,
  kind,
  at: at.toISOString(),
  tone: NOTIFICATION_TONES[kind],
  params: {},
  subject: null,
  href: null,
  ...rest,
});

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Rol va doiraga mos lenta: eng yangilari birinchi, ko'pi bilan 30 ta. */
  async feed(actor: SchoolActor, now = new Date()): Promise<NotificationItem[]> {
    assertCan(actor, 'dashboard.view');
    const groups = await Promise.all([
      this.stored(actor),
      this.earlyExits(actor, now),
      this.verifications(actor),
      this.care(actor),
      this.messages(actor, now),
      this.emergency(actor),
      this.parentMessages(actor),
    ]);
    // Bir xil id: saqlangan (nishonlangan) bildirishnoma hisoblanganidan ustun — `groups` tartibida birinchi.
    const unique = new Map<string, NotificationItem>();
    for (const n of groups.flat()) if (!unique.has(n.id)) unique.set(n.id, n);
    return [...unique.values()]
      .filter((n) => n.kind === 'EMERGENCY' || Date.parse(n.at) <= now.getTime())
      .sort((a, b) => Date.parse(b.at) - Date.parse(a.at) || a.id.localeCompare(b.id))
      .slice(0, FEED_LIMIT);
  }

  /** Foydalanuvchi ko'ra oladigan saqlangan bildirishnomalar (rol va sinf doirasi). */
  storedWhere(actor: SchoolActor): Prisma.SchoolStaffNotificationWhereInput {
    const allowed = allowedClassIds(actor);
    return {
      schoolId: actor.schoolId,
      roles: { has: actor.role },
      // Nishonlangan xodimlar ro'yxati bo'sh — rolga mos hammaga; aks holda faqat shu xodimlarga.
      AND: [
        { OR: [{ staffIds: { isEmpty: true } }, { staffIds: { has: actor.staffId } }] },
        ...(allowed ? [{ OR: [{ classIds: { isEmpty: true } }, { classIds: { hasSome: allowed } }] }] : []),
      ],
    };
  }

  private async stored(actor: SchoolActor): Promise<NotificationItem[]> {
    const rows = await this.prisma.schoolStaffNotification.findMany({
      where: this.storedWhere(actor),
      orderBy: { at: 'desc' },
      take: STORED_LIMIT,
    });
    const linkSeen = new Map<string, number>();
    const visible = rows.filter((n) => {
      if (!LINK_KINDS.has(n.kind)) return true;
      const count = (linkSeen.get(n.kind) ?? 0) + 1;
      linkSeen.set(n.kind, count);
      return count <= LINK_FEED_PER_KIND;
    });
    return visible.map((n) => {
      // Ulanish so'rovlari (K2) — faqat o'quvchi ismi va sinf nomi: bola ismi, kod va izoh hech qachon.
      if (n.kind === LINK_REVIEW_KIND || n.kind === LINK_CORRECTION_KIND || n.kind === GUARDIAN_REVIEW_KIND) {
        const stored = (n.params ?? {}) as Record<string, unknown>;
        const params = { studentName: String(stored.studentName ?? ''), className: String(stored.className ?? '') };
        return item(n.kind, n.id, n.at, { params, href: LINK_REQUESTS_HREF });
      }
      // Bola ovozi (shoshilinch / eskalatsiya) — ism va matnsiz: sinf nomi va mavzu yorlig'i xolos.
      if (n.kind === 'CARE_URGENT' || n.kind === 'CARE_NEW') {
        const params = (n.params ?? {}) as Record<string, string | number>;
        return item(n.kind, n.id, n.at, { params, subject: (n.subject as Localized | null) ?? null, href: n.href });
      }
      // Ma'lumot o'chirish so'rovi — faqat o'quvchi ismi va sinf nomi (boshqa hech narsa).
      if (n.kind === DATA_DELETION_NOTIFICATION_KIND) {
        const stored = (n.params ?? {}) as Record<string, unknown>;
        const params = { studentName: String(stored.studentName ?? ''), className: String(stored.className ?? '') };
        return item('DATA_DELETION_REQUEST', n.id, n.at, { params });
      }
      // Kirish maʼlumotlarini tiklash so'rovi — faqat o'quvchi ismi va sinf nomi; `href` — shu o'quvchi kartasining «Kirish» bo'limi.
      if (n.kind === CHILD_RECOVERY_NOTIFICATION_KIND) {
        const stored = (n.params ?? {}) as Record<string, unknown>;
        const params = { studentName: String(stored.studentName ?? ''), className: String(stored.className ?? '') };
        return item('CHILD_RECOVERY_REQUEST', n.id, n.at, { params, href: n.href });
      }
      const kind = n.kind === 'SAFETY_SIGNAL' ? 'SAFETY_SIGNAL' : 'TEST_COMPLETED';
      // Xavfsizlik signalida ism / matn HECH QACHON yo'q.
      if (kind === 'SAFETY_SIGNAL') return item(kind, n.id, n.at, { href: n.href });
      const params = (n.params ?? {}) as Record<string, string | number>;
      const count = Number(params.count);
      return item(kind, n.id, n.at, {
        params: { ...params, count: Number.isFinite(count) && count > 0 ? count : 1 },
        subject: (n.subject as Localized | null) ?? null,
        href: n.href,
      });
    });
  }

  /** Ro'yxat bilan bir xil: tarix ruxsatisiz (navbatchi) — faqat bugungi; sabab — faqat `attendance.earlyExit` egasiga. */
  private async earlyExits(actor: SchoolActor, now: Date): Promise<NotificationItem[]> {
    if (!actorCan(actor, 'attendance.view')) return [];
    const onlyToday = !actorCan(actor, 'attendance.history');
    const showReason = actorCan(actor, 'attendance.earlyExit');
    const exits = await this.prisma.schoolEarlyExit.findMany({
      where: { schoolId: actor.schoolId, status: 'PENDING', ...classScopeWhere(actor), ...(onlyToday && { date: tashkentDay(now) }) },
      orderBy: { requestedAt: 'desc' },
      take: FEED_LIMIT,
    });
    const [students, classes] = await this.names(actor.schoolId, exits.map((e) => e.studentId));
    return exits.map((e) =>
      item('EARLY_EXIT_PENDING', `exit:${e.id}`, e.requestedAt, {
        params: { name: students.get(e.studentId) ?? '—', className: (e.classId && classes.get(e.classId)) || '', time: e.time },
        subject: showReason ? plain(e.reason) : null,
        href: '/attendance/early-exit',
      }),
    );
  }

  private async verifications(actor: SchoolActor): Promise<NotificationItem[]> {
    if (!actorCan(actor, 'payments.manage')) return [];
    const rows = await this.prisma.schoolVerificationRequest.findMany({
      where: { schoolId: actor.schoolId, status: 'OPEN' },
      orderBy: { createdAt: 'desc' },
      take: FEED_LIMIT,
    });
    const guardians = await this.prisma.schoolGuardian.findMany({
      where: { schoolId: actor.schoolId, id: { in: rows.map((r) => r.guardianId) } },
      select: { id: true, fullName: true },
    });
    const name = new Map(guardians.map((g) => [g.id, g.fullName]));
    return rows.map((v) =>
      item('VERIFICATION_OPEN', `ver:${v.id}`, v.createdAt, {
        params: { name: name.get(v.guardianId) ?? '—' },
        subject: plain(v.message),
        href: '/reminders/verifications',
      }),
    );
  }

  /** Bola ovozi: faqat psixolog. Ism yo'q — sinf va mavzu. */
  private async care(actor: SchoolActor): Promise<NotificationItem[]> {
    if (!actorCan(actor, 'care.individual')) return [];
    const rows = await this.prisma.schoolCareRequest.findMany({
      where: { schoolId: actor.schoolId, status: 'NEW' },
      orderBy: { createdAt: 'desc' },
      take: FEED_LIMIT,
    });
    const [, classes] = await this.names(actor.schoolId, []);
    return rows.map((r) => {
      const kind = r.urgency === 'URGENT' ? 'CARE_URGENT' : 'CARE_NEW';
      return item(kind, `care:${r.id}`, r.createdAt, {
        params: { className: (r.classId && classes.get(r.classId)) || '' },
        subject: CARE_TOPIC_LABELS[r.topic] ?? CARE_TOPIC_LABELS.OTHER!,
        href: `/care/requests/view?id=${r.id}`,
      });
    });
  }

  private async messages(actor: SchoolActor, now: Date): Promise<NotificationItem[]> {
    if (!actorCan(actor, 'messages.view')) return [];
    const sent = await this.prisma.schoolAnnouncement.findMany({
      where: { schoolId: actor.schoolId, status: 'SENT', sentAt: { gte: new Date(now.getTime() - MESSAGE_WINDOW_MS) } },
      orderBy: { sentAt: 'desc' },
    });
    if (sent.length === 0) return [];
    const roster = allowedClassIds(actor) ? await loadRoster(this.prisma, actor.schoolId) : null;
    return sent
      .filter((a) => !roster || audienceTouchesScope(actor, roster, toAudience(a.audience)))
      .map((a) =>
        item('MESSAGE_SENT', `ann:${a.id}`, a.sentAt ?? a.updatedAt, {
          params: { title: a.title, recipients: a.recipients },
          href: '/messages',
        }),
      );
  }

  /**
   * Ota-onadan o'qilmagan xabar — FAQAT qabul qiluvchi xodimga (yozishma maxfiy). Id oxirgi xabar
   * vaqtini o'z ichiga oladi: yangi xabar "o'qilgan" bildirishnomani qayta faollashtiradi.
   */
  private async parentMessages(actor: SchoolActor): Promise<NotificationItem[]> {
    if (!actorCan(actor, 'inbox.parents')) return [];
    const threads = await this.prisma.schoolParentThread.findMany({
      where: { schoolId: actor.schoolId, staffId: actor.staffId, staffUnread: { gt: 0 } },
      orderBy: { lastMessageAt: 'desc' },
      take: FEED_LIMIT,
      include: { student: { select: { firstName: true, lastName: true, class: { select: { name: true } } } } },
    });
    if (threads.length === 0) return [];
    const topics = await this.prisma.schoolParentMessage.findMany({
      where: { threadId: { in: threads.map((t) => t.id) }, author: 'PARENT', topic: { not: null } },
      orderBy: [{ threadId: 'asc' }, { createdAt: 'desc' }],
      distinct: ['threadId'],
      select: { threadId: true, topic: true },
    });
    const topicOf = new Map(topics.map((t) => [t.threadId, t.topic]));
    return threads.map((t) =>
      item('PARENT_MESSAGE', `pmsg:${t.id}:${t.lastMessageAt.getTime()}`, t.lastMessageAt, {
        params: { name: `${t.student.lastName} ${t.student.firstName}`, className: t.student.class?.name ?? '', count: t.staffUnread },
        subject: topicLabel(topicOf.get(t.id)),
        href: `/inbox?thread=${t.id}`,
      }),
    );
  }

  private async emergency(actor: SchoolActor): Promise<NotificationItem[]> {
    if (!actorCan(actor, 'schoolMode.view')) return [];
    const e = await this.prisma.schoolEmergency.findUnique({ where: { schoolId: actor.schoolId } });
    if (!e || !emergencyLive(e)) return [];
    const allowed = allowedClassIds(actor);
    if (allowed && e.scope === 'CLASS' && !e.classIds.some((id) => allowed.includes(id))) return [];
    const at = e.at ?? e.updatedAt;
    return [item('EMERGENCY', `emg:${at.toISOString()}`, at, { subject: plain(e.reason), href: '/school-mode' })];
  }

  private async names(schoolId: string, studentIds: string[]): Promise<[Map<string, string>, Map<string, string>]> {
    const [students, classes] = await Promise.all([
      studentIds.length
        ? this.prisma.schoolStudent.findMany({ where: { schoolId, id: { in: studentIds } }, select: { id: true, lastName: true, firstName: true } })
        : [],
      this.prisma.schoolClass.findMany({ where: { schoolId }, select: { id: true, name: true } }),
    ]);
    return [new Map(students.map((s) => [s.id, `${s.lastName} ${s.firstName}`])), new Map(classes.map((c) => [c.id, c.name]))];
  }
}
