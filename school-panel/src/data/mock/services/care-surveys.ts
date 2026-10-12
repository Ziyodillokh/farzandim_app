import type { AgeGroup, CareQuestion, CareSurvey } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import {
  careQuestionInputSchema,
  careSurveyInputSchema,
  type CareQuestionInput,
  type CareSurveyInput,
} from '@/data/schemas/care';
import { parseOrThrow } from '@/data/schemas/validate';
import { percent } from '@/lib/utils';
import { toLocalIso } from '../calendar';
import { clockNow } from '../clock';
import { assertCan, currentActor, latency, newId, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { ageGroupOf } from '../seed/care';
import type { Tables } from '../tables';

/**
 * So'rovnomalar va savollar banki — FAQAT psixolog (`care.surveys`).
 * Audit yozuvlarida savol matni yoki javoblar yo'q — faqat amal va obyekt ID.
 */
export type CareSurveyRow = CareSurvey & { respondents: number; participationRate: number };
export type CareQuestionRow = CareQuestion & { usedIn: number };

function requireSurveys() {
  const actor = currentActor();
  assertCan(actor, 'care.surveys');
  return actor;
}

function invitedFor(t: Tables, ageGroups: readonly AgeGroup[]): number {
  const classIds = new Set(t.classes.filter((c) => ageGroups.includes(ageGroupOf(c.grade))).map((c) => c.id));
  return t.students.filter((s) => !s.archived && classIds.has(s.classId)).length;
}

/** Savollar mavjud, faol va so'rovnoma yosh guruhiga mos bo'lishi shart. */
function assertQuestions(t: Tables, questionIds: readonly string[], ageGroups: readonly AgeGroup[]): void {
  const byId = new Map(t.careQuestions.map((q) => [q.id, q]));
  for (const id of questionIds) {
    const q = byId.get(id);
    if (!q || !q.active) throw new ServiceError('VALIDATION', `questionIds: ${id}`);
    if (!q.ageGroups.some((g) => ageGroups.includes(g))) throw new ServiceError('VALIDATION', `questionIds: ${id} ageGroups`);
  }
}

function findSurvey(t: Tables, id: string): CareSurvey {
  const survey = t.careSurveys.find((s) => s.id === id);
  if (!survey) throw new ServiceError('NOT_FOUND', id);
  return survey;
}

function setSurveyStatus(id: string, from: CareSurvey['status'], to: CareSurvey['status']): CareSurvey {
  const actor = requireSurveys();
  return transact((t) => {
    const survey = findSurvey(t, id);
    if (survey.status !== from) throw new ServiceError('CONFLICT', `status ${survey.status}`);
    if (to === 'ACTIVE') {
      // Bir vaqtda bitta faol so'rovnoma.
      for (const other of t.careSurveys) if (other.status === 'ACTIVE') other.status = 'CLOSED';
    }
    survey.status = to;
    // Simulyatsiya javoblari shu vaqtdan boshlab keladi (care-sim.ts).
    if (to === 'ACTIVE') survey.activatedAt = toLocalIso(clockNow());
    writeAudit(t, actor, 'CARE', to === 'ACTIVE' ? 'care.survey.activate' : 'care.survey.close', `So'rovnoma: ${survey.title}`, id, { status: from }, { status: to });
    return { ...survey };
  });
}

export const careSurveysService = {
  async listSurveys(): Promise<CareSurveyRow[]> {
    await latency(60, 160);
    requireSurveys();
    const t = getTables();
    const counts = new Map<string, number>();
    for (const r of t.careResponses) counts.set(r.surveyId, (counts.get(r.surveyId) ?? 0) + 1);
    return [...t.careSurveys]
      .sort((a, b) => b.weekStart.localeCompare(a.weekStart))
      .map((s) => {
        const respondents = counts.get(s.id) ?? 0;
        return { ...s, respondents, participationRate: percent(respondents, s.invited) };
      });
  },

  async createSurvey(input: CareSurveyInput): Promise<CareSurvey> {
    await latency();
    const actor = requireSurveys();
    const data = parseOrThrow(careSurveyInputSchema, input);
    return transact((t) => {
      assertQuestions(t, data.questionIds, data.ageGroups);
      const survey: CareSurvey = { id: newId('srv'), ...data, status: 'DRAFT', invited: invitedFor(t, data.ageGroups) };
      t.careSurveys.push(survey);
      writeAudit(t, actor, 'CARE', 'care.survey.create', `So'rovnoma yaratildi: ${survey.title}`, survey.id);
      return survey;
    });
  },

  async updateSurvey(id: string, input: CareSurveyInput): Promise<CareSurvey> {
    await latency();
    const actor = requireSurveys();
    const data = parseOrThrow(careSurveyInputSchema, input);
    return transact((t) => {
      const index = t.careSurveys.findIndex((s) => s.id === id);
      const before = t.careSurveys[index];
      if (!before) throw new ServiceError('NOT_FOUND', id);
      if (before.status !== 'DRAFT') throw new ServiceError('CONFLICT', 'only drafts are editable');
      assertQuestions(t, data.questionIds, data.ageGroups);
      const next: CareSurvey = { ...before, ...data, invited: invitedFor(t, data.ageGroups) };
      t.careSurveys[index] = next;
      writeAudit(t, actor, 'CARE', 'care.survey.update', `So'rovnoma tahrirlandi: ${next.title}`, id, before, next);
      return next;
    });
  },

  async deleteSurvey(id: string): Promise<void> {
    await latency();
    const actor = requireSurveys();
    transact((t) => {
      const survey = findSurvey(t, id);
      if (survey.status !== 'DRAFT') throw new ServiceError('CONFLICT', 'only drafts can be deleted');
      t.careSurveys = t.careSurveys.filter((s) => s.id !== id);
      writeAudit(t, actor, 'CARE', 'care.survey.delete', `So'rovnoma o'chirildi: ${survey.title}`, id);
    });
  },

  async activateSurvey(id: string): Promise<CareSurvey> {
    await latency();
    return setSurveyStatus(id, 'DRAFT', 'ACTIVE');
  },

  async closeSurvey(id: string): Promise<CareSurvey> {
    await latency();
    return setSurveyStatus(id, 'ACTIVE', 'CLOSED');
  },

  async listQuestions(): Promise<CareQuestionRow[]> {
    await latency(60, 140);
    requireSurveys();
    const t = getTables();
    return t.careQuestions.map((q) => ({ ...q, usedIn: t.careSurveys.filter((s) => s.questionIds.includes(q.id)).length }));
  },

  async createQuestion(input: CareQuestionInput): Promise<CareQuestion> {
    await latency();
    const actor = requireSurveys();
    const data = parseOrThrow(careQuestionInputSchema, input);
    return transact((t) => {
      const question: CareQuestion = { id: newId('q'), ...data };
      t.careQuestions.push(question);
      writeAudit(t, actor, 'CARE', 'care.question.create', 'Savollar bankiga savol qo\'shildi', question.id);
      return question;
    });
  },

  async updateQuestion(id: string, input: CareQuestionInput): Promise<CareQuestion> {
    await latency();
    const actor = requireSurveys();
    const data = parseOrThrow(careQuestionInputSchema, input);
    return transact((t) => {
      const index = t.careQuestions.findIndex((q) => q.id === id);
      const before = t.careQuestions[index];
      if (!before) throw new ServiceError('NOT_FOUND', id);
      const next: CareQuestion = { ...before, ...data };
      t.careQuestions[index] = next;
      writeAudit(t, actor, 'CARE', 'care.question.update', 'Savollar bankidagi savol tahrirlandi', id, { active: before.active }, { active: next.active });
      return next;
    });
  },

  /** So'rovnomada ishlatilgan savol o'chirilmaydi (natijalar buzilmasin) — nofaol qilinadi. */
  async deleteQuestion(id: string): Promise<void> {
    await latency();
    const actor = requireSurveys();
    transact((t) => {
      if (!t.careQuestions.some((q) => q.id === id)) throw new ServiceError('NOT_FOUND', id);
      if (t.careSurveys.some((s) => s.questionIds.includes(id))) throw new ServiceError('CONFLICT', 'question in use');
      t.careQuestions = t.careQuestions.filter((q) => q.id !== id);
      writeAudit(t, actor, 'CARE', 'care.question.delete', 'Savollar bankidan savol o\'chirildi', id);
    });
  },
};
