// Bola ovozi — umumlashgan natija (sof funksiyalar; panel `care-aggregate.ts`
// bilan bir xil qoidalar). Natijada studentId, matn yoki alohida javob YO'Q —
// faqat guruh sonlari va 0..100 ko'rsatkichlar (yuqori = yaxshi holat).

import { compareClasses } from '../common/list-query';
import { Atom, buildAtoms, CARE_MIN_GROUP, ClassCell, isUnionOfAtoms, maskSmallCount } from './care-suppression';
import { AGE_GROUPS, ageGroupOf, AgeGroup, CARE_TOPICS, CareBreakdown, CareTopic } from './care.schemas';

export type TopicScores = Partial<Record<CareTopic, number>>;
export interface QuestionMeta {
  topic: CareTopic;
  reverse: boolean;
}
export type Questions = ReadonlyMap<string, QuestionMeta>;
export interface ResponseRow {
  studentId: string;
  classId: string;
  /** Javob berilgan paytdagi sinf darajasi (nusxa — keyingi tahrirlar natijaga ta'sir qilmaydi). */
  grade: number;
  answers: Record<string, number>;
}
export interface ClassRow {
  id: string;
  name: string;
  grade: number;
  letter: string;
}

type TopicStat = { score: number; respondents: number };
type Bucket = { key: string; label: string; classIds: ReadonlySet<string>; responses: ResponseRow[] };
type Plan = { any: Atom[]; byTopic: ReadonlyMap<CareTopic, Atom[]> };

const validAnswer = (raw: unknown): raw is number => typeof raw === 'number' && Number.isFinite(raw) && raw >= 1 && raw <= 5;
const percent = (part: number, total: number) => (total > 0 ? Math.round((part / total) * 100) : 0);

export const distinctRespondents = (responses: readonly ResponseRow[]) => new Set(responses.map((r) => r.studentId)).size;

function answeredTopics(response: ResponseRow, questions: Questions): Set<CareTopic> {
  const topics = new Set<CareTopic>();
  for (const [questionId, raw] of Object.entries(response.answers)) {
    const question = questions.get(questionId);
    if (question && validAnswer(raw)) topics.add(question.topic);
  }
  return topics;
}

/** Mavzu bo'yicha: 1..5 → 0..100 (teskari savollar aylantiriladi) va distinct respondentlar. */
function topicStats(responses: readonly ResponseRow[], questions: Questions): Map<CareTopic, TopicStat> {
  const acc = new Map<CareTopic, { sum: number; answers: number; people: Set<string> }>();
  for (const response of responses) {
    for (const [questionId, raw] of Object.entries(response.answers)) {
      const question = questions.get(questionId);
      if (!question || !validAnswer(raw)) continue;
      const entry = acc.get(question.topic) ?? { sum: 0, answers: 0, people: new Set<string>() };
      entry.people.add(response.studentId);
      acc.set(question.topic, { sum: entry.sum + (question.reverse ? 6 - raw : raw), answers: entry.answers + 1, people: entry.people });
    }
  }
  return new Map([...acc].map(([topic, e]) => [topic, { score: Math.round(((e.sum / e.answers - 1) / 4) * 100), respondents: e.people.size }]));
}

/** Mavzu ko'rsatkichlari — faqat ≥ K distinct respondent javob bergan mavzular. */
export function topicScores(responses: readonly ResponseRow[], questions: Questions, k = CARE_MIN_GROUP): TopicScores {
  const stats = topicStats(responses, questions);
  return Object.fromEntries(
    CARE_TOPICS.flatMap((topic) => {
      const stat = stats.get(topic);
      return stat && stat.respondents >= k ? [[topic, stat.score]] : [];
    }),
  );
}

export function targetClasses<T extends ClassRow>(classes: readonly T[], ageGroups: readonly string[]): T[] {
  return classes.filter((c) => ageGroups.includes(ageGroupOf(c.grade))).sort(compareClasses);
}

/**
 * Guruhlash uchun sinflar — javoblardagi nusxadan (sinf id + javob paytidagi daraja).
 * Sinf darajasini keyin tahrirlash yoki sinfni o'chirish guruhlarni o'zgartirib,
 * ayirish orqali kichik guruhni ochib qo'ya olmaydi. Javobsiz sinflar (n = 0)
 * faqat ko'rsatish uchun joriy jadvaldan qo'shiladi — ular hech narsa ochmaydi.
 */
export function snapshotClasses(responses: readonly ResponseRow[], live: readonly ClassRow[], ageGroups: readonly string[]): ClassRow[] {
  const byId = new Map(live.map((c) => [c.id, c]));
  const seen = new Map<string, ClassRow>();
  for (const r of responses) {
    if (seen.has(r.classId)) continue;
    const current = byId.get(r.classId);
    seen.set(r.classId, { id: r.classId, name: current?.name ?? '—', grade: r.grade, letter: current?.letter ?? '' });
  }
  const empty = targetClasses(live, ageGroups).filter((c) => !seen.has(c.id));
  return [...seen.values(), ...empty];
}

