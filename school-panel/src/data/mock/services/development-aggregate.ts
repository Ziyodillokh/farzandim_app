import type {
  AbilityBand,
  DevDomain,
  IsoDate,
  Localized,
  PsychScale,
  PsychTest,
  ScaleScore,
  SchoolClass,
  SchoolDevOverview,
  ScoreBand,
  ScoredResult,
} from '@/data/contracts';
import { CARE_MIN_GROUP as K } from '@/lib/k-anon';
import { abilityBand, domainIndex, scoreResult } from '@/lib/psych/scoring';
import { quarterRanges, termOf } from '@/lib/psych/terms';
import { percent } from '@/lib/utils';
import { toIsoDate } from '../calendar';
import { compareClasses } from '../lookups';
import { findTest } from '../psych/catalog';
import { HISTORY_MIN_GRADE } from '../psych/history';
import { allResults } from '../psych/results';
import { ageGroupOf } from '../seed/care';
import type { Tables } from '../tables';
import { type Atom, buildAtoms, isUnionOfAtoms } from './care-suppression';

/**
 * Rivojlanish — natijalar indeksi va maktab kesimi.
 *
 * Indeks 0..100 = persentil (xavotir kabi HIGHER_CONCERN shkalalarda teskari): yuqori — yaxshiroq.
 * Direktor/admin uchun maktab kesimi Bola ovozi bilan bir xil "atom" qoidasida yashiriladi
 * (`care-suppression.ts`): har (chorak, soha) uchun alohida atomlar, e'lon qilinadigan har
 * guruh atomlarning to'liq birlashmasi va n ≥ K. Natijada studentId yoki ism YO'Q.
 */
export const DEV_DOMAINS: readonly DevDomain[] = ['REASONING', 'ATTENTION', 'MEMORY', 'EMOTIONAL', 'SELF_ESTEEM', 'SOCIAL'];
export const COGNITIVE: readonly DevDomain[] = ['REASONING', 'ATTENTION', 'MEMORY'];
export const MIN_GROUP = K;

export type DomainScore = { index: number | null; band: ScoreBand | null; standard: number | null };
export type DomainMap = Partial<Record<DevDomain, DomainScore>>;
export type Entry = { result: ScoredResult; testTitle: Localized; termKey: string; at: number; domains: DomainMap };
export type StudentTerm = { classId: string; domains: DomainMap; lastTakenAt: string };
export type DevIndex = {
  entries: Entry[];
  tests: ReadonlyMap<string, PsychTest>;
  byStudent: ReadonlyMap<string, Entry[]>;
  /** Natija bor choraklar (eskidan yangiga). */
  terms: string[];
  /** chorak → o'quvchi → shu chorakdagi har soha bo'yicha eng so'nggi qiymat. */
  snapshot: ReadonlyMap<string, ReadonlyMap<string, StudentTerm>>;
};

const mean = (xs: readonly number[]): number | null => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
const roundOrNull = (x: number | null): number | null => (x === null ? null : Math.round(x));

/** Bir sohaga bir nechta shkala (hissiy holat: xavotir + kayfiyat) — indekslar o'rtachasi. */
function domainsOf(test: Pick<PsychTest, 'scales'>, scores: readonly ScaleScore[]): DomainMap {
  const groups = new Map<DevDomain, Array<{ scale: PsychScale; score: ScaleScore }>>();
  for (const scale of test.scales) {
    const score = scores.find((s) => s.key === scale.key);
    if (!scale.domain || !score) continue;
    groups.set(scale.domain, [...(groups.get(scale.domain) ?? []), { scale, score }]);
  }
  const out: DomainMap = {};
  for (const [domain, items] of groups) {
    const indexes = items.map((i) => domainIndex(i.score, i.scale.polarity)).filter((x): x is number => x !== null);
    const concern = items.find((i) => i.scale.polarity === 'HIGHER_CONCERN');
    const standards = items.map((i) => i.score.standard).filter((x): x is number => x !== null);
    out[domain] = {
      index: roundOrNull(mean(indexes)),
      band: (concern ?? items[0])?.score.band ?? null,
      standard: concern || standards.length !== items.length ? null : roundOrNull(mean(standards)),
    };
  }
  return out;
}

