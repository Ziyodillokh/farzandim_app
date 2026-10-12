import { roleHas } from '@/auth/permissions';
import type { Localized, NotificationItem, NotificationKind, NotificationTone, OpenRequests, StaffNotification } from '@/data/contracts';
import { enums as ruEnums } from '@/i18n/ru/enums';
import { enums as uzEnums } from '@/i18n/uz/enums';
import { toLocalIso } from '../calendar';
import { clockNow } from '../clock';
import { type Actor, allowedClassIds, assertCan, currentActor, inScope, latency } from '../context';
import { getTables } from '../db';
import { studentName } from '../lookups';
import { notificationsFor } from '../notify';
import type { Tables } from '../tables';
import { audienceTouchesScope, timeOf } from './comms-shared';

/**
 * Bildirishnomalar markazi: saqlangan signallar (xavfsizlik, test yakunlandi) +
 * jadvallardan hisoblanadigan ochiq holatlar. Id'lar barqaror — "o'qildi" holati
 * qayta hisoblashda ham saqlanadi.
 */
export const FEED_LIMIT = 30;
const MESSAGE_WINDOW_MS = 3 * 24 * 3_600_000;
const SUBJECT_MAX = 90;

export const NOTIFICATION_TONES: Record<NotificationKind, NotificationTone> = {
  SAFETY_SIGNAL: 'destructive',
  TEST_COMPLETED: 'success',
  EARLY_EXIT_PENDING: 'warning',
  VERIFICATION_OPEN: 'info',
  CARE_NEW: 'info',
  CARE_URGENT: 'destructive',
  MESSAGE_SENT: 'success',
  EMERGENCY: 'destructive',
};

/** Erkin matn (sabab, xabar) — ikkala tilda bir xil, qisqartirilgan. */
function plain(text: string | null | undefined): Localized | null {
  const value = text?.trim();
  if (!value) return null;
  const short = value.length > SUBJECT_MAX ? `${value.slice(0, SUBJECT_MAX - 1)}…` : value;
  return { uz: short, ru: short };
}

function classNames(t: Tables): Map<string, string> {
  return new Map(t.classes.map((c) => [c.id, c.name]));
}

/** Saqlangan bildirishnoma → element. Xavfsizlik signalida ism/matn HECH QACHON yo'q. */
function fromStored(n: StaffNotification): NotificationItem {
  if (n.kind === 'SAFETY_SIGNAL') {
    return { id: n.id, kind: n.kind, at: n.at, tone: NOTIFICATION_TONES.SAFETY_SIGNAL, params: {}, subject: null, href: n.href };
  }
  const count = Number(n.params.count);
  return {
    id: n.id,
    kind: n.kind,
    at: n.at,
    tone: NOTIFICATION_TONES[n.kind],
    params: { ...n.params, count: Number.isFinite(count) && count > 0 ? count : 1 },
    subject: n.subject,
    href: n.href,
  };
}

function storedItems(t: Tables, actor: Actor): NotificationItem[] {
  return notificationsFor(t, actor).map(fromStored);
}

function earlyExitItems(t: Tables, actor: Actor): NotificationItem[] {
  if (!roleHas(actor.role, 'attendance.view')) return [];
  const classes = classNames(t);
  const students = new Map(t.students.map((s) => [s.id, s]));
  return inScope(actor, t.earlyExits.filter((e) => e.status === 'PENDING')).map((e) => {
    const student = students.get(e.studentId);
    return {
      id: `exit:${e.id}`,
      kind: 'EARLY_EXIT_PENDING',
      at: e.requestedAt,
      tone: NOTIFICATION_TONES.EARLY_EXIT_PENDING,
      params: { name: student ? studentName(student) : '—', className: classes.get(e.classId) ?? '', time: e.time },
      subject: plain(e.reason),
      href: '/attendance/early-exit',
    };
  });
}

function verificationItems(t: Tables, actor: Actor): NotificationItem[] {
  if (!roleHas(actor.role, 'payments.manage')) return [];
  const guardians = new Map(t.guardians.map((g) => [g.id, g.fullName]));
  return t.verifications
    .filter((v) => v.status === 'OPEN')
    .map((v) => ({
      id: `ver:${v.id}`,
      kind: 'VERIFICATION_OPEN',
      at: v.createdAt,
      tone: NOTIFICATION_TONES.VERIFICATION_OPEN,
      params: { name: guardians.get(v.guardianId) ?? '—' },
      subject: plain(v.message),
      href: '/reminders/verifications',
    }));
}

