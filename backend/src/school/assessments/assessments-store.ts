// Psixologik testlar ma'lumotlari: katalog (shablon + maktab testlari),
// sinflar, faol o'quvchilar soni, natijalar soni. Har so'rov `schoolId`
// bo'yicha (tenant izolyatsiyasi) — mijozdan kelgan ID shu filtrsiz ishlatilmaydi.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { notFound } from '../common/school-errors';
import { isTemplateId, templateTest, TEMPLATE_IDS, toPsychTest } from './psych/catalog';
import type { PsychTest } from './psych/types';
import { ScoredResult, scoreStoredResult } from './results-view';

export type Db = Prisma.TransactionClient | PrismaService;
export type ClassRow = { id: string; name: string; grade: number; letter: string };

@Injectable()
export class AssessmentsStore {
  constructor(private readonly prisma: PrismaService) {}

  /** Barcha testlar: shablonlar (holat qo'llangan) + maktabning o'z / import qilingan testlari. */
  async allTests(schoolId: string, db: Db = this.prisma): Promise<PsychTest[]> {
    const [states, own] = await Promise.all([
      db.schoolPsychTemplateState.findMany({ where: { schoolId } }),
      db.schoolPsychTest.findMany({ where: { schoolId }, orderBy: [{ createdAt: 'asc' }, { id: 'asc' }] }),
    ]);
    const byTemplate = new Map(states.map((s) => [s.templateId, s]));
    return [...TEMPLATE_IDS.map((id) => templateTest(id, byTemplate.get(id))), ...own.map(toPsychTest)];
  }

  async findTest(schoolId: string, id: string, db: Db = this.prisma): Promise<PsychTest | null> {
    if (isTemplateId(id)) {
      const state = await db.schoolPsychTemplateState.findUnique({ where: { schoolId_templateId: { schoolId, templateId: id } } });
      return templateTest(id, state);
    }
    const row = await db.schoolPsychTest.findFirst({ where: { id, schoolId } });
    return row ? toPsychTest(row) : null;
  }

  async requireTest(schoolId: string, id: string, db: Db = this.prisma): Promise<PsychTest> {
    const test = await this.findTest(schoolId, id, db);
    if (!test) throw notFound(id);
    return test;
  }

  /** Test → natijalar soni (barcha o'quvchilar, barcha vaqt). */
  async resultCounts(schoolId: string): Promise<Map<string, number>> {
    const rows = await this.prisma.schoolPsychResult.groupBy({ by: ['testId'], where: { schoolId }, _count: { _all: true } });
    return new Map(rows.map((r) => [r.testId, r._count._all]));
  }

  /** Tayinlash → yakunlaganlar soni. */
  async completedCounts(schoolId: string, assignmentIds?: readonly string[]): Promise<Map<string, number>> {
    const rows = await this.prisma.schoolPsychResult.groupBy({
      by: ['assignmentId'],
      where: { schoolId, assignmentId: assignmentIds ? { in: [...assignmentIds] } : { not: null } },
      _count: { _all: true },
    });
    return new Map(rows.flatMap((r) => (r.assignmentId ? [[r.assignmentId, r._count._all] as const] : [])));
  }

  classes(schoolId: string, db: Db = this.prisma): Promise<ClassRow[]> {
    return db.schoolClass.findMany({ where: { schoolId }, select: { id: true, name: true, grade: true, letter: true } });
  }

  /** Sinf → faol (arxivlanmagan) o'quvchilar soni. */
  async activeStudentCounts(schoolId: string, db: Db = this.prisma): Promise<Map<string, number>> {
    const rows = await db.schoolStudent.groupBy({
      by: ['classId'],
      where: { schoolId, archived: false, classId: { not: null } },
      _count: { _all: true },
    });
    return new Map(rows.flatMap((r) => (r.classId ? [[r.classId, r._count._all] as const] : [])));
  }

  /**
   * Maktab natijalari, o'qishda baholangan (joriy me'yorlar, `takenAt` bo'yicha eskidan
   * yangiga). Javoblar varag'i qaytmaydi. Rivojlanish bo'limi uchun umumiy o'qish nuqtasi —
   * ko'rinish (K=5, darajalar) chaqiruvchida qo'llanadi.
   */
  async scoredResults(schoolId: string, where: Prisma.SchoolPsychResultWhereInput = {}): Promise<ScoredResult[]> {
    const [tests, rows] = await Promise.all([
      this.allTests(schoolId),
      this.prisma.schoolPsychResult.findMany({
        where: { ...where, schoolId },
        orderBy: [{ takenAt: 'asc' }, { id: 'asc' }],
        select: { id: true, studentId: true, classId: true, grade: true, ageBand: true, testId: true, version: true, assignmentId: true, takenAt: true, origin: true, raw: true },
      }),
    ]);
    const byId = new Map(tests.map((t) => [t.id, t]));
    return rows.flatMap((r) => {
      const test = byId.get(r.testId);
      return test ? [scoreStoredResult(test, r)] : [];
    });
  }

  /** Tranzaksiya ichida kalit bo'yicha navbat (parallel yozuvlar bir-birini buzmasin). */
  async lock(tx: Prisma.TransactionClient, key: string): Promise<void> {
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${key}, 0))`;
  }
}
