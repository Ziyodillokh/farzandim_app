// Bola ovozi — anonim natija (`care.aggregate`: direktor, admin, psixolog):
// so'rovnoma tanlovi, o'tkazilganlar ro'yxati va umumlashgan ko'rsatkichlar.
// Shaxsga bog'liq maydon yo'q; kichik guruhlar K=5 atomlari bilan yashiriladi.

import { Injectable } from '@nestjs/common';
import { SchoolCareSurvey } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { addDays, isoWeekday, tashkentDay, tashkentDayStart } from '../../common/time/tashkent';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { ClassRow, computeCareAggregate, targetClasses, trendPoint } from './care-aggregate';
import { CareStore, toQuestionView, toSurveyView } from './care-store';
import { CARE_MIN_GROUP } from './care-suppression';
import { careAggregateQuerySchema, CARE_TOPICS } from './care.schemas';

/** Trendda oxirgi shuncha so'rovnoma. */
const TREND_SURVEYS = 4;
const percent = (part: number, total: number) => (total > 0 ? Math.round((part / total) * 100) : 0);

/** Yangisi birinchi: hafta boshi, so'ng faollashtirilgan vaqt. */
const byRecency = (a: SchoolCareSurvey, b: SchoolCareSurvey) =>
  b.weekStart.localeCompare(a.weekStart) || (b.activatedAt?.getTime() ?? 0) - (a.activatedAt?.getTime() ?? 0);

@Injectable()
export class CareInsightsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly store: CareStore,
  ) {}

  /** So'rovnoma tanlovi — faqat sarlavha / hafta / holat; `ready` — kamida K respondent. */
  async surveyOptions(actor: SchoolActor) {
    assertCan(actor, 'care.aggregate');
    const [surveys, classes] = await Promise.all([this.published(actor.schoolId), this.store.classes(actor.schoolId)]);
    return Promise.all(
      surveys.map(async (s) => ({
        id: s.id,
        title: s.title,
        weekStart: s.weekStart,
        status: s.status,
        ready: (await this.store.respondentCount(s, classes)) >= CARE_MIN_GROUP,
      })),
    );
  }

  /** O'tkazilgan so'rovnomalar (faqat o'qish) — mavzular; ishtirok faqat k ≥ 5 bo'lsa. */
  async surveySummaries(actor: SchoolActor) {
    assertCan(actor, 'care.aggregate');
    const [surveys, classes, questions] = await Promise.all([
      this.published(actor.schoolId),
      this.store.classes(actor.schoolId),
      this.store.questions(actor.schoolId),
    ]);
    const topicOf = new Map(questions.map((q) => [q.id, toQuestionView(q).topic]));
    return Promise.all(
      surveys.map(async (s) => {
        const used = new Set(s.questionIds.map((id) => topicOf.get(id)));
        const respondents = await this.store.respondentCount(s, classes);
        const view = toSurveyView(s);
        return {
          id: view.id,
          title: view.title,
          weekStart: view.weekStart,
          status: view.status,
          ageGroups: view.ageGroups,
          questionCount: s.questionIds.length,
          topics: CARE_TOPICS.filter((topic) => used.has(topic)),
          participation: respondents >= CARE_MIN_GROUP ? { respondents, invited: s.invited, rate: percent(respondents, s.invited) } : null,
        };
      }),
    );
  }

  /** Umumlashgan natija — bir vaqtda bitta kesim; k ≥ 5. */
  async aggregate(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'care.aggregate');
    const { surveyId, breakdown } = parseOrThrow(careAggregateQuerySchema, query);
    const [surveys, classes, questions] = await Promise.all([
      this.published(actor.schoolId),
      this.store.classes(actor.schoolId),
      this.store.questionMeta(actor.schoolId),
    ]);
    const survey = surveyId
      ? await this.prisma.schoolCareSurvey.findFirst({ where: { id: surveyId, schoolId: actor.schoolId } })
      : await this.defaultSurvey(surveys, classes);
    if (!survey) throw notFound(surveyId ?? 'survey');
    const trendSurveys = surveys
      .filter((s) => s.weekStart <= survey.weekStart)
      .sort((a, b) => a.weekStart.localeCompare(b.weekStart))
      .slice(-TREND_SURVEYS);
    const trend = [];
    for (const s of trendSurveys) {
      const ids = new Set(targetClasses(classes, s.ageGroups).map((c) => c.id));
      const responses = (await this.store.responses(s.id)).filter((r) => ids.has(r.classId));
      trend.push(...trendPoint(s.weekStart, responses, questions));
    }
    return computeCareAggregate({
      survey,
      classes,
      responses: await this.store.responses(survey.id),
      questions,
      breakdown,
      trend,
      requestsThisWeek: await this.requestsThisWeek(actor.schoolId),
    });
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  private async published(schoolId: string): Promise<SchoolCareSurvey[]> {
    const surveys = await this.prisma.schoolCareSurvey.findMany({ where: { schoolId, status: { not: 'DRAFT' } } });
    return surveys.sort(byRecency);
  }

  /** Eng so'nggi, kamida K respondentli; bunday yo'q bo'lsa — eng so'nggisi. */
  private async defaultSurvey(surveys: SchoolCareSurvey[], classes: ClassRow[]): Promise<SchoolCareSurvey | undefined> {
    for (const s of surveys) if ((await this.store.respondentCount(s, classes)) >= CARE_MIN_GROUP) return s;
    return surveys[0];
  }

  /** Joriy hafta (Toshkent, dushanbadan) murojaatlari soni. */
  private requestsThisWeek(schoolId: string): Promise<number> {
    const today = tashkentDay();
    const monday = addDays(today, 1 - isoWeekday(today));
    return this.prisma.schoolCareRequest.count({
      where: { schoolId, createdAt: { gte: tashkentDayStart(monday), lt: tashkentDayStart(addDays(monday, 7)) } },
    });
  }
}
