// O'quvchi profili va sinf ko'rinishi (sof funksiyalar; panel `development.ts`).
// Psixolog (`assessments.manage`) — hammasi: xom ball, javoblar, vaqt.
// Sinf rahbari — xom ballsiz, javoblarsiz, vaqtsiz; hissiy holat FAQAT daraja.

import { ageBandOf, ageOn } from '../assessments/psych/scoring';
import type { DevDomain, IsoDate } from '../assessments/psych/types';
import { studentName } from './development-attention';
import { K } from './development-cells';
import { DEV_DOMAINS, DevIndex, Entry, latestDomains, localDay, termEnd } from './development-index';
import type { ClassDevOverview, LiveClass, LiveStudent, ProfileResult, Roster, StudentDevProfile } from './development.types';

const average = (xs: readonly number[]) => Math.round(xs.reduce((a, b) => a + b, 0) / xs.length);

/** Sinfdoshlar o'rtachasi (o'quvchining o'zisiz), faqat n ≥ K bo'lgan sohalar. */
function classmatesAverage(idx: DevIndex, roster: Roster, student: LiveStudent): StudentDevProfile['classAverage'] {
  const mates = roster.students.filter((s) => !s.archived && s.classId === student.classId && s.id !== student.id);
  const latest = mates.map((s) => latestDomains(idx.byStudent.get(s.id) ?? []));
  const out: StudentDevProfile['classAverage'] = {};
  for (const d of DEV_DOMAINS) {
    const xs = latest.map((m) => m[d]?.index).filter((x): x is number => typeof x === 'number');
    if (xs.length >= K) out[d] = average(xs);
  }
  return out;
}

function timeline(entries: readonly Entry[], full: boolean): StudentDevProfile['timeline'] {
  const terms = [...new Set(entries.map((e) => e.termKey))].sort();
  return terms.map((termKey) => {
    const inTerm = entries.filter((e) => e.termKey === termKey);
    const domains = latestDomains(inTerm);
    const values: Partial<Record<DevDomain, number>> = {};
    for (const d of DEV_DOMAINS) {
      const v = domains[d]?.index;
      if (typeof v === 'number' && (full || d !== 'EMOTIONAL')) values[d] = v;
    }
    const last = inTerm.at(-1);
    return { termKey, date: last ? localDay(last.result.takenAt) : termEnd(termKey), values };
  });
}

/** Psixolog uchun to'liq natija (javoblar — faqat ochilgan bo'lsa). */
function fullResult(e: Entry, answers: string | undefined): ProfileResult {
  const r = e.result;
  return {
    id: r.id,
    studentId: r.studentId,
    classId: r.classId ?? '',
    grade: r.grade,
    ageBand: r.ageBand,
    testId: r.testId,
    version: r.version,
    assignmentId: r.assignmentId,
    takenAt: r.takenAt,
    origin: r.origin,
    raw: { ...r.raw },
    ...(answers ? { answers } : {}),
    ...(r.durationSec !== null ? { durationSec: r.durationSec } : {}),
    scales: r.scales,
    topCodes: r.topCodes,
    testTitle: e.testTitle,
  };
}

/** Sinf rahbari: javoblar, vaqt va xom ballar yo'q; hissiy holat shkalalarida faqat daraja. */
function protectedResult(e: Entry, idx: DevIndex): ProfileResult {
  const { answers: _answers, durationSec: _duration, ...rest } = fullResult(e, undefined);
  void _answers;
  void _duration;
  const test = idx.tests.get(e.result.testId);
  const emotional = new Set(test?.scales.filter((s) => s.domain === 'EMOTIONAL').map((s) => s.key) ?? []);
  return {
    ...rest,
    raw: {},
    scales: e.result.scales.map((s) =>
      emotional.has(s.key) ? { ...s, raw: 0, max: null, z: null, standard: null, percentile: null } : { ...s, raw: 0, max: null },
    ),
  };
}

