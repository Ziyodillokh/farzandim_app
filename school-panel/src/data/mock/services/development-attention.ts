import type { AttentionReason, AttentionRow, DevDomain, Student } from '@/data/contracts';
import { CARE_MIN_GROUP as K } from '@/lib/k-anon';
import { buildIndexes, compareClasses, studentName } from '../lookups';
import type { Tables } from '../tables';
import { COGNITIVE, type DevIndex, type DomainMap, type Entry, termEnd } from './development-aggregate';

/**
 * E'tibor ro'yxati (FAQAT psixolog). Qoidalar — skrining signali, tashxis emas:
 * - COG_LOW — oxirgi mantiqiy fikrlash standart bali < 70;
 * - ATT_LOW — oxirgi diqqat yoki xotira standart bali < 70;
 * - EMO_SUPPORT — oxirgi xavotir darajasi "psixolog suhbati tavsiya etiladi";
 * - SELF_LOW — o'ziga ishonch < 70 (persentil ≤ 2);
 * - DECLINE — oxirgi 2 chorak orasida kognitiv kompozit (umumiy sohalar o'rtachasi) ≥ 15 ball pasaygan;
 * - MISSED — sinfdoshlari (≥ K) qatnashgan oxirgi 2 to'lqinni o'tkazib yuborgan.
 */
export const LOW_STANDARD = 70;
export const DECLINE_POINTS = 15;

function latestDomains(entries: readonly Entry[]): DomainMap {
  return entries.reduce<DomainMap>((acc, e) => ({ ...acc, ...e.domains }), {});
}

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

/** Sinf bo'yicha har chorakdagi qatnashchilar soni. */
function classParticipation(idx: DevIndex): Map<string, Map<string, number>> {
  const out = new Map<string, Map<string, number>>();
  for (const [term, students] of idx.snapshot) {
    for (const st of students.values()) {
      const perTerm = out.get(st.classId) ?? new Map<string, number>();
      perTerm.set(term, (perTerm.get(term) ?? 0) + 1);
      out.set(st.classId, perTerm);
    }
  }
  return out;
}

function missed(idx: DevIndex, student: Student, perClass: ReadonlyMap<string, Map<string, number>>): boolean {
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

export function reasonsFor(idx: DevIndex, student: Student, perClass: ReadonlyMap<string, Map<string, number>>): AttentionReason[] {
  const entries = idx.byStudent.get(student.id) ?? [];
  const latest = latestDomains(entries);
  const reasons: AttentionReason[] = [];
  if (below(latest, 'REASONING')) reasons.push('COG_LOW');
  if (below(latest, 'ATTENTION') || below(latest, 'MEMORY')) reasons.push('ATT_LOW');
  if (latest.EMOTIONAL?.band === 'SUPPORT') reasons.push('EMO_SUPPORT');
  if (below(latest, 'SELF_ESTEEM')) reasons.push('SELF_LOW');
  if (declined(idx, student.id, entries)) reasons.push('DECLINE');
  if (missed(idx, student, perClass)) reasons.push('MISSED');
  return reasons;
}

const cache = new WeakMap<Tables, AttentionRow[]>();

/** Barcha faol o'quvchilar bo'yicha (ko'p sababli — tepada, keyin sinf va ism). */
export function computeAttention(t: Tables, idx: DevIndex): AttentionRow[] {
  const hit = cache.get(t);
  if (hit) return hit;
  const lookup = buildIndexes(t);
  const perClass = classParticipation(idx);
  const rows = t.students
    .filter((s) => !s.archived && lookup.classes.has(s.classId))
    .flatMap((s) => {
      const reasons = reasonsFor(idx, s, perClass);
      if (reasons.length === 0) return [];
      const cls = lookup.classes.get(s.classId);
      const last = idx.byStudent.get(s.id)?.at(-1);
      return [{ student: s, cls, row: { studentId: s.id, name: studentName(s), className: cls?.name ?? '—', classId: s.classId, reasons, lastTakenAt: last?.result.takenAt ?? null } }];
    })
    .sort(
      (a, b) =>
        b.row.reasons.length - a.row.reasons.length ||
        (a.cls && b.cls ? compareClasses(a.cls, b.cls) : 0) ||
        a.row.name.localeCompare(b.row.name, 'uz'),
    )
    .map((x) => x.row);
  cache.set(t, rows);
  return rows;
}