function localDate(stamp: string): IsoDate {
  return toIsoDate(new Date(Date.parse(stamp)));
}

function buildIndex(t: Tables): DevIndex {
  const tests = new Map<string, PsychTest | undefined>();
  const testOf = (id: string) => {
    if (!tests.has(id)) tests.set(id, findTest(t, id));
    return tests.get(id);
  };
  const entries: Entry[] = [];
  for (const r of allResults(t)) {
    const test = testOf(r.testId);
    if (!test) continue;
    const scored = scoreResult(test, r);
    entries.push({
      result: { ...r, ...scored },
      testTitle: test.title,
      termKey: termOf(localDate(r.takenAt)).key,
      at: Date.parse(r.takenAt),
      domains: domainsOf(test, scored.scales),
    });
  }
  const byStudent = new Map<string, Entry[]>();
  const snapshot = new Map<string, Map<string, StudentTerm>>();
  for (const e of entries) {
    byStudent.set(e.result.studentId, [...(byStudent.get(e.result.studentId) ?? []), e]);
    const term = snapshot.get(e.termKey) ?? new Map<string, StudentTerm>();
    const prev = term.get(e.result.studentId);
    term.set(e.result.studentId, {
      classId: e.result.classId,
      domains: { ...prev?.domains, ...e.domains },
      lastTakenAt: e.result.takenAt,
    });
    snapshot.set(e.termKey, term);
  }
  const terms = [...snapshot.keys()].sort();
  const known = new Map([...tests].flatMap(([id, test]) => (test ? [[id, test] as const] : [])));
  return { entries, tests: known, byStudent, terms, snapshot };
}

const indexCache = new WeakMap<Tables, DevIndex>();

/** Har `transact` yangi jadvallar obyektini yaratadi — kesh shu obyektga bog'langan. */
export function devIndex(t: Tables): DevIndex {
  const hit = indexCache.get(t);
  if (hit) return hit;
  const built = buildIndex(t);
  indexCache.set(t, built);
  return built;
}

/** "2025-26:Q3" → 2025. */
export function termYear(termKey: string): number {
  return Number(termKey.slice(0, 4));
}

/** Chorak tugash sanasi ("2025-26:Q3" → 2026-03-20). */
export function termEnd(termKey: string): IsoDate {
  const no = Number(termKey.slice(-1));
  return quarterRanges(termYear(termKey))[no - 1]?.end ?? `${termYear(termKey) + 1}-05-31`;
}

/** Sinf o'sha chorakda nechanchi sinf edi (o'quvchilar har yili bir sinf yuqoriga o'tadi). */
export function gradeInTerm(cls: Pick<SchoolClass, 'grade'>, termKey: string, today: IsoDate): number {
  return cls.grade - (termOf(today).year - termYear(termKey));
}

type ClassAgg = { cls: SchoolClass; grade: number; any: number; byDomain: Map<DevDomain, { indexes: number[]; standards: number[] }> };

function classAggregates(t: Tables, snap: ReadonlyMap<string, StudentTerm> | undefined, termKey: string, today: IsoDate): ClassAgg[] {
  const aggs = new Map<string, ClassAgg>(
    [...t.classes]
      .sort(compareClasses)
      .map((cls) => [cls.id, { cls, grade: gradeInTerm(cls, termKey, today), any: 0, byDomain: new Map() }]),
  );
  for (const st of snap?.values() ?? []) {
    const agg = aggs.get(st.classId);
    if (!agg) continue;
    agg.any += 1;
    for (const d of DEV_DOMAINS) {
      const v = st.domains[d];
      if (!v || v.index === null) continue;
      const slot = agg.byDomain.get(d) ?? { indexes: [], standards: [] };
      agg.byDomain.set(d, { indexes: [...slot.indexes, v.index], standards: v.standard === null ? slot.standards : [...slot.standards, v.standard] });
    }
  }
  return [...aggs.values()];
}

const domainN = (a: ClassAgg, d: DevDomain) => a.byDomain.get(d)?.indexes.length ?? 0;
const sumOf = <T>(items: readonly T[], f: (x: T) => number) => items.reduce((s, x) => s + f(x), 0);

function atomsFor(aggs: readonly ClassAgg[], count: (a: ClassAgg) => number): Atom[] {
  return buildAtoms(aggs.map((a) => ({ classId: a.cls.id, grade: Math.max(1, a.grade), ageGroup: ageGroupOf(Math.max(1, a.grade)), n: count(a) })));
}

