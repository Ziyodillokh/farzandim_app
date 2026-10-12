import type { PsychResult } from '@/data/contracts';
import type { Tables } from '../tables';

/** Saqlangan natijalar + o'tgan choraklarning hisoblangan tarixi (agent B to'ldiradi). */
export function allResults(t: Tables): PsychResult[] {
  return t.psychResults ?? [];
}

export function resultsForStudent(t: Tables, studentId: string): PsychResult[] {
  return allResults(t).filter((r) => r.studentId === studentId);
}