function suppressionPlan(classes: readonly ClassRow[], responses: readonly ResponseRow[], questions: Questions): Plan {
  const perClass = new Map<string, ResponseRow[]>();
  for (const r of responses) perClass.set(r.classId, [...(perClass.get(r.classId) ?? []), r]);
  const cells = (count: (items: readonly ResponseRow[]) => number): ClassCell[] =>
    classes.map((c) => ({ classId: c.id, grade: c.grade, ageGroup: ageGroupOf(c.grade), n: count(perClass.get(c.id) ?? []) }));
  const forTopic = (topic: CareTopic) => (items: readonly ResponseRow[]) =>
    distinctRespondents(items.filter((r) => answeredTopics(r, questions).has(topic)));
  return {
    any: buildAtoms(cells(distinctRespondents)),
    byTopic: new Map(CARE_TOPICS.map((topic) => [topic, buildAtoms(cells(forTopic(topic)))])),
  };
}

function buckets(classes: readonly ClassRow[], ageGroups: readonly string[], breakdown: CareBreakdown, responses: ResponseRow[]): Bucket[] {
  const make = (key: string, label: string, members: readonly ClassRow[]): Bucket => {
    const classIds = new Set(members.map((c) => c.id));
    return { key, label, classIds, responses: responses.filter((r) => classIds.has(r.classId)) };
  };
  switch (breakdown) {
    case 'SCHOOL':
      return [make('SCHOOL', 'SCHOOL', classes)];
    case 'AGE_GROUP':
      return AGE_GROUPS.filter((g: AgeGroup) => ageGroups.includes(g)).map((g) => make(g, g, classes.filter((c) => ageGroupOf(c.grade) === g)));
    case 'GRADE':
      return [...new Set(classes.map((c) => c.grade))].map((grade) => make(String(grade), String(grade), classes.filter((c) => c.grade === grade)));
    case 'CLASS':
      return classes.map((c) => make(c.id, c.name, [c]));
  }
}

function publishGroup(bucket: Bucket, plan: Plan, questions: Questions) {
  const respondents = distinctRespondents(bucket.responses);
  if (respondents < CARE_MIN_GROUP || !isUnionOfAtoms(bucket.classIds, plan.any)) {
    return { key: bucket.key, label: bucket.label, respondents: 0, hidden: true, topicScores: null };
  }
  const stats = topicStats(bucket.responses, questions);
  const scores: TopicScores = Object.fromEntries(
    CARE_TOPICS.flatMap((topic) => {
      const stat = stats.get(topic);
      const safe = stat && stat.respondents >= CARE_MIN_GROUP && isUnionOfAtoms(bucket.classIds, plan.byTopic.get(topic) ?? []);
      return safe ? [[topic, stat.score]] : [];
    }),
  );
  return { key: bucket.key, label: bucket.label, respondents, hidden: false, topicScores: scores };
}

/** Haftalik trend nuqtasi — faqat maktab darajasi, k ≥ 5. */
export function trendPoint(weekStart: string, responses: readonly ResponseRow[], questions: Questions) {
  const respondents = distinctRespondents(responses);
  const scores = topicScores(responses, questions);
  const values = Object.values(scores);
  const wellbeing = scores.WELLBEING ?? (values.length ? Math.round(values.reduce((a, b) => a + b, 0) / values.length) : null);
  return respondents >= CARE_MIN_GROUP && wellbeing !== null ? [{ weekStart, respondents, wellbeing }] : [];
}

export function computeCareAggregate(input: {
  survey: { id: string; invited: number; ageGroups: readonly string[] };
  classes: readonly ClassRow[];
  responses: ResponseRow[];
  questions: Questions;
  breakdown: CareBreakdown;
  trend: Array<{ weekStart: string; respondents: number; wellbeing: number }>;
  requestsThisWeek: number;
}) {
  const inTarget = input.responses.filter((r) => input.survey.ageGroups.includes(ageGroupOf(r.grade)));
  const classes = targetClasses(snapshotClasses(inTarget, input.classes, input.survey.ageGroups), input.survey.ageGroups);
  const ids = new Set(classes.map((c) => c.id));
  const responses = inTarget.filter((r) => ids.has(r.classId));
  const respondents = distinctRespondents(responses);
  const plan = suppressionPlan(classes, responses, input.questions);
  return {
    surveyId: input.survey.id,
    invited: input.survey.invited,
    respondents,
    participationRate: percent(respondents, input.survey.invited),
    overall: respondents >= CARE_MIN_GROUP ? topicScores(responses, input.questions) : {},
    groups: buckets(classes, input.survey.ageGroups, input.breakdown, responses).map((b) => publishGroup(b, plan, input.questions)),
    weeklyTrend: input.trend,
    requestsThisWeek: maskSmallCount(input.requestsThisWeek),
  };
}
