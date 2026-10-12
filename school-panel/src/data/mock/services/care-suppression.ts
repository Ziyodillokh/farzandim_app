import type { AgeGroup } from '@/data/contracts';
import { AGE_GROUPS } from '@/data/schemas/care';
import { CARE_MIN_GROUP } from '@/lib/k-anon';

/**
 * Bola ovozi — kesimlararo izchil yashirish (hierarchical cell suppression).
 *
 * Ierarxiya: maktab ⊃ yosh guruhi ⊃ parallel ⊃ sinf. Direktor bir so'rovnoma uchun
 * barcha 4 kesimni so'rashi mumkin, shuning uchun yashirish bitta kesim ichida emas,
 * BARCHA kesimlar uchun umumiy "atom"lar asosida qilinadi:
 *
 * 1. Sinflar atomlarga bo'linadi (`buildAtoms`). Bo'sh bo'lmagan har atomda ≥ K
 *    respondent bor. Kichik sinf (0 < n < K) avval o'z paralleli ichida birlashtiriladi;
 *    yetmasa — o'sha parallelning eng kichik qo'shni atomi qo'shiladi; parallel butunlay
 *    kichik bo'lsa — yosh guruhi ichida, u ham kichik bo'lsa — maktab ichida xuddi shunday.
 * 2. Har qanday kesimdagi guruh FAQAT atomlarning to'liq birlashmasi bo'lsa (har atom
 *    guruhga yo butunlay kiradi, yo umuman kirmaydi) va n ≥ K bo'lsa ko'rsatiladi.
 * 3. Isbot: e'lon qilinadigan har qanday qo'shiluvchi statistika (respondentlar soni,
 *    mavzu bo'yicha yig'indi ≈ o'rtacha × son) — atomlar yig'indisi. Demak har qanday
 *    kesimlar va guruhlar orasidagi ayirish/qo'shish ham faqat atomlar yig'indisini beradi;
 *    atomdan kichik to'plamni ajratib bo'lmaydi, atom esa ≥ K kishidan iborat.
 *    Bo'sh atom (n = 0) faqat "javob yo'q" ekanini bildiradi.
 * 4. Mavzu ko'rsatkichlari uchun shu qoida HAR MAVZU bo'yicha alohida qo'llanadi
 *    (n — shu mavzuga kamida bitta javob bergan distinct respondentlar soni).
 */
export type ClassCell = { classId: string; grade: number; ageGroup: AgeGroup; n: number };
export type Atom = { classIds: readonly string[]; n: number };

type Settled = { atoms: Atom[]; carry: Atom | null };

function merge(atoms: readonly Atom[]): Atom {
  return { classIds: atoms.flatMap((a) => a.classIds), n: atoms.reduce((sum, a) => sum + a.n, 0) };
}

function bySize(a: Atom, b: Atom): number {
  return a.n - b.n || (a.classIds[0] ?? '').localeCompare(b.classIds[0] ?? '');
}

/**
 * Bitta ota guruh ichida: kichik bloklar birlashtiriladi; K ga yetmasa eng kichik
 * (bo'sh bo'lmagan) qo'shni atomlar qo'shiladi. Baribir yetmasa — ota guruhning
 * barcha ma'lumoti K dan kam: blok yuqori darajaga `carry` sifatida uzatiladi.
 */
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

/** Sinflarni atomlarga bo'lish: sinf → parallel → yosh guruhi → maktab. */
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

/** Guruh atomlarning to'liq birlashmasimi (har atom guruhga butunlay kiradimi yoki umuman kirmaydimi). */
export function isUnionOfAtoms(classIds: ReadonlySet<string>, atoms: readonly Atom[]): boolean {
  return atoms.every((atom) => {
    const inside = atom.classIds.filter((id) => classIds.has(id)).length;
    return inside === 0 || inside === atom.classIds.length;
  });
}
