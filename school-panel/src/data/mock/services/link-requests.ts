import type { LinkRequest, Student } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { toLocalIso } from '../calendar';
import { clockNow } from '../clock';
import { type Actor, assertCan, assertClassInScope, currentActor, inScope, latency, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { studentName } from '../lookups';
import type { MockLinkRequest } from '../access-tables';
import type { Tables } from '../tables';

/**
 * Ulanish so'rovlari (K2): bola 6 xonali kodni kiritdi (REVIEW — xodim tasdig'i kerak) yoki maktab/sinf noto'g'ri deb
 * bildirdi (CORRECTION). Ruxsat — `guardians.link`; sinf rahbari faqat o'z sinfidagi so'rovlarni ko'radi va hal qiladi.
 *  - REVIEW: tasdiqlash → o'quvchi bola profiliga ulanadi; rad etish → o'quvchi o'rni bo'shaydi (bola qayta kiritishi mumkin).
 *  - CORRECTION: tasdiqlash = ulanishni saqlash; rad etish = ulanishni uzish.
 */

function toView(t: Tables, r: MockLinkRequest): LinkRequest | null {
  const student = t.students.find((s) => s.id === r.studentId);
  if (!student) return null;
  return {
    id: r.id,
    kind: r.kind,
    studentId: student.id,
    studentName: studentName(student),
    className: t.classes.find((c) => c.id === student.classId)?.name ?? '—',
    createdAt: r.createdAt,
    parentUsed: r.parentUsed,
    note: r.note,
    reason: r.reason,
  };
}

/** Ochiq so'rov va uning o'quvchisi (doiradan tashqari sinf — FORBIDDEN, hal qilingan — CONFLICT). */
function openRequest(t: Tables, actor: Actor, id: string): { request: MockLinkRequest; student: Student } {
  const request = t.access.linkRequests.find((r) => r.id === id);
  const student = request && t.students.find((s) => s.id === request.studentId);
  if (!request || !student) throw new ServiceError('NOT_FOUND', id, 'REQUEST_NOT_FOUND');
  assertClassInScope(actor, student.classId);
  if (request.status !== 'OPEN') throw new ServiceError('CONFLICT', 'already resolved', 'ALREADY_RESOLVED');
  return { request, student };
}

type Decision = 'confirm' | 'reject';

function decide(t: Tables, actor: Actor, id: string, decision: Decision): void {
  const { request, student } = openRequest(t, actor, id);
  const studentId = student.id;
  const now = toLocalIso(clockNow());
  request.status = decision === 'confirm' ? 'CONFIRMED' : 'REJECTED';
  request.resolvedAt = now;

  const linked = t.access.linkedStudentIds;
  if (request.kind === 'REVIEW') {
    if (decision === 'confirm') {
      if (!linked.includes(studentId)) linked.push(studentId);
    } else {
      // O'quvchi o'rni bo'shaydi — bola kodni qayta kiritishi mumkin.
      for (const invite of t.access.inviteCodes) {
        if (invite.studentId === studentId && invite.closedAt === null) invite.studentUsedAt = null;
      }
    }
  } else if (decision === 'reject') {
    t.access.linkedStudentIds = linked.filter((x) => x !== studentId);
  }

  const name = studentName(student);
  const correction = request.kind === 'CORRECTION';
  const summary =
    decision === 'confirm'
      ? `${name}: ${correction ? 'tuzatish soʻrovi koʻrib chiqildi, ulanish saqlandi' : 'bola profiliga ulanish tasdiqlandi'}`
      : `${name}: ${correction ? 'tuzatish soʻrovi koʻrib chiqildi, ulanish uzildi' : 'bola profiliga ulanish rad etildi'}`;
  writeAudit(t, actor, 'STUDENTS', `student.link.${decision}`, summary, studentId, null, null, { name, ...(correction ? { variant: 'correction' } : {}) });
}

export const linkRequestsService = {
  /** Ochiq so'rovlar (eng yangisi birinchi), rol doirasida. */
  async list(): Promise<LinkRequest[]> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'guardians.link');
    const t = getTables();
    const open = t.access.linkRequests
      .filter((r) => r.status === 'OPEN')
      .map((r) => ({ r, classId: t.students.find((s) => s.id === r.studentId)?.classId ?? '' }));
    return inScope(actor, open)
      .map(({ r }) => toView(t, r))
      .filter((x): x is LinkRequest => x !== null)
      .sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt) || a.id.localeCompare(b.id));
  },

  async confirm(id: string): Promise<void> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'guardians.link');
    transact((t) => decide(t, actor, id, 'confirm'));
  },

  async reject(id: string): Promise<void> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'guardians.link');
    transact((t) => decide(t, actor, id, 'reject'));
  },
};
