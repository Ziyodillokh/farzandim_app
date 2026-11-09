import type {
  InboxCounts,
  InboxFilter,
  InboxPage,
  ParentMessage,
  ParentThreadBase,
  ParentThreadDetail,
  ParentThreadRow,
  ParentThreadStatus,
} from '@/data/contracts';
import { PARENT_REPLY_MAX, ServiceError } from '@/data/contracts';
import { toLocalIso } from '../calendar';
import { clockNow } from '../clock';
import { type Actor, assertCan, currentActor, latency, newId, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { studentName } from '../lookups';
import { paginate } from '../query';
import type { MockParentThread } from '../seed/parent-threads';
import type { Tables } from '../tables';

/**
 * Ota-onalar xabarlari (backend `staff-threads.service.ts` bilan bir xil qoidalar): xodim FAQAT o'ziga
 * yozilgan yozishmalarni ko'radi — direktor ham boshqalarnikini ko'rmaydi (psixolog va o'qituvchi suhbati
 * maxfiy). Ruxsat — `inbox.parents`. Auditda faqat metama'lumot (matn yo'q).
 */

const PREVIEW_MAX = 120;
const time = (v: string) => Date.parse(v) || 0;

const notFound = (id: string) => new ServiceError('NOT_FOUND', `thread ${id}`);

function snippet(text: string): string {
  const flat = text.replace(/\s+/g, ' ').trim();
  return flat.length <= PREVIEW_MAX ? flat : `${flat.slice(0, PREVIEW_MAX - 1).trimEnd()}…`;
}

const last = (t: MockParentThread) => t.messages[t.messages.length - 1];

/** Xodim o'qimagan ota-ona xabarlari. */
export function unreadOf(t: MockParentThread): number {
  const readAt = t.staffReadAt ? time(t.staffReadAt) : -1;
  return t.messages.filter((m) => m.author === 'PARENT' && time(m.createdAt) > readAt).length;
}

function own(tables: Tables, actor: Actor): MockParentThread[] {
  return tables.parentThreads.filter((t) => t.staffId === actor.staffId);
}

function locate(tables: Tables, actor: Actor, id: string): MockParentThread {
  const thread = own(tables, actor).find((t) => t.id === id);
  if (!thread) throw notFound(id);
  return thread;
}

function base(tables: Tables, t: MockParentThread): ParentThreadBase {
  const student = tables.students.find((s) => s.id === t.studentId);
  const guardian = tables.guardians.find((g) => g.id === t.guardianId);
  const lastMessage = last(t);
  return {
    id: t.id,
    status: t.status,
    guardian: { id: t.guardianId, fullName: guardian?.fullName ?? '—', relation: guardian?.relation ?? 'OTHER' },
    student: {
      id: t.studentId,
      name: student ? studentName(student) : '—',
      className: tables.classes.find((c) => c.id === student?.classId)?.name ?? '',
    },
    lastAuthor: lastMessage?.author ?? 'PARENT',
    lastMessageAt: lastMessage?.createdAt ?? t.createdAt,
    unread: unreadOf(t),
    createdAt: t.createdAt,
  };
}

function row(tables: Tables, t: MockParentThread): ParentThreadRow {
  const m = last(t);
  return { ...base(tables, t), preview: m ? { author: m.author, text: snippet(m.text), at: m.createdAt } : null };
}

function detail(tables: Tables, t: MockParentThread): ParentThreadDetail {
  const staffRead = t.staffReadAt ? time(t.staffReadAt) : -1;
  const parentRead = t.parentReadAt ? time(t.parentReadAt) : -1;
  const messages: ParentMessage[] = t.messages.map((m) => ({
    id: m.id,
    author: m.author,
    topic: m.topic,
    body: m.text,
    createdAt: m.createdAt,
    seen: (m.author === 'PARENT' ? staffRead : parentRead) >= time(m.createdAt),
  }));
  return { ...base(tables, t), parentReadAt: t.parentReadAt, messages };
}

function counts(tables: Tables, actor: Actor): InboxCounts {
  const mine = own(tables, actor);
  return { unread: mine.filter((t) => unreadOf(t) > 0).length, open: mine.filter((t) => t.status === 'OPEN').length };
}

function matches(tables: Tables, t: MockParentThread, search: string): boolean {
  const needle = search.toLocaleLowerCase('uz');
  const view = base(tables, t);
  return [view.guardian.fullName, view.student.name].some((v) => v.toLocaleLowerCase('uz').includes(needle));
}

export const inboxService = {
  async list(filter: InboxFilter & { page?: number; limit?: number } = { status: 'OPEN' }): Promise<InboxPage> {
    await latency(60, 160);
    const actor = currentActor();
    assertCan(actor, 'inbox.parents');
    const tables = getTables();
    const items = own(tables, actor)
      .filter((t) => filter.status === 'ALL' || t.status === filter.status)
      .filter((t) => !filter.search?.trim() || matches(tables, t, filter.search.trim()))
      .sort((a, b) => time(last(b)?.createdAt ?? b.createdAt) - time(last(a)?.createdAt ?? a.createdAt) || a.id.localeCompare(b.id))
      .map((t) => row(tables, t));
    return { ...paginate(items, filter.page ?? 1, filter.limit ?? 30), counts: counts(tables, actor) };
  },

  /** Menyu nishoni: o'qilmagan va ochiq yozishmalar. */
  async summary(): Promise<InboxCounts> {
    await latency(30, 80);
    const actor = currentActor();
    assertCan(actor, 'inbox.parents');
    return counts(getTables(), actor);
  },

  async get(id: string): Promise<ParentThreadDetail> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'inbox.parents');
    const tables = getTables();
    return detail(tables, locate(tables, actor, id));
  },

  async reply(id: string, body: string): Promise<ParentThreadDetail> {
    await latency(120, 260);
    const actor = currentActor();
    assertCan(actor, 'inbox.parents');
    const text = body.replace(/\r\n/g, '\n').trim();
    if (!text) throw new ServiceError('VALIDATION', 'body: errors.form.required');
    if (text.length > PARENT_REPLY_MAX) throw new ServiceError('VALIDATION', 'body: errors.form.tooLong');
    return transact((tables) => {
      const thread = locate(tables, actor, id);
      const now = toLocalIso(clockNow());
      thread.messages.push({ id: newId('pm'), author: 'STAFF', topic: null, text, createdAt: now });
      thread.staffReadAt = now;
      const view = base(tables, thread);
      writeAudit(tables, actor, 'MESSAGES', 'parentThread.reply', `${view.student.name}: ota-onaga javob yozildi`, thread.id, null, null, {
        name: view.student.name,
      });
      return detail(tables, thread);
    });
  },

  async markRead(id: string): Promise<{ id: string; readAt: string }> {
    await latency(30, 80);
    const actor = currentActor();
    assertCan(actor, 'inbox.parents');
    return transact((tables) => {
      const thread = locate(tables, actor, id);
      thread.staffReadAt = toLocalIso(clockNow());
      return { id: thread.id, readAt: thread.staffReadAt };
    });
  },

  async setStatus(id: string, status: ParentThreadStatus): Promise<ParentThreadDetail> {
    await latency(80, 180);
    const actor = currentActor();
    assertCan(actor, 'inbox.parents');
    return transact((tables) => {
      const thread = locate(tables, actor, id);
      if (thread.status !== status) {
        thread.status = status;
        const view = base(tables, thread);
        const action = status === 'RESOLVED' ? 'parentThread.resolve' : 'parentThread.reopen';
        writeAudit(tables, actor, 'MESSAGES', action, `${view.student.name}: yozishma holati — ${status}`, thread.id, null, null, {
          name: view.student.name,
        });
      }
      return detail(tables, thread);
    });
  },
};
