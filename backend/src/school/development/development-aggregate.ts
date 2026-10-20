// Maktab kesimi (panel `development-aggregate.ts` bilan bir xil qoidalar).
// Direktor / admin uchun (chorak, soha) bo'yicha alohida K=5 atomlari: e'lon
// qilinadigan har guruh atomlarning to'liq birlashmasi va n ≥ K. Natijada
// studentId yoki ism YO'Q. Guruhlash natijalardagi sinf / daraja nusxasidan.

import { percent } from '../attendance/attendance-view';
import { abilityBand } from '../assessments/psych/scoring';
import { termOf } from '../assessments/psych/terms';
import type { AbilityBand, DevDomain, IsoDate } from '../assessments/psych/types';
import { Cell, cellsOf, domainMean, domainN, idsOf, K, plan, Plan, schoolDomainValues, sumOf, visible } from './development-cells';
import { DEV_DOMAINS, DevIndex, meanOf, roundOrNull, termEnd, termYear } from './development-index';
import type { LiveClass, Roster, SchoolDevOverview } from './development.types';

/** Testlar shu sinfdan boshlanadi (shablonlar 3-sinfdan) — qamrov va bo'sh qatorlar uchun. */
export const MIN_GRADE = 3;
/** Joriy chorak hali davom etayotgan bo'lsa (masalan, faqat 2 sinf), standart ko'rinish uchun yetarli emas. */
export const DEFAULT_MIN_COVERAGE = 0.5;

/** Sinf o'sha chorakda nechanchi sinf edi (jonli daraja — faqat qamrov va bo'sh qatorlar uchun). */
export function gradeInTerm(cls: Pick<LiveClass, 'grade'>, termKey: string, today: IsoDate): number {
  return cls.grade - (termOf(today).year - termYear(termKey));
}

function emptyBands(): Record<AbilityBand, number> {
  return { VERY_LOW: 0, LOW: 0, AVERAGE: 0, HIGH: 0, VERY_HIGH: 0 };
}

function cognitiveByGrade(cells: readonly Cell[], p: Plan, suppress: boolean): SchoolDevOverview['cognitiveByGrade'] {
  const grades = [...new Set(cells.filter((c) => domainN(c, 'REASONING') > 0).map((c) => c.grade))].sort((a, b) => a - b);
  return grades.map((grade) => {
    const members = cells.filter((c) => c.grade === grade);
    const n = sumOf(members, (c) => domainN(c, 'REASONING'));
    const shown = visible(suppress, n, idsOf(members), p.byDomain.get('REASONING') ?? []);
    const standards = members.flatMap((c) => c.byDomain.get('REASONING')?.standards ?? []);
    const bands = standards.reduce((acc, ss) => ({ ...acc, [abilityBand(ss)]: acc[abilityBand(ss)] + 1 }), emptyBands());
    return {
      grade,
      n: shown ? n : 0,
      hidden: !shown,
      meanStandard: shown ? roundOrNull(meanOf(standards)) : null,
      bands: shown && !suppress ? bands : null,
    };
  });
}

/** Qo'pol taqsimot: bitta katak yashirilsa — ayirma orqali tiklanmasligi uchun keyingisi ham. */
function coarse(cells: readonly Cell[], suppress: boolean): SchoolDevOverview['cognitiveCoarse'] {
  const standards = cells.flatMap((c) => c.byDomain.get('REASONING')?.standards ?? []);
  if (standards.length === 0) return null;
  const counts = { below: standards.filter((s) => s < 85).length, within: standards.filter((s) => s >= 85 && s < 115).length, above: standards.filter((s) => s >= 115).length };
  if (!suppress) return counts;
  if (standards.length < K) return null;
  const keys = (['below', 'within', 'above'] as const).slice().sort((a, b) => counts[a] - counts[b]);
  const small = keys.filter((k) => counts[k] < K);
  const next = small.length === 1 ? keys.find((k) => !small.includes(k)) : undefined;
  const hidden = new Set([...small, ...(next ? [next] : [])]);
  if (hidden.size > 0 && sumOf([...hidden], (k) => counts[k]) < K) return null;
  return { below: hidden.has('below') ? null : counts.below, within: hidden.has('within') ? null : counts.within, above: hidden.has('above') ? null : counts.above };
}

function trend(idx: DevIndex, suppress: boolean): SchoolDevOverview['trend'] {
  const minN = suppress ? K : 1;
  return idx.terms.flatMap((termKey) => {
    const cells = cellsOf(idx.snapshot.get(termKey));
    const n = sumOf(cells, (c) => c.any);
    if (n < minN) return [];
    const values: Partial<Record<DevDomain, number>> = {};
    for (const d of DEV_DOMAINS) {
      const m = sumOf(cells, (c) => domainN(c, d)) >= minN ? domainMean(cells, d, 'indexes') : null;
      if (m !== null) values[d] = m;
    }
    return [{ termKey, n, values }];
  });
}