type Plan = { any: Atom[]; byDomain: Map<DevDomain, Atom[]> };

function plan(aggs: readonly ClassAgg[]): Plan {
  return { any: atomsFor(aggs, (a) => a.any), byDomain: new Map(DEV_DOMAINS.map((d) => [d, atomsFor(aggs, (a) => domainN(a, d))])) };
}

/** Psixolog — to'liq; boshqalar — n ≥ K va atomlar birlashmasi. */
function visible(suppress: boolean, n: number, classIds: ReadonlySet<string>, atoms: readonly Atom[]): boolean {
  if (n === 0) return false;
  return !suppress || (n >= K && isUnionOfAtoms(classIds, atoms));
}

function domainMean(aggs: readonly ClassAgg[], d: DevDomain, pick: 'indexes' | 'standards'): number | null {
  return roundOrNull(mean(aggs.flatMap((a) => a.byDomain.get(d)?.[pick] ?? [])));
}

/**
 * Maktab bo'yicha soha o'rtachalari (n ≥ minN). Shu chorakda umuman o'tkazilmagan soha
 * ro'yxatga kirmaydi; `index: null` — faqat yashirilgan (0 < n < K) soha.
 */
export function schoolDomainValues(t: Tables, idx: DevIndex, termKey: string, today: IsoDate, minN = K): Array<{ domain: DevDomain; index: number | null; n: number }> {
  const aggs = classAggregates(t, idx.snapshot.get(termKey), termKey, today);
  return DEV_DOMAINS.flatMap((d) => {
    const n = sumOf(aggs, (a) => domainN(a, d));
    if (n === 0) return [];
    return [n >= minN ? { domain: d, index: domainMean(aggs, d, 'indexes'), n } : { domain: d, index: null, n: 0 }];
  });
}

function emptyBands(): Record<AbilityBand, number> {
  return { VERY_LOW: 0, LOW: 0, AVERAGE: 0, HIGH: 0, VERY_HIGH: 0 };
}

function cognitiveByGrade(aggs: readonly ClassAgg[], p: Plan, suppress: boolean): SchoolDevOverview['cognitiveByGrade'] {
  const grades = [...new Set(aggs.filter((a) => domainN(a, 'REASONING') > 0).map((a) => a.grade))].sort((a, b) => a - b);
  return grades.map((grade) => {
    const members = aggs.filter((a) => a.grade === grade);
    const n = sumOf(members, (a) => domainN(a, 'REASONING'));
    const shown = visible(suppress, n, new Set(members.map((a) => a.cls.id)), p.byDomain.get('REASONING') ?? []);
    const standards = members.flatMap((a) => a.byDomain.get('REASONING')?.standards ?? []);
    const bands = emptyBands();
    for (const ss of standards) bands[abilityBand(ss)] += 1;
    return { grade, n: shown ? n : 0, hidden: !shown, meanStandard: shown ? roundOrNull(mean(standards)) : null, bands: shown && !suppress ? bands : null };
  });
}

/** Qo'pol taqsimot: bitta katak yashirilsa — ayirma orqali tiklanmasligi uchun keyingisi ham. */
function coarse(aggs: readonly ClassAgg[], suppress: boolean): SchoolDevOverview['cognitiveCoarse'] {
  const standards = aggs.flatMap((a) => a.byDomain.get('REASONING')?.standards ?? []);
  if (standards.length === 0) return null;
  const counts = { below: standards.filter((s) => s < 85).length, within: standards.filter((s) => s >= 85 && s < 115).length, above: standards.filter((s) => s >= 115).length };
  if (!suppress) return counts;
  if (standards.length < K) return null;
  const keys = (['below', 'within', 'above'] as const).slice().sort((a, b) => counts[a] - counts[b]);
  const hidden = new Set(keys.filter((k) => counts[k] < K));
  if (hidden.size === 1) {
    const next = keys.find((k) => !hidden.has(k));
    if (next) hidden.add(next);
  }
  if (hidden.size > 0 && sumOf([...hidden], (k) => counts[k]) < K) return null;
  return { below: hidden.has('below') ? null : counts.below, within: hidden.has('within') ? null : counts.within, above: hidden.has('above') ? null : counts.above };
}

