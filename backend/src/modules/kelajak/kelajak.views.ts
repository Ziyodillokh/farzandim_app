// Kelajak API ko'rinishlari — docs/KELAJAK-REJA.md §4 va §5 dagi kontrakt
// (bola, ota-ona ilovalari va admin-web shu shakllarga tayanadi).

import { KelajakAgeStatus } from './domain/age';
import { RiasecCode } from './domain/catalog';
import { L } from './domain/localized';
import { SupportLevel } from './domain/insights';

export interface AgeView {
  status: KelajakAgeStatus;
  age: number | null;
  ageGroup: string | null;
}

export type TodayStatus = 'NEW' | 'STARTED' | 'IN_PROGRESS' | 'COMPLETED';

export interface OverviewTestView {
  type: string;
  title: L;
  description: L;
  questionCount: number;
  estimatedMinutes: number;
  today: { status: TodayStatus; sessionId: string | null };
}

export interface OverviewView {
  age: AgeView;
  tests: OverviewTestView[];
  categories: Array<{ id: string; name: L; order: number }>;
  profile: ProfileView | null;
}

export interface SessionQuestionView {
  id: string;
  externalId: string;
  category: string;
  categoryName: L;
  text: L;
  answerType: string;
  options: Array<{ value: number; label: L }>;
  required: boolean;
  maxLength: number | null;
}

/**
 * `text` — faqat bolaga (ota-onaga hech qachon) va faqat ochiq sessiyada;
 * yopiq sessiyada `text` va wellbeing / safety `value`si — null.
 */
export interface SessionAnswerView {
  questionId: string;
  value: number | null;
  text: string | null;
}

export interface SessionView {
  id: string;
  type: string;
  title: L;
  ageGroup: string;
  day: string;
  status: 'STARTED' | 'IN_PROGRESS' | 'COMPLETED' | 'ABANDONED';
  startedAt: Date;
  completedAt: Date | null;
  total: number;
  answeredCount: number;
  questions: SessionQuestionView[];
  answers: SessionAnswerView[];
  result: ResultView | null;
}

export interface AnswerView {
  questionId: string;
  value: number | null;
  text: string | null;
  sessionStatus: string;
  answeredCount: number;
}

export interface CategoryScoreView {
  category: string;
  name: L;
  score: number;
  answered: number;
}

export interface InterestsView {
  dimensions: Array<{ code: RiasecCode; name: L; score: number; answered: number }>;
  top: string[];
  reliable: boolean;
}

export interface DirectionView {
  externalId: string;
  activity: L;
  code: string | null;
  rating: number;
}

/** Ota-onaga: faoliyat nomi va yo'nalishi — savol id'si va xom reytingsiz. */
export interface ParentDirectionView {
  activity: L;
  code: string | null;
}

export type CareerLabVerdictView = 'liked' | 'neutral' | 'disliked';

export interface NextView {
  kind: 'take_test' | 'career_lab' | 'come_back';
  testType: string | null;
  /** Career Lab faoliyati (`career_lab` turida), aks holda null. */
  externalId: string | null;
  title: L;
  body: L;
}

export interface InsightsView {
  strengths: Array<{ key: string; title: L }>;
  interests: Array<{ code: string; title: L; body: L; suggestions: L[] }>;
  likedDirections: DirectionView[];
  triedDirections: Array<DirectionView & { verdict: CareerLabVerdictView }>;
  growthAreas: Array<{ key: string; title: L; tip: L }>;
  /** Bolaga raqamsiz, mehribon matn. */
  support: { level: SupportLevel; message: L } | null;
  next: NextView[];
}

/** Ota-onaga: signal alohida (`ParentSupportView`), Career Lab — reytingsiz. */
export interface ParentInsightsView {
  strengths: InsightsView['strengths'];
  interests: InsightsView['interests'];
  likedDirections: ParentDirectionView[];
  triedDirections: Array<ParentDirectionView & { verdict: CareerLabVerdictView }>;
  growthAreas: InsightsView['growthAreas'];
  next: NextView[];
}

export interface ResultView {
  answered: number;
  total: number;
  /** Faqat ballanadigan kategoriyalar — wellbeing / safety YO'Q. */
  categories: CategoryScoreView[];
  interests: InterestsView | null;
  insights: InsightsView;
  disclaimer: L;
}

export interface ProfileView {
  updatedAt: Date;
  answeredQuestions: number;
  availableQuestions: number;
  categories: CategoryScoreView[];
  interests: InterestsView | null;
  insights: InsightsView;
  disclaimer: L;
}

export interface SessionSummaryView {
  id: string;
  type: string;
  title: L;
  day: string;
  status: string;
  completedAt: Date | null;
  answered: number;
  total: number;
}

export interface ProgressCategoryView {
  category: string;
  name: L;
  latest: number;
  previous: number | null;
  delta: number | null;
  points: Array<{ day: string; score: number }>;
}

export interface ProgressInterestView {
  code: string;
  name: L;
  latest: number;
  previous: number | null;
  delta: number | null;
}

export interface ProgressView {
  sessionsCompleted: number;
  firstCompletedAt: Date | null;
  lastCompletedAt: Date | null;
  categories: ProgressCategoryView[];
  interests: ProgressInterestView[];
  improved: string[];
  interestsRising: string[];
  history: SessionSummaryView[];
}

export interface ParentSupportView {
  level: 'watch' | 'support';
  areas: Array<{ key: string; name: L }>;
  day: string;
  guidance: L;
}

/**
 * Ota-onaga: savol darajasidagi javoblar, ochiq matn, wellbeing/safety
 * raqamlari va `parent_communication` YO'Q; kategoriya — kamida 2 javob bo'lsa.
 */
export interface ParentSummaryView {
  age: AgeView;
  sessionsCompleted: number;
  lastCompletedAt: Date | null;
  categories: CategoryScoreView[];
  interests: InterestsView | null;
  insights: ParentInsightsView;
  support: ParentSupportView | null;
  progress: { categories: ProgressCategoryView[]; interests: ProgressInterestView[] };
  disclaimer: L;
}