/** Bola ovozi: faqat `care.individual` (psixolog). Ism yo'q — sinf va mavzu. */
function careItems(t: Tables, actor: Actor): NotificationItem[] {
  if (!roleHas(actor.role, 'care.individual')) return [];
  const classes = classNames(t);
  return t.careRequests
    .filter((r) => r.status === 'NEW')
    .map((r) => {
      const kind = r.urgency === 'URGENT' ? 'CARE_URGENT' : 'CARE_NEW';
      return {
        id: `care:${r.id}`,
        kind,
        at: r.createdAt,
        tone: NOTIFICATION_TONES[kind],
        params: { className: classes.get(r.classId) ?? '' },
        subject: { uz: uzEnums.careTopicTag[r.topic], ru: ruEnums.careTopicTag[r.topic] },
        href: `/care/requests/view?id=${r.id}`,
      };
    });
}

function messageItems(t: Tables, actor: Actor, nowMs: number): NotificationItem[] {
  if (!roleHas(actor.role, 'messages.view')) return [];
  return t.announcements
    .filter((a) => {
      const sent = timeOf(a.sentAt);
      return a.status === 'SENT' && nowMs - sent <= MESSAGE_WINDOW_MS && audienceTouchesScope(actor, t, a.audience);
    })
    .map((a) => ({
      id: `ann:${a.id}`,
      kind: 'MESSAGE_SENT',
      at: a.sentAt ?? '',
      tone: NOTIFICATION_TONES.MESSAGE_SENT,
      params: { title: a.title, recipients: a.stats.recipients },
      subject: null,
      href: '/messages',
    }));
}

function emergencyItems(t: Tables, actor: Actor, now: Date): NotificationItem[] {
  const e = t.emergency;
  if (!e.active || !roleHas(actor.role, 'schoolMode.view')) return [];
  const allowed = allowedClassIds(actor);
  if (allowed && e.scope === 'CLASS' && !e.classIds.some((id) => allowed.includes(id))) return [];
  const at = e.at ?? toLocalIso(now);
  return [{ id: `emg:${at}`, kind: 'EMERGENCY', at, tone: NOTIFICATION_TONES.EMERGENCY, params: {}, subject: plain(e.reason), href: '/school-mode' }];
}

/**
 * Rol va doiraga mos lenta: eng yangilari birinchi, ko'pi bilan 30 ta. Demo
 * soatidan "keyingi" hodisalar (masalan, 09:10 dagi so'rov soat 07:45 da yoki
 * ertalab qayta boshlanganda qolganlari) vaqti kelguncha ko'rsatilmaydi.
 */
export function buildFeed(t: Tables, actor: Actor, now: Date): NotificationItem[] {
  const nowMs = now.getTime();
  const all: NotificationItem[] = [
    ...storedItems(t, actor),
    ...earlyExitItems(t, actor),
    ...verificationItems(t, actor),
    ...careItems(t, actor),
    ...messageItems(t, actor, nowMs),
    ...emergencyItems(t, actor, now),
  ];
  const at = (item: NotificationItem) => {
    const ms = timeOf(item.at);
    return Number.isNaN(ms) ? 0 : ms;
  };
  return all
    // Faol favqulodda rejim — har doim (vaqtidan qat'i nazar).
    .filter((item) => item.kind === 'EMERGENCY' || at(item) <= nowMs)
    .sort((a, b) => at(b) - at(a) || a.id.localeCompare(b.id))
    .slice(0, FEED_LIMIT);
}

/** Rolga mos "ochiq so'rovlar" (bosh sahifa KPI): erta ketish + to'lov tekshiruvlari. */
export function openRequests(t: Tables, actor: Actor): OpenRequests | null {
  if (!roleHas(actor.role, 'attendance.view')) return null;
  const earlyExits = inScope(actor, t.earlyExits.filter((e) => e.status === 'PENDING')).length;
  const verifications = roleHas(actor.role, 'payments.manage') ? t.verifications.filter((v) => v.status === 'OPEN').length : null;
  const href = earlyExits === 0 && (verifications ?? 0) > 0 ? '/reminders/verifications' : '/attendance/early-exit';
  return { earlyExits, verifications, total: earlyExits + (verifications ?? 0), href };
}

export const notificationsService = {
  async feed(): Promise<NotificationItem[]> {
    await latency(60, 160);
    const actor = currentActor();
    assertCan(actor, 'dashboard.view');
    return buildFeed(getTables(), actor, clockNow());
  },
};
