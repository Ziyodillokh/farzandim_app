// DB yozuvlari va domen kodlari → API ko'rinishlari. Natijada faqat kodlar
// va ballar saqlanadi; mahalliylashtirilgan matnlar shu yerda `texts.ts`dan
// qo'shiladi (matn tahrirlansa, eski natijalar ham yangi matn bilan chiqadi).
// wellbeing / safety raqamlari hech qaysi ko'rinishga chiqmaydi.

import { KelajakQuestion, KelajakSession, Prisma } from '@prisma/client';
import { KelajakAge } from './domain/age';
import { careerLabLabel } from './domain/career-lab';
import {
  categoryDef,
  isKelajakTestType,
  isParentVisibleCategory,
  isSupportCategory,
  KELAJAK_CATEGORIES,
  TEXT_ANSWER_MAX_LENGTH,
} from './domain/catalog';
import { CareerLabRating, CATEGORY_MIN_ANSWERS, SupportSnapshot } from './domain/insights';
import { L } from './domain/localized';
import { KelajakInsightCodes, KelajakProfile, KelajakResultData } from './domain/profile';
import { KelajakProgress } from './domain/progress';
import { CategoryScore, InterestScores } from './domain/scoring';
import {
  DISCLAIMERS,
  GROWTH_TEXTS,
  nextText,
  RIASEC_TEXTS,
  STRENGTH_TEXTS,
  SUPPORT_CHILD_TEXTS,
  SUPPORT_PARENT_TEXTS,
  TEST_TEXTS,
} from './domain/texts';
import {
  AgeView,
  CategoryScoreView,
  DirectionView,
  InsightsView,
  InterestsView,
  OverviewView,
  ParentInsightsView,
  ParentSupportView,
  ProfileView,
  ProgressCategoryView,
  ProgressInterestView,
  ResultView,
  SessionAnswerView,
  SessionQuestionView,
  SessionSummaryView,
  SessionView,
} from './kelajak.views';

/** Career Lab faoliyati nomi (`externalId` → matn). */
export type ActivityLabel = (externalId: string) => L;

/** Xaritadagi nom, bo'lmasa (admin qo'shgan savol) savol matni. */
export function activityLabeler(fallback: ReadonlyMap<string, L>): ActivityLabel {
  return (externalId) => careerLabLabel(externalId) ?? fallback.get(externalId) ?? { uz: externalId };
}

/** Insight kodlaridagi Career Lab faoliyatlari (matni kerak bo'ladiganlar). */
export function activityIds(codes: KelajakInsightCodes): string[] {
  const ids = [
    ...codes.careerLab.map((r) => r.externalId),
    ...codes.next.flatMap((n) => (n.externalId ? [n.externalId] : [])),
  ];
  return [...new Set(ids)];
}

export function categoryName(id: string): L {
  return categoryDef(id)?.name ?? { uz: id };
}

export function testTitle(type: string): L {
  return isKelajakTestType(type) ? TEST_TEXTS[type].title : { uz: type };
}

export function toAgeView(age: KelajakAge): AgeView {
  return { status: age.status, age: age.age, ageGroup: age.ageGroup };
}

export function toOverviewCategories(): OverviewView['categories'] {
  return KELAJAK_CATEGORIES.map((c) => ({ id: c.id, name: c.name, order: c.order }));
}

export function toCategoryScoreViews(scores: readonly CategoryScore[]): CategoryScoreView[] {
  return scores.map((c) => ({ category: c.category, name: categoryName(c.category), score: c.score, answered: c.answered }));
}

export function toInterestsView(scores: InterestScores | null): InterestsView | null {
  if (!scores) return null;
  return {
    dimensions: scores.dimensions.map((d) => ({
      code: d.code,
      name: RIASEC_TEXTS[d.code].name,
      score: d.score,
      answered: d.answered,
    })),
    top: [...scores.top],
    reliable: scores.reliable,
  };
}

