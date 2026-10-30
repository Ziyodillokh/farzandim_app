/**
 * Maktablar kesimi: maktab turlari bo'yicha taqqoslash, tumanlar va
 * anonimlashtirilgan maktablar reytingi (namoyishda maktab nomlari
 * ko'rsatilmaydi — faqat SOATO asosidagi kod).
 */
import type { Filters, SchoolRow, Schools, SchoolTypeStat, Scope } from '@/data/contracts';
import { districtsOf } from '@/data/mock/model/latent';
import { regionPupils, regionSchools } from '@/data/mock/model/population';
import { signedNoise } from '@/data/mock/model/latent';
import { SCHOOL_TYPES, type SchoolType } from '@/data/reference/domains';
import { REGION_IDS, type RegionId, regionRef } from '@/data/reference/regions';
import { metricStat, round, scopeArea } from './core';

const withFilter = (f: Filters, patch: Partial<Filters>): Filters => ({ ...f, ...patch });

function typeStat(scope: Scope, f: Filters, type: SchoolType): SchoolTypeStat {
  const area = scopeArea(scope);
  const g = withFilter(f, { schoolType: type });
  const regions: readonly RegionId[] = scope.kind === 'NATIONAL' ? REGION_IDS : [scope.regionId];
  const schools = regions.reduce((s, id) => {
    const r = regionSchools(id);
    if (type === 'PRIVATE') return s + r.privateSchools;
    const special = Math.max(1, Math.round(r.schools * 0.012));
    return s + (type === 'SPECIAL' ? special : r.schools - r.privateSchools - special);
  }, 0);
  const pupils = metricStat('coverage', area, g).n;
  return {
    type,
    schools,
    pupils,
    mastery: metricStat('mastery', area, g).value,
    attendance: metricStat('attendance', area, g).value,
    wellbeing: metricStat('wellbeing', area, g, 0).value,
    iqMean: metricStat('iqMean', area, g).value,
  };
}

/**
 * Maktab o'sishidagi tafovut: ko'pchilik tuman o'rtachasi atrofida, ozchiligi
 * (yangi metodika, kuchli jamoa) sezilarli yuqori — reyting "dumi" tabiiy bo'lsin.
 */
function schoolGrowthNoise(id: string): number {
  const base = signedNoise('gr', id) * 1.8 + signedNoise('gr2', id) * 1.2;
  const standout = signedNoise('gr3', id) > 0.86 ? (signedNoise('gr4', id) + 1) * 2.6 : 0;
  return base + standout;
}

/** Tuman maktablari (deterministik, anonim). */
function schoolsOf(regionId: RegionId, f: Filters): SchoolRow[] {
  const { schools, privateSchools } = regionSchools(regionId);
  const pupilsPerSchool = regionPupils(regionId) / Math.max(1, schools);
  const out: SchoolRow[] = [];
  // Kod hudud ichida yagona: SOATO + tartib raqami (tumanlar bo'ylab davom etadi).
  let seq = 0;
  for (const d of districtsOf(regionId)) {
    const area = { kind: 'DISTRICT', id: d.id } as const;
    const mastery = metricStat('mastery', area, f);
    const attendance = metricStat('attendance', area, f).value;
    const wellbeing = metricStat('wellbeing', area, f, 0).value;
    const count = Math.max(1, Math.round(schools * d.weight));
    for (let i = 0; i < count; i++) {
      seq += 1;
      const id = `${d.id}-${i + 1}`;
      const isPrivate = signedNoise('priv', id) > 1 - (2 * privateSchools) / Math.max(1, schools);
      const type: SchoolType = isPrivate ? 'PRIVATE' : signedNoise('spec', id) > 0.985 ? 'SPECIAL' : 'STATE';
      const typeFx = type === 'PRIVATE' ? 4 : type === 'SPECIAL' ? 7 : 0;
      const noise = signedNoise('sch', id) * 7;
      const m = mastery.value === null ? null : round(Math.min(97, Math.max(25, mastery.value + typeFx + noise)));
      out.push({
        id,
        code: `${regionRef(regionId).soato}-${String(seq).padStart(4, '0')}`,
        districtId: d.id,
        districtName: d.name,
        regionId,
        type,
        pupils: Math.round(pupilsPerSchool * (0.55 + (signedNoise('sz', id) + 1) * 0.45) * (type === 'PRIVATE' ? 0.4 : 1)),
        mastery: m,
        growth: mastery.delta === null ? null : round(mastery.delta + schoolGrowthNoise(id)),
        attendance: attendance === null ? null : round(Math.min(99.5, attendance + signedNoise('sa', id) * 1.4)),
        wellbeing: wellbeing === null ? null : round(Math.min(95, Math.max(40, wellbeing + signedNoise('sw', id) * 5)), 0),
      });
    }
  }
  return out;
}

const TOP = 10;

export function getSchools(scope: Scope, f: Filters): Schools {
  const regions: readonly RegionId[] = scope.kind === 'NATIONAL' ? REGION_IDS : [scope.regionId];
  const all = regions.flatMap((id) => schoolsOf(id, f)).filter((s) => s.mastery !== null);
  const filtered = f.schoolType === 'ALL' ? all : all.filter((s) => s.type === f.schoolType);
  const topGrowth = filtered
    .filter((s) => s.growth !== null)
    .sort((a, b) => (b.growth as number) - (a.growth as number))
    .slice(0, TOP);
  const needSupport = filtered
    .slice()
    .sort((a, b) => (a.mastery as number) + (a.attendance ?? 95) / 10 - ((b.mastery as number) + (b.attendance ?? 95) / 10))
    .slice(0, TOP);
  const districts =
    scope.kind === 'REGION'
      ? districtsOf(scope.regionId).map((d) => {
          const area = { kind: 'DISTRICT', id: d.id } as const;
          return {
            id: d.id,
            name: d.name,
            schools: all.filter((s) => s.districtId === d.id).length,
            mastery: metricStat('mastery', area, f).value,
            attendance: metricStat('attendance', area, f).value,
            wellbeing: metricStat('wellbeing', area, f, 0).value,
          };
        })
      : [];
  return { types: SCHOOL_TYPES.map((t) => typeStat(scope, f, t)), topGrowth, needSupport, districts };
}
