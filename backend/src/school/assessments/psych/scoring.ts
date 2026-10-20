// Psixologik testlar — sof hisob-kitob (skrining, tashxis emas). Panel
// `school-panel/src/lib/psych/scoring.ts` bilan BAYTMA-BAYT bir xil semantika
// (unit testlar ham ko'chirilgan: `scoring.spec.ts`).
// Standart ball: 100 + 15·z (55..145), persentil — normal taqsimot bo'yicha.

import type {
  AbilityBand,
  AgeBand,
  ConcernBand,
  IsoDate,
  NormRow,
  PsychItem,
  PsychNorms,
  PsychScale,
  PsychTest,
  ScalePolarity,
  ScaleScore,
  ScoreBand,
} from './types';

export const STANDARD = { mean: 100, sd: 15, min: 55, max: 145 } as const;
export const AGE_BANDS: readonly AgeBand[] = ['A7_8', 'A9_10', 'A11_12', 'A13_14', 'A15_17'];
export const CAREER_ORDER = ['R', 'I', 'A', 'S', 'E', 'C'] as const;

export function zScore(raw: number, norm: Pick<NormRow, 'mean' | 'sd'>): number {
  if (!(norm.sd > 0)) throw new RangeError('sd must be > 0');
  return (raw - norm.mean) / norm.sd;
}

export function toStandard(z: number): number {
  return Math.min(STANDARD.max, Math.max(STANDARD.min, Math.round(STANDARD.mean + STANDARD.sd * z)));
}

/** erf — Abramowitz & Stegun 7.1.26 (xato < 1.5e-7). */
function erf(x: number): number {
  const sign = x < 0 ? -1 : 1;
  const ax = Math.abs(x);
  const t = 1 / (1 + 0.3275911 * ax);
  const y = 1 - ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * Math.exp(-ax * ax);
  return sign * y;
}

export function toPercentile(z: number): number {
  const p = 0.5 * (1 + erf(z / Math.SQRT2));
  return Math.min(99, Math.max(1, Math.round(p * 100)));
}

export function abilityBand(ss: number): AbilityBand {
  if (ss < 70) return 'VERY_LOW';
  if (ss < 85) return 'LOW';
  if (ss < 115) return 'AVERAGE';
  if (ss < 130) return 'HIGH';
  return 'VERY_HIGH';
}

/** Xavotir kabi shkalalar: yuqori ball — e'tibor kerakligini bildiradi. */
export function concernBand(ss: number): ConcernBand {
  if (ss < 115) return 'TYPICAL';
  if (ss < 130) return 'WATCH';
  return 'SUPPORT';
}

export function bandFor(polarity: ScalePolarity, ss: number): ScoreBand {
  return polarity === 'HIGHER_CONCERN' ? concernBand(ss) : abilityBand(ss);
}

export function likertScore(a: number, reverse: boolean, min = 1, max = 5): number {
  if (!Number.isInteger(a) || a < min || a > max) throw new RangeError(`likert ${a}`);
  return reverse ? min + max - a : a;
}

/** SINGLE — variant kaliti; LIKERT — 1..5; MULTI — tanlangan variant indekslari; null — o'tkazib yuborilgan. */
export type AnswerVector = Array<string | number | number[] | null>;

export function rawScores(test: Pick<PsychTest, 'items' | 'scales'>, answers: AnswerVector): Record<string, number> {
  const raw: Record<string, number> = {};
  for (const s of test.scales) raw[s.key] = 0;
  test.items.forEach((item, i) => {
    const a = answers[i];
    if (a === null || a === undefined) return;
    if (item.type === 'SINGLE') {
      if (a === item.correct) raw[item.scale] = (raw[item.scale] ?? 0) + 1;
    } else if (item.type === 'LIKERT') {
      if (typeof a === 'number') raw[item.scale] = (raw[item.scale] ?? 0) + likertScore(a, item.reverse);
    } else if (Array.isArray(a)) {
      for (const idx of new Set(a)) {
        const opt = item.options[idx];
        if (opt) raw[opt.scale] = (raw[opt.scale] ?? 0) + 1;
      }
    }
  });
  return raw;
}

function itemMax(item: PsychItem, scaleKey: string): number {
  if (item.type === 'SINGLE') return item.scale === scaleKey ? 1 : 0;
  if (item.type === 'LIKERT') return item.scale === scaleKey ? 5 : 0;
  return item.options.filter((o) => o.scale === scaleKey).length;
}

export function maxRaw(test: Pick<PsychTest, 'items'>, scaleKey: string): number {
  return test.items.reduce((sum, item) => sum + itemMax(item, scaleKey), 0);
}

