import type { LinkDecisionResult, LinkDecisionStatus, LinkRequest, Student } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { accessNotificationId } from '../access-model';
import type { MockLinkRequest } from '../access-tables';
import { toLocalIso } from '../calendar';
import { clockNow } from '../clock';
import { type Actor, assertCan, assertClassInScope, currentActor, inScope, latency, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { studentFullName, studentName } from '../lookups';
import type { Tables } from '../tables';

/**
 * Ulanish so'rovlari (K2 §5, backend `link-requests.service.ts` bilan bir xil qoidalar): bola 6 xonali kodni kiritdi
 * (REVIEW — xodim tasdig'i kerak) yoki maktab/sinf noto'g'ri deb bildirdi (CORRECTION). Ruxsat — `guardians.link`; sinf rahbari
 * faqat o'z sinfidagi so'rovlarni ko'radi va hal qiladi (boshqasi — `FORBIDDEN`).
 *  - REVIEW: `confirm` → o'quvchi bola profiliga ulanadi (audit `student.childLinked`); `reject` → o'quvchi o'rni bo'shaydi
 *    (audit `student.linkRejected`), so'rov ro'yxatdan chiqadi.
 *  - CORRECTION: `confirm` = ulanish SAQLANADI (audit `student.linkCorrectionKept`); `reject` = ulanish UZILADI (audit `student.childUnlinked`).
 * Idempotentlik: bir xil qaror takrori `200`; qarama-qarshi qaror yoki o'zgargan so'rov `409 REQUEST_STALE`; rad etilgan REVIEW ro'yxatdan
 * chiqqani uchun qayta rad etish `404`. Hal bo'lgan so'rovning xodim bildirishnomasi o'chadi.
 */

type Decision = 'confirm' | 'reject';

const STATUS_OF: Readonly<Record<Decision, LinkDecisionStatus>> = { confirm: 'CONFIRMED', reject: 'REJECTED' };

const gone = () => new ServiceError('NOT_FOUND', 'Link request not found', 'NOT_FOUND');
const stale = () => new ServiceError('CONFLICT', 'Link request is no longer open', 'REQUEST_STALE');
const linkedElsewhere = () => new ServiceError('CONFLICT', 'Linked by another family member', 'STUDENT_LINKED_ELSEWHERE');

function toView(t: Tables, r: MockLinkRequest, student: Student): LinkRequest {
  return {
    id: r.id,
    kind: r.kind,
    createdAt: r.createdAt,
    student: {
      id: student.id,
      fullName: studentFullName(student),
      classId: student.classId,
      className: t.classes.find((c) => c.id === student.classId)?.name ?? '',
    },
    child: { name: r.childName },
    // Mock'da vasiylik so'rovlari (GUARDIAN) yo'q — faqat REVIEW / CORRECTION.
    parent: null,
    parentLinked: r.parentLinked,
    reason: r.reason,
    note: r.note,
  };
}

/** Navbatdagi (ochiq) so'rovmi: arxivdagi o'quvchiniki ko'rsatilmaydi; tuzatish — bog'lanish hali bor bo'lsa. */
function isQueued(t: Tables, r: MockLinkRequest, student: Student | undefined): student is Student {
  if (r.status !== 'OPEN' || !student || student.archived) return false;
  return r.kind === 'REVIEW' || t.access.linkedStudentIds.includes(student.id);
}

/** So'rov va uning o'quvchisi: noma'lum id — `NOT_FOUND`, doiradan tashqari sinf — `FORBIDDEN`. */
function locate(t: Tables, actor: Actor, id: string): { request: MockLinkRequest; student: Student } {
  const request = t.access.linkRequests.find((r) => r.id === id);
  const student = request && t.students.find((s) => s.id === request.studentId);
  if (!request || !student) throw gone();
  assertClassInScope(actor, student.classId);
  return { request, student };
}

/** Allaqachon hal bo'lgan so'rovga takroriy qaror (backend bilan bir xil). */
function repeatedDecision(request: MockLinkRequest, status: LinkDecisionStatus): LinkDecisionResult {
  if (request.status !== status) throw stale();
  // Rad etilgan REVIEW ro'yxatdan chiqqan (o'quvchi o'rni bo'shagan) — takroriy rad etish `404`.
  if (request.kind === 'REVIEW' && status === 'REJECTED') throw gone();
  return { id: request.id, kind: request.kind, status };
}

function dropNotification(t: Tables, request: MockLinkRequest): void {
  const id = accessNotificationId(request.kind === 'REVIEW' ? 'LINK_REVIEW' : 'LINK_CORRECTION', request.id);
  t.notifications = t.notifications.filter((n) => n.id !== id);
}

function applyReview(t: Tables, student: Student, status: LinkDecisionStatus, now: string): void {
  const linked = t.access.linkedStudentIds;
  if (status === 'CONFIRMED') {
    // O'quvchi allaqachon (boshqa oila farzandiga) ulangan — tasdiqlab bo'lmaydi; xodim rad etib o'rinni bo'shatishi mumkin.
    if (linked.includes(student.id)) throw linkedElsewhere();
    linked.push(student.id);
    for (const invite of t.access.inviteCodes) {
      if (invite.studentId === student.id && invite.studentUsedAt !== null && invite.studentConfirmedAt === null) invite.studentConfirmedAt = now;
    }
    return;
  }
  // Rad etish: o'quvchi o'rni bo'shaydi (kod hali faol bo'lsa bola qayta kirita oladi; yopilgan bo'lsa — yangi kod kerak).
  for (const invite of t.access.inviteCodes) {
    if (invite.studentId === student.id && invite.studentConfirmedAt === null) invite.studentUsedAt = null;
  }
}

function applyCorrection(t: Tables, student: Student, status: LinkDecisionStatus): void {
  // `confirm` — bog'lanish qoladi (hech narsa o'zgarmaydi). `reject` — bog'lanish uziladi, bolaning kod o'rinlari bo'shaydi.
  if (status === 'CONFIRMED') return;
  t.access.linkedStudentIds = t.access.linkedStudentIds.filter((id) => id !== student.id);
  for (const invite of t.access.inviteCodes) {
    if (invite.studentId !== student.id) continue;
    invite.studentUsedAt = null;
    invite.studentConfirmedAt = null;
  }
}

function auditOf(request: MockLinkRequest, status: LinkDecisionStatus, name: string): { action: string; summary: string } {
  if (request.kind === 'REVIEW') {
    return status === 'CONFIRMED'
      ? { action: 'student.childLinked', summary: `${name}: Parvoz bola ilovasi bog'landi` }
      : { action: 'student.linkRejected', summary: `${name}: bola ulanish so'rovi rad etildi` };
  }
  return status === 'CONFIRMED'
    ? { action: 'student.linkCorrectionKept', summary: `${name}: bola so'rovi ko'rib chiqildi, bog'lanish qoldi` }
    : { action: 'student.childUnlinked', summary: `${name}: Parvoz bola ilovasi uzildi` };
}

function decide(t: Tables, actor: Actor, id: string, decision: Decision): LinkDecisionResult {
  const { request, student } = locate(t, actor, id);
  const status = STATUS_OF[decision];
  if (request.status !== 'OPEN') return repeatedDecision(request, status);
  if (student.archived) throw stale();

  const now = toLocalIso(clockNow());
  if (request.kind === 'REVIEW') applyReview(t, student, status, now);
  else applyCorrection(t, student, status);
  request.status = status;
  request.resolvedAt = now;
  dropNotification(t, request);

  const name = studentName(student);
  const { action, summary } = auditOf(request, status, name);
  writeAudit(t, actor, 'STUDENTS', action, summary, student.id, null, null, { name });
  return { id: request.id, kind: request.kind, status };
}

export const linkRequestsService = {
  /** Navbatdagi so'rovlar, rol doirasida — ENG ESKILARI BIRINCHI (backend bilan bir xil). */
  async list(): Promise<LinkRequest[]> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'guardians.link');
    const t = getTables();
    const students = new Map(t.students.map((s) => [s.id, s]));
    const queued = t.access.linkRequests.flatMap((r) => {
      const student = students.get(r.studentId);
      return isQueued(t, r, student) ? [{ r, student, classId: student.classId }] : [];
    });
    return inScope(actor, queued)
      .map(({ r, student }) => toView(t, r, student))
      .sort((a, b) => Date.parse(a.createdAt) - Date.parse(b.createdAt) || a.id.localeCompare(b.id));
  },

  /** REVIEW: bog'lanishni tasdiqlash. CORRECTION: bog'lanishni SAQLASH. */
  async confirm(id: string): Promise<LinkDecisionResult> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'guardians.link');
    return transact((t) => decide(t, actor, id, 'confirm'));
  },

  /** REVIEW: o'quvchi o'rnini bo'shatish. CORRECTION: bog'lanishni UZISH. */
  async reject(id: string): Promise<LinkDecisionResult> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'guardians.link');
    return transact((t) => decide(t, actor, id, 'reject'));
  },
};
