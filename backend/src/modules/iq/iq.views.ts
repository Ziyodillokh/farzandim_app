// IQ API ko'rinishlari (docs/IQ-REJA.md §4–§5) va xom natija → baho.
// Savolning `answer` maydoni bu yerdagi hech bir ko'rinishga KIRMAYDI.

import { IqSession, IqSessionStatus } from '@prisma/client';
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
}

export interface IqItemView {
  id: string;
  position: number;
  gridSvg: string;
  options: Array<{ key: string; svg: string }>;
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

/**
 * Xom natija → baho. `bs` — sessiya tartibidagi savol qiyinliklari;
 * `norm` — guruh statistikasi (o'qilgan paytdagi).
 */
export function scoreSession(
  session: Pick<IqSession, 'normGroup' | 'completedAt'>,
  stored: StoredIqResult,
  bs: readonly number[],
  norm: NormStats,
): IqResultView {
  const center = designCenter(bs);
  const ability = eapAbility(
    stored.responses.map((r, i) => ({ b: bs[i] ?? center, correct: r === 1 })),
    center,
  );
  const offset = session.normGroup ? groupOffset(session.normGroup) : 0;
  const score = scoreAbility(ability, norm, { mean: center + offset, sd: 1 });
  return {
    correct: stored.correct,
    total: stored.total,
    ...score,
    normGroup: session.normGroup,
    completedAt: (session.completedAt ?? new Date(0)).toISOString(),
  };
}
