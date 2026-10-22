// IQ API ko'rinishlari (docs/IQ-REJA.md §4–§5) va xom natija → baho.
// Savolning `answer` maydoni bu yerdagi hech bir ko'rinishga KIRMAYDI.

import { IqSession, IqSessionStatus } from '@prisma/client';
import { IQ_ITEM_KINDS, IqItemKind, LocalizedText } from './domain/bank';
import { groupOffset, IqAge } from './domain/levels';
import { eapAbility, IqBand, IqResultStatus, NormStats, scoreAbility } from './domain/scoring';

export interface IqResultView {
  correct: number;
  total: number;
  status: IqResultStatus;
  percentile: number;
  band: IqBand;
  standardScore: number | null;
  ci95: [number, number] | null;
  normGroup: string | null;
  completedAt: string;
  /** Aralash formada tur bo'yicha xom natija (rasm / son / so'z / mantiq); bitta turli formada yo'q. */
  domains?: IqDomainScore[];
}

export interface IqDomainScore {
  kind: IqItemKind;
  right: number;
  total: number;
}

/** Variant: rasmli savolda `svg`, matnli savolda `text` (uch tilda). */
export interface IqOptionView {
  key: string;
  svg?: string;
  text?: LocalizedText;
}

export interface IqItemView {
  id: string;
  position: number;
  kind: IqItemKind;
  /** Faqat rasmli savolda; matnli savolda null. */
  gridSvg: string | null;
  /** Faqat matnli savolda: shart (birinchi qator — ko'rsatma, qolgani — savolning o'zi). */
  stem: LocalizedText | null;
  options: IqOptionView[];
  choice: string | null;
}

export interface IqSessionView {
  id: string;
  status: IqSessionStatus;
  level: number;
  form: string;
  total: number;
  startedAt: string;
  completedAt: string | null;
  items: IqItemView[];
  result: IqResultView | null;
}

export interface IqHistoryEntry {
  sessionId: string;
  completedAt: string;
  level: number;
  result: IqResultView;
}

export interface IqOverview {
  age: IqAge;
  canStart: boolean;
  nextAvailableAt: string | null;
  active: { sessionId: string; answered: number; total: number } | null;
  last: IqResultView | null;
  history: IqHistoryEntry[];
}

export interface IqParentSummary {
  age: IqAge;
  last: IqResultView | null;
  nextAvailableAt: string | null;
  history: IqHistoryEntry[];
}

/** Sessiyada saqlangan xom natija. */
export interface StoredIqResult {
  correct: number;
  total: number;
  responses: number[];
}

export function parseStoredResult(value: unknown): StoredIqResult | null {
  if (typeof value !== 'object' || value === null) return null;
  const r = value as Record<string, unknown>;
  const ok =
    Number.isInteger(r.correct) &&
    Number.isInteger(r.total) &&
    Array.isArray(r.responses) &&
    r.responses.every((x) => x === 0 || x === 1);
  return ok
    ? {
        correct: r.correct as number,
        total: r.total as number,
        responses: r.responses as number[],
      }
    : null;
}

/** Sessiya itemlari `b` qiymatlari (tartib bilan) — dizayn markazi va EAP uchun. */
export const designCenter = (bs: readonly number[]): number =>
  bs.length ? bs.reduce((a, b) => a + b, 0) / bs.length : 0;

/** Tur bo'yicha xom natija — faqat bir nechta tur bo'lsa (aralash forma). */
export function domainScores(responses: readonly number[], kinds: ReadonlyArray<IqItemKind | undefined>): IqDomainScore[] | undefined {
  const present = IQ_ITEM_KINDS.filter((k) => kinds.includes(k));
  if (present.length < 2) return undefined;
  return present.map((kind) => {
    const own = responses.filter((_, i) => kinds[i] === kind);
    return { kind, right: own.filter((r) => r === 1).length, total: own.length };
  });
}

/**
 * Xom natija → baho. `bs` / `kinds` — sessiya tartibidagi savol qiyinliklari va
 * turlari; `norm` — guruh statistikasi (o'qilgan paytdagi).
 */
export function scoreSession(
  session: Pick<IqSession, 'normGroup' | 'completedAt'>,
  stored: StoredIqResult,
  bs: readonly number[],
  norm: NormStats,
  kinds: ReadonlyArray<IqItemKind | undefined> = [],
): IqResultView {
  const center = designCenter(bs);
  const ability = eapAbility(
    stored.responses.map((r, i) => ({ b: bs[i] ?? center, correct: r === 1 })),
    center,
  );
  const offset = session.normGroup ? groupOffset(session.normGroup) : 0;
  const score = scoreAbility(ability, norm, { mean: center + offset, sd: 1 });
  const domains = domainScores(stored.responses, kinds);
  return {
    correct: stored.correct,
    total: stored.total,
    ...score,
    normGroup: session.normGroup,
    completedAt: (session.completedAt ?? new Date(0)).toISOString(),
    ...(domains ? { domains } : {}),
  };
}
