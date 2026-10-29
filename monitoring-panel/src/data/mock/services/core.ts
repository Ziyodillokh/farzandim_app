/**
 * Servislar uchun umumiy yordamchilar: davr, doira → hudud, Stat (joriy +
 * taqqoslash + farq), oylik qatorlar va hudud/tuman ro'yxatlari.
 */
import type { AreaStat, Filters, PeriodInfo, Scope, SeriesPoint, Stat } from '@/data/contracts';
import { districtsOf } from '@/data/mock/model/latent';
import { ayLabel, lastSchoolMonths, resolvePeriod, type PeriodWindow, type SchoolMonth } from '@/data/mock/model/calendar';
import { aggregate, type Agg, type Area, type StrataFilters } from '@/data/mock/model/engine';
import type { Ctx } from '@/data/mock/model/formulas';
import { type MetricKey, metricValue } from '@/data/mock/model/metrics';
import { REGION_IDS, type RegionId, regionRef } from '@/data/reference/regions';

let fixedNow: Date | null = null;

/** Joriy sana (testlarda qotiriladi). */
export function now(): Date {
  return fixedNow ? new Date(fixedNow) : new Date();
}

export function __setNowForTests(date: Date | null): void {
  fixedNow = date;
}

export function strata(f: Filters): StrataFilters {
  return { grades: f.grades, gender: f.gender, schoolType: f.schoolType };
}

export function scopeArea(scope: Scope): Area {
  return scope.kind === 'NATIONAL' ? { kind: 'NATIONAL' } : { kind: 'REGION', id: scope.regionId };
}

export function window(f: Filters): PeriodWindow {
  return resolvePeriod(f.period, now());
}

export function periodInfo(f: Filters): PeriodInfo {
  const w = window(f);
  return {
    period: f.period,
    ayLabel: ayLabel(w.ay),
    quarter: w.quarter,
    months: w.months.map((m) => m.key),
    baselineMonths: w.baseline.map((m) => m.key),
    asOf: now().toISOString(),
  };
}

const round = (v: number | null, d = 1) => (v === null ? null : Math.round(v * 10 ** d) / 10 ** d);

export function toStat(current: Agg, baseline: Agg | null, decimals = 1): Stat {
  const value = round(current.value, decimals);
  const base = baseline ? round(baseline.value, decimals) : null;
  return {
    value,
    base,
    delta: value !== null && base !== null ? round(value - base, decimals) : null,
    n: current.n,
  };
}

/** Skalyar ko'rsatkich: joriy davr va o'tgan yilning shu davri. */
export function metricStat(key: MetricKey, area: Area, f: Filters, decimals = 1): Stat {
  const w = window(f);
  const sf = strata(f);
  const current = metricValue(key, area, sf, w.months);
  const baseline = w.baseline.length ? metricValue(key, area, sf, w.baseline) : null;
  return toStat(current, baseline, decimals);
}

/** Ixtiyoriy formula uchun Stat (taqsimotlar, fanlar). */
export function customStat(
  tag: string,
  area: Area,
  f: Filters,
  fn: (c: Ctx) => number | null,
  base?: (c: Ctx) => number,
  decimals = 1,
): Stat {
  const w = window(f);
  const sf = strata(f);
  const current = aggregate(tag, area, sf, w.months, fn, base);
  const baseline = w.baseline.length ? aggregate(tag, area, sf, w.baseline, fn, base) : null;
  return toStat(current, baseline, decimals);
}

export function customValue(
  tag: string,
  area: Area,
  f: Filters,
  fn: (c: Ctx) => number | null,
  base?: (c: Ctx) => number,
  months?: readonly SchoolMonth[],
): number | null {
  return aggregate(tag, area, strata(f), months ?? window(f).months, fn, base).value;
}

/** Oxirgi 12 o'quv oyi bo'yicha qator (davr filtridan mustaqil, tendensiya uchun). */
export function metricSeries(key: MetricKey, area: Area, f: Filters, decimals = 1): SeriesPoint[] {
  const sf = strata(f);
  return lastSchoolMonths(now(), 12).map((m) => ({ key: m.key, value: round(metricValue(key, area, sf, [m]).value, decimals) }));
}

export function customSeries(tag: string, area: Area, f: Filters, fn: (c: Ctx) => number | null, base?: (c: Ctx) => number, decimals = 1): SeriesPoint[] {
  const sf = strata(f);
  return lastSchoolMonths(now(), 12).map((m) => ({ key: m.key, value: round(aggregate(tag, area, sf, [m], fn, base).value, decimals) }));
}

/** Doira ichidagi bo'linmalar: respublika → hududlar, hudud → tumanlar. */
export function childAreas(scope: Scope): Array<{ area: Area; id: string; name: string }> {
  if (scope.kind === 'NATIONAL') {
    return REGION_IDS.map((id) => ({ area: { kind: 'REGION', id } as Area, id, name: regionRef(id).nameUz }));
  }
  return districtsOf(scope.regionId).map((d) => ({ area: { kind: 'DISTRICT', id: d.id } as Area, id: d.id, name: d.name }));
}

/** Bo'linmalar bo'yicha ko'rsatkich, reyting bilan (yaxshi yo'nalish bo'yicha 1 — eng yaxshi). */
export function rankAreas(stats: Array<Omit<AreaStat, 'rank'>>, better: 'up' | 'down' | 'neutral'): AreaStat[] {
  const ranked = stats
    .filter((s) => s.value !== null)
    .sort((a, b) => (better === 'down' ? (a.value as number) - (b.value as number) : (b.value as number) - (a.value as number)));
  const rankOf = new Map(ranked.map((s, i) => [s.id, i + 1]));
  return stats.map((s) => ({ ...s, rank: better === 'neutral' ? null : (rankOf.get(s.id) ?? null) }));
}

export function regionIds(): readonly RegionId[] {
  return REGION_IDS;
}

export { round };
