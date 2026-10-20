// O'quvchi 360° kartasi: tarix lentasi (erta ketish, davomat tuzatishi,
// ota-onaga xabar, School Mode istisnosi, to'lov eslatmasi) va xodim
// eslatmalari. Karta — `students.view` + `guardians.link` + sinf doirasi.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { actorCan, assertCan, assertClassInScope, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { forbidden, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { studentName } from './student-view';
import { studentNoteSchema } from './students.schemas';

/** Tarix lentasidagi eng ko'p yozuvlar (eng yangilari). */
export const HISTORY_LIMIT = 150;

interface PaymentEntry {
  at: string;
  byStaffId: string;
  action: string;
  note: string;
}

type HistoryItem = { id: string; at: string; kind: string } & Record<string, unknown>;

@Injectable()
export class Student360Service {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  async history(actor: SchoolActor, studentId: string) {
    assertCan(actor, 'attendance.view');
    await this.scopedStudent(actor, studentId);
    const canPayments = actorCan(actor, 'payments.manage');
    const canExceptions = actorCan(actor, 'schoolMode.view');
    const where = { schoolId: actor.schoolId, studentId };
    const [exits, corrections, notices, exceptions, payment] = await Promise.all([
      this.prisma.schoolEarlyExit.findMany({ where }),
      this.prisma.schoolAttendanceCorrection.findMany({
        where: { attendance: where },
        include: { attendance: { select: { date: true } } },
      }),
      this.prisma.schoolParentNotice.findMany({ where, orderBy: { at: 'desc' }, take: HISTORY_LIMIT }),
      canExceptions ? this.prisma.schoolModeException.findMany({ where }) : [],
      canPayments
        ? this.prisma.schoolPaymentReminder.findFirst({
            where: { schoolId: actor.schoolId, studentIds: { has: studentId } },
            orderBy: { createdAt: 'asc' },
          })
        : null,
    ]);
    const payments = payment ? paymentEntries(payment.history) : [];
    const names = await this.names(actor.schoolId, notices.map((n) => n.guardianId), [
      ...exits.map((e) => e.decidedByStaffId),
      ...corrections.map((c) => c.byStaffId),
      ...exceptions.map((e) => e.byStaffId),
      ...payments.map((p) => p.byStaffId),
    ]);
    const staff = (id: string | null) => (id ? (names.staff.get(id) ?? '—') : '—');
    const items: HistoryItem[] = [
      ...exits.map((e) => ({
        id: `exit:${e.id}`,
        at: (e.decidedAt ?? e.requestedAt).toISOString(),
        kind: 'EARLY_EXIT',
        status: e.status,
        date: e.date,
        time: e.time,
        reason: e.reason,
        pickupBy: e.pickupBy,
        decidedByName: e.decidedByStaffId ? staff(e.decidedByStaffId) : null,
      })),
      ...corrections.map((c) => ({
        id: `corr:${c.id}`,
        at: c.at.toISOString(),
        kind: 'CORRECTION',
        date: c.attendance.date,
        from: c.from,
        to: c.to,
        reason: c.reason,
        byName: staff(c.byStaffId),
      })),
      ...notices.map((n) => ({
        id: `ntf:${n.id}`,
        at: n.at.toISOString(),
        kind: 'NOTIFICATION',
        notification: n.kind,
        guardianName: names.guardians.get(n.guardianId) ?? '—',
        delivered: n.delivered,
      })),
      ...exceptions.map((e) => ({
        id: `exc:${e.id}`,
        at: e.from.toISOString(),
        kind: 'EXCEPTION',
        from: e.from.toISOString(),
        until: e.until.toISOString(),
        reason: e.reason,
        byName: staff(e.byStaffId),
        revoked: Boolean(e.revokedAt),
      })),
      ...payments.map((p, i) => ({
        id: `pay:${payment?.id}:${i}`,
        at: p.at,
        kind: 'PAYMENT',
        action: p.action,
        note: p.note,
        byName: staff(p.byStaffId),
      })),
    ];
    return {
      items: items.sort((a, b) => Date.parse(b.at) - Date.parse(a.at)).slice(0, HISTORY_LIMIT),
      payment: payment
        ? { nextDate: payment.nextDate, paused: payment.paused, prepaidMonths: payment.prepaidMonths }
        : null,
    };
  }

