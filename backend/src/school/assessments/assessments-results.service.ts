// Test natijalari (har o'quvchining eng so'nggisi). Ko'rinish serverda:
// psixolog (`assessments.manage`) — xom ball, standart ball, persentil, javoblar
// varag'i va vaqt; sinf rahbari (`development.individual`) — FAQAT o'z sinfi va
// FAQAT darajalar; direktor / admin / navbatchi — FORBIDDEN (ularga faqat
// rivojlanish bo'limidagi K=5 agregatlar).

import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { actorCan, allowedClassIds, assertCan, assertClassInScope, SchoolActor } from '../auth/school-actor';
import { SchoolCryptoService } from '../common/school-crypto.service';
import { parseOrThrow } from '../common/school-zod';
import { ResultsFilter, resultsFilterSchema } from './assessments-inputs.schemas';
import { AssessmentsStore, ClassRow } from './assessments-store';
import type { PsychTest } from './psych/types';
import { buildDistribution, distributionScale, latestPerStudent, ResultsByTest, StoredResult, toResultRow } from './results-view';

const RESULT_SELECT = {
  id: true,
  studentId: true,
  classId: true,
  takenAt: true,
  origin: true,
  assignmentId: true,
  ageBand: true,
  raw: true,
  durationSec: true,
  answersEnc: true,
} as const;

@Injectable()
export class AssessmentsResultsService {
  private readonly logger = new Logger(AssessmentsResultsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly store: AssessmentsStore,
    private readonly crypto: SchoolCryptoService,
  ) {}

  async resultsByTest(actor: SchoolActor, testId: string, query: unknown): Promise<ResultsByTest> {
    const bandsOnly = this.bandsOnly(actor);
    const filter = parseOrThrow(resultsFilterSchema, query ?? {});
    if (filter.classId) assertClassInScope(actor, filter.classId);
    const test = await this.store.requireTest(actor.schoolId, testId);
    const allowed = allowedClassIds(actor);
    const classWhere = filter.classId ? { classId: filter.classId } : allowed ? { classId: { in: allowed } } : {};
    const stored: StoredResult[] = await this.prisma.schoolPsychResult.findMany({
      where: { schoolId: actor.schoolId, testId, ...(filter.assignmentId && { assignmentId: filter.assignmentId }), ...classWhere },
      orderBy: [{ takenAt: 'asc' }, { id: 'asc' }],
      select: RESULT_SELECT,
    });
    const latest = latestPerStudent(stored);
    const [students, classes] = await Promise.all([
      this.prisma.schoolStudent.findMany({
        where: { schoolId: actor.schoolId, id: { in: latest.map((r) => r.studentId) } },
        select: { id: true, lastName: true, firstName: true },
      }),
      this.store.classes(actor.schoolId),
    ]);
    const lookups = {
      names: new Map(students.map((s) => [s.id, `${s.lastName} ${s.firstName}`])),
      classNames: new Map(classes.map((c) => [c.id, c.name])),
    };
    const rows = latest.map((r) => toResultRow(test, r, bandsOnly, lookups, bandsOnly ? undefined : this.answersOf(r)));
    const scaleKey = distributionScale(test, filter.scale);
    return {
      rows,
      distribution: buildDistribution(test, rows, scaleKey),
      scaleKey,
      needsNorms: scaleKey !== null && !(test.norms[scaleKey]?.length),
      participation: await this.participation(actor, test, filter, classes, rows.length),
      bandsOnly,
    };
  }

  /** Psixolog — to'liq; aks holda `development.individual` (sinf rahbari) — faqat darajalar. */
  private bandsOnly(actor: SchoolActor): boolean {
    if (actorCan(actor, 'assessments.manage')) return false;
    assertCan(actor, 'development.individual');
    return true;
  }

  /** Taklif qilinganlar: tayinlash sinflari (yoki test parallellari) ∩ filtr ∩ xodim doirasi. */
  private async participation(actor: SchoolActor, test: PsychTest, f: ResultsFilter, classes: readonly ClassRow[], completed: number) {
    const a = f.assignmentId
      ? await this.prisma.schoolPsychAssignment.findFirst({ where: { id: f.assignmentId, schoolId: actor.schoolId }, select: { classIds: true } })
      : null;
    const allowed = allowedClassIds(actor);
    const classIds = classes
      .filter((c) => (a ? a.classIds.includes(c.id) : test.grades.includes(c.grade)))
      .filter((c) => (!f.classId || c.id === f.classId) && (!allowed || allowed.includes(c.id)))
      .map((c) => c.id);
    const invited = await this.prisma.schoolStudent.count({ where: { schoolId: actor.schoolId, archived: false, classId: { in: classIds } } });
    return { invited, completed };
  }

  /** Javoblar varag'i (ixcham kod) — faqat psixolog uchun ochiladi. */
  private answersOf(r: StoredResult): string | undefined {
    if (!r.answersEnc) return undefined;
    try {
      return this.crypto.decrypt(r.answersEnc);
    } catch (err) {
      this.logger.warn(`psych result ${r.id}: answers could not be decrypted (${(err as Error).message})`);
      return undefined;
    }
  }
}
