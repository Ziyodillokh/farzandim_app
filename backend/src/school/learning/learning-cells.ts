// Growth Learning maxfiyligi: natija ko'rsatkichlari (topshiriqlar, o'rtacha
// ball, DON) faqat kamida K faol bolasi bor (sinf, hafta) kataklaridan va faqat
// YAKUNLANGAN haftalardan chiqariladi. Har chiqarilgan raqam — butun ochiq,
// endi o'zgarmaydigan kataklar yig'indisi: sinf filtri, umumiy jami, oylik
// hisobot yoki ikki vaqtdagi o'qishni bir-biridan ayirib kichik guruh (yoki
// bitta bola) natijasini tiklab bo'lmaydi. Sinf — urinish paytidagi snapshot
// (`LearningAttempt.schoolClassId`, faqat shu haftada yakunlangan urinishga
// yoziladi): o'quvchini ko'chirish yoki uzish o'tgan kataklarni o'zgartirmaydi.
// Faollar soni — hammasidan.

import { addDays, isoWeekday } from '../../common/time/tashkent';
import { CARE_MIN_GROUP } from '../care/care-suppression';

export const LEARNING_MIN_COHORT = CARE_MIN_GROUP;

export type LearningCell = { classId: string; weekStart: string; active: Set<string>; tasks: number; scoreSum: number; don: number };
export type CellAttempt = { childId: string; schoolClassId: string | null; day: string; correct: number; total: number; donEarned: number };

/** Kataklar yig'indisi. `suppressed` — faol bolalar bor, lekin natijalar yashirilgan. */
export type LearningTotals = {
  activeStudents: number;
  completedTasks: number | null;
  avgScore: number | null;
  donPoints: number | null;
  suppressed: boolean;
};

const percent = (part: number, total: number) => (total > 0 ? Math.round((part / total) * 100) : 0);

export const mondayOf = (day: string) => addDays(day, 1 - isoWeekday(day));
export const cellKey = (classId: string, weekStart: string) => `${classId}|${weekStart}`;

/** Urinishlarni (urinish paytidagi sinf, hafta) kataklariga yig'adi; sinfsiz urinish hisobga olinmaydi. */
export function buildCells(attempts: readonly CellAttempt[]): Map<string, LearningCell> {
  const cells = new Map<string, LearningCell>();
  for (const a of attempts) {
    const classId = a.schoolClassId;
    if (!classId) continue;
    const weekStart = mondayOf(a.day);
    const key = cellKey(classId, weekStart);
    const cell = cells.get(key) ?? { classId, weekStart, active: new Set<string>(), tasks: 0, scoreSum: 0, don: 0 };
    cell.active.add(a.childId);
    cell.tasks += 1;
    cell.scoreSum += percent(a.correct, a.total);
    cell.don += a.donEarned;
    cells.set(key, cell);
  }
  return cells;
}

const isOpen = (cell: LearningCell) => cell.active.size >= LEARNING_MIN_COHORT;

export function totalsOf(cells: ReadonlyArray<LearningCell | undefined>): LearningTotals {
  const present = cells.filter((c): c is LearningCell => Boolean(c));
  const activeStudents = present.reduce((n, c) => n + c.active.size, 0);
  const open = present.filter(isOpen);
  if (open.length === 0) {
    return activeStudents === 0
      ? { activeStudents, completedTasks: 0, avgScore: null, donPoints: 0, suppressed: false }
      : { activeStudents, completedTasks: null, avgScore: null, donPoints: null, suppressed: true };
  }
  const tasks = open.reduce((n, c) => n + c.tasks, 0);
  return {
    activeStudents,
    completedTasks: tasks,
    avgScore: Math.round(open.reduce((n, c) => n + c.scoreSum, 0) / tasks),
    donPoints: open.reduce((n, c) => n + c.don, 0),
    suppressed: false,
  };
}
