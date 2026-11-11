// Tayinlashlar: sinflar / parallellarga test yuborish (ota-onalar xabardor —
// rozilik belgisi majburiy), ro'yxat, yopish va bekor qilish. FAQAT psixolog.
// Tayinlangach testni ko'radigan bolalarga neytral push ketadi (tranzaksiyadan
// KEYIN; xatosi tayinlashni yiqitmaydi).

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { allowedClassIds, assertCan, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, invalid, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { AssignInput, assignInputSchema, assignmentFilterSchema, toInstant } from './assessments-inputs.schemas';
import { AssessmentsIqService, PARVOZ_IQ_TEST_ID, PARVOZ_IQ_TITLE } from './assessments-iq.service';
import { AssessmentsStore, ClassRow } from './assessments-store';
import { AssignmentRow, PsychAssignment, toAssignment, toAssignmentRow } from './assessments-view';
import { PsychAssignmentPushService } from './psych-assignment-push.service';
import type { PsychTest } from './psych/types';

/** Tayinlash maqsadi → sinflar (test parallellari bilan kesishma; faqat shu maktab sinflari). */
export function resolveClasses(classes: readonly ClassRow[], target: AssignInput['target'], test: Pick<PsychTest, 'grades'>): string[] {
  if (target.kind === 'STUDENTS') return [];
  return classes
    .filter((c) => test.grades.includes(c.grade))
    .filter((c) => (target.kind === 'CLASSES' ? target.classIds.includes(c.id) : target.grades.includes(c.grade)))
    .map((c) => c.id);
}

/** Tayinlash qamrovi: sinflar (sinf / daraja maqsadi) yoki shaxsiy o'quvchilar; taklif qilinganlar soni. */
export interface AssignScope {
  classIds: string[];
  studentIds: string[];
  invited: number;
  /** Saqlanadigan maqsad (`STUDENTS` da `careRequestId` kirmaydi — u alohida ustunda). */
  target: Prisma.InputJsonValue;
}

@Injectable()
export class AssessmentsAssignService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly store: AssessmentsStore,
    private readonly audit: SchoolAuditService,
    private readonly iq: AssessmentsIqService,
    private readonly childPush: PsychAssignmentPushService,
  ) {}

  async listAssignments(actor: SchoolActor, query: unknown): Promise<AssignmentRow[]> {
    assertCan(actor, 'assessments.manage');
    const filter = parseOrThrow(assignmentFilterSchema, query ?? {});
    const [rows, tests, classes, completed] = await Promise.all([
      this.prisma.schoolPsychAssignment.findMany({
        where: { schoolId: actor.schoolId, ...(filter.testId && { testId: filter.testId }) },
        orderBy: [{ opensAt: 'desc' }, { createdAt: 'desc' }],
      }),
      this.store.allTests(actor.schoolId),
      this.store.classes(actor.schoolId),
      this.store.completedCounts(actor.schoolId),
    ]);
    const nowMs = Date.now();
    const byId = new Map(tests.map((t) => [t.id, t]));
    const names = new Map(classes.map((c) => [c.id, c.name]));
    const iqRows = rows.filter((a) => a.testId === PARVOZ_IQ_TEST_ID);
    const iqDone = await this.iq.completedCounts(this.prisma, actor.schoolId, iqRows);
    const done = new Map([...completed, ...iqDone]);
    return rows
      .map((a) => {
        const row = toAssignmentRow(a, nowMs, done, byId.get(a.testId), names);
        return a.testId === PARVOZ_IQ_TEST_ID ? { ...row, testTitle: { ...PARVOZ_IQ_TITLE }, testKind: 'COGNITIVE' as const } : row;
      })
      .filter((a) => !filter.state || a.state === filter.state);
  }

  async assign(actor: SchoolActor, input: unknown): Promise<PsychAssignment> {
    assertCan(actor, 'assessments.manage');
    const data = parseOrThrow(assignInputSchema, input);
    const assignment = data.testId === PARVOZ_IQ_TEST_ID ? await this.assignIq(actor, data) : await this.assignTest(actor, data);
    await this.childPush.notify(assignment.id);
    return assignment;
  }

  private assignTest(actor: SchoolActor, data: AssignInput): Promise<PsychAssignment> {
    return this.prisma.$transaction(async (tx) => {
      // Test tahriri / arxivi bilan bir navbatda — tayinlash eskirgan versiyaga bog'lanmasin.
      await this.store.lock(tx, `psych-test:${data.testId}`);
      const test = await this.store.requireTest(actor.schoolId, data.testId, tx);
      if (test.status !== 'PUBLISHED' || test.items.length === 0) throw conflict('test not assignable');
      const scope = await this.resolveScope(tx, actor, data, test);
      const row = await tx.schoolPsychAssignment.create({
        data: {
          schoolId: actor.schoolId,
          testId: test.id,
          testVersion: test.version,
          target: scope.target,
          classIds: scope.classIds,
          studentIds: scope.studentIds,
          careRequestId: await this.careRequestOf(tx, actor.schoolId, data),
          opensAt: toInstant(data.opensAt),
          closesAt: toInstant(data.closesAt),
          status: 'OPEN',
          invited: scope.invited,
          consent: 'PARENTS_INFORMED',
          createdBy: actor.staffId,
        },
      });
      await this.audit.write(
        actor,
        {
          module: 'ASSESSMENTS',
          action: 'assessments.assign',
          summary: `Test tayinlandi: ${test.title.uz}`,
          entityId: row.id,
          params: { classes: scope.classIds.length, count: scope.invited, title: test.title.uz },
        },
        tx,
      );
      return toAssignment(row);
    });
  }

  /**
   * Sinf / daraja maqsadi — test parallellari bilan kesishma; `STUDENTS` — shu maktabning, doiradagi,
   * arxivlanmagan, test darajasiga mos o'quvchilari (hammasi shart; begona yoki noma'lum id — 400,
   * qaysi biri ekani oshkor qilinmaydi).
   */
  private async resolveScope(tx: Prisma.TransactionClient, actor: SchoolActor, data: AssignInput, test: Pick<PsychTest, 'grades'>): Promise<AssignScope> {
    if (data.target.kind === 'STUDENTS') {
      const studentIds = [...new Set(data.target.studentIds)];
      const allowed = allowedClassIds(actor);
      const students = await tx.schoolStudent.findMany({
        where: { schoolId: actor.schoolId, archived: false, id: { in: studentIds } },
        select: { id: true, classId: true, class: { select: { grade: true } } },
      });
      const usable = students.filter((s) => s.classId && s.class && test.grades.includes(s.class.grade) && (!allowed || allowed.includes(s.classId)));
      if (usable.length !== studentIds.length) throw invalid('target.studentIds: assessments.validation.noStudents');
      return { classIds: [], studentIds, invited: studentIds.length, target: { kind: 'STUDENTS', studentIds } };
    }
    const classIds = resolveClasses(await this.store.classes(actor.schoolId, tx), data.target, test);
    if (classIds.length === 0) throw invalid('target: assessments.validation.noClasses');
    const invited = await tx.schoolStudent.count({ where: { schoolId: actor.schoolId, archived: false, classId: { in: classIds } } });
    return { classIds, studentIds: [], invited, target: data.target as Prisma.InputJsonValue };
  }

  /** Bola ovozi murojaati (ixtiyoriy): shu maktabniki bo'lishi shart. */
  private async careRequestOf(tx: Prisma.TransactionClient, schoolId: string, data: AssignInput): Promise<string | null> {
    const id = data.careRequestId ?? (data.target.kind === 'STUDENTS' ? data.target.careRequestId : undefined);
    if (!id) return null;
    const found = await tx.schoolCareRequest.findFirst({ where: { id, schoolId }, select: { id: true } });
    if (!found) throw invalid('careRequestId: errors.form.invalid');
    return found.id;
  }

  /**
   * Parvoz IQ (docs/IQ-REJA.md §7): savollar maktab testlari omborida emas —
   * IQ bankida; sinflar tanlovi yosh darajasidan qat'i nazar (yoshni IQ moduli
   * tekshiradi: 9–20 dan tashqari bola topshiriqni ko'rmaydi).
   */
  private assignIq(actor: SchoolActor, data: AssignInput): Promise<PsychAssignment> {
    return this.prisma.$transaction(async (tx) => {
      const allGrades = { grades: Array.from({ length: 11 }, (_, i) => i + 1) };
      const scope = await this.resolveScope(tx, actor, data, allGrades);
      const row = await tx.schoolPsychAssignment.create({
        data: {
          schoolId: actor.schoolId,
          testId: PARVOZ_IQ_TEST_ID,
          testVersion: 1,
          target: scope.target,
          classIds: scope.classIds,
          studentIds: scope.studentIds,
          careRequestId: await this.careRequestOf(tx, actor.schoolId, data),
          opensAt: toInstant(data.opensAt),
          closesAt: toInstant(data.closesAt),
          status: 'OPEN',
          invited: scope.invited,
          consent: 'PARENTS_INFORMED',
          createdBy: actor.staffId,
        },
      });
      await this.audit.write(
        actor,
        {
          module: 'ASSESSMENTS',
          action: 'assessments.assign',
          summary: `Test tayinlandi: ${PARVOZ_IQ_TITLE.uz}`,
          entityId: row.id,
          params: { classes: scope.classIds.length, count: scope.invited, title: PARVOZ_IQ_TITLE.uz },
        },
        tx,
      );
      return toAssignment(row);
    });
  }

  /** Natija yo'q — bekor qilinadi; natija bor — yopiladi (natijalar saqlanadi). */
  unassign(actor: SchoolActor, id: string): Promise<PsychAssignment> {
    return this.closeOrCancel(actor, id, 'unassign');
  }

  closeAssignment(actor: SchoolActor, id: string): Promise<PsychAssignment> {
    return this.closeOrCancel(actor, id, 'close');
  }

  private async closeOrCancel(actor: SchoolActor, id: string, mode: 'unassign' | 'close'): Promise<PsychAssignment> {
    assertCan(actor, 'assessments.manage');
    return this.prisma.$transaction(async (tx) => {
      // Bola topshirig'i bilan bir navbatda: yopilayotgan paytda natija yo'qolmasin.
      await this.store.lock(tx, `psych-assignment:${id}`);
      const a = await tx.schoolPsychAssignment.findFirst({ where: { id, schoolId: actor.schoolId } });
      if (!a) throw notFound(id);
      if (a.status !== 'OPEN') throw conflict(`status ${a.status}`);
      const hasResults =
        a.testId === PARVOZ_IQ_TEST_ID
          ? ((await this.iq.completedCounts(tx, actor.schoolId, [a])).get(a.id) ?? 0) > 0
          : (await tx.schoolPsychResult.count({ where: { schoolId: actor.schoolId, assignmentId: id } })) > 0;
      const status = mode === 'close' || hasResults ? 'CLOSED' : 'CANCELLED';
      const next = await tx.schoolPsychAssignment.update({ where: { id }, data: { status } });
      await this.audit.write(
        actor,
        {
          module: 'ASSESSMENTS',
          action: mode === 'close' ? 'assessments.assignment.close' : 'assessments.unassign',
          summary: `Tayinlash: ${status}`,
          entityId: id,
          before: { status: a.status },
          after: { status },
        },
        tx,
      );
      return toAssignment(next);
    });
  }
}
