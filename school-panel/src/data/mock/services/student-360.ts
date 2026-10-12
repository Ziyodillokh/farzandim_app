import { roleHas } from '@/auth/permissions';
import type {
  AttendanceStatus,
  EarlyExitStatus,
  HhMm,
  IsoDate,
  IsoDateTime,
  ParentNotification,
  PaymentReminderEntry,
  Student,
  StudentNote,
} from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { studentNoteSchema, type StudentNoteInput } from '@/data/schemas/students';
import { parseOrThrow } from '@/data/schemas/validate';
import { toLocalIso } from '../calendar';
import { clockNow } from '../clock';
import { type Actor, assertCan, assertClassInScope, currentActor, latency, newId, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { studentName } from '../lookups';
import type { Tables } from '../tables';

/**
 * O'quvchi 360° kartasi: tarix (erta ketish, tuzatish, ota-onaga xabar, School Mode
 * istisnolari, to'lov eslatmasi) va xodim eslatmalari. Ruxsat va sinf doirasi shu yerda.
 */

/** Tarix lentasidagi eng ko'p yozuvlar (eng yangilari). */
const HISTORY_LIMIT = 150;

type HistoryBase = { id: string; at: IsoDateTime };

export type StudentHistoryItem =
  | (HistoryBase & { kind: 'EARLY_EXIT'; status: EarlyExitStatus; date: IsoDate; time: HhMm; reason: string; pickupBy: string; decidedByName: string | null })
  | (HistoryBase & { kind: 'CORRECTION'; date: IsoDate; from: AttendanceStatus; to: AttendanceStatus; reason: string; byName: string })
  | (HistoryBase & { kind: 'NOTIFICATION'; notification: ParentNotification['kind']; guardianName: string; delivered: boolean })
  | (HistoryBase & { kind: 'EXCEPTION'; from: IsoDateTime; until: IsoDateTime; reason: string; byName: string; revoked: boolean })
  | (HistoryBase & { kind: 'PAYMENT'; action: PaymentReminderEntry['action']; note: string; byName: string });

export type StudentHistoryKind = StudentHistoryItem['kind'];

/** To'lov eslatmasi holati — faqat `payments.manage` huquqi bilan. */
export type StudentPaymentStatus = { nextDate: IsoDate; paused: boolean; prepaidMonths: number };

export type StudentHistory = { items: StudentHistoryItem[]; payment: StudentPaymentStatus | null };

export type StudentNoteRow = StudentNote & { byName: string; canDelete: boolean };

function staffName(t: Tables, id: string | null): string {
  if (!id) return '—';
  return t.staff.find((s) => s.id === id)?.fullName ?? '—';
}

function timeOf(stamp: string): number {
  const ms = Date.parse(stamp);
  return Number.isNaN(ms) ? 0 : ms;
}

/** Karta tarixi va eslatmalari: `students.view` + ota-onaga ulash huquqi (psixolog/o'qituvchida yo'q). */
function assertCardAccess(actor: Actor): void {
  assertCan(actor, 'students.view');
  assertCan(actor, 'guardians.link');
}

/** O'quvchi + huquq + sinf doirasi. */
function scopedStudent(t: Tables, actor: Actor, studentId: string): Student {
  assertCardAccess(actor);
  const student = t.students.find((s) => s.id === studentId);
  if (!student) throw new ServiceError('NOT_FOUND', studentId);
  assertClassInScope(actor, student.classId);
  return student;
}

function earlyExitItems(t: Tables, studentId: string): StudentHistoryItem[] {
  return t.earlyExits
    .filter((e) => e.studentId === studentId)
    .map((e) => ({
      id: `exit:${e.id}`,
      at: e.decidedAt ?? e.requestedAt,
      kind: 'EARLY_EXIT' as const,
      status: e.status,
      date: e.date,
      time: e.time,
      reason: e.reason,
      pickupBy: e.pickupBy,
      decidedByName: e.decidedByStaffId ? staffName(t, e.decidedByStaffId) : null,
    }));
}

function correctionItems(t: Tables, studentId: string): StudentHistoryItem[] {
  return t.attendance
    .filter((r) => r.studentId === studentId)
    .flatMap((r) =>
      r.corrections.map((c, i) => ({
        id: `corr:${r.id}:${i}`,
        at: c.at,
        kind: 'CORRECTION' as const,
        date: r.date,
        from: c.from,
        to: c.to,
        reason: c.reason,
        byName: staffName(t, c.byStaffId),
      })),
    );
}

function notificationItems(t: Tables, studentId: string): StudentHistoryItem[] {
  const guardians = new Map(t.guardians.map((g) => [g.id, g.fullName]));
  return t.parentNotifications
    .filter((n) => n.studentId === studentId)
    .map((n) => ({
      id: `ntf:${n.id}`,
      at: n.at,
      kind: 'NOTIFICATION' as const,
      notification: n.kind,
      guardianName: guardians.get(n.guardianId) ?? '—',
      delivered: n.delivered,
    }));
}

function exceptionItems(t: Tables, studentId: string): StudentHistoryItem[] {
  return t.exceptions
    .filter((e) => e.studentId === studentId)
    .map((e) => ({
      id: `exc:${e.id}`,
      at: e.from,
      kind: 'EXCEPTION' as const,
      from: e.from,
      until: e.until,
      reason: e.reason,
      byName: staffName(t, e.byStaffId),
      revoked: Boolean(e.revokedAt),
    }));
}

function paymentOf(t: Tables, studentId: string) {
  return t.payments.find((p) => p.studentIds.includes(studentId)) ?? null;
}

function paymentItems(t: Tables, studentId: string): StudentHistoryItem[] {
  const payment = paymentOf(t, studentId);
  if (!payment) return [];
  return payment.history.map((h, i) => ({
    id: `pay:${payment.id}:${i}`,
    at: h.at,
    kind: 'PAYMENT' as const,
    action: h.action,
    note: h.note,
    byName: staffName(t, h.byStaffId),
  }));
}

/** Tarix: barcha manbalar bitta lentada, eng yangisi birinchi. */
export function composeHistory(t: Tables, actor: Actor, studentId: string): StudentHistory {
  assertCan(actor, 'attendance.view');
  scopedStudent(t, actor, studentId);
  const canPayments = roleHas(actor.role, 'payments.manage');
  const items = [
    ...earlyExitItems(t, studentId),
    ...correctionItems(t, studentId),
    ...notificationItems(t, studentId),
    ...(roleHas(actor.role, 'schoolMode.view') ? exceptionItems(t, studentId) : []),
    ...(canPayments ? paymentItems(t, studentId) : []),
  ]
    .sort((a, b) => timeOf(b.at) - timeOf(a.at))
    .slice(0, HISTORY_LIMIT);
  const payment = canPayments ? paymentOf(t, studentId) : null;
  return {
    items,
    payment: payment ? { nextDate: payment.nextDate, paused: payment.paused, prepaidMonths: payment.prepaidMonths } : null,
  };
}

/** Eslatmani muallif yoki o'quvchilarni boshqaruvchi (direktor/admin) o'chira oladi. */
function canDeleteNote(actor: Actor, note: StudentNote): boolean {
  return note.byStaffId === actor.staffId || roleHas(actor.role, 'students.manage');
}

export const student360 = {
  async history(studentId: string): Promise<StudentHistory> {
    await latency(60, 140);
    return composeHistory(getTables(), currentActor(), studentId);
  },

  async notes(studentId: string): Promise<StudentNoteRow[]> {
    await latency(40, 100);
    const actor = currentActor();
    const t = getTables();
    scopedStudent(t, actor, studentId);
    return t.studentNotes
      .filter((n) => n.studentId === studentId)
      .sort((a, b) => timeOf(b.at) - timeOf(a.at))
      .map((n) => ({ ...n, byName: staffName(t, n.byStaffId), canDelete: canDeleteNote(actor, n) }));
  },

  async addNote(studentId: string, rawText: string): Promise<StudentNote> {
    await latency();
    const actor = currentActor();
    assertCardAccess(actor);
    const { text } = parseOrThrow(studentNoteSchema, { text: rawText } satisfies StudentNoteInput);
    return transact((t) => {
      const student = scopedStudent(t, actor, studentId);
      const note: StudentNote = { id: newId('note'), studentId, classId: student.classId, at: toLocalIso(clockNow()), byStaffId: actor.staffId, text };
      t.studentNotes.push(note);
      // Maxfiylik: eslatma matni auditga yozilmaydi — faqat kim, kimga va hajmi.
      const name = studentName(student);
      writeAudit(t, actor, 'STUDENTS', 'student.note.add', `${name}: kartaga eslatma qo'shildi`, note.id, null, null, { name, chars: text.length });
      return note;
    });
  },

  async deleteNote(noteId: string): Promise<void> {
    await latency();
    const actor = currentActor();
    transact((t) => {
      const note = t.studentNotes.find((n) => n.id === noteId);
      if (!note) throw new ServiceError('NOT_FOUND', noteId);
      const student = scopedStudent(t, actor, note.studentId);
      if (!canDeleteNote(actor, note)) throw new ServiceError('FORBIDDEN', noteId);
      t.studentNotes = t.studentNotes.filter((n) => n.id !== noteId);
      const name = studentName(student);
      writeAudit(t, actor, 'STUDENTS', 'student.note.delete', `${name}: kartadagi eslatma o'chirildi`, noteId, null, null, { name });
    });
  },
};
