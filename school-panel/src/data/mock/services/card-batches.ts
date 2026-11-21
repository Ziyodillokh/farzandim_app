import type { AssignedCard, CardImportResult, CardImportSummary, CardReservation, CardReserveResult, Student } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import {
  cardBindSchema,
  cardImportSchema,
  cardReserveSchema,
  normalizeCardUid,
  normalizeReaderUid,
  type CardBindInput,
  type CardImportInput,
  type CardReserveInput,
} from '@/data/schemas/cards';
import { parseOrThrow } from '@/data/schemas/validate';
import { clockNow } from '../clock';
import { type Actor, assertCan, currentActor, latency, newId, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { studentName } from '../lookups';
import type { MockCardReservation, Tables } from '../tables';
import { issueCard, nextNumber } from './cards';

/**
 * Karta partiyasi (demo; backend `card-reservations.service.ts` bilan bir xil qoidalar):
 * sinflar bo'yicha raqam ajratish → bosmaxona ro'yxati → chiplarni ketma-ket yoki fayldan bog'lash.
 */

function toView(t: Tables, r: MockCardReservation): CardReservation {
  const student = t.students.find((s) => s.id === r.studentId);
  const cls = student ? t.classes.find((c) => c.id === student.classId) : undefined;
  return {
    ...r,
    studentName: student ? studentName(student) : '—',
    studentCode: student?.studentCode ?? '',
    classId: student?.classId ?? null,
    className: cls?.name ?? '',
  };
}

const printOrder = (a: CardReservation, b: CardReservation) =>
  a.className.localeCompare(b.className, 'uz', { numeric: true }) || a.studentName.localeCompare(b.studentName, 'uz');

function listViews(t: Tables): CardReservation[] {
  return t.cardReservations.map((r) => toView(t, r)).sort(printOrder);
}

function activeStudent(t: Tables, r: MockCardReservation): Student {
  const student = t.students.find((s) => s.id === r.studentId);
  if (!student) throw new ServiceError('NOT_FOUND', r.studentId);
  if (student.archived) throw new ServiceError('CONFLICT', 'student archived', 'STUDENT_ARCHIVED');
  return student;
}

function importRow(t: Tables, actor: Actor, number: string, rawUid: string): CardImportResult {
  const uid = normalizeCardUid(rawUid);
  if (!uid) return { number, ok: false, code: 'INVALID_UID' };
  const reservation = t.cardReservations.find((r) => r.number === number);
  if (!reservation) return { number, ok: false, code: 'RESERVATION_NOT_FOUND' };
  try {
    issueCard(t, actor, activeStudent(t, reservation), uid, reservation);
    return { number, ok: true, code: null };
  } catch (error) {
    if (error instanceof ServiceError) return { number, ok: false, code: error.detail ?? 'ERROR' };
    throw error;
  }
}

export const cardBatchService = {
  async list(): Promise<CardReservation[]> {
    await latency();
    assertCan(currentActor(), 'students.manage');
    return listViews(getTables());
  },

  /** Tanlangan sinflardagi faol kartasi va raqami yo'q o'quvchilarga raqam ajratish. */
  async reserve(input: CardReserveInput): Promise<CardReserveResult> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'students.manage');
    const { classIds } = parseOrThrow(cardReserveSchema, input);
    return transact((t) => {
      const classSet = new Set(classIds);
      const waiting = new Set(t.cardReservations.map((r) => r.studentId));
      const carded = new Set(t.cards.filter((c) => c.status === 'ACTIVE').map((c) => c.studentId));
      const students = t.students.filter((s) => !s.archived && classSet.has(s.classId) && !waiting.has(s.id) && !carded.has(s.id));
      const createdAt = clockNow().toISOString();
      for (const s of students) t.cardReservations.push({ id: newId('res'), number: nextNumber(t), studentId: s.id, createdAt });
      if (students.length > 0) {
        writeAudit(t, actor, 'STUDENTS', 'card.reserve', `${students.length} ta o'quvchiga karta raqami ajratildi`, null, null, null, { count: students.length });
      }
      return { created: students.length, items: listViews(t) };
    });
  },

  async cancel(id: string): Promise<void> {
    await latency();
    assertCan(currentActor(), 'students.manage');
    transact((t) => {
      if (!t.cardReservations.some((r) => r.id === id)) throw new ServiceError('NOT_FOUND', id);
      t.cardReservations = t.cardReservations.filter((r) => r.id !== id);
    });
  },

  /** Ketma-ket biriktirish: chop etilgan kartaning chipi shu raqamga bog'lanadi. */
  async bind(id: string, input: CardBindInput): Promise<AssignedCard> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'students.manage');
    const data = parseOrThrow(cardBindSchema, input);
    const uid = data.uid ? normalizeReaderUid(data.uid) : null;
    if (!uid) throw new ServiceError('VALIDATION', 'uid: errors.form.invalidCardUid');
    return transact((t) => {
      const reservation = t.cardReservations.find((r) => r.id === id);
      if (!reservation) throw new ServiceError('NOT_FOUND', id);
      return issueCard(t, actor, activeStudent(t, reservation), uid, reservation);
    });
  },

  /** Ta'minotchi fayli (raqam ↔ UID): har qator alohida, natija qatorma-qator. */
  async importBindings(input: CardImportInput): Promise<CardImportSummary> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'students.manage');
    const { rows } = parseOrThrow(cardImportSchema, input);
    return transact((t) => {
      const results = rows.map((row) => importRow(t, actor, row.number.replace(/\s/g, ''), row.uid));
      return { bound: results.filter((r) => r.ok).length, results };
    });
  },
};
