/**
 * O'quv yo'nalishlari: o'zlashtirish (Daily Learning), Parvoz IQ va
 * qiziqishlar (fanlar, umumiy qiziqishlar, RIASEC, kasb sohalari).
 */
import type { Filters, Interests, Iq, Mastery, Scope, ShareItem } from '@/data/contracts';
import * as F from '@/data/mock/model/formulas';
import { aggregate, type Area } from '@/data/mock/model/engine';
import { findDistrict, REGION_LATENT } from '@/data/mock/model/latent';
import { overallMastery, riasecMean, subjectInterestShare, subjectMastery } from '@/data/mock/model/metrics';
import {
  CAREER_FIELD_PROFILE,
  CAREER_FIELDS,
  type CareerField,
  GRADES,
  INTERESTS,
  IQ_DISPLAY_BANDS,
  IQ_DOMAINS,
  type IqDisplayBand,
  RIASEC,
  type Riasec,
  SCHOOL_TYPES,
  type Subject,
  SUBJECT_KEYS,
} from '@/data/reference/domains';
import {
  childAreas,
  customSeries,
  customStat,
  customValue,
  metricSeries,
  metricStat,
  round,
  scopeArea,
  strata,
  window,
} from './core';

const NATIONAL: Area = { kind: 'NATIONAL' };
const withFilter = (f: Filters, patch: Partial<Filters>): Filters => ({ ...f, ...patch });

// ───────────────────────────── O'zlashtirish ─────────────────────────────

function difficultyMix(m: number | null): Mastery['difficulty'] {
  if (m === null) return { level1: 0, level2: 0, level3: 0 };
  const level3 = Math.min(0.7, Math.max(0.05, (m - 55) / 45));
  const level1 = Math.min(0.7, Math.max(0.05, (78 - m) / 45));
  const level2 = Math.max(0.05, 1 - level1 - level3);
  const total = level1 + level2 + level3;
  return { level1: round((level1 / total) * 100) ?? 0, level2: round((level2 / total) * 100) ?? 0, level3: round((level3 / total) * 100) ?? 0 };
}

export function getMastery(scope: Scope, f: Filters): Mastery {
  const area = scopeArea(scope);
  const w = window(f);
  const sf = strata(f);
  const overall = metricStat('mastery', area, f);
  const bySubject = SUBJECT_KEYS.map((subject) => {
    const cur = subjectMastery(subject, area, sf, w.months);
    const base = w.baseline.length ? subjectMastery(subject, area, sf, w.baseline) : null;
    const value = round(cur.value);
    const baseValue = base ? round(base.value) : null;
    return {
      subject,
      value,
      base: baseValue,
      delta: value !== null && baseValue !== null ? round(value - baseValue) : null,
      n: cur.n,
      interest: round(subjectInterestShare(subject, area, sf, w.months).value),
      success: value === null ? null : round(F.successRate(value)),
      national: scope.kind === 'NATIONAL' ? value : round(subjectMastery(subject, NATIONAL, sf, w.months).value),
    };
  });
  const heat = childAreas(scope).map(({ area: a, id, name }) => ({
    id,
    name,
    overall: round(customValue('mastery', a, f, overallMastery, F.activeRate)),
    values: Object.fromEntries(SUBJECT_KEYS.map((s) => [s, round(subjectMastery(s, a, sf, w.months).value)])) as Record<Subject, number | null>,
  }));
  return {
    overall,
    success: metricStat('success', area, f),
    tests: metricStat('tests', area, f),
    national: { overall: scope.kind === 'NATIONAL' ? overall.value : metricStat('mastery', NATIONAL, f).value },
    bySubject,
    byGrade: GRADES.map((grade) => ({
      grade,
      value: round(customValue(`mastery:g${grade}`, area, f, (c) => (c.grade === grade ? overallMastery(c) : null), F.activeRate)),
    })),
    byGender: (['M', 'F'] as const).map((gender) => ({ gender, value: metricStat('mastery', area, withFilter(f, { gender })).value })),
    bySchoolType: SCHOOL_TYPES.map((type) => ({ type, value: metricStat('mastery', area, withFilter(f, { schoolType: type })).value })),
    trend: metricSeries('mastery', area, f),
    heat,
    difficulty: difficultyMix(overall.value),
  };
}

