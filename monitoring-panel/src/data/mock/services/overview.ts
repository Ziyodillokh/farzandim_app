/**
 * Umumiy ko'rinish: qamrov sonlari, asosiy KPI'lar (trend bilan), xarita
 * uchun hudud/tuman ko'rsatkichi va hududlar jadvali.
 */
import type { AreaMatrix, AreaMetric, Counts, Filters, Kpi, Overview, RegionRow, Scope, Stat } from '@/data/contracts';
import { coverageCounts, type MetricKey, METRICS } from '@/data/mock/model/metrics';
import { districtsOf } from '@/data/mock/model/latent';
import { coverageRate, regionSchools } from '@/data/mock/model/population';
import { OFFICIAL_NATIONAL } from '@/data/reference/official-stats';
import { REGION_IDS, regionRef } from '@/data/reference/regions';
import { childAreas, metricSeries, metricStat, periodInfo, rankAreas, scopeArea, strata, window } from './core';

/** Bosh sahifa KPI'lari (tartib bilan). */
export const OVERVIEW_KPIS: readonly MetricKey[] = [
  'coverage',
  'active',
  'mastery',
  'iqParticipation',
  'wellbeing',
  'attendance',
  'screenTime',
  'bullying',
];

function counts(scope: Scope, f: Filters): Counts {
  const w = window(f);
  const area = scopeArea(scope);
  const { official, covered } = coverageCounts(area, strata(f), w.months);
  const last = w.months[w.months.length - 1];
  if (scope.kind === 'NATIONAL') {
    const schoolsConnected = REGION_IDS.reduce(
      (s, id) => s + Math.round(regionSchools(id).schools * (last ? coverageRate(id, last.t) : 0) * 0.94),
      0,
    );
    return {
      official,
      covered,
      schools: OFFICIAL_NATIONAL.schools,
      privateSchools: OFFICIAL_NATIONAL.privateSchools,
      schoolsConnected,
      districts: REGION_IDS.reduce((s, id) => s + districtsOf(id).length, 0),
    };
  }
  const { schools, privateSchools } = regionSchools(scope.regionId);
  return {
    official,
    covered,
    schools,
    privateSchools,
    schoolsConnected: Math.round(schools * (last ? coverageRate(scope.regionId, last.t) : 0) * 0.94),
    districts: districtsOf(scope.regionId).length,
  };
}

export function getOverview(scope: Scope, f: Filters): Overview {
  const area = scopeArea(scope);
  const kpis: Kpi[] = OVERVIEW_KPIS.map((key) => {
    const d = METRICS[key];
    const stat = metricStat(key, area, f, d.decimals);
    const kpi: Kpi = { key, ...stat, series: metricSeries(key, area, f, d.decimals) };
    if (scope.kind === 'REGION') kpi.national = metricStat(key, { kind: 'NATIONAL' }, f, d.decimals).value;
    return kpi;
  });
  return { period: periodInfo(f), scope, counts: counts(scope, f), kpis };
}

export function getAreaMetric(metric: MetricKey, scope: Scope, f: Filters): AreaMetric {
  const d = METRICS[metric];
  const national: Stat = metricStat(metric, { kind: 'NATIONAL' }, f, d.decimals);
  const scopeValue = scope.kind === 'NATIONAL' ? national : metricStat(metric, scopeArea(scope), f, d.decimals);
  const areas = rankAreas(
    childAreas(scope).map(({ area, id, name }) => ({ id, name, ...metricStat(metric, area, f, d.decimals) })),
    d.better,
  );
  return { metric, national, scopeValue, areas, level: scope.kind === 'NATIONAL' ? 'REGION' : 'DISTRICT' };
}

/** Hududlar jadvali uchun ko'rsatkichlar. */
export const REGION_TABLE_METRICS: readonly MetricKey[] = [
  'coverage',
  'active',
  'mastery',
  'success',
  'iqMean',
  'iqParticipation',
  'wellbeing',
  'bullying',
  'anxiety',
  'attendance',
  'chronic',
  'screenTime',
  'night',
];

/** Bolalar orasidagi muammo signallari (hammasi "kam — yaxshi"). */
export const PROBLEM_METRICS: readonly MetricKey[] = ['bullying', 'anxiety', 'support', 'sleep', 'safetyGap', 'chronic', 'night'];

/** Doira bo'linmalari (hududlar yoki tumanlar) × tanlangan ko'rsatkichlar. */
export function getAreaMatrix(metrics: readonly MetricKey[], scope: Scope, f: Filters): AreaMatrix {
  const w = window(f);
  const statsFor = (area: ReturnType<typeof scopeArea>) =>
    Object.fromEntries(metrics.map((key) => [key, metricStat(key, area, f, METRICS[key].decimals)])) as AreaMatrix['scope'];
  return {
    level: scope.kind === 'NATIONAL' ? 'REGION' : 'DISTRICT',
    metrics: [...metrics],
    scope: statsFor(scopeArea(scope)),
    rows: childAreas(scope).map(({ area, id, name }) => ({ id, name, ...coverageCounts(area, strata(f), w.months), values: statsFor(area) })),
  };
}

export function getRegionsTable(f: Filters): RegionRow[] {
  const w = window(f);
  return REGION_IDS.map((id) => {
    const area = { kind: 'REGION', id } as const;
    const { official, covered } = coverageCounts(area, strata(f), w.months);
    const values = Object.fromEntries(
      REGION_TABLE_METRICS.map((key) => [key, metricStat(key, area, f, METRICS[key].decimals)]),
    ) as RegionRow['values'];
    return { id, name: regionRef(id).nameUz, official, covered, values };
  });
}
