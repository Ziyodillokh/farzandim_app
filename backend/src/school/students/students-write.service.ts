// O'quvchini qo'shish / tahrirlash / arxivlash va CSV import. Sinf
// almashganda bugungi va ochiq yozuvlar yangi sinfga ko'chadi (doira
// tekshiruvlari shu ustunni o'qiydi); o'tgan kunlar tarixi eski sinfda qoladi.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { randomInt } from 'node:crypto';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, invalid, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { duplicateKey, normalizeClassName, parseImportRows } from './student-import';
import { studentName, toStudentView } from './student-view';
import {
  importRowsSchema,
  StudentCreate,
  studentCreateSchema,
  studentInputSchema,
} from './students.schemas';

type Tx = Prisma.TransactionClient;

const guardianIdsInclude = {
  guardians: { select: { guardian: { select: { id: true } } }, orderBy: { guardian: { createdAt: 'asc' } } },
} satisfies Prisma.SchoolStudentInclude;

/** Import bitta tranzaksiyada shuncha o'quvchidan yoziladi. */
const IMPORT_CHUNK = 200;
const STUDENT_CODE_SPACE = 9000;

@Injectable()
export class StudentsWriteService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  async create(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'students.manage');
    const data = parseOrThrow(studentCreateSchema, input);
    return this.prisma.$transaction(async (tx) => {
      await this.assertClass(tx, actor, data.classId);
      const codes = await this.takenCodes(tx, actor.schoolId);
      const student = await this.insert(tx, actor, data, codes);
      const view = toStudentView(student);
      await this.audit.write(
        actor,
        {
          module: 'STUDENTS',
          action: 'student.create',
          summary: `${studentName(student)} qo'shildi`,
          entityId: student.id,
          after: view,
          params: { name: studentName(student) },
        },
        tx,
      );
      return view;
    });
  }

  async update(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'students.manage');
    const data = parseOrThrow(studentInputSchema, input);
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.schoolStudent.findFirst({
        where: { id, schoolId: actor.schoolId },
        include: guardianIdsInclude,
      });
      if (!before) throw notFound(id);
      await this.assertClass(tx, actor, data.classId);
      const next = await tx.schoolStudent.update({ where: { id }, data, include: guardianIdsInclude });
      if (before.classId !== next.classId) await moveOpenItems(tx, id, data.classId);
      const name = studentName(next);
      await this.audit.write(
        actor,
        {
          module: 'STUDENTS',
          action: 'student.update',
          summary: `${name} ma'lumotlari yangilandi`,
          entityId: id,
          before: toStudentView(before),
          after: toStudentView(next),
          params: { name },
        },
        tx,
      );
      return toStudentView(next);
    });
  }

  async setArchived(actor: SchoolActor, id: string, archived: unknown) {
    assertCan(actor, 'students.manage');
    if (typeof archived !== 'boolean') throw invalid('archived: errors.form.required');
    return this.prisma.$transaction(async (tx) => {
      const found = await tx.schoolStudent.findFirst({ where: { id, schoolId: actor.schoolId } });
      if (!found) throw notFound(id);
      const student = await tx.schoolStudent.update({
        where: { id },
        data: { archived, archivedAt: archived ? new Date() : null },
        include: guardianIdsInclude,
      });
      const name = studentName(student);
      await this.audit.write(
        actor,
        {
          module: 'STUDENTS',
          action: archived ? 'student.archive' : 'student.restore',
          summary: `${name} ${archived ? 'arxivga olindi' : 'qayta tiklandi'}`,
          entityId: id,
          params: { name },
        },
        tx,
      );
      return toStudentView(student);
    });
  }

  /** CSV import: yaroqli qatorlar qo'shiladi, qolganlari sababi bilan qaytadi. */
  async importRows(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'students.manage');
    const { rows } = parseOrThrow(importRowsSchema, input);
    const [classes, existing] = await Promise.all([
      this.prisma.schoolClass.findMany({ where: { schoolId: actor.schoolId }, select: { id: true, name: true } }),
      this.prisma.schoolStudent.findMany({
        where: { schoolId: actor.schoolId, archived: false },
        select: { lastName: true, firstName: true, birthDate: true },
      }),
    ]);
    const classIdByName = new Map(classes.map((c) => [normalizeClassName(c.name), c.id]));
    const { candidates, skipped } = parseImportRows(rows, classIdByName, new Set(existing.map(duplicateKey)));
    for (let i = 0; i < candidates.length; i += IMPORT_CHUNK) {
      const chunk = candidates.slice(i, i + IMPORT_CHUNK);
      await this.prisma.$transaction(
        async (tx) => {
          const codes = await this.takenCodes(tx, actor.schoolId);
          for (const c of chunk) await this.insert(tx, actor, c.data, codes);
        },
        { timeout: 60_000 },
      );
    }
    const created = candidates.length;
    await this.audit.write(actor, {
      module: 'STUDENTS',
      action: 'student.import',
      summary: `CSV import: ${created} ta o'quvchi qo'shildi, ${skipped.length} ta qator o'tkazib yuborildi`,
      params: { created, skipped: skipped.length },
    });
    return { created, skipped };
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  private async assertClass(tx: Tx, actor: SchoolActor, classId: string): Promise<void> {
    const found = await tx.schoolClass.findFirst({ where: { id: classId, schoolId: actor.schoolId } });
    if (!found) throw invalid('classId: errors.form.required');
  }

  private async takenCodes(tx: Tx, schoolId: string): Promise<Set<string>> {
    const rows = await tx.schoolStudent.findMany({ where: { schoolId }, select: { studentCode: true } });
    return new Set(rows.map((r) => r.studentCode));
  }

  private async insert(tx: Tx, actor: SchoolActor, data: StudentCreate, codes: Set<string>) {
    const { guardian, ...fields } = data;
    const studentCode = newStudentCode(codes);
    codes.add(studentCode);
    return tx.schoolStudent.create({
      data: {
        ...fields,
        schoolId: actor.schoolId,
        studentCode,
        enrolledAt: tashkentDay(),
        ...(guardian && {
          guardians: { create: [{ guardian: { create: { ...guardian, schoolId: actor.schoolId } } }] },
        }),
      },
      include: guardianIdsInclude,
    });
  }
}

/** Kiosk / QR uchun qisqa kod "P-4821" (maktab ichida yagona). */
function newStudentCode(taken: ReadonlySet<string>): string {
  if (taken.size >= STUDENT_CODE_SPACE) throw conflict('student codes exhausted');
  for (;;) {
    const code = `P-${1000 + randomInt(STUDENT_CODE_SPACE)}`;
    if (!taken.has(code)) return code;
  }
}

/** Sinf almashganda: bugungi / ochiq yozuvlar yangi sinfga o'tadi. */
async function moveOpenItems(tx: Tx, studentId: string, classId: string): Promise<void> {
  const today = tashkentDay();
  const now = new Date();
  const data = { classId };
  await Promise.all([
    tx.schoolAttendance.updateMany({ where: { studentId, date: { gte: today } }, data }),
    tx.schoolAttendanceEvent.updateMany({ where: { studentId, date: { gte: today } }, data }),
    tx.schoolEarlyExit.updateMany({
      where: { studentId, OR: [{ status: 'PENDING' }, { date: { gte: today } }] },
      data,
    }),
    tx.schoolModeException.updateMany({ where: { studentId, revokedAt: null, until: { gt: now } }, data }),
    tx.schoolCareRequest.updateMany({ where: { studentId, status: { not: 'RESOLVED' } }, data }),
  ]);
}
