// Direktor / admin (va psixolog bo'lmagan barcha maktab kesimlari) uchun
// "e'lon qilingan" natijalar — jonli ayirish hujumidan himoya (xavfsizlik ko'rigi):
//
// 1. Faqat YAKUNIY partiyalar: tayinlash yopilgan yoki muddati (topshirish uchun
//    qo'shimcha vaqt bilan) o'tgan; CSV import — bitta import + bitta test = partiya.
//    Ochiq tayinlashda bolalar birma-bir topshirgani sari ko'rsatkich o'zgarsa, ikki
//    so'rov orasidagi farq oxirgi bolaning natijasini ochib qo'yardi.
// 2. Har partiya har (chorak, sinf nusxasi) katagiga 0 yoki ≥ K bola qo'shadi: undan
//    kam bo'lsa — o'sha bo'lak yashiriladi. Shunda har qanday e'lon qilingan guruh
//    (sinflar birlashmasi) bir partiyadan keyin 0 yoki ≥ K bolaga o'zgaradi.

import { CARE_MIN_GROUP } from '../care/care-suppression';
import type { ScoredResult } from '../assessments/results-view';

export type FinalAssignments = ReadonlySet<string>;

/** Natija partiyasi: tayinlash yoki (CSV import lahzasi + test). */
export function batchOf(r: Pick<ScoredResult, 'assignmentId' | 'createdAt' | 'testId'>): string {
  return r.assignmentId ? `a:${r.assignmentId}` : `import:${r.createdAt}:${r.testId}`;
}

/** Sinf nusxasi kaliti (sinfsiz natija — daraja bo'yicha alohida "katak"). */
export const classKeyOf = (classId: string | null, grade: number): string => classId ?? `none:${grade}`;

export function releasedResults<T extends ScoredResult>(
  results: readonly T[],
  finalAssignments: FinalAssignments,
  termOfResult: (r: T) => string,
  k: number = CARE_MIN_GROUP,
): T[] {
  const final = results.filter((r) => !r.assignmentId || finalAssignments.has(r.assignmentId));
  const keyOf = (r: T) => `${batchOf(r)}|${termOfResult(r)}|${classKeyOf(r.classId, r.grade)}`;
  // Mahalliy hisoblagich (kirish ma'lumoti o'zgartirilmaydi).
  const students = new Map<string, Set<string>>();
  for (const r of final) {
    const key = keyOf(r);
    const set = students.get(key) ?? new Set<string>();
    set.add(r.studentId);
    students.set(key, set);
  }
  return final.filter((r) => (students.get(keyOf(r))?.size ?? 0) >= k);
}
