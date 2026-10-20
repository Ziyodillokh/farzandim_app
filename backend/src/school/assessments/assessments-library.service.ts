// Testlar kutubxonasi (o'qish): ro'yxat, ko'rinish, JSON eksport, sinflar.
// FAQAT psixolog (`assessments.manage`).

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { compareClasses } from '../common/list-query';
import { parseOrThrow } from '../common/school-zod';
import { testFilterSchema } from './assessments-inputs.schemas';
import { AssessmentsStore } from './assessments-store';
import { activeByTest, matchesTestFilter, PsychTestDetail, PsychTestRow, RowsContext, toTestRow } from './assessments-view';
import { PSYCH_EXPORT_FORMAT, PSYCH_EXPORT_VERSION, psychTestInputSchema } from './assessments.schemas';
import { isTemplateId, portableTest } from './psych/catalog';
import { PSYCH_TEMPLATES } from './psych/templates';

export type ClassOption = { id: string; name: string; grade: number; size: number };

@Injectable()
export class AssessmentsLibraryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly store: AssessmentsStore,
  ) {}

  async listTests(actor: SchoolActor, query: unknown): Promise<PsychTestRow[]> {
    assertCan(actor, 'assessments.manage');
    const filter = parseOrThrow(testFilterSchema, query ?? {});
    const [tests, ctx] = await Promise.all([this.store.allTests(actor.schoolId), this.rowsContext(actor.schoolId)]);
    return tests.filter((t) => matchesTestFilter(t, filter)).map((t) => toTestRow(t, ctx));
  }

  async getTest(actor: SchoolActor, id: string): Promise<PsychTestDetail> {
    assertCan(actor, 'assessments.manage');
    const test = await this.store.requireTest(actor.schoolId, id);
    const template = isTemplateId(id);
    const state = template
      ? await this.prisma.schoolPsychTemplateState.findUnique({ where: { schoolId_templateId: { schoolId: actor.schoolId, templateId: id } } })
      : null;
    return {
      ...toTestRow(test, await this.rowsContext(actor.schoolId)),
      readOnly: template || test.source === 'EXTERNAL' || test.status === 'ARCHIVED',
      normsOverridden: template && state?.norms !== null && state?.norms !== undefined,
      defaultNorms: template ? PSYCH_TEMPLATES[id].norms : null,
    };
  }

  /** JSON fayl konverti (panel uni 2 bo'shliqli matnga aylantirib yuklab beradi). */
  async exportTest(actor: SchoolActor, id: string) {
    assertCan(actor, 'assessments.manage');
    const test = await this.store.requireTest(actor.schoolId, id);
    const portable = portableTest(test);
    // Sxema orqali — kalitlar panel tartibida (JSONB tartibni o'zgartiradi).
    const normalized = psychTestInputSchema.safeParse(portable);
    return {
      format: PSYCH_EXPORT_FORMAT,
      formatVersion: PSYCH_EXPORT_VERSION,
      exportedAt: new Date().toISOString(),
      test: normalized.success ? normalized.data : portable,
    };
  }

  /** Tayinlash va filtrlar uchun sinflar (psixologda `classes.view` yo'q). */
  async classOptions(actor: SchoolActor): Promise<ClassOption[]> {
    assertCan(actor, 'assessments.manage');
    const [classes, sizes] = await Promise.all([this.store.classes(actor.schoolId), this.store.activeStudentCounts(actor.schoolId)]);
    return [...classes].sort(compareClasses).map((c) => ({ id: c.id, name: c.name, grade: c.grade, size: sizes.get(c.id) ?? 0 }));
  }

  private async rowsContext(schoolId: string): Promise<RowsContext> {
    const [assignments, results] = await Promise.all([
      this.prisma.schoolPsychAssignment.findMany({
        where: { schoolId, status: 'OPEN' },
        select: { testId: true, status: true, opensAt: true, closesAt: true },
      }),
      this.store.resultCounts(schoolId),
    ]);
    return { active: activeByTest(assignments, Date.now()), results };
  }
}