const toDirection = (r: CareerLabRating, label: ActivityLabel): DirectionView => ({
  externalId: r.externalId,
  activity: label(r.externalId),
  code: r.code,
  rating: r.rating,
});

export function toInsightsView(codes: KelajakInsightCodes, label: ActivityLabel): InsightsView {
  return {
    strengths: codes.strengths.map((key) => ({ key, title: STRENGTH_TEXTS[key].title })),
    interests: codes.interests.map((code) => ({
      code,
      title: RIASEC_TEXTS[code].title,
      body: RIASEC_TEXTS[code].body,
      suggestions: [...RIASEC_TEXTS[code].suggestions],
    })),
    likedDirections: codes.careerLab.filter((r) => r.verdict === 'liked').map((r) => toDirection(r, label)),
    triedDirections: codes.careerLab.map((r) => ({ ...toDirection(r, label), verdict: r.verdict })),
    growthAreas: codes.growthAreas.map((key) => ({ key, title: GROWTH_TEXTS[key].title, tip: GROWTH_TEXTS[key].tip })),
    support: codes.support ? { level: codes.support, message: SUPPORT_CHILD_TEXTS[codes.support] } : null,
    next: codes.next.map((code) => ({
      kind: code.kind,
      testType: code.testType,
      externalId: code.externalId,
      ...nextText(code, code.externalId ? label(code.externalId) : null),
    })),
  };
}

/**
 * Ota-onaga: qo'llab-quvvatlash alohida (`toParentSupportView`), bolaga
 * yozilgan matnsiz; Career Lab — faoliyat va xulosa (savol id'si va xom
 * reytingsiz, tavsiyada ham id yo'q); `parent_communication` yorliqlari yo'q.
 */
export function toParentInsightsView(codes: KelajakInsightCodes, label: ActivityLabel): ParentInsightsView {
  const view = toInsightsView(codes, label);
  return {
    strengths: view.strengths.filter((s) => isParentVisibleCategory(s.key)),
    interests: view.interests,
    likedDirections: view.likedDirections.map(({ activity, code }) => ({ activity, code })),
    triedDirections: view.triedDirections.map(({ activity, code, verdict }) => ({ activity, code, verdict })),
    growthAreas: view.growthAreas.filter((g) => isParentVisibleCategory(g.key)),
    // Faoliyat nomi matnda; savol id'si ota-onaga berilmaydi.
    next: view.next.map((n) => ({ ...n, externalId: null })),
  };
}

/** Ota-onaga kategoriyalar: yashirinlari yo'q va kamida 2 javob (bitta javob = savol darajasi). */
export function isParentVisibleScore(c: { category: string; answered: number }): boolean {
  return isParentVisibleCategory(c.category) && c.answered >= CATEGORY_MIN_ANSWERS;
}

export function toResultView(
  result: KelajakResultData,
  counts: { answered: number; total: number },
  label: ActivityLabel,
): ResultView {
  return {
    answered: counts.answered,
    total: counts.total,
    categories: toCategoryScoreViews(result.scores.categories),
    interests: toInterestsView(result.scores.interests),
    insights: toInsightsView(result.insightCodes, label),
    disclaimer: DISCLAIMERS.child,
  };
}

/** Yakunlangan sessiya yo'q (`updatedAt` null) — profil yo'q. */
export function toProfileView(
  profile: KelajakProfile,
  availableQuestions: number,
  label: ActivityLabel,
): ProfileView | null {
  if (!profile.updatedAt) return null;
  return {
    updatedAt: profile.updatedAt,
    answeredQuestions: profile.answeredQuestions,
    availableQuestions,
    categories: toCategoryScoreViews(profile.categories),
    interests: toInterestsView(profile.interests),
    insights: toInsightsView(profile.insightCodes, label),
    disclaimer: DISCLAIMERS.child,
  };
}

export function toSessionQuestionView(q: KelajakQuestion): SessionQuestionView {
  return {
    id: q.id,
    externalId: q.externalId,
    category: q.category,
    categoryName: categoryName(q.category),
    text: q.text as unknown as L,
    answerType: q.answerType,
    options: q.options as unknown as SessionQuestionView['options'],
    required: q.required,
    maxLength: q.answerType === 'text' ? TEXT_ANSWER_MAX_LENGTH : null,
  };
}