// ───────────────────────────── IQ ─────────────────────────────

const iqBase = (c: F.Ctx) => F.iqParticipation(c) ?? 0;

function displayBands(area: Area, f: Filters, months = window(f).months): Record<IqDisplayBand, number> | null {
  const raw = Object.fromEntries(
    (['VERY_HIGH', 'HIGH', 'ABOVE_AVERAGE', 'AVERAGE', 'BELOW_AVERAGE', 'LOW', 'VERY_LOW'] as const).map((band) => [
      band,
      customValue(`iqband:${band}`, area, f, (c) => {
        const mu = F.iqMean(c);
        return mu === null ? null : F.iqBandShares(mu)[band] * 100;
      }, iqBase, months),
    ]),
  ) as Record<string, number | null>;
  if (Object.values(raw).some((v) => v === null)) return null;
  const r = raw as Record<string, number>;
  return {
    VERY_HIGH: round(r.VERY_HIGH!) ?? 0,
    HIGH: round(r.HIGH!) ?? 0,
    ABOVE_AVERAGE: round(r.ABOVE_AVERAGE!) ?? 0,
    AVERAGE: round(r.AVERAGE!) ?? 0,
    BELOW_AVERAGE: round(r.BELOW_AVERAGE!) ?? 0,
    GROWTH_ZONE: round(r.LOW! + r.VERY_LOW!) ?? 0,
  };
}

export function getIq(scope: Scope, f: Filters): Iq {
  const area = scopeArea(scope);
  const w = window(f);
  const participation = metricStat('iqParticipation', area, f);
  const mean = metricStat('iqMean', area, f);
  const bands = displayBands(area, f);
  const baseBands = w.baseline.length ? displayBands(area, f, w.baseline) : null;
  const participants = Math.round(customStat('iqn', area, f, (c) => (F.iqParticipation(c) === null ? null : 1), iqBase).n);
  return {
    participation,
    mean,
    high: metricStat('iqHigh', area, f),
    growthZone: metricStat('iqGrowthZone', area, f),
    // Har yosh guruhida ≥300 birinchi urinish bo'lsa NORMED (demo hajmida doim bajariladi).
    normed: participants >= 300 * 9,
    participants,
    bands: IQ_DISPLAY_BANDS.map((key) => ({
      key,
      share: bands?.[key] ?? 0,
      delta: bands && baseBands ? round(bands[key] - baseBands[key]) : null,
    })),
    domains: IQ_DOMAINS.map((domain) => ({
      domain,
      value: round(customValue(`iqd:${domain}`, area, f, (c) => F.iqDomainPercent(c, domain), iqBase)),
      national: round(customValue(`iqd:${domain}`, NATIONAL, f, (c) => F.iqDomainPercent(c, domain), iqBase)),
    })),
    byArea: childAreas(scope).map(({ area: a, id, name }) => ({
      id,
      name,
      bands: displayBands(a, f),
      mean: metricStat('iqMean', a, f).value,
      participation: metricStat('iqParticipation', a, f).value,
    })),
    byGradeBand: (['G1_4', 'G5_9', 'G10_11'] as const).map((band) => ({
      band,
      mean: metricStat('iqMean', area, withFilter(f, { grades: band })).value,
      participation: metricStat('iqParticipation', area, withFilter(f, { grades: band })).value,
    })),
    byGender: (['M', 'F'] as const).map((gender) => ({ gender, mean: metricStat('iqMean', area, withFilter(f, { gender })).value })),
    trend: metricSeries('iqParticipation', area, f),
  };
}

// ───────────────────────────── Qiziqishlar ─────────────────────────────

function riasecScores(area: Area, f: Filters): Record<Riasec, number | null> {
  const w = window(f);
  return Object.fromEntries(RIASEC.map((code) => [code, round(riasecMean(code, area, strata(f), w.months).value)])) as Record<Riasec, number | null>;
}

function topShares(scores: Record<Riasec, number | null>): Record<Riasec, number> | null {
  if (RIASEC.some((c) => scores[c] === null)) return null;
  return F.riasecTopShares(scores as Record<Riasec, number>);
}

