// Test holati (nashr / arxiv) va me'yorlar. Shablonlar kodda — ularning
// maktabga xos holati va me'yori `SchoolPsychTemplateState`da. Me'yor
// o'zgarsa natijalar o'qishda darhol qayta baholanadi (xom ball saqlanadi).

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, invalid } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { normsBodySchema } from './assessments-inputs.schemas';
import { parseTestNorms } from './assessments-parse';
import { AssessmentsStore, OPEN_ASSIGNMENTS } from './assessments-store';
import { definitionOf, isTemplateId, portableTest } from './psych/catalog';
import type { PsychTest, PsychTestStatus } from './psych/types';

type Tx = Prisma.TransactionClient;

@Injectable()
export class AssessmentsStatusService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly store: AssessmentsStore,
    private readonly audit: SchoolAuditService,
  ) {}

  publishTest(actor: SchoolActor, id: string): Promise<PsychTest> {
    return this.setStatus(actor, id, 'PUBLISHED', ['DRAFT', 'ARCHIVED'], 'assessments.test.publish');
  }

  archiveTest(actor: SchoolActor, id: string): Promise<PsychTest> {
    return this.setStatus(actor, id, 'ARCHIVED', ['DRAFT', 'PUBLISHED'], 'assessments.test.archive');
  }

  /** Shablon: maktab me'yori (`null` — standart demo me'yorlar tiklanadi); o'z testi: `null` → bo'sh. */
  async updateNorms(actor: SchoolActor, id: string, body: unknown): Promise<void> {
    assertCan(actor, 'assessments.manage');
    const { norms } = parseOrThrow(normsBodySchema, body ?? {});
    if (norms === undefined) throw invalid('norms: errors.form.required');
    await this.prisma.$transaction(async (tx) => {
      await this.store.lock(tx, `psych-test:${id}`);
      const test = await this.store.requireTest(actor.schoolId, id, tx);
      const parsed = norms === null ? null : parseTestNorms(test, norms);
      if (isTemplateId(id)) {
        const value = parsed === null ? Prisma.DbNull : (parsed as Prisma.InputJsonValue);
        await tx.schoolPsychTemplateState.upsert({
          where: { schoolId_templateId: { schoolId: actor.schoolId, templateId: id } },
          create: { schoolId: actor.schoolId, templateId: id, status: test.status, norms: value },
          update: { norms: value },
        });
      } else {
        const definition = definitionOf({ ...portableTest(test), norms: parsed ?? {} }, test.source);
        await tx.schoolPsychTest.update({ where: { id }, data: { definition: definition as Prisma.InputJsonValue } });
      }
      await this.write(tx, actor, parsed ? 'assessments.norms.update' : 'assessments.norms.restore', `Me'yorlar: ${test.title.uz}`, id, null, {
        title: test.title.uz,
      });
    });
  }

  private async setStatus(
    actor: SchoolActor,
    id: string,
    to: PsychTestStatus,
    from: readonly PsychTestStatus[],
    action: string,
  ): Promise<PsychTest> {
    assertCan(actor, 'assessments.manage');
    return this.prisma.$transaction(async (tx) => {
      await this.store.lock(tx, `psych-test:${id}`);
      const test = await this.store.requireTest(actor.schoolId, id, tx);
      if (!from.includes(test.status)) throw conflict(`status ${test.status}`);
      if (to === 'PUBLISHED' && test.source !== 'EXTERNAL' && test.items.length === 0) throw invalid('items: assessments.validation.noItems');
      if (to === 'ARCHIVED' && (await this.store.hasLiveAssignments(actor.schoolId, test, tx))) throw conflict(OPEN_ASSIGNMENTS);
      if (isTemplateId(id)) {
        await tx.schoolPsychTemplateState.upsert({
          where: { schoolId_templateId: { schoolId: actor.schoolId, templateId: id } },
          create: { schoolId: actor.schoolId, templateId: id, status: to },
          update: { status: to },
        });
      } else {
        await tx.schoolPsychTest.update({ where: { id }, data: { status: to } });
      }
      await this.write(tx, actor, action, `Test holati: ${test.title.uz}`, id, { before: { status: test.status }, after: { status: to } }, {
        title: test.title.uz,
      });
      return this.store.requireTest(actor.schoolId, id, tx);
    });
  }

  private write(
    tx: Tx,
    actor: SchoolActor,
    action: string,
    summary: string,
    entityId: string,
    change: { before: unknown; after: unknown } | null,
    params: Record<string, string | number>,
  ): Promise<void> {
    return this.audit.write(actor, { module: 'ASSESSMENTS', action, summary, entityId, before: change?.before, after: change?.after, params }, tx);
  }
}

