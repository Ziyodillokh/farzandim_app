// Karta partiyasi — kartalar maktabga tayyor holda beriladi:
// 1) tanlangan sinflardagi kartasiz o'quvchilarga 10 xonali raqam ajratiladi (bosmaxona ro'yxati);
// 2) chop etilgan kartalarning chipi ketma-ket tegizib yoki ta'minotchi fayli (raqam ↔ UID) bilan
//    bir yo'la bog'lanadi. Bog'langach oddiy karta (`CardsService.issue`) bo'ladi.
// Ruxsat: `students.manage`.

import { HttpException, Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { classNames } from './attendance-lookups';
import { studentName } from './attendance-view';
import { CardKeyService } from './card-keys.service';
import { normalizeUid } from './card-sun';
import { cardBindSchema, cardImportSchema, cardReserveSchema } from './cards.schemas';
import { cardConflict, CardsService, cardStudentSelect, freshCardNumbers } from './cards.service';

const reservationInclude = { student: { select: { ...cardStudentSelect, archived: true } } } as const;
type ReservationRow = Prisma.SchoolCardReservationGetPayload<{ include: typeof reservationInclude }>;

export type CardImportResult = { number: string; ok: boolean; code: string | null };

function toReservationView(row: ReservationRow, classes: Map<string, string>) {
  return {
    id: row.id,
    number: row.number,
    studentId: row.studentId,
    studentName: studentName(row.student),
    studentCode: row.student.studentCode,
    classId: row.student.classId,
    className: (row.student.classId && classes.get(row.student.classId)) || '',
    createdAt: row.createdAt,
  };
}
type ReservationView = ReturnType<typeof toReservationView>;

/** Bosmaxona tartibi: sinf (raqamli tartibda), keyin familiya va ism. */
const printOrder = (a: ReservationView, b: ReservationView) =>
  a.className.localeCompare(b.className, 'uz', { numeric: true }) || a.studentName.localeCompare(b.studentName, 'uz');

/** Xato kodi (409 `{ code }`) yoki umumiy `ERROR`. */
function errorCode(error: unknown): string {
  if (error instanceof HttpException) {
    const body = error.getResponse();
    if (typeof body === 'object' && body && 'code' in body && typeof body.code === 'string') return body.code;
  }
  return 'ERROR';
}

@Injectable()
export class CardReservationsService {
  private readonly logger = new Logger(CardReservationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly keys: CardKeyService,
    private readonly cards: CardsService,
    private readonly audit: SchoolAuditService,
  ) {}

  /** Chop etish navbati: raqam ajratilgan, hali chip bog'lanmagan o'quvchilar. */
  async list(actor: SchoolActor) {
    assertCan(actor, 'students.manage');
    const rows = await this.prisma.schoolCardReservation.findMany({ where: { schoolId: actor.schoolId }, include: reservationInclude });
    const classes = await classNames(
      this.prisma,
      actor.schoolId,
      rows.map((r) => r.student.classId),
    );
    return { items: rows.map((r) => toReservationView(r, classes)).sort(printOrder) };
  }

  /** Tanlangan sinflardagi faol kartasi va raqami yo'q o'quvchilarga raqam ajratish. */
  async reserve(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'students.manage');
    const { classIds } = parseOrThrow(cardReserveSchema, input);
    const created = await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`school-card:${actor.schoolId}`}, 0))`;
      const students = await tx.schoolStudent.findMany({
        where: { schoolId: actor.schoolId, archived: false, classId: { in: classIds }, cardReservation: null, cards: { none: { status: 'ACTIVE' } } },
        select: { id: true },
      });
      if (students.length === 0) return 0;
      const numbers = await freshCardNumbers(tx, students.length);
      await tx.schoolCardReservation.createMany({
        data: students.map((s, i) => ({ schoolId: actor.schoolId, studentId: s.id, number: numbers[i] })),
      });
      await this.audit.write(
        actor,
        { module: 'STUDENTS', action: 'card.reserve', summary: `${students.length} ta o'quvchiga karta raqami ajratildi`, params: { count: students.length } },
        tx,
      );
      return students.length;
    });
    return { created, ...(await this.list(actor)) };
  }

  /** Ajratilgan raqamni bekor qilish (masalan, o'quvchi ketdi). */
  async cancel(actor: SchoolActor, id: string): Promise<void> {
    assertCan(actor, 'students.manage');
    const { count } = await this.prisma.schoolCardReservation.deleteMany({ where: { id, schoolId: actor.schoolId } });
    if (count === 0) throw notFound(id);
  }

  /** Ketma-ket biriktirish: chop etilgan kartaning chipi shu raqamga bog'lanadi. */
  async bind(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'students.manage');
    const data = parseOrThrow(cardBindSchema, input);
    const row = await this.prisma.schoolCardReservation.findFirst({ where: { id, schoolId: actor.schoolId }, include: reservationInclude });
    if (!row) throw notFound(id);
    if (row.student.archived) throw cardConflict('STUDENT_ARCHIVED', 'Student is archived');
    const identity = await this.keys.identify(actor.schoolId, data);
    if (!identity) throw cardConflict('CARD_CODE_INVALID', 'Card code failed verification');
    return this.cards.issue(actor, row.student, identity, { id: row.id, number: row.number });
  }

  /** Ta'minotchi fayli (kartaga bosilgan raqam ↔ chip UID): har qator alohida, natija qatorma-qator. */
  async importBindings(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'students.manage');
    const { rows } = parseOrThrow(cardImportSchema, input);
    const results: CardImportResult[] = [];
    for (const row of rows) results.push(await this.importRow(actor, row.number.replace(/\s/g, ''), row.uid));
    return { bound: results.filter((r) => r.ok).length, results };
  }

  private async importRow(actor: SchoolActor, number: string, rawUid: string): Promise<CardImportResult> {
    const uid = normalizeUid(rawUid);
    if (!uid) return { number, ok: false, code: 'INVALID_UID' };
    const row = await this.prisma.schoolCardReservation.findFirst({ where: { schoolId: actor.schoolId, number }, include: reservationInclude });
    if (!row) return { number, ok: false, code: 'RESERVATION_NOT_FOUND' };
    if (row.student.archived) return { number, ok: false, code: 'STUDENT_ARCHIVED' };
    try {
      await this.cards.issue(actor, row.student, { uid, kind: 'UID', counter: null }, { id: row.id, number: row.number });
      return { number, ok: true, code: null };
    } catch (error) {
      if (!(error instanceof HttpException)) this.logger.error(`card import row ${number} failed`, error instanceof Error ? error.stack : String(error));
      return { number, ok: false, code: errorCode(error) };
    }
  }
}
