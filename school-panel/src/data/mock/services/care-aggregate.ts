import type {
  CareAggregate,
  CareAggregateGroup,
  CareQuestion,
  CareResponse,
  CareSurvey,
  CareTopic,
  IsoDate,
  SchoolClass,
} from '@/data/contracts';
import { AGE_GROUPS, CARE_TOPICS, type CareBreakdown } from '@/data/schemas/care';
import { CARE_MIN_GROUP, maskSmallCount } from '@/lib/k-anon';
import { percent } from '@/lib/utils';
import { addDays, toIsoDate, weekStart } from '../calendar';
import { compareClasses } from '../lookups';
import { ageGroupOf } from '../seed/care';
import type { Tables } from '../tables';
import { type Atom, buildAtoms, type ClassCell, isUnionOfAtoms } from './care-suppression';

/**
 * Bola ovozi — umumlashgan natija (direktor, admin, psixolog; dashboard va hisobotlar ham).
 *
 * Maxfiylik qoidalari:
 * - FAQAT `careResponses` jadvalidan hisoblanadi; natijada studentId, matn yoki alohida
 *   javob yo'q — faqat guruh sonlari va 0..100 ko'rsatkichlar.
 * - Yashirish barcha kesimlar (maktab / yosh guruhi / parallel / sinf) uchun umumiy
 *   atomlar asosida — bir kesimni boshqasidan ayirib yashirin guruhni topib bo'lmaydi
 *   (isbot: `care-suppression.ts`).
 * - Mavzu ko'rsatkichi faqat shu mavzuga kamida K ta DISTINCT respondent javob bergan
 *   va guruh shu mavzu atomlarining to'liq birlashmasi bo'lsa chiqariladi (maktab
 *   o'rtachasi uchun ham).
 * - Yashirilgan guruhning respondentlar soni ham ko'rsatilmaydi (0).
 */

type TopicScores = Partial<Record<CareTopic, number>>;
type TopicStat = { score: number; respondents: number };
type Bucket = { key: string; label: string; classIds: ReadonlySet<string>; responses: CareResponse[] };
type Plan = { any: Atom[]; byTopic: ReadonlyMap<CareTopic, Atom[]> };
type Questions = ReadonlyMap<string, CareQuestion>;

const TREND_SURVEYS = 4;

/** Javobning yaroqli bo'lgan savollari bo'yicha mavzular. */
function answeredTopics(response: CareResponse, questions: Questions): Set<CareTopic> {
  const topics = new Set<CareTopic>();
  for (const [questionId, raw] of Object.entries(response.answers)) {
    const question = questions.get(questionId);
    if (question && Number.isFinite(raw) && raw >= 1 && raw <= 5) topics.add(question.topic);
  }
  return topics;
}

function distinctRespondents(responses: readonly CareResponse[]): number {
  return new Set(responses.map((r) => r.studentId)).size;
}

/** Mavzu bo'yicha: 1..5 → 0..100 (teskari savollar aylantiriladi) va distinct respondentlar soni. */
function topicStats(responses: readonly CareResponse[], questions: Questions): Map<CareTopic, TopicStat> {
  const acc = new Map<CareTopic, { sum: number; answers: number; people: Set<string> }>();
  for (const response of responses) {
    for (const [questionId, raw] of Object.entries(response.answers)) {
      const question = questions.get(questionId);
      if (!question || !Number.isFinite(raw) || raw < 1 || raw > 5) continue;
      const entry = acc.get(question.topic) ?? { sum: 0, answers: 0, people: new Set<string>() };
      entry.people.add(response.studentId);
      acc.set(question.topic, { sum: entry.sum + (question.reverse ? 6 - raw : raw), answers: entry.answers + 1, people: entry.people });
    }
  }
  return new Map(
    [...acc].map(([topic, e]) => [topic, { score: Math.round(((e.sum / e.answers - 1) / 4) * 100), respondents: e.people.size }]),
  );
}

