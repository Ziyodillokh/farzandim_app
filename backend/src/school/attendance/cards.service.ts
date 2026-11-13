// NFC kartalar ro'yxati (panel «Kartalar»): biriktirish, almashtirish, bloklash
// (yo'qolgan karta), qayta faollashtirish va kiosk tegishlari jurnali.
// Ruxsatlar: ko'rish — `students.view` (sinf doirasi bilan); biriktirish —
// `students.manage`; bloklash — `students.manage` yoki `attendance.mark` (sinf rahbari).

import { ConflictException, Injectable } from '@nestjs/common';
import { Prisma, SchoolCard, SchoolCardStatus } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { actorCan, assertCan, assertCanAny, assertClassInScope, classScopeWhere, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { classNames } from './attendance-lookups';
import { AttendanceClock } from './attendance-time';
import { studentName } from './attendance-view';
import { CardKeyService } from './card-keys.service';
import { cardAssignSchema, cardBlockSchema, cardListQuerySchema, cardTapsQuerySchema } from './cards.schemas';

const NUMBER_PREFIX = 'K-';
const NUMBER_DIGITS = 6;
export const REPLACED_REASON = 'REPLACED';

const cardStudentSelect = { id: true, firstName: true, lastName: true, studentCode: true, classId: true } as const;
type CardWithStudent = SchoolCard & { student: Prisma.SchoolStudentGetPayload<{ select: typeof cardStudentSelect }> };

const cardConflict = (code: string, message: string) => new ConflictException({ code, message });

export function toCardView(card: CardWithStudent, classes: Map<string, string>) {
  return {
    id: card.id,
    number: card.number,
    uid: card.uid,
    kind: card.kind,
    status: card.status,
    studentId: card.studentId,
    studentName: studentName(card.student),
    studentCode: card.student.studentCode,
    classId: card.student.classId,
    className: (card.student.classId && classes.get(card.student.classId)) || '',
    issuedAt: card.issuedAt.toISOString(),
    lastTapAt: card.lastTapAt?.toISOString() ?? null,
    blockedAt: card.blockedAt?.toISOString() ?? null,
    blockedReason: card.blockedReason,
  };
}

@Injectable()
export class CardsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
    private readonly clock: AttendanceClock,
    private readonly keys: CardKeyService,
  ) {}

  async list(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'students.view');
    const { status } = parseOrThrow(cardListQuerySchema, query ?? {});
    const cards = await this.prisma.schoolCard.findMany({
      where: { schoolId: actor.schoolId, ...(status && { status }), student: classScopeWhere(actor) },
      include: { student: { select: cardStudentSelect } },
      orderBy: [{ status: 'asc' }, { issuedAt: 'desc' }],
    });
    const classes = await classNames(
      this.prisma,
      actor.schoolId,
      cards.map((c) => c.student.classId),
    );
    return { items: cards.map((c) => toCardView(c, classes)) };
  }

  /**
   * Kartani o'quvchiga biriktirish. O'quvchida faol karta bo'lsa — u «almashtirildi» deb bloklanadi
   * (yo'qolgan kartaning o'rniga yangisi). Bir karta maktabda faqat bitta o'quvchida bo'ladi.
   */
  async assign(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'students.manage');
    const data = parseOrThrow(cardAssignSchema, input);
    const identity = await this.keys.identify(actor.schoolId, data);
    if (!identity) throw cardConflict('CARD_CODE_INVALID', 'Card code failed verification');
    const student = await this.prisma.schoolStudent.findFirst({
      where: { id: data.studentId, schoolId: actor.schoolId, archived: false },
      select: cardStudentSelect,
    });
    if (!student) throw notFound(data.studentId);
    const now = this.clock.now();
    const name = studentName(student);
    const { card, replaced } = await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`school-card:${actor.schoolId}`}, 0))`;
      const taken = await tx.schoolCard.findUnique({
        where: { schoolId_uid: { schoolId: actor.schoolId, uid: identity.uid } },
        include: { student: { select: cardStudentSelect } },
      });
      if (taken) throw cardConflict('CARD_TAKEN', `Card already assigned to ${studentName(taken.student)}`);
      const number = data.number ?? (await this.nextNumber(tx, actor.schoolId));
      if (await tx.schoolCard.findUnique({ where: { schoolId_number: { schoolId: actor.schoolId, number } } })) {
        throw cardConflict('CARD_NUMBER_TAKEN', `Card number ${number} is in use`);
      }
      const previous = await tx.schoolCard.findFirst({ where: { studentId: student.id, status: 'ACTIVE' } });
      if (previous) {
        await tx.schoolCard.update({ where: { id: previous.id }, data: { status: 'BLOCKED', blockedAt: now, blockedReason: REPLACED_REASON } });
      }
      const created = await tx.schoolCard.create({
        data: { schoolId: actor.schoolId, studentId: student.id, uid: identity.uid, kind: identity.kind, number, lastCounter: identity.counter, issuedAt: now },
        include: { student: { select: cardStudentSelect } },
      });
      await this.audit.write(
        actor,
        {
          module: 'STUDENTS',
          action: 'card.assign',
          summary: `Karta ${number} biriktirildi: ${name}${previous ? ` (eski ${previous.number} bloklandi)` : ''}`,
          entityId: created.id,
          params: { number, name, ...(previous && { replaced: previous.number }) },
        },
        tx,
      );
      return { card: created, replaced: previous?.number ?? null };
    });
    const classes = await classNames(this.prisma, actor.schoolId, [student.classId]);
    return { ...toCardView(card, classes), replacedNumber: replaced };
  }

  /** Yo'qolgan yoki bloklangan karta — kiosk uni darhol rad etadi. */
  async block(actor: SchoolActor, id: string, input: unknown) {
    assertCanAny(actor, ['students.manage', 'attendance.mark']);
    const { reason, note } = parseOrThrow(cardBlockSchema, input);
    const card = await this.findInScope(actor, id);
    if (card.status !== 'ACTIVE') return this.view(actor, card);
    const status: SchoolCardStatus = reason;
    const updated = await this.prisma.$transaction(async (tx) => {
      const saved = await tx.schoolCard.update({
        where: { id: card.id },
        data: { status, blockedAt: this.clock.now(), blockedReason: note || reason },
        include: { student: { select: cardStudentSelect } },
      });
      await this.audit.write(
        actor,
        {
          module: 'STUDENTS',
          action: 'card.block',
          summary: `Karta ${card.number} ${reason === 'LOST' ? "yo'qolgan deb bloklandi" : 'bloklandi'}: ${studentName(card.student)}`,
          entityId: card.id,
          params: { number: card.number, name: studentName(card.student), reason },
        },
        tx,
      );
      return saved;
    });
    return this.view(actor, updated);
  }

  /** Topilgan kartani qayta faollashtirish — o'quvchida boshqa faol karta bo'lmasa. */
  async unblock(actor: SchoolActor, id: string) {
    assertCan(actor, 'students.manage');
    const card = await this.findInScope(actor, id);
    if (card.status === 'ACTIVE') return this.view(actor, card);
    const active = await this.prisma.schoolCard.count({ where: { studentId: card.studentId, status: 'ACTIVE' } });
    if (active > 0) throw cardConflict('CARD_STUDENT_HAS_ACTIVE', 'Student already has an active card');
    const updated = await this.prisma.$transaction(async (tx) => {
      const saved = await tx.schoolCard.update({
        where: { id: card.id },
        data: { status: 'ACTIVE', blockedAt: null, blockedReason: null },
        include: { student: { select: cardStudentSelect } },
      });
      await this.audit.write(
        actor,
        {
          module: 'STUDENTS',
          action: 'card.unblock',
          summary: `Karta ${card.number} qayta faollashtirildi: ${studentName(card.student)}`,
          entityId: card.id,
          params: { number: card.number, name: studentName(card.student) },
        },
        tx,
      );
      return saved;
    });
    return this.view(actor, updated);
  }

  /** Xato biriktirilgan kartani o'chirish (tegishlar jurnalda qoladi). */
  async remove(actor: SchoolActor, id: string): Promise<void> {
    assertCan(actor, 'students.manage');
    const card = await this.findInScope(actor, id);
    await this.prisma.$transaction(async (tx) => {
      await tx.schoolCard.delete({ where: { id: card.id } });
      await this.audit.write(
        actor,
        {
          module: 'STUDENTS',
          action: 'card.remove',
          summary: `Karta ${card.number} o'chirildi: ${studentName(card.student)}`,
          entityId: card.id,
          params: { number: card.number, name: studentName(card.student) },
        },
        tx,
      );
    });
  }

  /** Kiosk tegishlari (eng yangisi birinchi); `suspicious=true` — faqat shubhalilar. */
  async taps(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'students.view');
    const { suspicious, limit } = parseOrThrow(cardTapsQuerySchema, query ?? {});
    const scope = classScopeWhere(actor);
    const scopedIds = scope.classId
      ? (await this.prisma.schoolStudent.findMany({ where: { schoolId: actor.schoolId, ...scope }, select: { id: true } })).map((s) => s.id)
      : null;
    const rows = await this.prisma.schoolCardTap.findMany({
      where: {
        schoolId: actor.schoolId,
        ...(suspicious && { suspicious: suspicious === 'true' }),
        ...(scopedIds && { studentId: { in: scopedIds } }),
      },
      orderBy: { tappedAt: 'desc' },
      take: limit,
    });
    const studentIds = [...new Set(rows.map((r) => r.studentId).filter((v): v is string => Boolean(v)))];
    const cardIds = [...new Set(rows.map((r) => r.cardId).filter((v): v is string => Boolean(v)))];
    const [students, cards] = await Promise.all([
      this.prisma.schoolStudent.findMany({ where: { id: { in: studentIds } }, select: cardStudentSelect }),
      this.prisma.schoolCard.findMany({ where: { id: { in: cardIds } }, select: { id: true, number: true } }),
    ]);
    const byStudent = new Map(students.map((s) => [s.id, s]));
    const numbers = new Map(cards.map((c) => [c.id, c.number]));
    const classes = await classNames(
      this.prisma,
      actor.schoolId,
      students.map((s) => s.classId),
    );
    return {
      items: rows.map((r) => {
        const student = r.studentId ? byStudent.get(r.studentId) : undefined;
        return {
          id: r.id,
          tappedAt: r.tappedAt.toISOString(),
          result: r.result,
          suspicious: r.suspicious,
          uid: r.uid,
          cardNumber: (r.cardId && numbers.get(r.cardId)) || null,
          studentId: r.studentId,
          studentName: student ? studentName(student) : null,
          className: (student?.classId && classes.get(student.classId)) || '',
        };
      }),
    };
  }

  private async findInScope(actor: SchoolActor, id: string): Promise<CardWithStudent> {
    const card = await this.prisma.schoolCard.findFirst({
      where: { id, schoolId: actor.schoolId },
      include: { student: { select: cardStudentSelect } },
    });
    if (!card) throw notFound(id);
    if (!actorCan(actor, 'students.manage')) assertClassInScope(actor, card.student.classId);
    return card;
  }

  private async view(actor: SchoolActor, card: CardWithStudent) {
    const classes = await classNames(this.prisma, actor.schoolId, [card.student.classId]);
    return toCardView(card, classes);
  }

  /** Keyingi `K-000001` (maktab ichida, biriktirish qulfi ostida). */
  private async nextNumber(tx: Prisma.TransactionClient, schoolId: string): Promise<string> {
    const last = await tx.schoolCard.findFirst({
      where: { schoolId, number: { startsWith: NUMBER_PREFIX } },
      orderBy: { number: 'desc' },
      select: { number: true },
    });
    const n = last ? Number(last.number.slice(NUMBER_PREFIX.length)) || 0 : 0;
    return `${NUMBER_PREFIX}${String(n + 1).padStart(NUMBER_DIGITS, '0')}`;
  }
}