function careerFields(top: Record<Riasec, number> | null, agro: number): Array<ShareItem<CareerField>> {
  if (!top) return CAREER_FIELDS.map((key) => ({ key, share: 0 }));
  const raw = CAREER_FIELDS.map((field) => {
    const profile = CAREER_FIELD_PROFILE[field];
    let v = RIASEC.reduce((s, code) => s + (profile[code] ?? 0) * top[code], 0);
    if (field === 'AGRO') v *= 0.55 + agro;
    if (field === 'IT') v *= 1.55;
    return { key: field, v };
  });
  const total = raw.reduce((s, r) => s + r.v, 0) || 1;
  return raw.map((r) => ({ key: r.key, share: round((r.v / total) * 100) ?? 0 })).sort((a, b) => b.share - a.share);
}

/** Hudud/tuman qishloq xo'jaligi omili (kasb sohalari uchun). */
function agroOf(area: Area): number {
  if (area.kind === 'NATIONAL') return 0.55;
  if (area.kind === 'REGION') return REGION_LATENT[area.id].agro;
  return findDistrict(area.id)?.latent.agro ?? 0.55;
}

/**
 * Ulush: hech kim o'qimasa (fan bu sinflarda yo'q) — 0; guruh K-anonimlik chegarasidan
 * kichik bo'lsa — null ("—"), aks holda yaxlitlangan qiymat.
 */
function shareOf(agg: { value: number | null; n: number }): number | null {
  return agg.n === 0 ? 0 : round(agg.value);
}

/** Kamayish tartibida, yashirilganlar oxirida. */
const byShareDesc = (a: { share: number | null }, b: { share: number | null }) => (b.share ?? -1) - (a.share ?? -1);

export function getInterests(scope: Scope, f: Filters): Interests {
  const area = scopeArea(scope);
  const w = window(f);
  const sf = strata(f);
  const scores = riasecScores(area, f);
  const national = scope.kind === 'NATIONAL' ? scores : riasecScores(NATIONAL, f);
  const top = topShares(scores);
  const subjects = SUBJECT_KEYS.map((subject) => ({
    key: subject,
    share: shareOf(subjectInterestShare(subject, area, sf, w.months)),
    mastery: round(subjectMastery(subject, area, sf, w.months).value),
  })).sort(byShareDesc);
  const general = INTERESTS.map((interest) => ({
    key: interest,
    share: shareOf(aggregate(`gi:${interest}`, area, sf, w.months, (c) => F.generalInterest(c, interest) * 100, F.activeRate)),
  })).sort(byShareDesc);
  const byArea = childAreas(scope).map(({ area: a, id, name }) => {
    const subs = SUBJECT_KEYS.map((s) => ({ s, v: subjectInterestShare(s, a, sf, w.months).value ?? -1 })).sort((x, y) => y.v - x.v);
    const sc = riasecScores(a, f);
    const ts = topShares(sc);
    const topCode = ts ? (RIASEC.slice().sort((x, y) => ts[y] - ts[x])[0] ?? null) : null;
    const fields = careerFields(ts, agroOf(a));
    return {
      id,
      name,
      topSubject: subs[0] && subs[0].v >= 0 ? subs[0].s : null,
      topSubjectShare: subs[0] && subs[0].v >= 0 ? round(subs[0].v) : null,
      topCode,
      topField: fields[0]?.key ?? null,
    };
  });
  return {
    subjects,
    general,
    riasec: RIASEC.map((code) => ({ code, score: scores[code], national: national[code] })),
    riasecTop: top ? RIASEC.map((key) => ({ key, share: round(top[key] * 100) ?? 0 })).sort((a, b) => b.share - a.share) : [],
    careerFields: careerFields(top, agroOf(area)),
    careerReadiness: metricStat('careerReadiness', area, f, 0),
    byArea,
    byGender: (['M', 'F'] as const).map((gender) => ({
      gender,
      subjects: SUBJECT_KEYS.map((s) => ({
        key: s,
        share: shareOf(subjectInterestShare(s, area, strata(withFilter(f, { gender })), w.months)),
      })).sort(byShareDesc),
    })),
  };
}

export { customSeries };