/** Mavzu ko'rsatkichlari — faqat ≥ K distinct respondent javob bergan mavzular. */
export function topicScores(responses: readonly CareResponse[], questions: Questions, k: number = CARE_MIN_GROUP): TopicScores {
  const stats = topicStats(responses, questions);
  return Object.fromEntries(
    CARE_TOPICS.flatMap((topic) => {
      const stat = stats.get(topic);
      return stat && stat.respondents >= k ? [[topic, stat.score]] : [];
    }),
  ) as TopicScores;
}

function targetClasses(tables: Tables, survey: CareSurvey): SchoolClass[] {
  return tables.classes.filter((c) => survey.ageGroups.includes(ageGroupOf(c.grade))).sort(compareClasses);
}

/** Yashirish rejasi: umumiy atomlar (respondentlar) va har mavzu uchun alohida atomlar. */
function suppressionPlan(classes: readonly SchoolClass[], responses: readonly CareResponse[], questions: Questions): Plan {
  const perClass = new Map<string, CareResponse[]>();
  for (const r of responses) perClass.set(r.classId, [...(perClass.get(r.classId) ?? []), r]);
  const cells = (count: (items: readonly CareResponse[]) => number): ClassCell[] =>
    classes.map((c) => ({ classId: c.id, grade: c.grade, ageGroup: ageGroupOf(c.grade), n: count(perClass.get(c.id) ?? []) }));
  const forTopic = (topic: CareTopic) => (items: readonly CareResponse[]) =>
    distinctRespondents(items.filter((r) => answeredTopics(r, questions).has(topic)));
  return {
    any: buildAtoms(cells(distinctRespondents)),
    byTopic: new Map(CARE_TOPICS.map((topic) => [topic, buildAtoms(cells(forTopic(topic)))])),
  };
}

function buckets(classes: readonly SchoolClass[], survey: CareSurvey, breakdown: CareBreakdown, responses: CareResponse[]): Bucket[] {
  const make = (key: string, label: string, members: readonly SchoolClass[]): Bucket => {
    const classIds = new Set(members.map((c) => c.id));
    return { key, label, classIds, responses: responses.filter((r) => classIds.has(r.classId)) };
  };
  switch (breakdown) {
    case 'SCHOOL':
      return [make('SCHOOL', 'SCHOOL', classes)];
    case 'AGE_GROUP':
      return AGE_GROUPS.filter((g) => survey.ageGroups.includes(g)).map((g) => make(g, g, classes.filter((c) => ageGroupOf(c.grade) === g)));
    case 'GRADE':
      return [...new Set(classes.map((c) => c.grade))].map((grade) => make(String(grade), String(grade), classes.filter((c) => c.grade === grade)));
    case 'CLASS':
      return classes.map((c) => make(c.id, c.name, [c]));
  }
}

function publishGroup(bucket: Bucket, plan: Plan, questions: Questions): CareAggregateGroup {
  const respondents = distinctRespondents(bucket.responses);
  if (respondents < CARE_MIN_GROUP || !isUnionOfAtoms(bucket.classIds, plan.any)) {
    return { key: bucket.key, label: bucket.label, respondents: 0, hidden: true, topicScores: null };
  }
  const stats = topicStats(bucket.responses, questions);
  const scores = Object.fromEntries(
    CARE_TOPICS.flatMap((topic) => {
      const stat = stats.get(topic);
      const safe = stat && stat.respondents >= CARE_MIN_GROUP && isUnionOfAtoms(bucket.classIds, plan.byTopic.get(topic) ?? []);
      return safe ? [[topic, stat.score]] : [];
    }),
  ) as TopicScores;
  return { key: bucket.key, label: bucket.label, respondents, hidden: false, topicScores: scores };
}

function surveyResponses(tables: Tables, survey: CareSurvey, classes: readonly SchoolClass[]): CareResponse[] {
  const ids = new Set(classes.map((c) => c.id));
  return tables.careResponses.filter((r) => r.surveyId === survey.id && ids.has(r.classId));
}