/** Sinf qatorlari — faqat hozir mavjud sinflar (o'chirilgan sinf natijalari atomlarda qoladi, qator chiqmaydi). */
function heat(cells: readonly Cell[], p: Plan, suppress: boolean, roster: Roster, termKey: string, today: IsoDate): SchoolDevOverview['heat'] {
  return roster.classes
    .flatMap((cls) => {
      const members = cells.filter((c) => c.classId === cls.id);
      const any = sumOf(members, (c) => c.any);
      if (any === 0 && gradeInTerm(cls, termKey, today) < MIN_GRADE) return [];
      const ids = idsOf(members);
      const shown = any > 0 && visible(suppress, any, ids, p.any);
      const values: Partial<Record<DevDomain, number | null>> = {};
      for (const d of DEV_DOMAINS) {
        const ok = shown && visible(suppress, sumOf(members, (c) => domainN(c, d)), ids, p.byDomain.get(d) ?? []);
        values[d] = ok ? domainMean(members, d, 'indexes') : null;
      }
      const latest = [...members].sort((a, b) => b.lastAt - a.lastAt)[0];
      const grade = latest ? latest.grade : cls.grade;
      return [{ letter: cls.letter, row: { classId: cls.id, className: cls.name, grade, n: shown ? any : 0, hidden: any > 0 && !shown, cells: values } }];
    })
    .sort((a, b) => a.row.grade - b.row.grade || a.letter.localeCompare(b.letter))
    .map((x) => x.row);
}

/** Qamrov: baholanganlar / shu chorakda 3-sinfdan yuqori faol o'quvchilar (jonli ro'yxat — faqat son). */
export function participation(cells: readonly Cell[], roster: Roster, termKey: string, today: IsoDate): SchoolDevOverview['participation'] {
  const end = termEnd(termKey);
  const gradeOf = new Map(roster.classes.map((c) => [c.id, gradeInTerm(c, termKey, today)]));
  const eligible = roster.students.filter((s) => !s.archived && s.classId && (gradeOf.get(s.classId) ?? 0) >= MIN_GRADE && s.enrolledAt <= end).length;
  const assessed = sumOf(cells, (c) => c.any);
  const total = Math.max(eligible, assessed);
  return { assessed, eligible: total, rate: percent(assessed, total) };
}

/**
 * Standart chorak: maktab bo'yicha n ≥ K bo'lgan eng so'nggi chorak; agar shunday choraklardan
 * birida qamrov ≥ 50% bo'lsa — o'shalarning eng so'nggisi (yarim to'lqin bo'sh ko'rinmasin).
 */
export function defaultSchoolTerm(idx: DevIndex, roster: Roster, today: IsoDate): string | null {
  const stats = idx.terms.map((term) => {
    const cells = cellsOf(idx.snapshot.get(term));
    return { term, n: sumOf(cells, (c) => c.any), coverage: participation(cells, roster, term, today).rate / 100 };
  });
  const publishable = stats.filter((s) => s.n >= K);
  const covered = publishable.filter((s) => s.coverage >= DEFAULT_MIN_COVERAGE);
  return covered.at(-1)?.term ?? publishable.at(-1)?.term ?? idx.terms.at(-1) ?? null;
}

export function computeSchoolOverview(
  idx: DevIndex,
  roster: Roster,
  termKey: string,
  opts: { suppress: boolean; today: IsoDate; attentionCount: string | null },
): SchoolDevOverview {
  const { suppress, today } = opts;
  const cells = cellsOf(idx.snapshot.get(termKey));
  const p = plan(cells);
  return {
    termKey,
    suppressed: suppress,
    participation: participation(cells, roster, termKey, today),
    domainAverages: schoolDomainValues(cells, suppress ? K : 1),
    cognitiveByGrade: cognitiveByGrade(cells, p, suppress),
    cognitiveCoarse: coarse(cells, suppress),
    trend: trend(idx, suppress),
    heat: heat(cells, p, suppress, roster, termKey, today),
    attentionCount: opts.attentionCount,
  };
}

export function emptySchoolOverview(termKey: string, suppress: boolean): SchoolDevOverview {
  return {
    termKey,
    suppressed: suppress,
    participation: { assessed: 0, eligible: 0, rate: 0 },
    domainAverages: DEV_DOMAINS.map((domain) => ({ domain, index: null, n: 0 })),
    cognitiveByGrade: [],
    cognitiveCoarse: null,
    trend: [],
    heat: [],
    attentionCount: null,
  };
}
