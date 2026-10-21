// Kelajak insight kodlari (docs/KELAJAK-REJA.md §3): kuchli tomon va
// rivojlanish, Career Lab xulosalari, qo'llab-quvvatlash signali va keyingi
// tavsiya. Faqat kodlar — matnlar `texts.ts`da.

import { DayKey } from '../../../common/time/tashkent';
import { categoryOrder, KelajakTestType, RiasecCode, ScoredCategory, SupportCategory } from './catalog';
import {
  careerLabRiasec,
  CategoryScore,
  isWithinDays,
  mean,
  normalizedOf,
  normalizeItem,
  ProfileSession,
  ScoredItem,
  ScoringQuestion,
  supportSignalKind,
  toScoredItems,
} from './scoring';

/** Kuchli tomon: kategoriya bali ≥70 va ≥2 javob. */
export const STRENGTH_MIN_SCORE = 70;
/** Rivojlantirish mumkin: kategoriya bali <50 va ≥2 javob. */
export const GROWTH_BELOW_SCORE = 50;
export const CATEGORY_MIN_ANSWERS = 2;

/**
 * Career Lab xulosasi normallashtirilgan balldan (shkala qanday bo'lmasin):
 * ≥60 — yoqdi, ≤40 — yoqmadi, oraliq — betaraf (`career_lab_5`: 4–5 / 3 / 1–2).
 */
export const CAREER_LAB_LIKED_MIN_SCORE = 60;
export const CAREER_LAB_DISLIKED_MAX_SCORE = 40;

/** Holat (`distress`) savolida normallashtirilgan ball ≤25 — tashvish; ≥2 tashvish — `support`. */
export const CONCERN_MAX_SCORE = 25;
export const SUPPORT_MIN_CONCERNS = 2;
export const SUPPORT_WINDOW_DAYS = 30;

/** Shuncha kunda wellbeing sessiyasi bo'lmasa — tavsiya qilinadi. */
export const WELLBEING_RECENT_DAYS = 14;
/** `career_interest` qamrovi shundan kam bo'lsa — `career` testi. */
export const CAREER_COVERAGE_MIN = 0.8;
export const MAX_NEXT = 2;

/**
 * Xavfsizlik bilimi (`knowledge` savollari, signalga kirmaydi): o'rtacha <50 va
 * ≥2 javob — "Xavfsizlik qoidalari" rivojlanish maslahati.
 */
export function safetyRulesGap(items: readonly ScoredItem[]): boolean {
  const xs = normalizedOf(items, (i) => supportSignalKind(i.question) === 'knowledge');
  return xs.length >= CATEGORY_MIN_ANSWERS && mean(xs) < GROWTH_BELOW_SCORE;
}

export function strengthsAndGrowth(categories: readonly CategoryScore[]): {
  strengths: ScoredCategory[];
  growthAreas: ScoredCategory[];
} {
  const enough = categories.filter((c) => c.answered >= CATEGORY_MIN_ANSWERS);
  return {
    strengths: enough.filter((c) => c.score >= STRENGTH_MIN_SCORE).map((c) => c.category),
    growthAreas: enough.filter((c) => c.score < GROWTH_BELOW_SCORE).map((c) => c.category),
  };
}

// ─── Career Lab ──────────────────────────────────────────────────────

export type CareerLabVerdict = 'liked' | 'neutral' | 'disliked';

export interface CareerLabRating {
  questionId: string;
  externalId: string;
  code: RiasecCode | null;
  /** Xom javob qiymati (bolaga ko'rsatiladi). */
  rating: number;
  /** Normallashtirilgan 0–100 (xulosa va saralash shundan). */
  score: number;
  verdict: CareerLabVerdict;
}

/** Bolaning yosh guruhidagi faol Career Lab faoliyati. */
export interface CareerLabAvailable {
  externalId: string;
  code: RiasecCode | null;
}

export interface CareerLabNext {
  externalId: string;
  code: RiasecCode | null;
  /** `try` — yangi faoliyat, `deepen` — yoqqanini chuqurlashtirish. */
  mode: 'try' | 'deepen';
}

/** Xulosa normallashtirilgan balldan (0–100). */
export function careerLabVerdict(score: number): CareerLabVerdict {
  if (score >= CAREER_LAB_LIKED_MIN_SCORE) return 'liked';
  if (score <= CAREER_LAB_DISLIKED_MAX_SCORE) return 'disliked';
  return 'neutral';
}

export function careerLabRatings(items: readonly ScoredItem[]): CareerLabRating[] {
  return items
    .filter((i) => i.question.category === 'career_lab')
    .flatMap((i) => {
      const normalized = normalizeItem(i);
      if (normalized === null) return [];
      const score = Math.round(normalized);
      return [
        {
          questionId: i.question.id,
          externalId: i.question.externalId,
          code: careerLabRiasec(i.question),
          rating: i.value,
          score,
          verdict: careerLabVerdict(score),
        },
      ];
    })
    .sort((a, b) => a.externalId.localeCompare(b.externalId));
}

/**
 * "Keyingi sinash": top qiziqish kodiga mos (`scoring.riasec`), hali
 * baholanmagan faoliyat; bo'lmasa eng yuqori baholangan yoqqan faoliyatni
 * chuqurlashtirish.
 */
