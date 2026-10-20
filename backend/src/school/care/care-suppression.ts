// Bola ovozi — kesimlararo izchil yashirish (panel `care-suppression.ts` bilan
// bir xil algoritm). Ierarxiya: maktab ⊃ yosh guruhi ⊃ parallel ⊃ sinf.
//
// 1. Sinflar atomlarga bo'linadi: bo'sh bo'lmagan har atomda ≥ K respondent.
//    Kichik sinf avval o'z paralleli ichida birlashtiriladi; yetmasa — parallelning
//    eng kichik qo'shni atomi qo'shiladi; parallel butunlay kichik bo'lsa — yosh
//    guruhi, u ham kichik bo'lsa — maktab ichida xuddi shunday.
// 2. Har qanday kesimdagi guruh FAQAT atomlarning to'liq birlashmasi va n ≥ K
//    bo'lsa ko'rsatiladi — ayirish / qo'shish faqat atomlar yig'indisini beradi,
//    atom esa ≥ K kishidan iborat (ayirish hujumidan himoya).
// 3. Mavzu ko'rsatkichlari uchun qoida har mavzu bo'yicha alohida qo'llanadi.

import { AGE_GROUPS, AgeGroup } from './care.schemas';

/** K-anonimlik chegarasi: kam respondentli guruh yashiriladi. */
export const CARE_MIN_GROUP = 5;

export type ClassCell = { classId: string; grade: number; ageGroup: AgeGroup; n: number };
export type Atom = { classIds: readonly string[]; n: number };
type Settled = { atoms: Atom[]; carry: Atom | null };

const merge = (atoms: readonly Atom[]): Atom => ({
  classIds: atoms.flatMap((a) => a.classIds),
  n: atoms.reduce((sum, a) => sum + a.n, 0),
});

const bySize = (a: Atom, b: Atom) => a.n - b.n || (a.classIds[0] ?? '').localeCompare(b.classIds[0] ?? '');

/** Bitta ota guruh ichida kichik bloklarni birlashtirish; yetmasa — yuqoriga `carry`. */
function settle(small: readonly Atom[], others: readonly Atom[], k: number): Settled {
  if (small.length === 0) return { atoms: [...others], carry: null };
  const zeros = others.filter((a) => a.n === 0);
  const pool = others.filter((a) => a.n > 0).sort(bySize);
  let block = merge(small);
  let used = 0;
  while (block.n < k && used < pool.length) {
    block = merge([block, pool[used] as Atom]);
    used += 1;
  }
  if (block.n >= k) return { atoms: [...zeros, ...pool.slice(used), block], carry: null };
  return { atoms: zeros, carry: block };
}

const carries = (results: readonly Settled[]): Atom[] => results.flatMap((r) => (r.carry ? [r.carry] : []));
const atomsOf = (results: readonly Settled[]): Atom[] => results.flatMap((r) => r.atoms);

export function buildAtoms(cells: readonly ClassCell[], k: number = CARE_MIN_GROUP): Atom[] {
  const ageResults = AGE_GROUPS.map((age) => {
    const inAge = cells.filter((c) => c.ageGroup === age);
    const grades = [...new Set(inAge.map((c) => c.grade))].sort((a, b) => a - b);
    const gradeResults = grades.map((grade) => {
      const singles = inAge.filter((c) => c.grade === grade).map((c) => ({ classIds: [c.classId], n: c.n }));
      return settle(
        singles.filter((a) => a.n > 0 && a.n < k),
        singles.filter((a) => a.n === 0 || a.n >= k),
        k,
      );
    });
    return settle(carries(gradeResults), atomsOf(gradeResults), k);
  });
  const school = settle(carries(ageResults), atomsOf(ageResults), k);
  return school.carry ? [...school.atoms, school.carry] : school.atoms;
}

/** Guruh atomlarning to'liq birlashmasimi (har atom yo butunlay kiradi, yo umuman kirmaydi). */
export function isUnionOfAtoms(classIds: ReadonlySet<string>, atoms: readonly Atom[]): boolean {
  return atoms.every((atom) => {
    const inside = atom.classIds.filter((id) => classIds.has(id)).length;
    return inside === 0 || inside === atom.classIds.length;
  });
}

/** Kichik sonlar "<5" ko'rinishida (murojaatlar soni direktor uchun). */
export function maskSmallCount(count: number, k: number = CARE_MIN_GROUP): string {
  return count > 0 && count < k ? `<${k}` : String(count);
}