/**
 * Sessiya javoblari. Yopiq (COMPLETED / ABANDONED) sessiyada ochiq matn va
 * wellbeing / safety qiymatlari qaytarilmaydi: "orqaga" faqat ochiq sessiyada
 * kerak, keyin esa shu bolaga ulangan boshqa qurilma ham ularni o'qiy olmaydi.
 */
export function toSessionAnswerViews(params: {
  open: boolean;
  questions: readonly Pick<KelajakQuestion, 'id' | 'category'>[];
  answers: readonly SessionAnswerView[];
}): SessionAnswerView[] {
  const { open, questions, answers } = params;
  if (open) return [...answers];
  const hidden = new Set(questions.filter((q) => isSupportCategory(q.category)).map((q) => q.id));
  return answers.map((a) => ({
    questionId: a.questionId,
    value: hidden.has(a.questionId) ? null : a.value,
    text: null,
  }));
}

export function toSessionView(params: {
  session: KelajakSession;
  questions: readonly KelajakQuestion[];
  answers: readonly SessionAnswerView[];
  label: ActivityLabel;
}): SessionView {
  const { session, questions, answers, label } = params;
  const result = session.status === 'COMPLETED' ? parseStoredResult(session.result) : null;
  const open = session.status === 'STARTED' || session.status === 'IN_PROGRESS';
  return {
    id: session.id,
    type: session.type,
    title: testTitle(session.type),
    ageGroup: session.ageGroup,
    day: session.day,
    status: session.status,
    startedAt: session.startedAt,
    completedAt: session.completedAt,
    total: session.total,
    answeredCount: answers.length,
    questions: questions.map(toSessionQuestionView),
    answers: toSessionAnswerViews({ open, questions, answers }),
    result: result ? toResultView(result, { answered: answers.length, total: session.total }, label) : null,
  };
}

export function toSessionSummaryView(session: KelajakSession & { answered: number }): SessionSummaryView {
  return {
    id: session.id,
    type: session.type,
    title: testTitle(session.type),
    day: session.day,
    status: session.status,
    completedAt: session.completedAt,
    answered: session.answered,
    total: session.total,
  };
}

export function toProgressViews(progress: KelajakProgress): {
  categories: ProgressCategoryView[];
  interests: ProgressInterestView[];
} {
  return {
    categories: progress.categories.map((t) => ({
      category: t.key,
      name: categoryName(t.key),
      latest: t.latest,
      previous: t.previous,
      delta: t.delta,
      points: t.points,
    })),
    interests: progress.interests.map((t) => ({
      code: t.key,
      name: RIASEC_TEXTS[t.key].name,
      latest: t.latest,
      previous: t.previous,
      delta: t.delta,
    })),
  };
}

/** Ota-onaga: faqat daraja, soha nomi, kun va yo'l-yo'riq; `none` — null. */
export function toParentSupportView(snapshot: SupportSnapshot | null): ParentSupportView | null {
  if (!snapshot || snapshot.level === 'none') return null;
  return {
    level: snapshot.level,
    areas: snapshot.areas.map((key) => ({ key, name: categoryName(key) })),
    day: snapshot.day,
    guidance: SUPPORT_PARENT_TEXTS[snapshot.level],
  };
}

const isRecord = (v: unknown): v is Record<string, unknown> => !!v && typeof v === 'object' && !Array.isArray(v);

/** `kelajak_sessions.result` (o'zimiz yozgan JSON) — shakli mos bo'lmasa null. */
export function parseStoredResult(value: Prisma.JsonValue | null): KelajakResultData | null {
  if (!isRecord(value) || typeof value.version !== 'number') return null;
  if (!isRecord(value.scores) || !isRecord(value.insightCodes)) return null;
  return value as unknown as KelajakResultData;
}