  async notes(actor: SchoolActor, studentId: string) {
    await this.scopedStudent(actor, studentId);
    const notes = await this.prisma.schoolStudentNote.findMany({
      where: { schoolId: actor.schoolId, studentId },
      orderBy: { at: 'desc' },
    });
    const names = await this.names(actor.schoolId, [], notes.map((n) => n.byStaffId));
    return notes.map((n) => ({
      ...noteView(n),
      byName: names.staff.get(n.byStaffId) ?? '—',
      canDelete: canDeleteNote(actor, n.byStaffId),
    }));
  }

  /** Maxfiylik: eslatma matni auditga yozilmaydi — faqat kim, kimga va hajmi. */
  async addNote(actor: SchoolActor, studentId: string, input: unknown) {
    const { text } = parseOrThrow(studentNoteSchema, input);
    return this.prisma.$transaction(async (tx) => {
      const student = await this.scopedStudent(actor, studentId, tx);
      const note = await tx.schoolStudentNote.create({
        data: { schoolId: actor.schoolId, studentId, classId: student.classId, byStaffId: actor.staffId, text },
      });
      const name = studentName(student);
      await this.audit.write(
        actor,
        {
          module: 'STUDENTS',
          action: 'student.note.add',
          summary: `${name}: kartaga eslatma qo'shildi`,
          entityId: note.id,
          params: { name, chars: text.length },
        },
        tx,
      );
      return noteView(note);
    });
  }

  /** Eslatmani muallif yoki o'quvchilarni boshqaruvchi (direktor/admin) o'chira oladi. */
  async deleteNote(actor: SchoolActor, noteId: string): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const note = await tx.schoolStudentNote.findFirst({ where: { id: noteId, schoolId: actor.schoolId } });
      if (!note) throw notFound(noteId);
      const student = await this.scopedStudent(actor, note.studentId, tx);
      if (!canDeleteNote(actor, note.byStaffId)) throw forbidden(noteId);
      await tx.schoolStudentNote.delete({ where: { id: noteId } });
      const name = studentName(student);
      await this.audit.write(
        actor,
        {
          module: 'STUDENTS',
          action: 'student.note.delete',
          summary: `${name}: kartadagi eslatma o'chirildi`,
          entityId: noteId,
          params: { name },
        },
        tx,
      );
    });
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  private async scopedStudent(actor: SchoolActor, studentId: string, db: Prisma.TransactionClient = this.prisma) {
    assertCan(actor, 'students.view');
    assertCan(actor, 'guardians.link');
    const student = await db.schoolStudent.findFirst({ where: { id: studentId, schoolId: actor.schoolId } });
    if (!student) throw notFound(studentId);
    assertClassInScope(actor, student.classId);
    return student;
  }

  private async names(schoolId: string, guardianIds: string[], staffIds: Array<string | null>) {
    const [guardians, staff] = await Promise.all([
      guardianIds.length
        ? this.prisma.schoolGuardian.findMany({ where: { schoolId, id: { in: guardianIds } }, select: { id: true, fullName: true } })
        : [],
      this.prisma.schoolStaff.findMany({
        where: { schoolId, id: { in: staffIds.filter((id): id is string => Boolean(id)) } },
        select: { id: true, fullName: true },
      }),
    ]);
    return {
      guardians: new Map(guardians.map((g) => [g.id, g.fullName])),
      staff: new Map(staff.map((s) => [s.id, s.fullName])),
    };
  }
}

function canDeleteNote(actor: SchoolActor, authorId: string): boolean {
  return authorId === actor.staffId || actorCan(actor, 'students.manage');
}

function noteView(n: { id: string; studentId: string; classId: string | null; at: Date; byStaffId: string; text: string }) {
  return { id: n.id, studentId: n.studentId, classId: n.classId ?? '', at: n.at.toISOString(), byStaffId: n.byStaffId, text: n.text };
}

/** To'lov tarixi JSON — faqat to'g'ri shakldagi yozuvlar. */
function paymentEntries(history: Prisma.JsonValue): PaymentEntry[] {
  if (!Array.isArray(history)) return [];
  return history.filter((h): h is PaymentEntry & Prisma.JsonObject => {
    if (!h || typeof h !== 'object' || Array.isArray(h)) return false;
    const e = h as Record<string, unknown>;
    return typeof e.at === 'string' && typeof e.byStaffId === 'string' && typeof e.action === 'string';
  }).map((e) => ({ at: e.at, byStaffId: e.byStaffId, action: e.action, note: typeof e.note === 'string' ? e.note : '' }));
}
