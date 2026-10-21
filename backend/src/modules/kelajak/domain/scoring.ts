// Kelajak ballari (docs/KELAJAK-REJA.md §3). Natija faqat kod va raqam —
// matnlar o'qishda `texts.ts`dan qo'shiladi. Qoida o'zgarsa
// `SCORING_VERSION` oshiriladi (eski natijalar o'z versiyasini saqlaydi).

import { DayKey, daysBetween, tashkentDay } from '../../../common/time/tashkent';
import {
  DEFAULT_SUPPORT_SIGNAL,
  isRiasecCode,
  isSupportCategory,
  isSupportSignalKind,
  RIASEC_CODES,
  RiasecCode,
  SCORED_CATEGORY_IDS,
  ScoredCategory,
  SupportSignalKind,
} from './catalog';

export const SCORING_VERSION = 1;

/** Top yo'nalish bo'lishi uchun minimal o'lcham bali. */
export const TOP_INTEREST_MIN_SCORE = 50;
export const TOP_INTEREST_COUNT = 3;
/** `reliable` — har top o'lchamda kamida shuncha javob. */
export const RELIABLE_MIN_ANSWERS = 2;
/** Kumulyativ profil oynasi (Toshkent kunlari). */
export const PROFILE_WINDOW_DAYS = 180;

export interface ScoringQuestion {
  id: string;
  externalId: string;
  category: string;
  answerType: string;
  options: ReadonlyArray<{ value: number }>;
  scoring: unknown;
  reverse: boolean;
}

/** Shkala qiymati berilgan javob (ochiq matn bu yerga kirmaydi). */
export interface ScoredItem {
  question: ScoringQuestion;
  value: number;
}

export interface CategoryScore {
  category: ScoredCategory;
  score: number;
  answered: number;
}

export interface InterestDimension {
  code: RiasecCode;
  score: number;
  answered: number;
}

export interface InterestScores {
  dimensions: InterestDimension[];
  top: RiasecCode[];
  reliable: boolean;
}

/**
 * 0–100 ga keltirish: `(v - min) / (max - min) * 100` (min/max — variantlar
 * qiymatlari), `reverse` bo'lsa `100 - x`. Variantda yo'q qiymat — `null`.
 */
export function normalizeValue(
  value: number,
  options: ReadonlyArray<{ value: number }>,
  reverse: boolean,
): number | null {
  const values = options.map((o) => o.value);
  if (!values.includes(value)) return null;
  const min = Math.min(...values);
  const max = Math.max(...values);
  if (max === min) return null;
  const x = ((value - min) / (max - min)) * 100;
  return reverse ? 100 - x : x;
}

export function normalizeItem(item: ScoredItem): number | null {
  return normalizeValue(item.value, item.question.options, item.question.reverse);
}

/** `scoring` obyektidagi maydon (scoring yo'q yoki obyekt emas — undefined). */
function scoringField(question: Pick<ScoringQuestion, 'scoring'>, key: string): unknown {
  const scoring = question.scoring;
  if (!scoring || typeof scoring !== 'object' || Array.isArray(scoring)) return undefined;
  return (scoring as Record<string, unknown>)[key];
}

/** `career_interest` savolining RIASEC o'lchami (`scoring.dimension`). */
export function riasecDimension(question: ScoringQuestion): RiasecCode | null {
  if (question.category !== 'career_interest') return null;
  const dimension = scoringField(question, 'dimension');
  return isRiasecCode(dimension) ? dimension : null;
}

/** Career Lab faoliyatining RIASEC kodi (`scoring.riasec`); umumiy faoliyat — null. */
export function careerLabRiasec(question: Pick<ScoringQuestion, 'category' | 'scoring'>): RiasecCode | null {
  if (question.category !== 'career_lab') return null;
  const code = scoringField(question, 'riasec');
  return isRiasecCode(code) ? code : null;
}

/** wellbeing / safety savolining signal turi (`scoring.signal`, standart — `distress`); boshqasi — null. */
export function supportSignalKind(question: ScoringQuestion): SupportSignalKind | null {
  if (!isSupportCategory(question.category)) return null;
  const kind = scoringField(question, 'signal');
  return isSupportSignalKind(kind) ? kind : DEFAULT_SUPPORT_SIGNAL;
}

export const mean = (xs: readonly number[]) => xs.reduce((sum, x) => sum + x, 0) / xs.length;

