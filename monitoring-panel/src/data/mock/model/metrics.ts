/**
 * Ko'rsatkichlar reyestri: har bir skalyar ko'rsatkichning birligi, yaxshi
 * yo'nalishi va hisoblash usuli. Xarita, reyting, KPI va trendlar shu
 * reyestrdan foydalanadi (bitta manba).
 */
import type { Riasec, Subject } from '@/data/reference/domains';
import { SUBJECT_KEYS } from '@/data/reference/domains';
import type { SchoolMonth } from './calendar';
import { aggregate, type Agg, type Area, coveredCount, officialCount, type StrataFilters } from './engine';
import * as F from './formulas';
import { coverageRate } from './population';

export const METRIC_KEYS = [
  'coverage',
  'active',
  'parents',
  'mastery',
  'success',
  'tests',
  'iqParticipation',
  'iqMean',
  'iqHigh',
  'iqGrowthZone',
  'careerReadiness',
  'wellbeing',
  'bullying',
  'support',
  'anxiety',
  'sleep',
  'careRequests',
  'safetyGap',
  'schoolQuality',
  'teacherRelation',
  'attendance',
  'late',
  'chronic',
  'screenTime',
  'night',
  'schoolMode',
  'steps',
] as const;
export type MetricKey = (typeof METRIC_KEYS)[number];

export type MetricUnit = '%' | 'score' | 'index' | 'min' | 'per1000' | 'steps' | 'perWeek';
export type MetricDomain = 'coverage' | 'mastery' | 'iq' | 'interests' | 'wellbeing' | 'attendance' | 'digital';

export type MetricDef = {
  key: MetricKey;
  unit: MetricUnit;
  /** Qaysi yo'nalish yaxshi: xarita ranglari va o'zgarish belgisi shunga qarab. */
  better: 'up' | 'down' | 'neutral';
  decimals: number;
  domain: MetricDomain;
  compute: (area: Area, f: StrataFilters, months: readonly SchoolMonth[]) => Agg;
};

/** Qatlamdagi umumiy o'zlashtirish: fanlar bo'yicha, urinishlar ulushi (fan tanlovi) vazni bilan. */
export function overallMastery(c: F.Ctx): number | null {
  let sum = 0;
  let w = 0;
  for (const s of SUBJECT_KEYS) {
    const m = F.mastery(c, s);
    const wi = F.subjectInterest(c, s);
    if (m === null || wi === null) continue;
    sum += m * wi;
    w += wi;
  }
  return w > 0 ? sum / w : null;
}

const pct = (fn: (c: F.Ctx) => number | null) => (c: F.Ctx) => {
  const v = fn(c);
  return v === null ? null : v * 100;
};

function def(
  key: MetricKey,
  unit: MetricUnit,
  better: MetricDef['better'],
  decimals: number,
  domain: MetricDomain,
  fn: (c: F.Ctx) => number | null,
  base?: (c: F.Ctx) => number,
): MetricDef {
  return { key, unit, better, decimals, domain, compute: (area, f, months) => aggregate(key, area, f, months, fn, base) };
}

const iqBase = (c: F.Ctx) => F.iqParticipation(c) ?? 0;
const surveyBase = F.surveyParticipation;

