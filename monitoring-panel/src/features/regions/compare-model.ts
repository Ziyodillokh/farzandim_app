import type { MetricKey, RegionRow } from '@/data/contracts';
import { METRICS } from '@/data/mock/model/metrics';
import type { RegionId } from '@/data/reference/regions';
import { bestIds, type CompareRowData, type CompareSeries } from './kit/compare-bars';
import { isNum } from './kit/heat';
import type { NationalStats } from './use-regions-data';

/** Respublikadan sezilarli farq: 14 hudud orasidagi eng katta chetlanishning 15%. */
const SIGNIFICANT = 0.15;
const TAGS = 2;

export type RegionSummary = {
  id: RegionId;
  /** Tanlanganlar orasida eng yaxshi bo'lgan ko'rsatkichlar soni. */
  wins: number;
  /** Respublikadan yaxshiroq ko'rsatkichlar soni. */
  above: number;
  /** Baholanadigan (neytral bo'lmagan) ko'rsatkichlar soni. */
  total: number;
  strengths: MetricKey[];
  attention: MetricKey[];
};

/**
 * Respublikaga nisbatan normallashgan farq (+ — yaxshiroq): 1 — 14 hudud
 * orasidagi eng katta chetlanish. Neytral ko'rsatkichda — null.
 */
export function normalizedGap(metric: MetricKey, value: number | null | undefined, national: number | null | undefined, context: ReadonlyArray<number | null | undefined>): number | null {
  const better = METRICS[metric].better;
  if (better === 'neutral' || !isNum(value) || !isNum(national)) return null;
  const spread = Math.max(0, ...context.filter(isNum).map((v) => Math.abs(v - national)));
  if (spread === 0) return 0;
  const gap = (value - national) / spread;
  return better === 'down' ? -gap : gap;
}

/** Har ko'rsatkich uchun solishtirish qatori: tanlangan hududlar, respublika va 14 hudud konteksti. */
export function buildCompareRows(metrics: readonly MetricKey[], rows: readonly RegionRow[], selected: readonly RegionId[], national: NationalStats | undefined): CompareRowData[] {
  const byId = new Map(rows.map((r) => [r.id, r]));
  return metrics.map((metric) => ({
    metric,
    reference: national?.[metric]?.value ?? null,
    context: rows.map((r) => r.values[metric]?.value ?? null),
    values: Object.fromEntries(
      selected.map((id) => {
        const stat = byId.get(id)?.values[metric];
        return [id, { value: stat?.value ?? null, delta: stat?.delta ?? null }];
      }),
    ),
  }));
}

/** Hudud kartasi uchun xulosa: g'alabalar, respublikadan yaxshi ko'rsatkichlar, kuchli va e'tibor talab tomonlar. */
export function summarize(selected: readonly RegionId[], series: readonly CompareSeries[], compareRows: readonly CompareRowData[]): RegionSummary[] {
  const rated = compareRows.filter((r) => METRICS[r.metric].better !== 'neutral');
  const winners = rated.map((r) => bestIds(series, r.values, METRICS[r.metric].better));
  return selected.map((id) => {
    const gaps = rated
      .map((r) => ({ metric: r.metric, gap: normalizedGap(r.metric, r.values[id]?.value, r.reference, r.context) }))
      .filter((g): g is { metric: MetricKey; gap: number } => g.gap !== null);
    const strengths = gaps
      .filter((g) => g.gap >= SIGNIFICANT)
      .sort((a, b) => b.gap - a.gap)
      .slice(0, TAGS)
      .map((g) => g.metric);
    const attention = gaps
      .filter((g) => g.gap <= -SIGNIFICANT)
      .sort((a, b) => a.gap - b.gap)
      .slice(0, TAGS)
      .map((g) => g.metric);
    return {
      id,
      wins: winners.filter((w) => w.has(id)).length,
      above: gaps.filter((g) => g.gap > 0).length,
      total: rated.length,
      strengths,
      attention,
    };
  });
}
