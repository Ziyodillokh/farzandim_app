// Maktab kesimining qurilish bloklari: "katak" = natijalardagi sinf nusxasi +
// daraja nusxasi (jonli `SchoolClass` jadvali EMAS — sinf darajasini tahrirlash
// yoki sinfni o'chirish guruhlarni o'zgartirib, kichik guruhni ochib bera olmaydi).
// K=5 atomlari Bola ovozi bilan bir xil (`care-suppression.ts`).

import { Atom, buildAtoms, CARE_MIN_GROUP, isUnionOfAtoms } from '../care/care-suppression';
import { ageGroupOf } from '../care/care.schemas';
import type { DevDomain } from '../assessments/psych/types';
import { DEV_DOMAINS, meanOf, roundOrNull, StudentTerm } from './development-index';
import { classKeyOf } from './development-release';

export const K = CARE_MIN_GROUP;

type Slot = { indexes: number[]; standards: number[] };
export type Cell = {
  id: string;
  classId: string | null;
  grade: number;
  /** Shu chorakda natijasi bor o'quvchilar. */
  any: number;
  /** Eng so'nggi natija lahzasi (ko'rsatiladigan daraja uchun). */
  lastAt: number;
  byDomain: ReadonlyMap<DevDomain, Slot>;
};
export type Plan = { any: Atom[]; byDomain: ReadonlyMap<DevDomain, Atom[]> };

export function cellsOf(snap: ReadonlyMap<string, StudentTerm> | undefined): Cell[] {
  // Mahalliy yig'uvchilar (kirish o'zgartirilmaydi).
  const acc = new Map<string, { id: string; classId: string | null; grade: number; any: number; lastAt: number; byDomain: Map<DevDomain, Slot> }>();
  for (const st of snap?.values() ?? []) {
    const id = `${classKeyOf(st.classId, st.grade)}#${st.grade}`;
    const cell = acc.get(id) ?? { id, classId: st.classId, grade: st.grade, any: 0, lastAt: 0, byDomain: new Map<DevDomain, Slot>() };
    cell.any += 1;
    cell.lastAt = Math.max(cell.lastAt, st.lastAt);
    for (const d of DEV_DOMAINS) {
      const v = st.domains[d];
      if (!v || v.index === null) continue;
      const slot = cell.byDomain.get(d) ?? { indexes: [], standards: [] };
      cell.byDomain.set(d, { indexes: [...slot.indexes, v.index], standards: v.standard === null ? slot.standards : [...slot.standards, v.standard] });
    }
    acc.set(id, cell);
  }
  return [...acc.values()].sort((a, b) => a.grade - b.grade || a.id.localeCompare(b.id));
}

export const domainN = (c: Cell, d: DevDomain): number => c.byDomain.get(d)?.indexes.length ?? 0;
export const sumOf = <T>(items: readonly T[], f: (x: T) => number): number => items.reduce((s, x) => s + f(x), 0);
export const idsOf = (cells: readonly Cell[]): Set<string> => new Set(cells.map((c) => c.id));

function atomsFor(cells: readonly Cell[], count: (c: Cell) => number): Atom[] {
  return buildAtoms(cells.map((c) => ({ classId: c.id, grade: Math.max(1, c.grade), ageGroup: ageGroupOf(Math.max(1, c.grade)), n: count(c) })));
}

export function plan(cells: readonly Cell[]): Plan {
  return { any: atomsFor(cells, (c) => c.any), byDomain: new Map(DEV_DOMAINS.map((d) => [d, atomsFor(cells, (c) => domainN(c, d))])) };
}

/** Psixolog — to'liq; boshqalar — n ≥ K va atomlarning to'liq birlashmasi. */
export function visible(suppress: boolean, n: number, ids: ReadonlySet<string>, atoms: readonly Atom[]): boolean {
  if (n === 0) return false;
  return !suppress || (n >= K && isUnionOfAtoms(ids, atoms));
}

export function domainMean(cells: readonly Cell[], d: DevDomain, pick: keyof Slot): number | null {
  return roundOrNull(meanOf(cells.flatMap((c) => c.byDomain.get(d)?.[pick] ?? [])));
}

/**
 * Maktab bo'yicha soha o'rtachalari (n ≥ minN). Shu chorakda umuman o'tkazilmagan soha
 * ro'yxatga kirmaydi; `index: null` — faqat yashirilgan (0 < n < minN) soha.
 */
export function schoolDomainValues(cells: readonly Cell[], minN: number = K): Array<{ domain: DevDomain; index: number | null; n: number }> {
  return DEV_DOMAINS.flatMap((d) => {
    const n = sumOf(cells, (c) => domainN(c, d));
    if (n === 0) return [];
    return [n >= minN ? { domain: d, index: domainMean(cells, d, 'indexes'), n } : { domain: d, index: null, n: 0 }];
  });
}
