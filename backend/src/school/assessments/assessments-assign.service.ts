// Tayinlashlar: sinflar / parallellarga test yuborish (ota-onalar xabardor —
// rozilik belgisi majburiy), ro'yxat, yopish va bekor qilish. FAQAT psixolog.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, invalid, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { AssignInput, assignInputSchema, assignmentFilterSchema, toInstant } from './assessments-inputs.schemas';
import { AssessmentsStore, ClassRow } from './assessments-store';
import { AssignmentRow, PsychAssignment, toAssignment, toAssignmentRow } from './assessments-view';
import type { PsychTest } from './psych/types';

/** Tayinlash maqsadi → sinflar (test parallellari bilan kesishma; faqat shu maktab sinflari). */
export function resolveClasses(classes: readonly ClassRow[], target: AssignInput['target'], test: Pick<PsychTest, 'grades'>): string[] {
  return classes
    .filter((c) => test.grades.includes(c.grade))
    .filter((c) => (target.kind === 'CLASSES' ? target.classIds.includes(c.id) : target.grades.includes(c.grade)))
    .map((c) => c.id);
}

@Injectable()
export class AssessmentsAssignService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly store: AssessmentsStore,
    private readonly audit: SchoolAuditService,
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
    return rows
      .map((a) => toAssignmentRow(a, nowMs, completed, byId.get(a.testId), names))
      .filter((a) => !filter.state || a.state === filter.state);
  }

  async assign(actor: SchoolActor, input: unknown): Promise<PsychAssignment> {
    assertCan(actor, 'assessments.manage');
    const data = parseOrThrow(assignInputSchema, input);
    return this.prisma.$transaction(async (tx) => {
      // Test tahriri / arxivi bilan bir navbatda — tayinlash eskirgan versiyaga bog'lanmasin.
      await this.store.lock(tx, `psych-test:${data.testId}`);
      const test = await this.store.requireTest(actor.schoolId, data.testId, tx);
      if (test.status !== 'PUBLISHED' || test.items.length === 0) throw conflict('test not assignable');
      const classIds = resolveClasses(await this.store.classes(actor.schoolId, tx), data.target, test);
      if (classIds.length === 0) throw invalid('target: assessments.validation.noClasses');
      const invited = await tx.schoolStudent.count({ where: { schoolId: actor.schoolId, archived: false, classId: { in: classIds } } });
      const row = await tx.schoolPsychAssignment.create({
        data: {
          schoolId: actor.schoolId,
          testId: test.id,
          testVersion: test.version,
          target: data.target as Prisma.InputJsonValue,
          classIds,
          opensAt: toInstant(data.opensAt),
          closesAt: toInstant(data.closesAt),
          status: 'OPEN',
          invited,
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
          params: { classes: classIds.length, count: invited, title: test.title.uz },
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
      const hasResults = (await tx.schoolPsychResult.count({ where: { schoolId: actor.schoolId, assignmentId: id } })) > 0;
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