export function nextCareerLab(params: {
  topCodes: readonly RiasecCode[];
  ratings: readonly CareerLabRating[];
  available: readonly CareerLabAvailable[];
}): CareerLabNext | null {
  const rated = new Set(params.ratings.map((r) => r.externalId));
  for (const code of params.topCodes) {
    const activity = params.available.find((a) => a.code === code && !rated.has(a.externalId));
    if (activity) return { externalId: activity.externalId, code, mode: 'try' };
  }
  const liked = params.ratings
    .filter((r) => r.verdict === 'liked')
    .sort((a, b) => b.score - a.score || a.externalId.localeCompare(b.externalId))[0];
  return liked ? { externalId: liked.externalId, code: liked.code, mode: 'deepen' } : null;
}

// ─── Qo'llab-quvvatlash signali ──────────────────────────────────────

export type SupportLevel = 'none' | 'watch' | 'support';

/** Faqat daraja va soha (kategoriya) — raqam ham, savol ham YO'Q. */
export interface SupportSignal {
  level: SupportLevel;
  areas: SupportCategory[];
}

export interface SupportSnapshot extends SupportSignal {
  sessionId: string;
  day: DayKey;
}

/** Faqat holat savollari; xavfsizlik bilimi (`knowledge`) signalga kirmaydi. */
const isDistressItem = (item: ScoredItem) => supportSignalKind(item.question) === 'distress';

/** wellbeing + safety holat javoblari bo'yicha signal; bunday javob yo'q — `null`. */
export function supportSignal(items: readonly ScoredItem[]): SupportSignal | null {
  const relevant = items.filter(isDistressItem);
  if (relevant.length === 0) return null;
  const concerns = relevant.filter((item) => {
    const x = normalizeItem(item);
    return x !== null && x <= CONCERN_MAX_SCORE;
  });
  const level: SupportLevel =
    concerns.length >= SUPPORT_MIN_CONCERNS ? 'support' : concerns.length === 1 ? 'watch' : 'none';
  const areas = [...new Set(concerns.map((c) => c.question.category as SupportCategory))].sort(
    (a, b) => categoryOrder(a) - categoryOrder(b),
  );
  return { level, areas };
}

const LEVEL_RANK: Readonly<Record<SupportLevel, number>> = { none: 0, watch: 1, support: 2 };

/**
 * Manba — oxirgi 30 kun. Eng so'nggi `wellbeing` testi (to'liq tekshiruv) —
 * tayanch: undan oldingilar hisobga olinmaydi, keyingi sessiyalar (kunlik
 * savollar) darajani faqat OSHIRADI, hech qachon tushirmaydi. Wellbeing testi
 * bo'lmasa — oynadagi barcha sessiyalarning eng yuqori darajasi. Sohalar —
 * hisobga olingan sessiyalardagi barcha tashvishlar; kun — shu darajaga olib
 * kelgan eng so'nggi sessiya.
 */
export function profileSupport(
  sessions: readonly ProfileSession[],
  questions: ReadonlyMap<string, ScoringQuestion>,
  now: Date,
): SupportSnapshot | null {
  const signals = sessions
    .filter((s) => isWithinDays(s.completedAt, now, SUPPORT_WINDOW_DAYS))
    .sort((a, b) => b.completedAt.getTime() - a.completedAt.getTime())
    .flatMap((s) => {
      const signal = supportSignal(toScoredItems(s.answers, questions));
      return signal ? [{ ...signal, sessionId: s.id, day: s.day, type: s.type }] : [];
    });
  const anchor = signals.findIndex((s) => s.type === 'wellbeing');
  const considered = anchor >= 0 ? signals.slice(0, anchor + 1) : signals;
  if (considered.length === 0) return null;

  const level = considered.reduce<SupportLevel>(
    (top, s) => (LEVEL_RANK[s.level] > LEVEL_RANK[top] ? s.level : top),
    'none',
  );
  const source = considered.find((s) => s.level === level) ?? considered[0];
  const areas = [...new Set(considered.flatMap((s) => s.areas))].sort((a, b) => categoryOrder(a) - categoryOrder(b));
  return { level, areas, sessionId: source.sessionId, day: source.day };
}

// ─── Keyingi tavsiya ─────────────────────────────────────────────────

export interface NextCode {
  kind: 'take_test' | 'career_lab' | 'come_back';
  testType: KelajakTestType | null;
  /** Career Lab faoliyati (`career_lab` turida). */
  externalId: string | null;
  mode: CareerLabNext['mode'] | null;
}

/**
 * ≤2 ta tavsiya: qiziqishlar qamrovi <80% → `career`; 14 kunda wellbeing
 * sessiyasi yo'q → `wellbeing`; mos Career Lab faoliyati → shu faoliyat;
 * hech biri bo'lmasa → "ertaga yana".
 */
export function nextRecommendations(params: {
  careerCoverage: number;
  hasRecentWellbeing: boolean;
  careerLabNext: CareerLabNext | null;
}): NextCode[] {
  const lab = params.careerLabNext;
  const candidates: NextCode[] = [
    ...(params.careerCoverage < CAREER_COVERAGE_MIN
      ? [{ kind: 'take_test' as const, testType: 'career' as const, externalId: null, mode: null }]
      : []),
    ...(!params.hasRecentWellbeing
      ? [{ kind: 'take_test' as const, testType: 'wellbeing' as const, externalId: null, mode: null }]
      : []),
    ...(lab
      ? [{ kind: 'career_lab' as const, testType: 'career_lab' as const, externalId: lab.externalId, mode: lab.mode }]
      : []),
  ];
  return candidates.length > 0
    ? candidates.slice(0, MAX_NEXT)
    : [{ kind: 'come_back', testType: null, externalId: null, mode: null }];
}
