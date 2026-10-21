// IQ baholash — sof funksiyalar (docs/IQ-REJA.md §3). Skrining, tashxis emas.
//
// 1) θ — Rasch (1PL) EAP, prior N(μ, 1), kvadratura [-5, 5] qadam 0.05.
// 2) Norma: guruh n ≥ 30 — empirik (Welford), aks holda dastlabki ma'lumotnoma.
// 3) z → persentil, standart ball 100 + 15z (55..145), 95% ishonch oralig'i.
// 4) n ≥ 300 — NORMED (IQ raqami ko'rsatiladi), aks holda PROVISIONAL.

import { toPercentile, toStandard } from '../../../school/assessments/psych/scoring';

export const SCORING_VERSION = 1;
export const MIN_EMPIRICAL_N = 30;
export const NORMED_N = 300;
const MIN_SD = 0.05;
const Z95 = 1.96;
const GRID: readonly number[] = Array.from({ length: 201 }, (_, i) => -5 + i * 0.05);

export type IqBand = 'VERY_HIGH' | 'HIGH' | 'ABOVE_AVERAGE' | 'AVERAGE' | 'BELOW_AVERAGE' | 'LOW' | 'VERY_LOW';
export type IqResultStatus = 'PROVISIONAL' | 'NORMED';

export interface Ability {
  theta: number;
  se: number;
}
export interface NormStats {
  n: number;
  mean: number;
  sd: number;
}
export interface WelfordRow {
  n: number;
  mean: number;
  m2: number;
}
export interface IqScore {
  status: IqResultStatus;
  percentile: number;
  band: IqBand;
  standardScore: number | null;
  ci95: [number, number] | null;
}

export const raschP = (theta: number, b: number): number => 1 / (1 + Math.exp(-(theta - b)));

/** EAP baho: javoblar (`b`, to'g'ri/noto'g'ri) → θ va standart xato. */
export function eapAbility(responses: ReadonlyArray<{ b: number; correct: boolean }>, priorMean = 0): Ability {
  const logPost = GRID.map((t) => {
    let ll = -((t - priorMean) ** 2) / 2;
    for (const r of responses) {
      const p = raschP(t, r.b);
      ll += Math.log(r.correct ? p : 1 - p);
    }
    return ll;
  });
  const max = Math.max(...logPost);
  const w = logPost.map((l) => Math.exp(l - max));
  const sum = w.reduce((a, x) => a + x, 0);
  const theta = GRID.reduce((a, t, i) => a + t * w[i], 0) / sum;
  const variance = GRID.reduce((a, t, i) => a + (t - theta) ** 2 * w[i], 0) / sum;
  return { theta, se: Math.sqrt(variance) };
}

export function welfordAdd(row: WelfordRow, x: number): WelfordRow {
  const n = row.n + 1;
  const delta = x - row.mean;
  const mean = row.mean + delta / n;
  return { n, mean, m2: row.m2 + delta * (x - mean) };
}

export function normStats(row: WelfordRow | null): NormStats {
  if (!row || row.n < 2) return { n: row?.n ?? 0, mean: row?.mean ?? 0, sd: 0 };
  return { n: row.n, mean: row.mean, sd: Math.sqrt(row.m2 / (row.n - 1)) };
}

/** WISC-V tasnifi (standart ball bo'yicha). */
export function bandFor(standard: number): IqBand {
  if (standard >= 130) return 'VERY_HIGH';
  if (standard >= 120) return 'HIGH';
  if (standard >= 110) return 'ABOVE_AVERAGE';
  if (standard >= 90) return 'AVERAGE';
  if (standard >= 80) return 'BELOW_AVERAGE';
  if (standard >= 70) return 'LOW';
  return 'VERY_LOW';
}

/**
 * θ → natija. `reference` — dastlabki ma'lumotnoma (dizayn markazi + yosh
 * siljishi, sd 1); guruhda `MIN_EMPIRICAL_N` dan ko'p natija bo'lsa empirik norma.
 */
export function scoreAbility(ability: Ability, norm: NormStats, reference: { mean: number; sd: number }): IqScore {
  const empirical = norm.n >= MIN_EMPIRICAL_N && norm.sd >= MIN_SD;
  const { mean, sd } = empirical ? norm : reference;
  const z = (ability.theta - mean) / sd;
  const standard = toStandard(z);
  const normed = empirical && norm.n >= NORMED_N;
  const margin = (Z95 * ability.se) / sd;
  return {
    status: normed ? 'NORMED' : 'PROVISIONAL',
    percentile: toPercentile(z),
    band: bandFor(standard),
    standardScore: normed ? standard : null,
    ci95: normed ? [toStandard(z - margin), toStandard(z + margin)] : null,
  };
}
