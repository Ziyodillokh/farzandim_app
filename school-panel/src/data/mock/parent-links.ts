import type { ParentLinkStatus } from '@/data/contracts';
import { percent } from '@/lib/utils';
import type { Tables } from './tables';

export type LinkShare = { linked: number; total: number; rate: number };

/**
 * Ota-onalar ulanishi — YAGONA hisob (bosh sahifa, /parents, servislar).
 * Ikki xil ulush aniq ajratiladi:
 * - `students` — kamida bitta ota-onasi Parvoz'ga ulangan faol o'quvchilar ulushi;
 * - `guardians` — doiradagi faol o'quvchilarning ota-onalari ichida ulanganlar ulushi.
 */
export type ParentLinkSummary = {
  students: LinkShare;
  guardians: LinkShare & { invited: number };
};

/** `allowed` — ruxsat etilgan sinflar (`null` — butun maktab). */
export function parentLinkSummary(tables: Tables, allowed: readonly string[] | null): ParentLinkSummary {
  const statusOf = new Map<string, ParentLinkStatus>(tables.guardians.map((g) => [g.id, g.linkStatus]));
  const students = tables.students.filter((s) => !s.archived && (!allowed || allowed.includes(s.classId)));
  const linkedStudents = students.filter((s) => s.guardianIds.some((id) => statusOf.get(id) === 'LINKED')).length;
  const guardianIds = new Set(students.flatMap((s) => s.guardianIds).filter((id) => statusOf.has(id)));
  const statuses = [...guardianIds].map((id) => statusOf.get(id));
  const linkedGuardians = statuses.filter((x) => x === 'LINKED').length;
  return {
    students: { linked: linkedStudents, total: students.length, rate: percent(linkedStudents, students.length) },
    guardians: {
      linked: linkedGuardians,
      invited: statuses.filter((x) => x === 'INVITED').length,
      total: guardianIds.size,
      rate: percent(linkedGuardians, guardianIds.size),
    },
  };
}