function careerOf(entries: readonly Entry[], full: boolean): StudentDevProfile['career'] {
  const last = [...entries].reverse().find((e) => e.result.topCodes);
  if (!last?.result.topCodes) return null;
  return { topCodes: last.result.topCodes, raw: full ? { ...last.result.raw } : {}, takenAt: last.result.takenAt };
}

export type ProfileInput = {
  idx: DevIndex;
  roster: Roster;
  student: LiveStudent;
  cls: LiveClass | undefined;
  full: boolean;
  today: IsoDate;
  /** Natija → ochilgan javoblar (faqat psixolog). */
  answers: ReadonlyMap<string, string>;
  context: StudentDevProfile['context'];
};

export function buildProfile(input: ProfileInput): StudentDevProfile {
  const { idx, student, full } = input;
  const entries = idx.byStudent.get(student.id) ?? [];
  const latest = DEV_DOMAINS.map((domain) => {
    const last = [...entries].reverse().find((e) => e.domains[domain]);
    const value = last?.domains[domain];
    return { domain, index: value && (full || domain !== 'EMOTIONAL') ? value.index : null, band: value?.band ?? null, takenAt: last?.result.takenAt ?? null };
  });
  return {
    student: {
      id: student.id,
      name: studentName(student),
      className: input.cls?.name ?? '—',
      grade: input.cls?.grade ?? 0,
      ageBand: ageBandOf(ageOn(student.birthDate, input.today)),
    },
    latest,
    classAverage: classmatesAverage(idx, input.roster, student),
    timeline: timeline(entries, full),
    career: careerOf(entries, full),
    results: [...entries].reverse().map((e) => (full ? fullResult(e, input.answers.get(e.result.id)) : protectedResult(e, idx))),
    context: input.context,
    canSeeRaw: full,
  };
}

/** Sinfning so'nggi baholangan choragi (jonli ro'yxatdagi o'quvchilar bo'yicha). */
export function classTerm(idx: DevIndex, roster: Roster, classId: string, fallback: string): string {
  const ids = new Set(roster.students.filter((s) => s.classId === classId).map((s) => s.id));
  const terms = idx.terms.filter((term) => [...(idx.snapshot.get(term)?.keys() ?? [])].some((id) => ids.has(id)));
  return terms.at(-1) ?? idx.terms.at(-1) ?? fallback;
}

export function buildClassOverview(input: {
  idx: DevIndex;
  roster: Roster;
  cls: LiveClass;
  termKey: string;
  full: boolean;
  flagged: ReadonlySet<string>;
  schoolAverages: ClassDevOverview['schoolAverages'];
}): ClassDevOverview {
  const { idx, cls, termKey, full } = input;
  const snap = idx.snapshot.get(termKey);
  const roster = input.roster.students.filter((s) => !s.archived && s.classId === cls.id).sort((a, b) => studentName(a).localeCompare(studentName(b), 'uz'));
  const rows = roster.map((s) => {
    const st = snap?.get(s.id);
    const domains: ClassDevOverview['rows'][number]['domains'] = {};
    for (const d of DEV_DOMAINS) {
      const v = st?.domains[d];
      if (v) domains[d] = { index: full || d !== 'EMOTIONAL' ? v.index : null, band: v.band };
    }
    return { studentId: s.id, name: studentName(s), assessedAt: st?.lastTakenAt ?? null, domains, attention: input.flagged.has(s.id) };
  });
  const domainAverages = DEV_DOMAINS.map((domain) => {
    const xs = roster.map((s) => snap?.get(s.id)?.domains[domain]?.index).filter((x): x is number => typeof x === 'number');
    return { domain, index: xs.length >= K ? average(xs) : null };
  });
  return {
    classId: cls.id,
    className: cls.name,
    termKey,
    assessed: rows.filter((r) => r.assessedAt).length,
    total: rows.length,
    domainAverages,
    schoolAverages: input.schoolAverages,
    rows,
  };
}