function trend(t: Tables, idx: DevIndex, today: IsoDate, suppress: boolean): SchoolDevOverview['trend'] {
  const minN = suppress ? K : 1;
  return idx.terms.flatMap((termKey) => {
    const aggs = classAggregates(t, idx.snapshot.get(termKey), termKey, today);
    const n = sumOf(aggs, (a) => a.any);
    if (n < minN) return [];
    const values: Partial<Record<DevDomain, number>> = {};
    for (const d of DEV_DOMAINS) {
      const m = sumOf(aggs, (a) => domainN(a, d)) >= minN ? domainMean(aggs, d, 'indexes') : null;
      if (m !== null) values[d] = m;
    }
    return [{ termKey, n, values }];
  });
}

function heat(aggs: readonly ClassAgg[], p: Plan, suppress: boolean): SchoolDevOverview['heat'] {
  return aggs
    .filter((a) => a.any > 0 || a.grade >= HISTORY_MIN_GRADE)
    .map((a) => {
      const self = new Set([a.cls.id]);
      const shown = a.any > 0 && visible(suppress, a.any, self, p.any);
      const cells: Partial<Record<DevDomain, number | null>> = {};
      for (const d of DEV_DOMAINS) {
        const ok = shown && visible(suppress, domainN(a, d), self, p.byDomain.get(d) ?? []);
        cells[d] = ok ? domainMean([a], d, 'indexes') : null;
      }
      return { classId: a.cls.id, className: a.cls.name, grade: a.cls.grade, n: shown ? a.any : 0, hidden: a.any > 0 && !shown, cells };
    });
}

function participation(t: Tables, aggs: readonly ClassAgg[], termKey: string): SchoolDevOverview['participation'] {
  const grade = new Map(aggs.map((a) => [a.cls.id, a.grade]));
  const end = termEnd(termKey);
  const eligible = t.students.filter((s) => !s.archived && (grade.get(s.classId) ?? 0) >= HISTORY_MIN_GRADE && s.enrolledAt <= end).length;
  const assessed = sumOf(aggs, (a) => a.any);
  const total = Math.max(eligible, assessed);
  return { assessed, eligible: total, rate: percent(assessed, total) };
}

/** Joriy chorak hali davom etayotgan bo'lsa (masalan, faqat 2 sinf), standart ko'rinish uchun yetarli emas. */
export const DEFAULT_MIN_COVERAGE = 0.5;

/**
 * Standart chorak: maktab bo'yicha n ≥ K bo'lgan eng so'nggi chorak; agar shunday choraklardan
 * birida qamrov ≥ 50% bo'lsa — o'shalarning eng so'nggisi (yarim to'lqin bo'sh ko'rinmasin).
 */
export function defaultSchoolTerm(t: Tables, idx: DevIndex, today: IsoDate): string | null {
  const stats = idx.terms.map((term) => {
    const aggs = classAggregates(t, idx.snapshot.get(term), term, today);
    return { term, n: sumOf(aggs, (a) => a.any), coverage: participation(t, aggs, term).rate / 100 };
  });
  const publishable = stats.filter((s) => s.n >= K);
  const covered = publishable.filter((s) => s.coverage >= DEFAULT_MIN_COVERAGE);
  return covered.at(-1)?.term ?? publishable.at(-1)?.term ?? idx.terms.at(-1) ?? null;
}

export function computeSchoolOverview(
  t: Tables,
  idx: DevIndex,
  termKey: string,
  opts: { suppress: boolean; today: IsoDate; attentionCount: string | null },
): SchoolDevOverview {
  const { suppress, today } = opts;
  const aggs = classAggregates(t, idx.snapshot.get(termKey), termKey, today);
  const p = plan(aggs);
  return {
    termKey,
    suppressed: suppress,
    participation: participation(t, aggs, termKey),
    domainAverages: schoolDomainValues(t, idx, termKey, today, suppress ? K : 1),
    cognitiveByGrade: cognitiveByGrade(aggs, p, suppress),
    cognitiveCoarse: coarse(aggs, suppress),
    trend: trend(t, idx, today, suppress),
    heat: heat(aggs, p, suppress),
    attentionCount: opts.attentionCount,
  };
}
