// Kumulyativ Kelajak profili va sessiya natijasi (`kelajak_sessions.result`).
// Natijada faqat kodlar va ballar saqlanadi:
// `{ version, scores: { categories, interests, careerLab, support }, insightCodes }`.

import {
  CareerLabAvailable,
  CareerLabRating,
  careerLabRatings,
  NextCode,
  nextCareerLab,
  nextRecommendations,
  profileSupport,
  safetyRulesGap,
  strengthsAndGrowth,
  SupportLevel,
  SupportSignal,
  SupportSnapshot,
  supportSignal,
  WELLBEING_RECENT_DAYS,
} from './insights';
import { GrowthKey, RiasecCode, SAFETY_RULES_GROWTH, ScoredCategory } from './catalog';
import {
  CategoryScore,
  categoryScores,
  interestScores,
  InterestScores,
  isWithinDays,
  latestAnswers,
  ProfileSession,
  ScoredItem,
  SCORING_VERSION,
  ScoringQuestion,
  toScoredItems,
} from './scoring';

export interface KelajakInsightCodes {
  strengths: ScoredCategory[];
  /** Ballanadigan kategoriyalar + `safety_rules` (xavfsizlik bilimi maslahati). */
  growthAreas: GrowthKey[];
  /** Top qiziqish yo'nalishlari (RIASEC) — faqat ishonchli (`reliable`) bo'lsa. */
  interests: RiasecCode[];
  /** Profil bo'yicha baholangan Career Lab faoliyatlari. */
  careerLab: CareerLabRating[];
  support: SupportLevel | null;
  next: NextCode[];
}

export interface KelajakProfile {
  updatedAt: Date | null;
  /** Joriy yosh guruhidagi faol shkala savollaridan javob berilganlari (`availableQuestions` bilan solishtiriladi). */
  answeredQuestions: number;
  categories: CategoryScore[];
  interests: InterestScores | null;
  careerLab: CareerLabRating[];
  support: SupportSnapshot | null;
  insightCodes: KelajakInsightCodes;
}

export interface ProfileInput {
  /** Javoblardagi barcha savollar (nofaollari ham — tarix buzilmasin). */
  questions: ReadonlyMap<string, ScoringQuestion>;
  /** Bolaning YAKUNLANGAN sessiyalari. */
  sessions: readonly ProfileSession[];
  /** Bolaning yosh guruhidagi faol savollar. */
  available: {
    careerInterestIds: readonly string[];
    careerLab: readonly CareerLabAvailable[];
    /** Faol shkala savollari (ochiq matnsiz). */
    scaleIds: readonly string[];
  };
  now: Date;
}

/** `career_interest` qamrovi: javob berilgan / mavjud (mavjudi yo'q — to'liq). */
export function careerCoverage(answeredIds: ReadonlySet<string>, availableIds: readonly string[]): number {
  if (availableIds.length === 0) return 1;
  return availableIds.filter((id) => answeredIds.has(id)).length / availableIds.length;
}

export function buildKelajakProfile(input: ProfileInput): KelajakProfile {
  const { questions, sessions, available, now } = input;
  const latest = latestAnswers(sessions, now);
  const items = toScoredItems(latest.values(), questions);

  const categories = categoryScores(items);
  const interests = interestScores(items);
  const careerLab = careerLabRatings(items);
  const support = profileSupport(sessions, questions, now);
  const { strengths, growthAreas } = strengthsAndGrowth(categories);
  // Bitta-ikkita javobdan yo'nalish tavsiya qilinmaydi — faqat ishonchli top.
  const topCodes = interests?.reliable ? interests.top : [];
  const scaleIds = new Set(available.scaleIds);

  const next = nextRecommendations({
    careerCoverage: careerCoverage(new Set(latest.keys()), available.careerInterestIds),
    hasRecentWellbeing: sessions.some(
      (s) => s.type === 'wellbeing' && isWithinDays(s.completedAt, now, WELLBEING_RECENT_DAYS),
    ),
    careerLabNext: nextCareerLab({ topCodes, ratings: careerLab, available: available.careerLab }),
  });

  const updatedAt = sessions.reduce<Date | null>(
    (max, s) => (max === null || s.completedAt > max ? s.completedAt : max),
    null,
  );

  return {
    updatedAt,
    answeredQuestions: items.filter((i) => scaleIds.has(i.question.id)).length,
    categories,
    interests,
    careerLab,
    support,
    insightCodes: {
      strengths,
      growthAreas: [...growthAreas, ...(safetyRulesGap(items) ? [SAFETY_RULES_GROWTH] : [])],
      interests: topCodes,
      careerLab,
      support: support?.level ?? null,
      next,
    },
  };
}

export interface KelajakResultData {
  version: number;
  scores: {
    categories: CategoryScore[];
    interests: InterestScores | null;
    careerLab: CareerLabRating[];
    support: SupportSignal | null;
  };
  insightCodes: KelajakInsightCodes;
}

/** Sessiya natijasi: sessiya ballari + yakundagi kumulyativ profil insightlari. */
export function buildSessionResult(
  sessionItems: readonly ScoredItem[],
  profile: KelajakProfile,
): KelajakResultData {
  return {
    version: SCORING_VERSION,
    scores: {
      categories: categoryScores(sessionItems),
      interests: interestScores(sessionItems),
      careerLab: careerLabRatings(sessionItems),
      support: supportSignal(sessionItems),
    },
    insightCodes: profile.insightCodes,
  };
}
