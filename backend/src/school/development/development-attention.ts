// E'tibor ro'yxati (FAQAT psixolog; panel `development-attention.ts` bilan bir xil
// qoidalar). Skrining signali, tashxis emas:
// - COG_LOW — oxirgi mantiqiy fikrlash standart bali < 70;
// - ATT_LOW — oxirgi diqqat yoki xotira standart bali < 70;
// - EMO_SUPPORT — oxirgi xavotir darajasi "psixolog suhbati tavsiya etiladi";
// - SELF_LOW — o'ziga ishonch < 70;
// - DECLINE — oxirgi 2 chorak orasida kognitiv kompozit ≥ 15 ball pasaygan;
// - MISSED — sinfdoshlari (≥ K) qatnashgan oxirgi 2 to'lqinni o'tkazib yuborgan.

import { compareClasses } from '../common/list-query';
import type { DevDomain } from '../assessments/psych/types';
import { K } from './development-cells';
import { COGNITIVE, DevIndex, DomainMap, Entry, latestDomains, termEnd } from './development-index';
import type { AttentionReason, AttentionRow, LiveStudent, Roster } from './development.types';

export const LOW_STANDARD = 70;
export const DECLINE_POINTS = 15;

const below = (map: DomainMap, d: DevDomain) => {
  const ss = map[d]?.standard;
  return ss !== null && ss !== undefined && ss < LOW_STANDARD;
};

function composite(map: DomainMap | undefined, domains: readonly DevDomain[]): number | null {
  const xs = domains.map((d) => map?.[d]?.standard).filter((x): x is number => typeof x === 'number');
  return xs.length === domains.length && xs.length > 0 ? xs.reduce((a, b) => a + b, 0) / xs.length : null;
}

function declined(idx: DevIndex, studentId: string, entries: readonly Entry[]): boolean {
  const terms = [...new Set(entries.map((e) => e.termKey))].sort().slice(-2);
  if (terms.length < 2) return false;
  const [prev, last] = terms.map((term) => idx.snapshot.get(term)?.get(studentId)?.domains);
  const common = COGNITIVE.filter((d) => prev?.[d]?.standard != null && last?.[d]?.standard != null);
  const a = composite(prev, common);
  const b = composite(last, common);
  return a !== null && b !== null && a - b >= DECLINE_POINTS;
}

/** Sinf (natijadagi nusxa) bo'yicha har chorakdagi qatnashchilar soni. */
export function classParticipation(idx: DevIndex): Map<string, Map<string, number>> {
  const out = new Map<string, Map<string, number>>();
  for (const [term, students] of idx.snapshot) {
    for (const st of students.values()) {
      if (!st.classId) continue;
      const perTerm = out.get(st.classId) ?? new Map<string, number>();
      perTerm.set(term, (perTerm.get(term) ?? 0) + 1);
      out.set(st.classId, perTerm);
    }
  }
  return out;
}

function missed(idx: DevIndex, student: LiveStudent, perClass: ReadonlyMap<string, Map<string, number>>): boolean {
  if (!student.classId) return false;
  const classTerms = [...(perClass.get(student.classId) ?? new Map<string, number>())]
    .filter(([, n]) => n >= K)
    .map(([term]) => term)
    .sort()
    .slice(-2);
  if (classTerms.length < 2) return false;
  const [first] = classTerms;
  if (!first || student.enrolledAt > termEnd(first)) return false;
  return classTerms.every((term) => !idx.snapshot.get(term)?.has(student.id));
}

export function reasonsFor(idx: DevIndex, student: LiveStudent, perClass: ReadonlyMap<string, Map<string, number>>): AttentionReason[] {
  const entries = idx.byStudent.get(student.id) ?? [];
  const latest = latestDomains(entries);
  const checks: Array<[AttentionReason, boolean]> = [
    ['COG_LOW', below(latest, 'REASONING')],
    ['ATT_LOW', below(latest, 'ATTENTION') || below(latest, 'MEMORY')],
    ['EMO_SUPPORT', latest.EMOTIONAL?.band === 'SUPPORT'],
    ['SELF_LOW', below(latest, 'SELF_ESTEEM')],
    ['DECLINE', declined(idx, student.id, entries)],
    ['MISSED', missed(idx, student, perClass)],
  ];
  return checks.flatMap(([reason, hit]) => (hit ? [reason] : []));
}

export const studentName = (s: Pick<LiveStudent, 'lastName' | 'firstName'>) => `${s.lastName} ${s.firstName}`;

/** Barcha faol o'quvchilar bo'yicha (ko'p sababli — tepada, keyin sinf va ism). */
export function computeAttention(idx: DevIndex, roster: Roster): AttentionRow[] {
  const classes = new Map(roster.classes.map((c) => [c.id, c]));
  const perClass = classParticipation(idx);
  return roster.students
    .filter((s) => !s.archived && s.classId && classes.has(s.classId))
    .flatMap((s) => {
      const reasons = reasonsFor(idx, s, perClass);
      if (reasons.length === 0) return [];
      const cls = classes.get(s.classId ?? '');
      const last = idx.byStudent.get(s.id)?.at(-1);
      return [{ cls, row: { studentId: s.id, name: studentName(s), className: cls?.name ?? '—', classId: s.classId ?? '', reasons, lastTakenAt: last?.result.takenAt ?? null } }];
    })
    .sort(
      (a, b) =>
        b.row.reasons.length - a.row.reasons.length ||
        (a.cls && b.cls ? compareClasses(a.cls, b.cls) : 0) ||
        a.row.name.localeCompare(b.row.name, 'uz'),
    )
    .map((x) => x.row);
}
