// Natijalarni CSV'dan import (masalan, qog'ozda o'tkazilgan testlar): oldindan
// ko'rish (bazani o'zgartirmaydi) va import — faqat OK qatorlar yoziladi,
// noma'lum test nomi uchun tashqi (EXTERNAL) test bir marta yaratiladi.
// FAQAT psixolog. Auditda faqat sonlar.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { addDays, tashkentDay, tashkentDayStart } from '../../common/time/tashkent';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { parseOrThrow } from '../common/school-zod';
import { csvBodySchema, toInstant } from './assessments-inputs.schemas';
import { AssessmentsStore, Db } from './assessments-store';
import { CsvContext, CsvFile, CsvImportResult, CsvPreview, HISTORY_DAYS, PlannedRow, planRows, readCsvFile, toPreview } from './csv-preview';
import { definitionOf, toPsychTest } from './psych/catalog';
import { ageBandOf, ageOn } from './psych/scoring';
import type { PsychTest, PsychTestInputShape } from './psych/types';

type Tx = Prisma.TransactionClient;

/** Import qilingan natija vaqti — shu kuni 09:00 (Toshkent). */
const IMPORT_TIME = 'T09:00:00';
const ALL_GRADES = Array.from({ length: 11 }, (_, i) => i + 1);

/** Tashqi test: bitta `total` shkala, me'yorlarsiz (UI me'yor kiritishni taklif qiladi). */
function externalDefinition(name: string): PsychTestInputShape {
  return {
    title: { uz: name, ru: name },
    description: { uz: '', ru: '' },
    instructions: { uz: '', ru: '' },
    kind: 'CUSTOM',
    grades: ALL_GRADES,
    timeLimitMin: null,
    scales: [{ key: 'total', label: { uz: 'Umumiy ball', ru: 'Общий балл' }, domain: 'REASONING', polarity: 'HIGHER_BETTER', display: 'STANDARD' }],
    items: [],
    scoring: { method: 'SUM' },
    norms: {},
  };
}

/** OK qator → natija (xom ball; yosh bandi — test kunidagi yosh bo'yicha). */
function importedResult(
  schoolId: string,
  p: PlannedRow,
  test: PsychTest,
  grades: ReadonlyMap<string, number>,
): Prisma.SchoolPsychResultCreateManyInput {
  const student = p.student as NonNullable<PlannedRow['student']>;
  const date = p.row.date as string;
  return {
    schoolId,
    studentId: student.id,
    classId: student.classId,
    grade: (student.classId && grades.get(student.classId)) || 0,
    ageBand: ageBandOf(ageOn(student.birthDate, date)),
    testId: test.id,
    version: test.version,
    assignmentId: null,
    takenAt: toInstant(`${date}${IMPORT_TIME}`),
    origin: 'IMPORT',
    raw: p.row.raw,
  };
}

@Injectable()
export class AssessmentsCsvService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly store: AssessmentsStore,
    private readonly audit: SchoolAuditService,
  ) {}

  async previewResultsCsv(actor: SchoolActor, body: unknown): Promise<CsvPreview> {
    assertCan(actor, 'assessments.manage');
    const file = readCsvFile(parseOrThrow(csvBodySchema, body ?? {}).text);
    const { ctx } = await this.context(actor.schoolId, file, this.prisma);
    return toPreview(planRows(ctx, file));
  }

  async importResultsCsv(actor: SchoolActor, body: unknown): Promise<CsvImportResult> {
    assertCan(actor, 'assessments.manage');
    const file = readCsvFile(parseOrThrow(csvBodySchema, body ?? {}).text);
    return this.prisma.$transaction(async (tx) => {
      // Bir maktabda bir vaqtda bitta import: tashqi test ikki marta yaratilmasin.
      await this.store.lock(tx, `psych-csv:${actor.schoolId}`);
      const { ctx, grades } = await this.context(actor.schoolId, file, tx);
      const planned = planRows(ctx, file);
      const created = new Map<string, PsychTest>();
      const fresh: Prisma.SchoolPsychResultCreateManyInput[] = [];
      for (const p of planned) {
        if (p.row.status !== 'OK' || !p.student || !p.row.date) continue;
        const lower = p.row.test.toLowerCase();
        const test = p.test ?? created.get(lower) ?? (await this.createExternal(tx, actor, p.row.test));
        if (!p.test) created.set(lower, test);
        fresh.push(importedResult(actor.schoolId, p, test, grades));
      }
      if (fresh.length) await tx.schoolPsychResult.createMany({ data: fresh });
      if (created.size) {
        await this.write(tx, actor, 'assessments.test.external', `Tashqi testlar qo'shildi: ${created.size}`, created.size);
      }
      await this.write(tx, actor, 'assessments.results.import', `Natijalar CSV'dan import qilindi: ${fresh.length}`, fresh.length);
      const skipped = planned.filter((p) => p.row.status !== 'OK').map((p) => ({ line: p.row.line, reason: p.row.reason ?? 'BAD_RAW' }));
      return { created: fresh.length, skipped };
    });
  }

  /** Faoldagi o'quvchilar, testlar va fayldagi o'quvchilarning mavjud natijalari (dublikat uchun). */
  private async context(schoolId: string, file: CsvFile, db: Db): Promise<{ ctx: CsvContext; grades: ReadonlyMap<string, number> }> {
    const today = tashkentDay();
    const codes = [...new Set(file.data.map((cells) => (cells[0] ?? '').trim().toUpperCase()).filter(Boolean))];
    const [students, classes, tests] = await Promise.all([
      db.schoolStudent.findMany({
        where: { schoolId, archived: false },
        select: { id: true, studentCode: true, lastName: true, firstName: true, classId: true, birthDate: true },
      }),
      this.store.classes(schoolId, db),
      this.store.allTests(schoolId, db),
    ]);
    const byCode = new Map(students.map((s) => [s.studentCode.toUpperCase(), s]));
    const ids = codes.flatMap((c) => byCode.get(c)?.id ?? []);
    const results = await db.schoolPsychResult.findMany({
      where: { schoolId, studentId: { in: ids }, takenAt: { gte: tashkentDayStart(addDays(today, -HISTORY_DAYS - 1)) } },
      select: { studentId: true, testId: true, takenAt: true },
    });
    const ctx: CsvContext = {
      today,
      existing: new Set(results.map((r) => `${r.studentId}|${r.testId}|${tashkentDay(r.takenAt)}`)),
      students: byCode,
      classNames: new Map(classes.map((c) => [c.id, c.name])),
      tests,
    };
    return { ctx, grades: new Map(classes.map((c) => [c.id, c.grade])) };
  }

  private async createExternal(tx: Tx, actor: SchoolActor, name: string): Promise<PsychTest> {
    const row = await tx.schoolPsychTest.create({
      data: {
        schoolId: actor.schoolId,
        definition: definitionOf(externalDefinition(name), 'EXTERNAL') as Prisma.InputJsonValue,
        version: 1,
        status: 'PUBLISHED',
        createdBy: actor.staffId,
        basedOn: null,
      },
    });
    return toPsychTest(row);
  }

  private write(tx: Tx, actor: SchoolActor, action: string, summary: string, count: number): Promise<void> {
    return this.audit.write(actor, { module: 'ASSESSMENTS', action, summary, params: { count } }, tx);
  }
}
