/**
 * Aholi qatlamlari: hudud o'quvchilari (rasmiy statistika) → sinf × jins ×
 * maktab turi bo'yicha ulushlar. Qamrov (Parvoz monitoringidagi o'quvchilar)
 * hudud yashirin omilidan olinadi.
 */
import { OFFICIAL_REGIONS } from '@/data/reference/official-stats';
import { GRADES, type Grade, gradesOf, type GradeBand, type GenderFilter, type SchoolType } from '@/data/reference/domains';
import type { RegionId } from '@/data/reference/regions';
import { REGION_LATENT } from './latent';

/** Sinflar bo'yicha o'quvchilar taqsimoti (9-sinfdan keyin bir qismi kollejga ketadi). */
const GRADE_RAW = [10.6, 10.3, 10.0, 9.8, 9.6, 9.4, 9.2, 8.9, 8.5, 7.2, 6.5];
const GRADE_TOTAL = GRADE_RAW.reduce((a, b) => a + b, 0);
export const GRADE_SHARE: Readonly<Record<Grade, number>> = Object.fromEntries(
  GRADES.map((g, i) => [g, (GRADE_RAW[i] as number) / GRADE_TOTAL]),
) as Record<Grade, number>;

export type Gender = 'M' | 'F';
export type Stratum = { grade: Grade; gender: Gender; type: SchoolType; share: number };

export type StrataFilter = { grades: GradeBand; gender: GenderFilter; schoolType: 'ALL' | SchoolType };

function typeShares(regionId: RegionId): Record<SchoolType, number> {
  const s = OFFICIAL_REGIONS[regionId];
  const privateSchoolShare = s ? s.privateSchools / s.schools : 0.05;
  // Xususiy maktablar kichikroq: o'quvchilar ulushi maktablar ulushidan past.
  const priv = privateSchoolShare * 0.42;
  const special = regionId === 'UZ-TK' ? 0.02 : 0.012;
  return { STATE: 1 - priv - special, PRIVATE: priv, SPECIAL: special };
}

function girlsShare(regionId: RegionId): number {
  const s = OFFICIAL_REGIONS[regionId];
  return s ? s.girls / s.pupils : 0.488;
}

const STRATA_CACHE = new Map<RegionId, readonly Stratum[]>();

/** Hudud qatlamlari (66 ta; ulushlar yig'indisi 1). */
export function regionStrata(regionId: RegionId): readonly Stratum[] {
  const cached = STRATA_CACHE.get(regionId);
  if (cached) return cached;
  const types = typeShares(regionId);
  const girls = girlsShare(regionId);
  const out: Stratum[] = [];
  for (const grade of GRADES) {
    for (const gender of ['M', 'F'] as const) {
      for (const type of ['STATE', 'PRIVATE', 'SPECIAL'] as const) {
        const g = gender === 'F' ? girls : 1 - girls;
        out.push({ grade, gender, type, share: GRADE_SHARE[grade] * g * types[type] });
      }
    }
  }
  STRATA_CACHE.set(regionId, out);
  return out;
}

export function matchesFilter(s: Stratum, f: StrataFilter): boolean {
  if (f.gender !== 'ALL' && s.gender !== f.gender) return false;
  if (f.schoolType !== 'ALL' && s.type !== f.schoolType) return false;
  return gradesOf(f.grades).includes(s.grade);
}

/** Hudud o'quvchilari (rasmiy). */
export function regionPupils(regionId: RegionId): number {
  return OFFICIAL_REGIONS[regionId]?.pupils ?? 0;
}

/** Monitoringdagi (Parvoz'ga ulangan) o'quvchilar ulushi. */
export function coverageRate(regionId: RegionId, t: number): number {
  // Qamrov vaqt o'tishi bilan o'sadi (pilotdan kengayish): 2024-09 da ~45%, joriy yilda yakuniy darajada.
  const target = REGION_LATENT[regionId].coverage;
  const ramp = Math.min(1, 0.55 + t * 0.03);
  return target * ramp;
}

export function regionSchools(regionId: RegionId): { schools: number; privateSchools: number } {
  const s = OFFICIAL_REGIONS[regionId];
  return { schools: s?.schools ?? 0, privateSchools: s?.privateSchools ?? 0 };
}
