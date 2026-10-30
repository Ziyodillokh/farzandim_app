import { beforeAll, describe, expect, it } from 'vitest';

import type { Filters } from '@/data/contracts';
import { currentSchoolMonth, lastSchoolMonths, resolvePeriod, schoolMonth } from '@/data/mock/model/calendar';
import { __clearEngineCache, aggregate } from '@/data/mock/model/engine';
import { districtsOf } from '@/data/mock/model/latent';
import { METRIC_KEYS, METRICS } from '@/data/mock/model/metrics';
import { regionStrata } from '@/data/mock/model/population';
import { __setNowForTests } from '@/data/mock/services/core';
import { getInsights } from '@/data/mock/services/insights';
import { getInterests, getIq, getMastery } from '@/data/mock/services/learning';
import { getAttendance, getDigital, getWellbeing } from '@/data/mock/services/life';
import { getAreaMetric, getOverview, getRegionsTable } from '@/data/mock/services/overview';
import { getSchools } from '@/data/mock/services/schools';
import { OFFICIAL_NATIONAL, OFFICIAL_REGIONS } from '@/data/reference/official-stats';
import { REGION_IDS } from '@/data/reference/regions';

const F0: Filters = { period: 'QUARTER', grades: 'ALL', gender: 'ALL', schoolType: 'ALL' };
const NAT = { kind: 'NATIONAL' } as const;
const SAM = { kind: 'REGION', regionId: 'UZ-SA' } as const;

beforeAll(() => {
  __setNowForTests(new Date('2026-10-30T09:00:00+05:00'));
  __clearEngineCache();
});

describe('kalendar', () => {
  it("o'quv oylari indeksi va davrlar", () => {
    expect(schoolMonth(2024, 9).t).toBe(0);
    expect(schoolMonth(2025, 5).t).toBe(17);
    expect(currentSchoolMonth(new Date('2026-10-30')).key).toBe('2026-10');
    // Yozda — o'tgan o'quv yilining mayi.
    expect(currentSchoolMonth(new Date('2026-07-15')).key).toBe('2026-05');
    const q = resolvePeriod('QUARTER', new Date('2026-10-30'));
    expect(q.months.map((m) => m.key)).toEqual(['2026-09', '2026-10']);
    expect(q.baseline.map((m) => m.key)).toEqual(['2025-09', '2025-10']);
    expect(resolvePeriod('PREV_AY', new Date('2026-10-30')).months).toHaveLength(9);
    expect(lastSchoolMonths(new Date('2026-10-30'), 12).at(-1)?.key).toBe('2026-10');
  });
});

describe('rasmiy statistika va qatlamlar', () => {
  it("hududlar yig'indisi respublikaga teng", () => {
    const pupils = REGION_IDS.reduce((s, id) => s + (OFFICIAL_REGIONS[id]?.pupils ?? 0), 0);
    const schools = REGION_IDS.reduce((s, id) => s + (OFFICIAL_REGIONS[id]?.schools ?? 0), 0);
    expect(pupils).toBe(OFFICIAL_NATIONAL.pupils);
    expect(schools).toBe(OFFICIAL_NATIONAL.schools);
  });

  it("qatlam ulushlari 1 ga, tuman vaznlari 1 ga teng", () => {
    for (const id of REGION_IDS) {
      expect(regionStrata(id).reduce((s, x) => s + x.share, 0)).toBeCloseTo(1, 6);
      expect(districtsOf(id).reduce((s, d) => s + d.weight, 0)).toBeCloseTo(1, 6);
    }
    expect(REGION_IDS.reduce((s, id) => s + districtsOf(id).length, 0)).toBe(206);
  });
});

describe('ko\'rsatkichlar', () => {
  it('har ko\'rsatkich respublika uchun chekli va real oraliqda', () => {
    const months = resolvePeriod('QUARTER', new Date('2026-10-30')).months;
    const ranges: Record<string, [number, number]> = {
      '%': [0, 100],
      score: [80, 120],
      index: [30, 95],
      min: [60, 400],
      per1000: [1, 20],
      steps: [3000, 11000],
      perWeek: [1, 7],
    };
    for (const key of METRIC_KEYS) {
      const def = METRICS[key];
      const v = def.compute(NAT, F0, months).value;
      expect(v, key).not.toBeNull();
      const [lo, hi] = ranges[def.unit] ?? [0, 100];
      expect(v as number, key).toBeGreaterThanOrEqual(lo);
      expect(v as number, key).toBeLessThanOrEqual(hi);
    }
  });

  it("respublika — hududlarning vaznli o'rtachasi", () => {
    const months = resolvePeriod('QUARTER', new Date('2026-10-30')).months;
    const fn = () => 1;
    const regions = REGION_IDS.map((id) => aggregate('t:one', { kind: 'REGION', id }, F0, months, fn));
    const nat = aggregate('t:one', NAT, F0, months, fn);
    expect(regions.reduce((s, r) => s + r.n, 0)).toBeCloseTo(nat.n, -2);
  });

  it('deterministik: ikki marta bir xil natija', () => {
    __clearEngineCache();
    const a = JSON.stringify(getOverview(NAT, F0));
    __clearEngineCache();
    const b = JSON.stringify(getOverview(NAT, F0));
    expect(a).toBe(b);
  });
});