export function minRaw(test: Pick<PsychTest, 'items'>, scaleKey: string): number {
  return test.items.reduce((sum, item) => sum + (item.type === 'LIKERT' && item.scale === scaleKey ? 1 : 0), 0);
}

const B36 = '0123456789abcdefghijklmnopqrstuv';

/** Ixcham kodlash: har savolga 1 belgi ('-' — o'tkazilgan). */
export function encodeAnswers(test: Pick<PsychTest, 'items'>, answers: AnswerVector): string {
  return test.items
    .map((item, i) => {
      const a = answers[i];
      if (a === null || a === undefined) return '-';
      if (item.type === 'SINGLE') {
        const idx = item.options.findIndex((o) => o.key === a);
        return idx >= 0 && idx < B36.length ? (B36[idx] ?? '-') : '-';
      }
      if (item.type === 'LIKERT') return typeof a === 'number' ? String(a) : '-';
      const mask = Array.isArray(a) ? a.reduce((m, idx) => (idx < 5 ? m | (1 << idx) : m), 0) : 0;
      return B36[mask] ?? '-';
    })
    .join('');
}

export function decodeAnswers(test: Pick<PsychTest, 'items'>, code: string): AnswerVector {
  return test.items.map((item, i) => {
    const c = code[i];
    if (!c || c === '-') return null;
    const n = B36.indexOf(c);
    if (n < 0) return null;
    if (item.type === 'SINGLE') return item.options[n]?.key ?? null;
    if (item.type === 'LIKERT') return n;
    const picked: number[] = [];
    for (let b = 0; b < 5; b++) if (n & (1 << b)) picked.push(b);
    return picked;
  });
}

export function ageOn(birthDate: IsoDate, at: IsoDate): number {
  const [by, bm, bd] = birthDate.split('-').map(Number) as [number, number, number];
  const [y, m, d] = at.slice(0, 10).split('-').map(Number) as [number, number, number];
  return y - by - (m < bm || (m === bm && d < bd) ? 1 : 0);
}

export function ageBandOf(age: number): AgeBand {
  if (age <= 8) return 'A7_8';
  if (age <= 10) return 'A9_10';
  if (age <= 12) return 'A11_12';
  if (age <= 14) return 'A13_14';
  return 'A15_17';
}

/** Aniq yosh bandi, bo'lmasa eng yaqini. */
export function normFor(norms: PsychNorms, scaleKey: string, band: AgeBand): NormRow | null {
  // Faqat o'z kalitlari: "constructor" kabi meros xossalar me'yor sifatida o'qilmasin.
  const rows = Object.prototype.hasOwnProperty.call(norms, scaleKey) ? norms[scaleKey] : undefined;
  if (!rows?.length) return null;
  const exact = rows.find((r) => r.band === band);
  if (exact) return exact;
  const target = AGE_BANDS.indexOf(band);
  return [...rows].sort((a, b) => Math.abs(AGE_BANDS.indexOf(a.band) - target) - Math.abs(AGE_BANDS.indexOf(b.band) - target))[0] ?? null;
}

export function scoreScale(scale: PsychScale, raw: number, max: number | null, norm: NormRow | null): ScaleScore {
  if (scale.display === 'RAW' || !norm || !(norm.sd > 0)) {
    return { key: scale.key, raw, max, z: null, standard: null, percentile: null, band: null };
  }
  const z = zScore(raw, norm);
  const standard = toStandard(z);
  return { key: scale.key, raw, max, z, standard, percentile: toPercentile(z), band: bandFor(scale.polarity, standard) };
}

export function topCodes(raw: Record<string, number>, order: readonly string[] = CAREER_ORDER, n = 3): string {
  return order
    .map((k, i) => ({ k, v: raw[k] ?? 0, i }))
    .sort((a, b) => b.v - a.v || a.i - b.i)
    .slice(0, n)
    .map((x) => x.k)
    .join('');
}

export function scoreResult(
  test: Pick<PsychTest, 'items' | 'scales' | 'norms' | 'kind'>,
  r: { raw: Record<string, number>; ageBand: AgeBand },
): { scales: ScaleScore[]; topCodes: string | null } {
  const scales = test.scales.map((s) => {
    const max = test.items.length ? maxRaw(test, s.key) : null;
    return scoreScale(s, r.raw[s.key] ?? 0, max, normFor(test.norms, s.key, r.ageBand));
  });
  return { scales, topCodes: test.kind === 'CAREER' ? topCodes(r.raw) : null };
}

/** Rivojlanish indeksi 0..100 (persentil): yuqori = kuchliroq / yaxshiroq holat. */
export function domainIndex(s: Pick<ScaleScore, 'percentile'>, polarity: ScalePolarity): number | null {
  if (s.percentile === null) return null;
  return polarity === 'HIGHER_CONCERN' ? 100 - s.percentile : s.percentile;
}
