// Test konstruktori (yozish): yaratish, tahrirlash (nashr etilgan testda savol /
// shkala o'zgarsa — yangi versiya), nusxa, JSON import. FAQAT psixolog.
// Auditda faqat amal, test nomi va sonlar — o'quvchi ma'lumoti YO'Q.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { AuditEntry, SchoolAuditService } from '../common/school-audit.service';
import { conflict, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { importBodySchema } from './assessments-inputs.schemas';
import { parseTestFile, parseTestInput } from './assessments-parse';
import { AssessmentsStore, OPEN_ASSIGNMENTS } from './assessments-store';
import { submitGraceMs } from './assessments-view';
import { canonicalJson, definitionOf, isTemplateId, portableTest, toPsychTest } from './psych/catalog';
import type { PsychTest, PsychTestInputShape, PsychTestSource } from './psych/types';

type Tx = Prisma.TransactionClient;

const COPY_SUFFIX = { uz: ' (nusxa)', ru: ' (копия)' } as const;

/** Ikki vaqt chegarasining kattasi (`null` — standart qo'shimcha vaqt, `submitGraceMs`). */
function longerLimit(a: number | null, b: number | null): number | null {
  const grace = (min: number | null) => submitGraceMs({ timeLimitMin: min });
  return grace(a) >= grace(b) ? a : b;
}
const TITLE_MAX = 120;

@Injectable()
export class AssessmentsEditorService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly store: AssessmentsStore,
    private readonly audit: SchoolAuditService,
  ) {}

  async createTest(actor: SchoolActor, input: unknown): Promise<PsychTest> {
    assertCan(actor, 'assessments.manage');
    const data = parseTestInput(input);
    return this.prisma.$transaction(async (tx) => {
      const test = await this.insert(tx, actor, data, 'CUSTOM', null);
      await this.write(tx, actor, {
        action: 'assessments.test.create',
        summary: `Test yaratildi: ${test.title.uz}`,
        entityId: test.id,
        params: { count: test.items.length, title: test.title.uz },
      });
      return test;
    });
  }

  /** Nashr etilgan testda savol/shkala o'zgarsa — yangi versiya (eski natijalar o'z versiyasida). */
  async updateTest(actor: SchoolActor, id: string, input: unknown): Promise<PsychTest> {
    assertCan(actor, 'assessments.manage');
    if (isTemplateId(id)) throw conflict('templates are read-only');
    const data = parseTestInput(input);
    return this.prisma.$transaction(async (tx) => {
      await this.store.lock(tx, `psych-test:${id}`);
      const row = await tx.schoolPsychTest.findFirst({ where: { id, schoolId: actor.schoolId } });
      if (!row) throw notFound(id);
      const test = toPsychTest(row);
      if (test.status === 'ARCHIVED' || test.source === 'EXTERNAL') throw conflict(`${test.source}/${test.status}`);
      const changed = canonicalJson(test.items) !== canonicalJson(data.items) || canonicalJson(test.scales) !== canonicalJson(data.scales);
      if (test.status === 'PUBLISHED') await this.assertEditableWhileLive(tx, actor.schoolId, test, data, changed);
      const version = test.status === 'PUBLISHED' && changed ? test.version + 1 : test.version;
      const next = toPsychTest(
        await tx.schoolPsychTest.update({
          where: { id },
          data: { definition: definitionOf(data, test.source) as Prisma.InputJsonValue, version },
        }),
      );
      await this.write(tx, actor, {
        action: 'assessments.test.update',
        summary: `Test tahrirlandi: ${next.title.uz}`,
        entityId: id,
        before: { version: test.version },
        after: { version },
        params: { version, title: next.title.uz },
      });
      return next;
    });
  }

  async duplicateTest(actor: SchoolActor, id: string): Promise<PsychTest> {
    assertCan(actor, 'assessments.manage');
    const source = await this.store.requireTest(actor.schoolId, id);
    const title = {
      uz: `${source.title.uz}${COPY_SUFFIX.uz}`.slice(0, TITLE_MAX),
      ru: `${source.title.ru}${COPY_SUFFIX.ru}`.slice(0, TITLE_MAX),
    };
    return this.prisma.$transaction(async (tx) => {
      const copy = await this.insert(tx, actor, { ...portableTest(source), title }, 'CUSTOM', source.id);
      await this.write(tx, actor, {
        action: 'assessments.test.duplicate',
        summary: `Test nusxalandi: ${source.title.uz}`,
        entityId: copy.id,
        params: { title: source.title.uz },
      });
      return copy;
    });
  }

  /** JSON fayl (`parvoz.psych-test` v1) → IMPORTED qoralama. */
  async importTest(actor: SchoolActor, body: unknown): Promise<PsychTest> {
    assertCan(actor, 'assessments.manage');
    const { json } = parseOrThrow(importBodySchema, body ?? {});
    const data = parseTestFile(json);
    return this.prisma.$transaction(async (tx) => {
      const test = await this.insert(tx, actor, data, 'IMPORTED', null);
      await this.write(tx, actor, {
        action: 'assessments.test.import',
        summary: `Test import qilindi: ${test.title.uz}`,
        entityId: test.id,
        params: { count: test.items.length, title: test.title.uz },
      });
      return test;
    });
  }

  /**
   * Faol tayinlash paytida: savol / shkala o'zgarmaydi (javoblar boshqa versiya bo'yicha
   * baholanardi; qo'shimcha vaqt — eski va yangi chegaraning kattasi, uzaytirish yopilganni
   * qayta ochmasin) va vaqt chegarasi o'zgarmaydi (qisqartirib, keyingi tahrirda tekshiruvni
   * chetlab o'tmasin; yechayotgan bola yubora olmay qolmasin).
   */
  private async assertEditableWhileLive(tx: Tx, schoolId: string, test: PsychTest, data: PsychTestInputShape, changed: boolean): Promise<void> {
    const limitChanged = (data.timeLimitMin ?? null) !== (test.timeLimitMin ?? null);
    if (!changed && !limitChanged) return;
    const grace = { id: test.id, timeLimitMin: changed ? longerLimit(test.timeLimitMin, data.timeLimitMin ?? null) : test.timeLimitMin };
    if (await this.store.hasLiveAssignments(schoolId, grace, tx)) throw conflict(OPEN_ASSIGNMENTS);
  }

  private async insert(tx: Tx, actor: SchoolActor, body: PsychTestInputShape, source: PsychTestSource, basedOn: string | null): Promise<PsychTest> {
    const row = await tx.schoolPsychTest.create({
      data: {
        schoolId: actor.schoolId,
        definition: definitionOf(body, source) as Prisma.InputJsonValue,
        version: 1,
        status: 'DRAFT',
        createdBy: actor.staffId,
        basedOn,
      },
    });
    return toPsychTest(row);
  }

  private write(tx: Tx, actor: SchoolActor, entry: Omit<AuditEntry, 'module'>): Promise<void> {
    return this.audit.write(actor, { module: 'ASSESSMENTS', ...entry }, tx);
  }
}