export function normalizedOf(items: readonly ScoredItem[], keep: (item: ScoredItem) => boolean): number[] {
  return items
    .filter(keep)
    .map(normalizeItem)
    .filter((x): x is number => x !== null);
}

/** Ballanadigan kategoriyalar o'rtachasi (wellbeing/safety, RIASEC va Career Lab YO'Q). */
export function categoryScores(items: readonly ScoredItem[]): CategoryScore[] {
  return SCORED_CATEGORY_IDS.flatMap((category) => {
    const xs = normalizedOf(items, (i) => i.question.category === category);
    return xs.length > 0 ? [{ category, score: Math.round(mean(xs)), answered: xs.length }] : [];
  });
}

/**
 * Top-3: ball kamayishi, tenglikda javoblar ko'pi, keyin R-I-A-S-E-C tartibi;
 * faqat ≥50 bo'lgan o'lchamlar.
 */
export function topInterests(dimensions: readonly InterestDimension[]): {
  top: RiasecCode[];
  reliable: boolean;
} {
  const order = (code: RiasecCode) => RIASEC_CODES.indexOf(code);
  const top = dimensions
    .filter((d) => d.score >= TOP_INTEREST_MIN_SCORE)
    .sort((a, b) => b.score - a.score || b.answered - a.answered || order(a.code) - order(b.code))
    .slice(0, TOP_INTEREST_COUNT);
  return {
    top: top.map((d) => d.code),
    reliable: top.length > 0 && top.every((d) => d.answered >= RELIABLE_MIN_ANSWERS),
  };
}

/** RIASEC o'lchamlari — `career_interest` savollari o'rtachasi (yig'indi emas). */
export function interestScores(items: readonly ScoredItem[]): InterestScores | null {
  const dimensions = RIASEC_CODES.flatMap((code) => {
    const xs = normalizedOf(items, (i) => riasecDimension(i.question) === code);
    return xs.length > 0 ? [{ code, score: Math.round(mean(xs)), answered: xs.length }] : [];
  });
  if (dimensions.length === 0) return null;
  return { dimensions, ...topInterests(dimensions) };
}

// ─── Kumulyativ profil ───────────────────────────────────────────────

export interface ProfileAnswer {
  questionId: string;
  /** Ochiq matn javobida `null`. */
  value: number | null;
  answeredAt: Date;
}

/** Yakunlangan sessiya (profil va signal manbai). */
export interface ProfileSession {
  id: string;
  type: string;
  day: DayKey;
  completedAt: Date;
  answers: readonly ProfileAnswer[];
}

export interface LatestAnswer {
  questionId: string;
  value: number;
  answeredAt: Date;
  sessionId: string;
}

/** `at` lahzasi `now`gacha bo'lgan oxirgi `days` Toshkent kuni ichidami. */
export function isWithinDays(at: Date, now: Date, days: number): boolean {
  return daysBetween(tashkentDay(at), tashkentDay(now)) < days;
}

/**
 * Oxirgi 180 kundagi YAKUNLANGAN sessiyalarda har savolning eng so'nggi
 * (shkala) javobi — kunlik aralash savollar vaqt bilan profilga yig'iladi.
 */
export function latestAnswers(
  sessions: readonly ProfileSession[],
  now: Date,
  windowDays: number = PROFILE_WINDOW_DAYS,
): Map<string, LatestAnswer> {
  const entries = sessions
    .filter((s) => isWithinDays(s.completedAt, now, windowDays))
    .flatMap((s) =>
      s.answers
        .filter((a) => a.value !== null)
        .map((a) => ({ answer: a, session: s })),
    )
    .sort(
      (a, b) =>
        a.answer.answeredAt.getTime() - b.answer.answeredAt.getTime() ||
        a.session.completedAt.getTime() - b.session.completedAt.getTime(),
    );
  // Vaqt bo'yicha o'sish tartibida — oxirgisi qoladi.
  return new Map(
    entries.map(({ answer, session }) => [
      answer.questionId,
      {
        questionId: answer.questionId,
        value: answer.value as number,
        answeredAt: answer.answeredAt,
        sessionId: session.id,
      },
    ]),
  );
}

/** Javoblarni savollar bilan bog'lash (noma'lum savol — tashlab yuboriladi). */
export function toScoredItems(
  answers: Iterable<{ questionId: string; value: number | null }>,
  questions: ReadonlyMap<string, ScoringQuestion>,
): ScoredItem[] {
  return [...answers].flatMap((a) => {
    const question = questions.get(a.questionId);
    return question && a.value !== null ? [{ question, value: a.value }] : [];
  });
}