export const METRICS: Readonly<Record<MetricKey, MetricDef>> = {
  coverage: {
    key: 'coverage',
    unit: '%',
    better: 'up',
    decimals: 1,
    domain: 'coverage',
    compute: (area, f, months) => {
      const official = officialCount(area, f);
      const covered = coveredCount(area, f, months);
      return { value: official > 0 ? (covered / official) * 100 : null, n: covered };
    },
  },
  active: def('active', '%', 'up', 1, 'coverage', pct(F.activeRate)),
  parents: def('parents', '%', 'up', 1, 'coverage', pct(F.parentsLinked)),
  mastery: def('mastery', '%', 'up', 1, 'mastery', overallMastery, F.activeRate),
  success: def('success', '%', 'up', 1, 'mastery', (c) => {
    const m = overallMastery(c);
    return m === null ? null : F.successRate(m);
  }, F.activeRate),
  tests: def('tests', 'perWeek', 'up', 1, 'mastery', F.testsPerWeek, F.activeRate),
  iqParticipation: def('iqParticipation', '%', 'up', 1, 'iq', pct(F.iqParticipation)),
  iqMean: def('iqMean', 'score', 'neutral', 1, 'iq', F.iqMean, iqBase),
  iqHigh: def('iqHigh', '%', 'up', 1, 'iq', (c) => {
    const mu = F.iqMean(c);
    if (mu === null) return null;
    const b = F.iqBandShares(mu);
    return (b.VERY_HIGH + b.HIGH + b.ABOVE_AVERAGE) * 100;
  }, iqBase),
  iqGrowthZone: def('iqGrowthZone', '%', 'down', 1, 'iq', (c) => {
    const mu = F.iqMean(c);
    if (mu === null) return null;
    const b = F.iqBandShares(mu);
    return (b.LOW + b.VERY_LOW) * 100;
  }, iqBase),
  careerReadiness: def('careerReadiness', 'index', 'up', 0, 'interests', F.careerReadiness),
  wellbeing: def('wellbeing', 'index', 'up', 0, 'wellbeing', (c) => F.wellbeingTopic(c, 'WELLBEING'), surveyBase),
  bullying: def('bullying', '%', 'down', 1, 'wellbeing', F.bullying, surveyBase),
  support: def('support', '%', 'down', 1, 'wellbeing', F.supportSignal, surveyBase),
  anxiety: def('anxiety', '%', 'down', 1, 'wellbeing', F.anxiety, surveyBase),
  sleep: def('sleep', '%', 'down', 1, 'wellbeing', F.sleepShort, surveyBase),
  careRequests: def('careRequests', 'per1000', 'neutral', 1, 'wellbeing', F.careRequests),
  safetyGap: def('safetyGap', '%', 'down', 1, 'wellbeing', F.safetyGap),
  schoolQuality: def('schoolQuality', 'index', 'up', 0, 'wellbeing', F.schoolQuality, surveyBase),
  teacherRelation: def('teacherRelation', 'index', 'up', 0, 'wellbeing', F.teacherRelation, surveyBase),
  attendance: def('attendance', '%', 'up', 1, 'attendance', F.attendance),
  late: def('late', '%', 'down', 1, 'attendance', F.late),
  chronic: def('chronic', '%', 'down', 1, 'attendance', F.chronicAbsence),
  screenTime: def('screenTime', 'min', 'down', 0, 'digital', F.screenTime, F.deviceShare),
  night: def('night', '%', 'down', 1, 'digital', F.nightUse, F.deviceShare),
  schoolMode: def('schoolMode', '%', 'up', 1, 'digital', F.schoolModeCompliance, F.deviceShare),
  steps: def('steps', 'steps', 'up', 0, 'digital', F.steps, F.deviceShare),
};

export function metricValue(key: MetricKey, area: Area, f: StrataFilters, months: readonly SchoolMonth[]): Agg {
  return METRICS[key].compute(area, f, months);
}

/** Fan bo'yicha o'zlashtirish. */
export function subjectMastery(subject: Subject, area: Area, f: StrataFilters, months: readonly SchoolMonth[]): Agg {
  return aggregate(`mastery:${subject}`, area, f, months, (c) => F.mastery(c, subject), (c) => F.activeRate(c) * (F.subjectInterest(c, subject) ?? 0));
}

/** Fanni tanlaganlar ulushi (%). */
export function subjectInterestShare(subject: Subject, area: Area, f: StrataFilters, months: readonly SchoolMonth[]): Agg {
  return aggregate(`si:${subject}`, area, f, months, (c) => {
    const v = F.subjectInterest(c, subject);
    return v === null ? null : v * 100;
  }, F.activeRate);
}

export function riasecMean(code: Riasec, area: Area, f: StrataFilters, months: readonly SchoolMonth[]): Agg {
  return aggregate(`ri:${code}`, area, f, months, (c) => F.riasecScore(c, code));
}

/** Monitoring qamrovi: rasmiy va ulangan o'quvchilar. */
export function coverageCounts(area: Area, f: StrataFilters, months: readonly SchoolMonth[]): { official: number; covered: number } {
  return { official: officialCount(area, f), covered: coveredCount(area, f, months) };
}

export { coverageRate };
