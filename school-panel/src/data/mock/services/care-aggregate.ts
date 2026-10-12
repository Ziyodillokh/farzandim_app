import type {
  CareAggregate,
  CareAggregateGroup,
  CareQuestion,
  CareResponse,
  CareSurvey,
  CareTopic,
  IsoDate,
} from '@/data/contracts';
import { AGE_GROUPS, CARE_TOPICS, type CareBreakdown } from '@/data/schemas/care';
import { applyKAnonymity, CARE_MIN_GROUP, maskSmallCount, type MaskedGroup } from '@/lib/k-anon';
import { percent } from '@/lib/utils';
import { addDays, toIsoDate, weekStart } from '../calendar';
import { compareClasses } from '../lookups';
import { ageGroupOf } from '../seed/care';
import type { Tables } from '../tables';

/**
 * Bola ovozi — umumlashgan natija (direktor, admin, psixolog).
 *
 * Maxfiylik qoidalari:
 * - FAQAT `careResponses` jadvalidan hisoblanadi; natijada studentId, matn yoki
 *   alohida javob yo'q — faqat guruh sonlari va 0..100 ko'rsatkichlar.
 * - Respondentlari K (5) dan kam guruh yashiriladi; bitta guruh yashirilsa —
 *   ayirish orqali topib bo'lmasligi uchun keyingi eng kichik guruh ham.
 *   Yashirilgan guruhlar yig'indisi ham K dan kam bo'lsa — yana bittasi.
 * - Yashirilgan guruhning respondentlar soni ham ko'rsatilmaydi (0).
 */

type TopicScores = Partial<Record<CareTopic, number>>;
type Bucket = { key: string; label: string; responses: CareResponse[] };

const TREND_SURVEYS = 4;

/** Javoblar → mavzu ko'rsatkichlari. 1..5 → 0..100; teskari savollar aylantiriladi (yuqori = yaxshi). */
export function topicScores(responses: readonly CareResponse[], questions: ReadonlyMap<string, CareQuestion>): TopicScores {
  const sums = new Map<CareTopic, { sum: number; n: number }>();
  for (const response of responses) {
    for (const [questionId, raw] of Object.entries(response.answers)) {
      const question = questions.get(questionId);
      if (!question || !Number.isFinite(raw) || raw < 1 || raw > 5) continue;
      const good = question.reverse ? 6 - raw : raw;
      const acc = sums.get(question.topic) ?? { sum: 0, n: 0 };
      sums.set(question.topic, { sum: acc.sum + good, n: acc.n + 1 });
    }
  }
  const out: TopicScores = {};
  for (const topic of CARE_TOPICS) {
    const acc = sums.get(topic);
    if (acc && acc.n > 0) out[topic] = Math.round(((acc.sum / acc.n - 1) / 4) * 100);
  }
  return out;
}

function buckets(tables: Tables, survey: CareSurvey, breakdown: CareBreakdown, responses: CareResponse[]): Bucket[] {
  const targetClasses = tables.classes
    .filter((c) => survey.ageGroups.includes(ageGroupOf(c.grade)))
    .sort(compareClasses);
  switch (breakdown) {
    case 'SCHOOL':
      return [{ key: 'SCHOOL', label: tables.school.shortName, responses }];
    case 'AGE_GROUP':
      return AGE_GROUPS.filter((g) => survey.ageGroups.includes(g)).map((g) => ({
        key: g,
        label: g,
        responses: responses.filter((r) => ageGroupOf(r.grade) === g),
      }));
    case 'GRADE':
      return [...new Set(targetClasses.map((c) => c.grade))].map((grade) => ({
        key: String(grade),
        label: String(grade),
        responses: responses.filter((r) => r.grade === grade),
      }));
    case 'CLASS':
      return targetClasses.map((c) => ({ key: c.id, label: c.name, responses: responses.filter((r) => r.classId === c.id) }));
  }
}

/** Qo'shimcha yashirish: yashirin guruhlar yig'indisi ham K dan kam bo'lmasin. */
function complementarySuppression<T>(groups: MaskedGroup<T>[]): MaskedGroup<T>[] {
  let current = groups;
  for (;;) {
    const hiddenTotal = current.filter((g) => g.hidden).reduce((sum, g) => sum + g.respondents, 0);
    if (hiddenTotal === 0 || hiddenTotal >= CARE_MIN_GROUP) return current;
    const smallest = current
      .map((g, index) => ({ g, index }))
      .filter(({ g }) => !g.hidden)
      .sort((a, b) => a.g.respondents - b.g.respondents)[0];
    if (!smallest) return current;
    current = current.map((g, i) => (i === smallest.index ? { ...g, hidden: true } : g));
  }
}

/** Guruhlar → k-anonim natija. Bo'sh guruhlar (0 respondent) yashirin, lekin ikkilamchi yashirishga ta'sir qilmaydi. */
function maskGroups(list: Bucket[], questions: ReadonlyMap<string, CareQuestion>): CareAggregateGroup[] {
  const nonEmpty = list.filter((b) => b.responses.length > 0);
  const masked = complementarySuppression(
    applyKAnonymity(nonEmpty.map((b) => ({ key: b.key, label: b.label, respondents: b.responses.length, value: b.responses }))),
  );
  const byKey = new Map(masked.map((m) => [m.key, m]));
  return list.map((bucket) => {
    const m = byKey.get(bucket.key);
    if (!m || m.hidden) return { key: bucket.key, label: bucket.label, respondents: 0, hidden: true, topicScores: null };
    return { key: m.key, label: m.label, respondents: m.respondents, hidden: false, topicScores: topicScores(m.value, questions) };
  });
}

function weeklyTrend(tables: Tables, survey: CareSurvey, questions: ReadonlyMap<string, CareQuestion>): CareAggregate['weeklyTrend'] {
  return tables.careSurveys
    .filter((s) => s.status !== 'DRAFT' && s.weekStart <= survey.weekStart)
    .sort((a, b) => a.weekStart.localeCompare(b.weekStart))
    .slice(-TREND_SURVEYS)
    .map((s) => {
      const responses = tables.careResponses.filter((r) => r.surveyId === s.id);
      const scores = topicScores(responses, questions);
      const values = Object.values(scores);
      const fallback = values.length ? Math.round(values.reduce((a, b) => a + b, 0) / values.length) : 0;
      return { weekStart: s.weekStart, respondents: responses.length, wellbeing: scores.WELLBEING ?? fallback };
    })
    .filter((point) => point.respondents >= CARE_MIN_GROUP);
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

/** So'rovnoma tanlanmasa — eng so'nggi (qoralama bo'lmagan) so'rovnoma. */
export function defaultSurvey(surveys: readonly CareSurvey[]): CareSurvey | undefined {
  return [...surveys].filter((s) => s.status !== 'DRAFT').sort((a, b) => b.weekStart.localeCompare(a.weekStart))[0];
}

export function computeCareAggregate(tables: Tables, survey: CareSurvey, breakdown: CareBreakdown, today: IsoDate): CareAggregate {
  const questions = new Map(tables.careQuestions.map((q) => [q.id, q]));
  const responses = tables.careResponses.filter((r) => r.surveyId === survey.id);
  const respondents = responses.length;
  return {
    surveyId: survey.id,
    invited: survey.invited,
    respondents,
    participationRate: percent(respondents, survey.invited),
    overall: respondents >= CARE_MIN_GROUP ? topicScores(responses, questions) : {},
    groups: maskGroups(buckets(tables, survey, breakdown, responses), questions),
    weeklyTrend: weeklyTrend(tables, survey, questions),
    requestsThisWeek: requestsThisWeek(tables, today),
  };
}
