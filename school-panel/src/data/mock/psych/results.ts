import type { PsychResult } from '@/data/contracts';
import type { Tables } from '../tables';
import { historyResults } from './history';

/**
 * Saqlangan natijalar (ilova, import, qo'lda) + o'tgan choraklarning hisoblangan tarixi,
 * `takenAt` bo'yicha (eskidan yangiga). Vaqt ikki formatda kelishi mumkin (mahalliy va "…Z"),
 * shuning uchun satr emas, vaqt belgisi solishtiriladi.
 */
type Merged = { history: PsychResult[]; count: number; last: PsychResult | undefined; merged: PsychResult[] };
const cache = new WeakMap<readonly PsychResult[], Merged>();

function sortByTakenAt(items: readonly PsychResult[]): PsychResult[] {
  return items
    .map((r) => ({ r, at: Date.parse(r.takenAt) }))
    .sort((a, b) => a.at - b.at || a.r.id.localeCompare(b.r.id))
    .map((x) => x.r);
}

export function allResults(t: Tables): PsychResult[] {
  const stored = t.psychResults ?? [];
  const history = historyResults(t);
  const hit = cache.get(stored);
  if (hit && hit.history === history && hit.count === stored.length && hit.last === stored.at(-1)) return hit.merged;
  const merged = sortByTakenAt([...stored, ...history]);
  cache.set(stored, { history, count: stored.length, last: stored.at(-1), merged });
  return merged;
}

export function resultsForStudent(t: Tables, studentId: string): PsychResult[] {
  return allResults(t).filter((r) => r.studentId === studentId);
}
