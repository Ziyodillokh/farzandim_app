import { roleHas } from '@/auth/permissions';
import type { AssignedCard, CardStatus, CardTapLog, CardTapResult, CardTapView, SchoolCard } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { cardAssignSchema, cardBlockSchema, cardTapSchema, normalizeCardUid, type CardAssignInput, type CardBlockInput, type CardTapInput } from '@/data/schemas/cards';
import { parseOrThrow } from '@/data/schemas/validate';
import { hhmmToMinutes, minutesToHhmm } from '@/lib/utils';
import { isSchoolDay } from '../calendar';
import { clockMinute, clockNow, clockToday } from '../clock';
import { type Actor, allowedClassIds, assertCan, assertClassInScope, currentActor, latency, newId, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { studentName } from '../lookups';
import type { MockCard, MockCardTap, Tables } from '../tables';
import { recordArrival } from './attendance';

/**
 * NFC kartalar (demo): backend `cards.service.ts` / `card-tap.service.ts` bilan bir xil qoidalar.
 * Demo'da kartalar faqat seriya raqami (UID) bilan — NTAG 424 DNA imzosi serverda tekshiriladi.
 */
const NUMBER_PREFIX = 'K-';
const MAX_TAPS = 500;
const SUSPICIOUS_WINDOW_MS = 3_000;
const OPEN_BEFORE_MINUTES = 120;
const CLOSE_AFTER_MINUTES = 180;
const REPLACED_REASON = 'REPLACED';

function toView(t: Tables, card: MockCard): SchoolCard {
  const student = t.students.find((s) => s.id === card.studentId);
  const cls = student ? t.classes.find((c) => c.id === student.classId) : undefined;
  return {
    ...card,
    studentName: student ? studentName(student) : '—',
    studentCode: student?.studentCode ?? '',
    classId: student?.classId ?? null,
    className: cls?.name ?? '',
  };
}

function findCard(t: Tables, actor: Actor, id: string): MockCard {
  const card = t.cards.find((c) => c.id === id);
  if (!card) throw new ServiceError('NOT_FOUND', id);
  const student = t.students.find((s) => s.id === card.studentId);
  if (!roleHas(actor.role, 'students.manage')) assertClassInScope(actor, student?.classId ?? '');
  return card;
}

function nextNumber(t: Tables): string {
  const max = t.cards.reduce((n, c) => (c.number.startsWith(NUMBER_PREFIX) ? Math.max(n, Number(c.number.slice(NUMBER_PREFIX.length)) || 0) : n), 0);
  return `${NUMBER_PREFIX}${String(max + 1).padStart(6, '0')}`;
}

function logTap(t: Tables, tap: Omit<MockCardTap, 'id'>): void {
  t.cardTaps.push({ id: newId('tap'), ...tap });
  if (t.cardTaps.length > MAX_TAPS) t.cardTaps.splice(0, t.cardTaps.length - MAX_TAPS);
}

export const cardsService = {
  async list(status?: CardStatus): Promise<SchoolCard[]> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'students.view');
    const t = getTables();
    const allowed = allowedClassIds(actor);
    const visible = t.cards.filter((c) => {
      if (status && c.status !== status) return false;
      if (!allowed) return true;
      const student = t.students.find((s) => s.id === c.studentId);
      return Boolean(student && allowed.includes(student.classId));
    });
    const order: Record<CardStatus, number> = { ACTIVE: 0, LOST: 1, BLOCKED: 2 };
    return visible
      .map((c) => toView(t, c))
      .sort((a, b) => order[a.status] - order[b.status] || b.issuedAt.localeCompare(a.issuedAt) || a.number.localeCompare(b.number));
  },

  /** Biriktirish: o'quvchining faol kartasi «almashtirildi» deb bloklanadi. */
  async assign(input: CardAssignInput): Promise<AssignedCard> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'students.manage');
    const data = parseOrThrow(cardAssignSchema, input);
    const uid = data.uid ? normalizeCardUid(data.uid) : null;
    if (!uid) throw new ServiceError('VALIDATION', 'uid: errors.form.invalidCardUid');
    return transact((t) => {
      const student = t.students.find((s) => s.id === data.studentId && !s.archived);
      if (!student) throw new ServiceError('NOT_FOUND', data.studentId);
      const taken = t.cards.find((c) => c.uid === uid);
      if (taken) throw new ServiceError('CONFLICT', 'card taken', 'CARD_TAKEN');
      const number = data.number ?? nextNumber(t);
      if (t.cards.some((c) => c.number === number)) throw new ServiceError('CONFLICT', 'number taken', 'CARD_NUMBER_TAKEN');
      const now = clockNow().toISOString();
      const previous = t.cards.find((c) => c.studentId === student.id && c.status === 'ACTIVE');
      if (previous) Object.assign(previous, { status: 'BLOCKED', blockedAt: now, blockedReason: REPLACED_REASON });
      const card: MockCard = { id: newId('card'), number, uid, kind: 'UID', status: 'ACTIVE', studentId: student.id, issuedAt: now, lastTapAt: null, blockedAt: null, blockedReason: null };
      t.cards.push(card);
      const name = studentName(student);
      writeAudit(t, actor, 'STUDENTS', 'card.assign', `Karta ${number} biriktirildi: ${name}`, card.id, null, card, { number, name });
      return { ...toView(t, card), replacedNumber: previous?.number ?? null };
    });
  },

  async block(cardId: string, input: CardBlockInput): Promise<SchoolCard> {
    await latency();
    const actor = currentActor();
    if (!roleHas(actor.role, 'students.manage')) assertCan(actor, 'attendance.mark');
    const { reason, note } = parseOrThrow(cardBlockSchema, input);
    return transact((t) => {
      const card = findCard(t, actor, cardId);
      if (card.status === 'ACTIVE') {
        Object.assign(card, { status: reason, blockedAt: clockNow().toISOString(), blockedReason: note || reason });
        const view = toView(t, card);
        writeAudit(t, actor, 'STUDENTS', 'card.block', `Karta ${card.number} bloklandi: ${view.studentName}`, card.id, null, null, { number: card.number, name: view.studentName, reason });
      }
      return toView(t, card);
    });
  },

  async unblock(cardId: string): Promise<SchoolCard> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'students.manage');
    return transact((t) => {
      const card = findCard(t, actor, cardId);
      if (card.status === 'ACTIVE') return toView(t, card);
      if (t.cards.some((c) => c.studentId === card.studentId && c.status === 'ACTIVE')) {
        throw new ServiceError('CONFLICT', 'student has active card', 'CARD_STUDENT_HAS_ACTIVE');
      }
      Object.assign(card, { status: 'ACTIVE', blockedAt: null, blockedReason: null });
      const view = toView(t, card);
      writeAudit(t, actor, 'STUDENTS', 'card.unblock', `Karta ${card.number} qayta faollashtirildi: ${view.studentName}`, card.id, null, null, {
        number: card.number,
        name: view.studentName,
      });
      return view;
    });
  },

  async remove(cardId: string): Promise<void> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'students.manage');
    transact((t) => {
      const card = findCard(t, actor, cardId);
      const view = toView(t, card);
      t.cards = t.cards.filter((c) => c.id !== card.id);
      writeAudit(t, actor, 'STUDENTS', 'card.remove', `Karta ${card.number} o'chirildi: ${view.studentName}`, card.id, null, null, { number: card.number, name: view.studentName });
    });
  },

  async taps(options: { suspicious?: boolean; limit?: number } = {}): Promise<CardTapLog[]> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'students.view');
    const t = getTables();
    const allowed = allowedClassIds(actor);
    return t.cardTaps
      .filter((tap) => options.suspicious === undefined || tap.suspicious === options.suspicious)
      .map((tap) => {
        const student = tap.studentId ? t.students.find((s) => s.id === tap.studentId) : undefined;
        return { tap, student };
      })
      .filter(({ student }) => !allowed || Boolean(student && allowed.includes(student.classId)))
      .sort((a, b) => b.tap.tappedAt.localeCompare(a.tap.tappedAt))
      .slice(0, options.limit ?? 50)
      .map(({ tap, student }) => ({
        id: tap.id,
        tappedAt: tap.tappedAt,
        result: tap.result,
        suspicious: tap.suspicious,
        uid: tap.uid,
        cardNumber: t.cards.find((c) => c.id === tap.cardId)?.number ?? null,
        studentId: tap.studentId,
        studentName: student ? studentName(student) : null,
        className: (student && t.classes.find((c) => c.id === student.classId)?.name) || '',
      }));
  },

  /** Kiosk tegishi: kirish / chiqish (QR qoidasi), noma'lum, bloklangan, dars vaqtidan tashqari, shubhali. */
  async tap(input: CardTapInput): Promise<CardTapView> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'attendance.kiosk');
    const data = parseOrThrow(cardTapSchema, input);
    const uid = data.uid ? normalizeCardUid(data.uid) : null;
    const kioskId = data.kioskId || actor.staffId;
    const now = clockNow();
    const minute = clockMinute();
    const today = clockToday();
    return transact((t) => {
      const base: CardTapView = { result: 'INVALID', time: minutesToHhmm(Math.floor(minute)), suspicious: false, cardNumber: null, student: null, className: '', status: null };
      const done = (view: CardTapView, card?: MockCard) => {
        logTap(t, { tappedAt: now.toISOString(), cardId: card?.id ?? null, studentId: card?.studentId ?? null, uid, result: view.result, suspicious: view.suspicious, kioskId });
        if (card) card.lastTapAt = now.toISOString();
        return view;
      };
      if (!uid) return done(base);
      const card = t.cards.find((c) => c.uid === uid);
      if (!card) return done({ ...base, result: 'UNKNOWN' });
      const student = t.students.find((s) => s.id === card.studentId);
      const cls = student ? t.classes.find((c) => c.id === student.classId) : undefined;
      const shift = cls ? t.shifts.find((s) => s.id === cls.shiftId) : undefined;
      const known: CardTapView = {
        ...base,
        cardNumber: card.number,
        student: student ? { id: student.id, firstName: student.firstName, lastName: student.lastName, studentCode: student.studentCode } : null,
        className: cls?.name ?? '',
      };
      if (card.status !== 'ACTIVE' || !student || student.archived) return done({ ...known, result: 'BLOCKED' }, card);
      const previous = [...t.cardTaps].reverse().find((tap) => tap.kioskId === kioskId && tap.cardId);
      const suspicious = Boolean(previous && previous.cardId !== card.id && now.getTime() - Date.parse(previous.tappedAt) <= SUSPICIOUS_WINDOW_MS);
      const open = shift && isSchoolDay(today, shift, t.holidays);
      if (!shift || !open || minute < hhmmToMinutes(shift.start) - OPEN_BEFORE_MINUTES || minute > hhmmToMinutes(shift.end) + CLOSE_AFTER_MINUTES) {
        return done({ ...known, suspicious, result: 'OUTSIDE' }, card);
      }
      const record = t.attendance.find((r) => r.date === today && r.studentId === student.id);
      let result: CardTapResult = 'NONE';
      let status = record?.status ?? null;
      if (!record?.inAt) {
        status = recordArrival(t, actor.staffId, student, shift, 'CARD', today, minute);
        result = 'IN';
      } else if (!record.outAt && (record.status === 'PRESENT' || record.status === 'LATE') && minute >= hhmmToMinutes(shift.end)) {
        record.outAt = minutesToHhmm(Math.floor(minute));
        t.attendanceEvents.push({ id: `${today}:${student.id}:OUT`, at: now.toISOString(), studentId: student.id, classId: student.classId, kind: 'OUT', source: 'CARD', late: false });
        const guardian = student.guardianIds.map((id) => t.guardians.find((g) => g.id === id)).find((g) => g?.linkStatus === 'LINKED');
        if (guardian) t.parentNotifications.push({ id: newId('ntf'), at: now.toISOString(), studentId: student.id, guardianId: guardian.id, kind: 'LEFT', delivered: true });
        result = 'OUT';
      }
      return done({ ...known, suspicious, result, status }, card);
    });
  },
};