describe('servislar', () => {
  it('umumiy ko\'rinish: 8 KPI, 12 oylik trend, hudud doirasida respublika qiymati', () => {
    const o = getOverview(NAT, F0);
    expect(o.kpis).toHaveLength(8);
    expect(o.kpis.every((k) => k.series.length === 12)).toBe(true);
    expect(o.counts.official).toBeGreaterThan(6_000_000);
    expect(o.counts.covered).toBeLessThan(o.counts.official);
    const r = getOverview(SAM, F0);
    expect(r.kpis.every((k) => k.national !== undefined)).toBe(true);
    expect(r.counts.districts).toBe(16);
  });

  it('xarita ko\'rsatkichi: 14 hudud reyting bilan; hudud doirasida tumanlar', () => {
    const m = getAreaMetric('mastery', NAT, F0);
    expect(m.areas).toHaveLength(14);
    expect(m.areas.map((a) => a.rank).sort((x, y) => (x as number) - (y as number))).toEqual(Array.from({ length: 14 }, (_, i) => i + 1));
    const top = m.areas.find((a) => a.rank === 1);
    expect(top?.id).toBe('UZ-TK');
    const d = getAreaMetric('mastery', SAM, F0);
    expect(d.level).toBe('DISTRICT');
    expect(d.areas).toHaveLength(16);
  });

  it('hududlar orasidagi farq mo\'tadil (namoyish)', () => {
    const m = getAreaMetric('mastery', NAT, F0);
    const values = m.areas.map((a) => a.value as number);
    expect(Math.max(...values) - Math.min(...values)).toBeLessThan(16);
    const iq = getAreaMetric('iqMean', NAT, F0);
    const iqv = iq.areas.map((a) => a.value as number);
    expect(Math.max(...iqv) - Math.min(...iqv)).toBeLessThan(6);
  });

  it("taqsimotlar 100% ga yaqin", () => {
    const iq = getIq(NAT, F0);
    expect(iq.bands.reduce((s, b) => s + b.share, 0)).toBeCloseTo(100, 0);
    const d = getDigital(NAT, F0);
    expect(d.categories.reduce((s, c) => s + c.share, 0)).toBeCloseTo(100, 0);
    expect(d.hourly.reduce((s, v) => s + v, 0)).toBeCloseTo(100, 0);
    const w = getWellbeing(NAT, F0);
    expect(w.careTopics.reduce((s, c) => s + c.share, 0)).toBeCloseTo(100, 0);
    const a = getAttendance(NAT, F0);
    const st = a.statuses!;
    expect(st.onTime + st.late + st.leftEarly + st.excused + st.absent).toBeCloseTo(100, 0);
  });

  it("filtrlar ta'sir qiladi va fanlar sinfga bog'liq", () => {
    const all = getMastery(NAT, F0);
    const primary = getMastery(NAT, { ...F0, grades: 'G1_4' });
    expect(primary.bySubject.find((s) => s.subject === 'CHEMISTRY')?.value).toBeNull();
    expect(all.bySubject.find((s) => s.subject === 'CHEMISTRY')?.value).not.toBeNull();
    expect(primary.overall.value).not.toBe(all.overall.value);
    const interests = getInterests(NAT, F0);
    expect(interests.subjects[0]?.share).toBeGreaterThan(40);
    expect(interests.riasec).toHaveLength(6);
  });

  it('jadval, maktablar va xulosalar', () => {
    expect(getRegionsTable(F0)).toHaveLength(14);
    const s = getSchools(SAM, F0);
    expect(s.types).toHaveLength(3);
    expect(s.topGrowth.length).toBeGreaterThan(0);
    expect(s.districts).toHaveLength(16);
    const ins = getInsights(NAT, F0);
    expect(ins.length).toBeGreaterThanOrEqual(6);
    expect(new Set(ins.map((i) => i.id)).size).toBe(ins.length);
  });

  it('tezlik: barcha sahifa ma\'lumotlari 3 soniyadan kam', () => {
    __clearEngineCache();
    const t0 = performance.now();
    for (const scope of [NAT, SAM]) {
      getOverview(scope, F0);
      getMastery(scope, F0);
      getIq(scope, F0);
      getInterests(scope, F0);
      getWellbeing(scope, F0);
      getAttendance(scope, F0);
      getDigital(scope, F0);
      getInsights(scope, F0);
    }
    expect(performance.now() - t0).toBeLessThan(3000);
  });
});