/** Oxirgi 4 so'rovnoma — faqat maktab darajasi, k ≥ 5 bo'lgan haftalar. */
function weeklyTrend(tables: Tables, survey: CareSurvey, questions: Questions): CareAggregate['weeklyTrend'] {
  return tables.careSurveys
    .filter((s) => s.status !== 'DRAFT' && s.weekStart <= survey.weekStart)
    .sort((a, b) => a.weekStart.localeCompare(b.weekStart))
    .slice(-TREND_SURVEYS)
    .flatMap((s) => {
      const responses = surveyResponses(tables, s, targetClasses(tables, s));
      const respondents = distinctRespondents(responses);
      const scores = topicScores(responses, questions);
      const values = Object.values(scores);
      const wellbeing = scores.WELLBEING ?? (values.length ? Math.round(values.reduce((a, b) => a + b, 0) / values.length) : null);
      return respondents >= CARE_MIN_GROUP && wellbeing !== null ? [{ weekStart: s.weekStart, respondents, wellbeing }] : [];
    });
}

function requestsThisWeek(tables: Tables, today: IsoDate): string {
  const start = weekStart(today);
  const end = addDays(start, 7);
  const count = tables.careRequests.filter((r) => {
    const day = toIsoDate(new Date(r.createdAt));
    return day >= start && day < end;
  }).length;
  return maskSmallCount(count);
}

/** So'rovnomaning distinct respondentlari — maqsadli sinflar bo'yicha (/care natijasi bilan bir xil). */
export function surveyRespondentCount(tables: Tables, survey: CareSurvey): number {
  return distinctRespondents(surveyResponses(tables, survey, targetClasses(tables, survey)));
}

/** Natija ko'rsatishga tayyormi: kamida K distinct respondent. */
export function isSurveyReady(tables: Tables, survey: CareSurvey): boolean {
  return surveyRespondentCount(tables, survey) >= CARE_MIN_GROUP;
}

/** Yangisi birinchi: hafta boshi, so'ng faollashtirilgan vaqt. */
export function compareSurveysByRecency(a: CareSurvey, b: CareSurvey): number {
  return b.weekStart.localeCompare(a.weekStart) || (b.activatedAt ?? '').localeCompare(a.activatedAt ?? '');
}

/**
 * So'rovnoma tanlanmasa: eng so'nggi qoralama bo'lmagan va kamida K distinct respondentli
 * so'rovnoma; bunday yo'q bo'lsa — eng so'nggi qoralama bo'lmagani. Shu tufayli yangi
 * faollashtirilgan (hali javobsiz) so'rovnoma direktor ko'rinishini bo'shatib qo'ymaydi.
 * `surveys` — nomzodlar (masalan, oylik hisobotda faqat shu oy so'rovnomalari).
 */
export function defaultSurvey(tables: Tables, surveys: readonly CareSurvey[] = tables.careSurveys): CareSurvey | undefined {
  const published = surveys.filter((s) => s.status !== 'DRAFT').sort(compareSurveysByRecency);
  return published.find((s) => isSurveyReady(tables, s)) ?? published[0];
}

export function computeCareAggregate(tables: Tables, survey: CareSurvey, breakdown: CareBreakdown, today: IsoDate): CareAggregate {
  const questions = new Map(tables.careQuestions.map((q) => [q.id, q]));
  const classes = targetClasses(tables, survey);
  const responses = surveyResponses(tables, survey, classes);
  const respondents = distinctRespondents(responses);
  const plan = suppressionPlan(classes, responses, questions);
  return {
    surveyId: survey.id,
    invited: survey.invited,
    respondents,
    participationRate: percent(respondents, survey.invited),
    overall: respondents >= CARE_MIN_GROUP ? topicScores(responses, questions) : {},
    groups: buckets(classes, survey, breakdown, responses).map((b) => publishGroup(b, plan, questions)),
    weeklyTrend: weeklyTrend(tables, survey, questions),
    requestsThisWeek: requestsThisWeek(tables, today),
  };
}
