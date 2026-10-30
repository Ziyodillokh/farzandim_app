/**
 * Muammo signallari tahlili (hududlar × signallar matritsasidan): qaysi signal
 * keng tarqalgan, qaysi hududlarda signallar o'rtachadan ko'proq. Signallar
 * qo'llab-quvvatlashni rejalashtirish uchun — bolalarga baho emas.
 */
import type { AreaMatrix, AreaRow, MetricKey } from '@/data/contracts';
import { meanOf } from './kit/analysis';

/**
 * Hudud signali "sezilarli yuqori" sanaladi, agar ikkala shart bajarilsa:
 * nisbiy — o'rtachadan kamida 5% ga yuqori, mutlaq — kamida 0,5 p.p. ga yuqori
 * (kichik asosda, masalan 3,7% → 3,9%, +0,2 p.p. — tasodifiy tebranish, sezilarli emas).
 * Signallar (PROBLEM_METRICS) — bolalar ulushi, %; mutlaq chegara p.p. da.
 */
export const NOTABLE_EXCESS = 0.05;
export const NOTABLE_MIN_DIFF = 0.5;
/** Suzuvchi nuqta xatosi: 4,1 − 3,6 = 0,4999… ham chegaradan o'tsin. */
const DIFF_EPSILON = 1e-9;
/** Ro'yxatda ko'rsatiladigan hududlar soni. */
export const HOTSPOT_LIMIT = 5;
/** Har hudud uchun ko'rsatiladigan signallar soni. */
export const HOTSPOT_SIGNALS = 3;

export type AreaPeak = { id: string; name: string; value: number };

export type ProblemRank = {
  metric: MetricKey;
  /** Doira (respublika yoki hudud) qiymati. */
  value: number | null;
  delta: number | null;
  /** Bo'linmalar o'rtachasi (issiqlik jadvali bo'yalishi bilan bir xil). */
  mean: number | null;
  /** Eng yuqori qiymatli bo'linma. */
  peak: AreaPeak | null;
};

export type HotspotSignal = { metric: MetricKey; value: number; mean: number; diff: number; rel: number };

export type Hotspot = {
  id: string;
  name: string;
  /** O'rtachadan jami oshish: o'rtachadan yuqori signallarning nisbiy oshishlari yig'indisi — saralash uchun. */
  burden: number;
  /** O'rtachadan sezilarli yuqori signallar soni. */
  aboveCount: number;
  signals: HotspotSignal[];
};

const valueOf = (row: AreaRow, metric: MetricKey): number | null => row.values[metric]?.value ?? null;

/** Har signal bo'yicha bo'linmalar o'rtachasi. */
export function columnMeans(rows: readonly AreaRow[], metrics: readonly MetricKey[]): Partial<Record<MetricKey, number>> {
  const out: Partial<Record<MetricKey, number>> = {};
  for (const metric of metrics) {
    const mean = meanOf(rows.map((r) => valueOf(r, metric)));
    if (mean !== null) out[metric] = mean;
  }
  return out;
}

function peakOf(rows: readonly AreaRow[], metric: MetricKey): AreaPeak | null {
  let peak: AreaPeak | null = null;
  for (const row of rows) {
    const value = valueOf(row, metric);
    if (value !== null && (peak === null || value > peak.value)) peak = { id: row.id, name: row.name, value };
  }
  return peak;
}

/** Signallar keng tarqalganligi bo'yicha (doira qiymati kamayish tartibida; ma'lumotsizlar oxirida). */
export function rankProblems(matrix: AreaMatrix, metrics: readonly MetricKey[]): ProblemRank[] {
  const means = columnMeans(matrix.rows, metrics);
  return metrics
    .map((metric) => ({
      metric,
      value: matrix.scope[metric]?.value ?? null,
      delta: matrix.scope[metric]?.delta ?? null,
      mean: means[metric] ?? null,
      peak: peakOf(matrix.rows, metric),
    }))
    .sort((a, b) => (b.value ?? -Infinity) - (a.value ?? -Infinity));
}

/** O'rtachadan "sezilarli yuqori": nisbiy (≥5%) va mutlaq (≥0,5 p.p.) chegaralar birga. */
export function isNotableExcess(diff: number, rel: number): boolean {
  return rel >= NOTABLE_EXCESS && diff >= NOTABLE_MIN_DIFF - DIFF_EPSILON;
}

/**
 * Bitta bo'linmaning o'rtachadan sezilarli yuqori signallari va o'rtachadan jami
 * oshish (`burden` — o'rtachadan yuqori barcha signallarning nisbiy oshishlari yig'indisi).
 */
export function areaExcess(row: AreaRow, metrics: readonly MetricKey[], means: Partial<Record<MetricKey, number>>): Omit<Hotspot, 'id' | 'name'> {
  let burden = 0;
  const signals: HotspotSignal[] = [];
  for (const metric of metrics) {
    const value = valueOf(row, metric);
    const mean = means[metric];
    if (value === null || mean === undefined || mean <= 0) continue;
    const diff = value - mean;
    const rel = diff / mean;
    if (rel <= 0) continue;
    burden += rel;
    if (isNotableExcess(diff, rel)) signals.push({ metric, value, mean, diff, rel });
  }
  signals.sort((a, b) => b.rel - a.rel);
  return { burden, aboveCount: signals.length, signals };
}

/**
 * Signallar o'rtachadan eng ko'p oshgan bo'linmalar: kamida bitta signali
 * sezilarli yuqori bo'lganlar, o'rtachadan jami oshish bo'yicha kamayish tartibida.
 */
export function findHotspots(matrix: AreaMatrix, metrics: readonly MetricKey[], limit = HOTSPOT_LIMIT): Hotspot[] {
  const means = columnMeans(matrix.rows, metrics);
  return matrix.rows
    .map((row) => ({ id: row.id, name: row.name, ...areaExcess(row, metrics, means) }))
    .filter((h) => h.aboveCount > 0)
    .sort((a, b) => b.burden - a.burden)
    .slice(0, limit)
    .map((h) => ({ ...h, signals: h.signals.slice(0, HOTSPOT_SIGNALS) }));
}

export type ProblemSort = 'official' | 'burden' | MetricKey;

/**
 * Issiqlik jadvali qatorlari tartibi: rasmiy (servis tartibi), o'rtachadan jami
 * oshish (`burden`, nisbiy) yoki tanlangan signal bo'yicha (yuqoridan — e'tibor talab).
 */
export function sortAreaRows(rows: readonly AreaRow[], metrics: readonly MetricKey[], sort: ProblemSort): AreaRow[] {
  if (sort === 'official') return [...rows];
  if (sort === 'burden') {
    const means = columnMeans(rows, metrics);
    const burden = new Map(rows.map((r) => [r.id, areaExcess(r, metrics, means).burden]));
    return [...rows].sort((a, b) => (burden.get(b.id) ?? 0) - (burden.get(a.id) ?? 0));
  }
  return [...rows].sort((a, b) => (valueOf(b, sort) ?? -Infinity) - (valueOf(a, sort) ?? -Infinity));
}
