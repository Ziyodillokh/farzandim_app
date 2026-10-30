/**
 * Agregatsiya dvigateli: qatlam formulalarini hudud / tuman / respublika
 * darajasida vaznli o'rtachaga aylantiradi. Vazn — monitoringdagi o'quvchilar
 * (rasmiy o'quvchilar × qatlam ulushi × qamrov) × ko'rsatkich bazasi
 * (faollar, so'rovnomada qatnashganlar, ulangan qurilmalar...).
 * Respublika = hududlar yig'indisi (alohida hisoblanmaydi).
 * `n` — natijaga hissa qo'shgan bolalar soni (K-anonimlik uchun).
 */
import type { GenderFilter, GradeBand, SchoolType } from '@/data/reference/domains';
import { REGION_IDS, type RegionId } from '@/data/reference/regions';
import type { SchoolMonth } from './calendar';
import { type Ctx } from './formulas';
import { districtsOf, findDistrict, type Latent, REGION_LATENT } from './latent';
import { coverageRate, matchesFilter, regionPupils, regionStrata } from './population';

export type Area = { kind: 'NATIONAL' } | { kind: 'REGION'; id: RegionId } | { kind: 'DISTRICT'; id: string };

export type StrataFilters = { grades: GradeBand; gender: GenderFilter; schoolType: 'ALL' | SchoolType };

/** K-anonimlik chegarasi: bundan kam bolalik natija ko'rsatilmaydi. */
export const K_MIN = 10;

export type Agg = { value: number | null; n: number };

type Component = { key: string; regionId: RegionId; L: Latent; pupils: number };

export function areaKey(area: Area): string {
  return area.kind === 'NATIONAL' ? 'UZ' : area.id;
}

function components(area: Area): Component[] {
  if (area.kind === 'NATIONAL') {
    return REGION_IDS.map((id) => ({ key: id, regionId: id, L: REGION_LATENT[id], pupils: regionPupils(id) }));
  }
  if (area.kind === 'REGION') {
    return [{ key: area.id, regionId: area.id, L: REGION_LATENT[area.id], pupils: regionPupils(area.id) }];
  }
  const d = findDistrict(area.id);
  if (!d) return [];
  return [{ key: d.id, regionId: d.regionId, L: d.latent, pupils: regionPupils(d.regionId) * d.weight }];
}

/**
 * Qamrov darajasi: hudud va respublika — hudud egri chizig'i; tuman — o'z latent
 * og'ishi bilan (hudud ichida vaznli o'rtachasi hudud darajasiga teng bo'ladi).
 */
function componentCoverage(comp: Component, t: number): number {
  const regional = coverageRate(comp.regionId, t);
  if (comp.key === comp.regionId) return regional;
  const target = REGION_LATENT[comp.regionId].coverage;
  return target > 0 ? Math.min(0.98, regional * (comp.L.coverage / target)) : regional;
}

const CACHE = new Map<string, Agg>();
const CACHE_LIMIT = 20000;

function cacheKey(tag: string, area: Area, f: StrataFilters, months: readonly SchoolMonth[]): string {
  return `${tag}|${areaKey(area)}|${f.grades}|${f.gender}|${f.schoolType}|${months.map((m) => m.t).join(',')}`;
}

/**
 * Umumiy vaznli agregat. `fn` — qatlam qiymati (null — qatlam hisobga olinmaydi),
 * `base` — qatlamdagi monitoring bolalaridan qaysi ulushi natija beradi (0..1).
 */
export function aggregate(
  tag: string,
  area: Area,
  filters: StrataFilters,
  months: readonly SchoolMonth[],
  fn: (c: Ctx) => number | null,
  base: (c: Ctx) => number = () => 1,
): Agg {
  const key = cacheKey(tag, area, filters, months);
  const hit = CACHE.get(key);
  if (hit) return hit;
  let sum = 0;
  let weight = 0;
  for (const comp of components(area)) {
    const strata = regionStrata(comp.regionId).filter((s) => matchesFilter(s, filters));
    for (const m of months) {
      const cov = componentCoverage(comp, m.t);
      for (const s of strata) {
        const c: Ctx = { key: comp.key, L: comp.L, grade: s.grade, gender: s.gender, type: s.type, t: m.t, month: m.month };
        const v = fn(c);
        if (v === null || !Number.isFinite(v)) continue;
        const w = comp.pupils * s.share * cov * base(c);
        sum += v * w;
        weight += w;
      }
    }
  }
  const n = months.length ? weight / months.length : 0;
  const result: Agg = { value: weight > 0 && n >= K_MIN ? sum / weight : null, n: Math.round(n) };
  if (CACHE.size > CACHE_LIMIT) CACHE.clear();
  CACHE.set(key, result);
  return result;
}

/** Monitoringdagi o'quvchilar soni (filtr bilan) — oylar o'rtachasi. */
export function coveredCount(area: Area, filters: StrataFilters, months: readonly SchoolMonth[]): number {
  return aggregate('covered', area, filters, months, () => 1).n;
}

/** Rasmiy o'quvchilar soni (filtr bilan). */
export function officialCount(area: Area, filters: StrataFilters): number {
  let total = 0;
  for (const comp of components(area)) {
    for (const s of regionStrata(comp.regionId)) if (matchesFilter(s, filters)) total += comp.pupils * s.share;
  }
  return Math.round(total);
}

export function districtAreas(regionId: RegionId): Area[] {
  return districtsOf(regionId).map((d) => ({ kind: 'DISTRICT', id: d.id }));
}

export function regionAreas(): Area[] {
  return REGION_IDS.map((id) => ({ kind: 'REGION', id }));
}

export function __clearEngineCache(): void {
  CACHE.clear();
}
