// So'rovnomalar va savollar banki — FAQAT psixolog (`care.surveys`).
// Audit yozuvlarida savol matni yoki javoblar yo'q — faqat amal va obyekt.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, invalid, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { CareStore, toQuestionView, toSurveyView } from './care-store';
import { careQuestionInputSchema, careSurveyInputSchema } from './care.schemas';

type Tx = Prisma.TransactionClient;
const percent = (part: number, total: number) => (total > 0 ? Math.round((part / total) * 100) : 0);

@Injectable()
export class CareSurveysService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly store: CareStore,
    private readonly audit: SchoolAuditService,
  ) {}

  async listSurveys(actor: SchoolActor) {
    assertCan(actor, 'care.surveys');
    const [surveys, counts] = await Promise.all([
      this.prisma.schoolCareSurvey.findMany({ where: { schoolId: actor.schoolId }, orderBy: [{ weekStart: 'desc' }, { createdAt: 'desc' }] }),
      this.prisma.schoolCareResponse.groupBy({ by: ['surveyId'], where: { schoolId: actor.schoolId }, _count: { _all: true } }),
    ]);
    const bySurvey = new Map(counts.map((c) => [c.surveyId, c._count._all]));
    return surveys.map((s) => {
      const respondents = bySurvey.get(s.id) ?? 0;
      return { ...toSurveyView(s), respondents, participationRate: percent(respondents, s.invited) };
    });
  }

  async createSurvey(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'care.surveys');
    const data = parseOrThrow(careSurveyInputSchema, input);
    await this.assertQuestions(actor.schoolId, data.questionIds, data.ageGroups);
    const invited = await this.store.invitedFor(actor.schoolId, data.ageGroups);
    return this.prisma.$transaction(async (tx) => {
      const survey = await tx.schoolCareSurvey.create({ data: { ...data, schoolId: actor.schoolId, invited } });
      await this.write(tx, actor, 'care.survey.create', `So'rovnoma yaratildi: ${survey.title}`, survey.id);
      return toSurveyView(survey);
    });
  }

  async updateSurvey(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'care.surveys');
    const data = parseOrThrow(careSurveyInputSchema, input);
    const before = await this.findSurvey(actor.schoolId, id);
    if (before.status !== 'DRAFT') throw conflict('only drafts are editable');
    await this.assertQuestions(actor.schoolId, data.questionIds, data.ageGroups);
    const invited = await this.store.invitedFor(actor.schoolId, data.ageGroups);
    return this.prisma.$transaction(async (tx) => {
      const next = await tx.schoolCareSurvey.update({ where: { id }, data: { ...data, invited } });
      await this.audit.write(
        actor,
        {
          module: 'CARE',
          action: 'care.survey.update',
          summary: `So'rovnoma tahrirlandi: ${next.title}`,
          entityId: id,
          before: toSurveyView(before),
          after: toSurveyView(next),
        },
        tx,
      );
      return toSurveyView(next);
    });
  }

  async deleteSurvey(actor: SchoolActor, id: string): Promise<void> {
    assertCan(actor, 'care.surveys');
    const survey = await this.findSurvey(actor.schoolId, id);
    if (survey.status !== 'DRAFT') throw conflict('only drafts can be deleted');
    await this.prisma.$transaction(async (tx) => {
      await tx.schoolCareSurvey.delete({ where: { id } });
      await this.write(tx, actor, 'care.survey.delete', `So'rovnoma o'chirildi: ${survey.title}`, id);
    });
  }

  /** Bir vaqtda bitta faol so'rovnoma; taklif qilinganlar soni faollashtirishda yangilanadi. */
  async activateSurvey(actor: SchoolActor, id: string) {
    assertCan(actor, 'care.surveys');
    const survey = await this.findSurvey(actor.schoolId, id);
    if (survey.status !== 'DRAFT') throw conflict(`status ${survey.status}`);
    const invited = await this.store.invitedFor(actor.schoolId, survey.ageGroups);
    return this.prisma.$transaction(async (tx) => {
      // Bir vaqtda bitta faol so'rovnoma — parallel faollashtirishlar navbat bilan.
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`care-survey-activate:${actor.schoolId}`}, 0))`;
      await tx.schoolCareSurvey.updateMany({ where: { schoolId: actor.schoolId, status: 'ACTIVE' }, data: { status: 'CLOSED' } });
      const res = await tx.schoolCareSurvey.updateMany({
        where: { id, status: 'DRAFT' },
        data: { status: 'ACTIVE', activatedAt: new Date(), invited },
      });
      if (res.count === 0) throw conflict('status changed');
      await this.statusAudit(tx, actor, 'care.survey.activate', survey.title, id, 'DRAFT', 'ACTIVE');
      return toSurveyView(await tx.schoolCareSurvey.findUniqueOrThrow({ where: { id } }));
    });
  }

  async closeSurvey(actor: SchoolActor, id: string) {
    assertCan(actor, 'care.surveys');
    const survey = await this.findSurvey(actor.schoolId, id);
    return this.prisma.$transaction(async (tx) => {
      const res = await tx.schoolCareSurvey.updateMany({ where: { id, status: 'ACTIVE' }, data: { status: 'CLOSED' } });
      if (res.count === 0) throw conflict(`status ${survey.status}`);
      await this.statusAudit(tx, actor, 'care.survey.close', survey.title, id, 'ACTIVE', 'CLOSED');
      return toSurveyView(await tx.schoolCareSurvey.findUniqueOrThrow({ where: { id } }));
    });
  }

  async listQuestions(actor: SchoolActor) {
    assertCan(actor, 'care.surveys');
    const [questions, surveys] = await Promise.all([
      this.store.questions(actor.schoolId),
      this.prisma.schoolCareSurvey.findMany({ where: { schoolId: actor.schoolId }, select: { questionIds: true } }),
    ]);
    return questions.map((q) => ({ ...toQuestionView(q), usedIn: surveys.filter((s) => s.questionIds.includes(q.id)).length }));
  }

  async createQuestion(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'care.surveys');
    const data = parseOrThrow(careQuestionInputSchema, input);
    await this.store.questions(actor.schoolId);
    return this.prisma.$transaction(async (tx) => {
      const question = await tx.schoolCareQuestion.create({ data: { ...data, schoolId: actor.schoolId } });
      await this.write(tx, actor, 'care.question.create', 'Savollar bankiga savol qo\'shildi', question.id);
      return toQuestionView(question);
    });
  }

  async updateQuestion(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'care.surveys');
    const data = parseOrThrow(careQuestionInputSchema, input);
    const before = await this.prisma.schoolCareQuestion.findFirst({ where: { id, schoolId: actor.schoolId } });
    if (!before) throw notFound(id);
    return this.prisma.$transaction(async (tx) => {
      const next = await tx.schoolCareQuestion.update({ where: { id }, data });
      await this.audit.write(
        actor,
        {
          module: 'CARE',
          action: 'care.question.update',
          summary: 'Savollar bankidagi savol tahrirlandi',
          entityId: id,
          before: { active: before.active },
          after: { active: next.active },
        },
        tx,
      );
      return toQuestionView(next);
    });
  }

  /** So'rovnomada ishlatilgan savol o'chirilmaydi (natijalar buzilmasin) — nofaol qilinadi. */
  async deleteQuestion(actor: SchoolActor, id: string): Promise<void> {
    assertCan(actor, 'care.surveys');
    const question = await this.prisma.schoolCareQuestion.findFirst({ where: { id, schoolId: actor.schoolId } });
    if (!question) throw notFound(id);
    if (await this.prisma.schoolCareSurvey.count({ where: { schoolId: actor.schoolId, questionIds: { has: id } } })) {
      throw conflict('question in use');
    }
    await this.prisma.$transaction(async (tx) => {
      await tx.schoolCareQuestion.delete({ where: { id } });
      await this.write(tx, actor, 'care.question.delete', 'Savollar bankidan savol o\'chirildi', id);
    });
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  private async findSurvey(schoolId: string, id: string) {
    const survey = await this.prisma.schoolCareSurvey.findFirst({ where: { id, schoolId } });
    if (!survey) throw notFound(id);
    return survey;
  }

  /** Savollar mavjud, faol va so'rovnoma yosh guruhiga mos bo'lishi shart. */
  private async assertQuestions(schoolId: string, questionIds: readonly string[], ageGroups: readonly string[]): Promise<void> {
    const byId = new Map((await this.store.questions(schoolId)).map((q) => [q.id, q]));
    for (const id of questionIds) {
      const q = byId.get(id);
      if (!q || !q.active) throw invalid(`questionIds: ${id}`);
      if (!q.ageGroups.some((g) => ageGroups.includes(g))) throw invalid(`questionIds: ${id} ageGroups`);
    }
  }

  private write(tx: Tx, actor: SchoolActor, action: string, summary: string, entityId: string) {
    return this.audit.write(actor, { module: 'CARE', action, summary, entityId }, tx);
  }

  private statusAudit(tx: Tx, actor: SchoolActor, action: string, title: string, id: string, from: string, to: string) {
    return this.audit.write(
      actor,
      { module: 'CARE', action, summary: `So'rovnoma: ${title}`, entityId: id, before: { status: from }, after: { status: to } },
      tx,
    );
  }
}
