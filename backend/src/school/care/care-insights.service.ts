// Bola ovozi — anonim natija (`care.aggregate`: direktor, admin, psixolog):
// so'rovnoma tanlovi, o'tkazilganlar ro'yxati va umumlashgan ko'rsatkichlar.
// Shaxsga bog'liq maydon yo'q; kichik guruhlar K=5 atomlari bilan yashiriladi.
//
// Ayirish hujumidan himoya: direktor / admin ko'rsatkichlarni faqat YOPILGAN
// so'rovnoma bo'yicha ko'radi (faol so'rovnomada har yangi javobdan keyingi
// o'zgarish shu bolaning javobini ochib qo'yardi) — faolida faqat ishtirok.
// Guruhlar javoblardagi sinf / daraja nusxasidan tuziladi (`snapshotClasses`).

import { Injectable } from '@nestjs/common';
import { SchoolCareSurvey } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { addDays, isoWeekday, tashkentDay, tashkentDayStart } from '../../common/time/tashkent';
import { actorCan, assertCan, SchoolActor } from '../auth/school-actor';
import { notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { computeCareAggregate, trendPoint } from './care-aggregate';
import { CareStore, toQuestionView, toSurveyView } from './care-store';
import { CARE_MIN_GROUP, maskSmallCount } from './care-suppression';
import { ageGroupOf, careAggregateQuerySchema as careAggregateQuery, CARE_TOPICS } from './care.schemas';

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

  /** So'rovnoma tanlovi — faqat sarlavha / hafta / holat; `ready` — natija ko'rsatiladimi. */
  async surveyOptions(actor: SchoolActor) {
    assertCan(actor, 'care.aggregate');
    const surveys = await this.published(actor.schoolId);
    return Promise.all(
      surveys.map(async (s) => ({
        id: s.id,
        title: s.title,
        weekStart: s.weekStart,
        status: s.status,
        ready: this.scoresVisible(actor, s) && (await this.store.respondentCount(s)) >= CARE_MIN_GROUP,
      })),
    );
  }

  /** O'tkazilgan so'rovnomalar (faqat o'qish) — mavzular; ishtirok faqat k ≥ 5 bo'lsa. */
  async surveySummaries(actor: SchoolActor) {
    assertCan(actor, 'care.aggregate');
    const [surveys, questions] = await Promise.all([this.published(actor.schoolId), this.store.questions(actor.schoolId)]);
    const topicOf = new Map(questions.map((q) => [q.id, toQuestionView(q).topic]));
    return Promise.all(
      surveys.map(async (s) => {
        const used = new Set(s.questionIds.map((id) => topicOf.get(id)));
        const respondents = await this.store.respondentCount(s);
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
    const { surveyId, breakdown } = parseOrThrow(careAggregateQuery, query);
    const [surveys, classes, questions] = await Promise.all([
      this.published(actor.schoolId),
      this.store.classes(actor.schoolId),
      this.store.questionMeta(actor.schoolId),
    ]);
    const survey = surveyId ? surveys.find((s) => s.id === surveyId) : await this.defaultSurvey(actor, surveys);
    if (!survey) throw notFound(surveyId ?? 'survey');
    const trend = [];
    const trendSurveys = surveys
      .filter((s) => s.weekStart <= survey.weekStart && this.scoresVisible(actor, s))
      .sort((a, b) => a.weekStart.localeCompare(b.weekStart))
      .slice(-TREND_SURVEYS);
    for (const s of trendSurveys) {
      const responses = (await this.store.responses(s.id)).filter((r) => s.ageGroups.includes(ageGroupOf(r.grade)));
      trend.push(...trendPoint(s.weekStart, responses, questions));
    }
    const requestsThisWeek = await this.requestsThisWeek(actor.schoolId);
    if (!this.scoresVisible(actor, survey)) {
      // Faol so'rovnoma (direktor / admin): faqat ishtirok, ko'rsatkichlarsiz.
      const respondents = await this.store.respondentCount(survey);
      return {
        surveyId: survey.id,
        invited: survey.invited,
        respondents,
        participationRate: percent(respondents, survey.invited),
        overall: {},
        groups: [],
        weeklyTrend: trend,
        requestsThisWeek: maskSmallCount(requestsThisWeek),
      };
    }
    return computeCareAggregate({
      survey,
      classes,
      responses: await this.store.responses(survey.id),
      questions,
      breakdown,
      trend,
      requestsThisWeek,
    });
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  /** Ko'rsatkichlar: psixolog — faol so'rovnomada ham; boshqalar — faqat yopilganda. */
  private scoresVisible(actor: SchoolActor, survey: SchoolCareSurvey): boolean {
    return survey.status === 'CLOSED' || actorCan(actor, 'care.individual');
  }

  private async published(schoolId: string): Promise<SchoolCareSurvey[]> {
    const surveys = await this.prisma.schoolCareSurvey.findMany({ where: { schoolId, status: { not: 'DRAFT' } } });
    return surveys.sort(byRecency);
  }

  /** Eng so'nggi ko'rsatkichi ko'rinadigan va kamida K respondentli; bo'lmasa — eng so'nggisi. */
  private async defaultSurvey(actor: SchoolActor, surveys: SchoolCareSurvey[]): Promise<SchoolCareSurvey | undefined> {
    for (const s of surveys) {
      if (this.scoresVisible(actor, s) && (await this.store.respondentCount(s)) >= CARE_MIN_GROUP) return s;
    }
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
