import { roleHas } from '@/auth/permissions';
import type { ClassActivity, IsoDate, LearningAssignment, LearningMaterial, MaterialKind, Subject } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { assignmentInputSchema, materialFilterSchema, SUBJECTS, type AssignmentInput, type MaterialFilter } from '@/data/schemas/learning';
import { parseOrThrow } from '@/data/schemas/validate';
import { CARE_MIN_GROUP } from '@/lib/k-anon';
import { matchesSearch } from '@/lib/normalize-search';
import { unitHash } from '@/lib/rng';
import { sharePercent } from '@/lib/utils';
import { addDays, weekStart } from '../calendar';
import { clockToday } from '../clock';
import { type Actor, allowedClassIds, assertCan, assertClassInScope, currentActor, inScope, latency, newId, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { buildIndexes, classSizes, compareClasses } from '../lookups';
import type { Tables } from '../tables';

/**
 * Growth Learning (maktab tomoni). Faollik — faqat SINF darajasida (shaxsiy reyting yo'q).
 * Sinf rahbari — faqat o'z sinfi (ko'rish va tayinlash).
 */

/**
 * K=5 kataklar (backend bilan bir xil): natija ko'rsatkichlari (topshiriqlar, o'rtacha ball, DON)
 * faqat kamida shuncha faol o'quvchisi bor (sinf, ISO hafta) kataklardan yig'iladi — kichik
 * guruhda shaxsiy natija oshkor bo'lmasin. Faol o'quvchilar soni hech qachon yashirilmaydi.
 */
export const LEARNING_MIN_COHORT = CARE_MIN_GROUP;

/** 1..4 faol — `suppressed`, natijalar null; 0 faol — 0 / null / 0 (yashirilmagan). */
export type LearningTotals = { activeStudents: number; completedTasks: number | null; avgScore: number | null; donPoints: number | null; suppressed: boolean };
export type ActivityWeek = { weekStart: IsoDate } & LearningTotals;
export type ClassActivityRow = LearningTotals & {
  classId: string;
  className: string;
  grade: number;
  size: number;
  activeRate: number;
  /** Faol o'quvchilar oldingi haftaga nisbatan (+/−). */
  activeDelta: number;
};
/** Joriy (tugallanmagan) hafta — faqat faol bolalar soni, natijalar hech qachon yo'q. */
export type CurrentWeek = { weekStart: IsoDate; activeStudents: number };
/**
 * `latestWeek` — oxirgi YOPIQ hafta dushanbasi; `weeks` — shu bilan tugaydigan 6 yopiq hafta (eskisi
 * birinchi); `classes` — `latestWeek` kataklari; `current` — joriy hafta (faqat faollar soni).
 */
export type LearningActivity = { latestWeek: IsoDate | null; weeks: ActivityWeek[]; classes: ClassActivityRow[]; current: CurrentWeek };
export type InterestRow = { grade: number; shares: Array<{ subject: Subject; percent: number }> };
export type MaterialRow = LearningMaterial & { assignedClasses: number };
export type AssignmentRow = LearningAssignment & {
  materialTitle: string;
  materialKind: MaterialKind | null;
  subject: Subject | null;
  classNames: string[];
  byName: string;
  overdue: boolean;
  canDelete: boolean;
};
export type LearningClassOption = { id: string; name: string; grade: number };

function requireView(): Actor {
  const actor = currentActor();
  assertCan(actor, 'learning.view');
  return actor;
}

function scopedClasses(t: Tables, actor: Actor) {
  const allowed = allowedClassIds(actor);
  return t.classes.filter((c) => !allowed || allowed.includes(c.id)).sort(compareClasses);
}

const sumOf = (rows: readonly ClassActivity[], pick: (r: ClassActivity) => number) => rows.reduce((s, r) => s + pick(r), 0);

/**
 * Kataklar jami (bitta katak ham): faollar — BARCHA kataklardan; natijalar — faqat ochiq
 * (≥ K faol) kataklardan, ball faollar soni bo'yicha tortilgan. Ochiq katak yo'q, lekin
 * faol bor — yashirin (null); umuman faol yo'q — 0 / null / 0.
 */
export function learningTotals(rows: readonly ClassActivity[]): LearningTotals {
  const activeStudents = sumOf(rows, (r) => r.activeStudents);
  const open = rows.filter((r) => r.activeStudents >= LEARNING_MIN_COHORT);
  if (open.length === 0 && activeStudents > 0) return { activeStudents, completedTasks: null, avgScore: null, donPoints: null, suppressed: true };
  const openActive = sumOf(open, (r) => r.activeStudents);
  return {
    activeStudents,
    completedTasks: sumOf(open, (r) => r.completedTasks),
    avgScore: openActive ? Math.round(sumOf(open, (r) => r.avgScore * r.activeStudents) / openActive) : null,
    donPoints: sumOf(open, (r) => r.donPoints),
    suppressed: false,
  };
}

function sumWeek(weekStart: IsoDate, rows: Tables['activity']): ActivityWeek {
  return { weekStart, ...learningTotals(rows) };
}

/** /learning grafigidagi yopiq haftalar soni (backend bilan bir xil). */
export const ACTIVITY_WEEKS = 6;

/**
 * Natijalar faqat YOPIQ haftalardan (backend bilan bir xil): hafta yakshanbasi o'tgach yopiladi.
 * Joriy hafta kataklari har yangi yakunlash bilan o'zgaradi — ikki o'qishni solishtirib bitta
 * bolaning natijasi topilmasin. Oxirgi yopiq hafta — o'tgan haftaning dushanbasi.
 */
export function lastClosedWeek(today: IsoDate): IsoDate {
  return addDays(weekStart(today), -7);
}

/** Foizlarni yaxlitlash (eng katta qoldiq usuli) — jami aniq 100. */
function toPercents(weights: number[]): number[] {
  const total = weights.reduce((a, b) => a + b, 0) || 1;
  const raw = weights.map((w) => (w / total) * 100);
  const floors = raw.map(Math.floor);
  const order = raw.map((v, i) => ({ i, rest: v - Math.floor(v) })).sort((a, b) => b.rest - a.rest);
  const missing = 100 - floors.reduce((a, b) => a + b, 0);
  const bump = new Set(order.slice(0, missing).map((o) => o.i));
  return floors.map((f, i) => (bump.has(i) ? f + 1 : f));
}

function canDeleteAssignment(actor: Actor, assignment: LearningAssignment): boolean {
  const allowed = allowedClassIds(actor);
  return !allowed || assignment.classIds.every((id) => allowed.includes(id));
}

export const learningService = {
  /** Natijalar — faqat yopiq haftalardan (`lastClosedWeek`); joriy haftadan — faqat faollar soni. */
  async activity(filter: { classId?: string } = {}): Promise<LearningActivity> {
    await latency(80, 180);
    const actor = requireView();
    if (filter.classId) assertClassInScope(actor, filter.classId);
    const t = getTables();
    const idx = buildIndexes(t);
    const sizes = classSizes(t);
    const rows = inScope(actor, t.activity).filter((r) => !filter.classId || r.classId === filter.classId);
    const today = clockToday();
    const latestWeek = lastClosedWeek(today);
    const previousWeek = addDays(latestWeek, -7);
    const weekKeys = Array.from({ length: ACTIVITY_WEEKS }, (_, i) => addDays(latestWeek, -7 * (ACTIVITY_WEEKS - 1 - i)));
    const weeks = weekKeys.map((w) => sumWeek(w, rows.filter((r) => r.weekStart === w)));
    const classes = rows
      .filter((r) => r.weekStart === latestWeek)
      .map((r) => {
        const cls = idx.classes.get(r.classId);
        const size = sizes.get(r.classId) ?? 0;
        const prev = rows.find((p) => p.classId === r.classId && p.weekStart === previousWeek);
        return {
          classId: r.classId,
          className: cls?.name ?? '—',
          grade: cls?.grade ?? 0,
          size,
          ...learningTotals([r]),
          activeRate: sharePercent(r.activeStudents, size),
          activeDelta: r.activeStudents - (prev?.activeStudents ?? 0),
        };
      })
      .sort((a, b) => a.grade - b.grade || a.className.localeCompare(b.className));
    const currentWeek = weekStart(today);
    const current = { weekStart: currentWeek, activeStudents: sumOf(rows.filter((r) => r.weekStart === currentWeek), (r) => r.activeStudents) };
    return { latestWeek, weeks, classes, current };
  },

  /**
   * Qiziqishlar taqsimoti (sinf darajasi) — DEMO BAHOSI: deterministik, shaxsiy ma'lumotsiz.
   * Backend 5 nafardan kam bola hissa qo'shgan darajani qaytarmaydi; demo baho bolalar tanloviga
   * asoslanmagani uchun bu yerda barcha darajalar bor (UI bo'sh ro'yxatni ham ko'tara oladi).
   */
  async interests(): Promise<InterestRow[]> {
    await latency(60, 140);
    const actor = requireView();
    const t = getTables();
    const grades = [...new Set(scopedClasses(t, actor).map((c) => c.grade))].sort((a, b) => a - b);
    return grades.map((grade) => {
      const weights = SUBJECTS.map((subject) => {
        const covered = t.materials.some((m) => m.subject === subject && m.grades.includes(grade));
        return 0.35 + unitHash('interest', grade, subject) + (covered ? 0.6 : 0);
      });
      const percents = toPercents(weights);
      return {
        grade,
        shares: SUBJECTS.map((subject, i) => ({ subject, percent: percents[i] ?? 0 })).sort((a, b) => b.percent - a.percent),
      };
    });
  },

  async materials(filter: MaterialFilter = {}): Promise<MaterialRow[]> {
    await latency(60, 140);
    const actor = requireView();
    const f = parseOrThrow(materialFilterSchema, filter);
    const t = getTables();
    const allowed = allowedClassIds(actor);
    const inScopeIds = (ids: string[]) => ids.filter((id) => !allowed || allowed.includes(id));
    return t.materials
      .filter(
        (m) =>
          (!f.kind || m.kind === f.kind) &&
          (!f.subject || m.subject === f.subject) &&
          (!f.grade || m.grades.includes(f.grade)) &&
          (!f.search || matchesSearch(m.title, f.search)),
      )
      .map((m) => ({
        ...m,
        assignedClasses: new Set(t.assignments.filter((a) => a.materialId === m.id).flatMap((a) => inScopeIds(a.classIds))).size,
      }));
  },

  async assignments(): Promise<AssignmentRow[]> {
    await latency(60, 160);
    const actor = requireView();
    const t = getTables();
    const idx = buildIndexes(t);
    const allowed = allowedClassIds(actor);
    const materials = new Map(t.materials.map((m) => [m.id, m]));
    const today = clockToday();
    return t.assignments
      .filter((a) => !allowed || a.classIds.some((id) => allowed.includes(id)))
      .map((a) => {
        const material = materials.get(a.materialId);
        return {
          ...a,
          materialTitle: material?.title ?? '—',
          materialKind: material?.kind ?? null,
          subject: material?.subject ?? null,
          classNames: a.classIds
            .filter((id) => !allowed || allowed.includes(id))
            .map((id) => idx.classes.get(id))
            .filter((c): c is NonNullable<typeof c> => Boolean(c))
            .sort(compareClasses)
            .map((c) => c.name),
          byName: idx.staff.get(a.byStaffId)?.fullName ?? '—',
          overdue: a.dueDate < today,
          canDelete: roleHas(actor.role, 'learning.assign') && canDeleteAssignment(actor, a),
        };
      })
      .sort((a, b) => a.dueDate.localeCompare(b.dueDate));
  },

  /** Topshiriq berish mumkin bo'lgan sinflar (doira bo'yicha). */
  async classOptions(): Promise<LearningClassOption[]> {
    await latency(40, 100);
    const actor = requireView();
    return scopedClasses(getTables(), actor).map((c) => ({ id: c.id, name: c.name, grade: c.grade }));
  },

  async createAssignment(input: AssignmentInput): Promise<LearningAssignment> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'learning.assign');
    const data = parseOrThrow(assignmentInputSchema, input);
    for (const classId of data.classIds) assertClassInScope(actor, classId);
    if (data.dueDate < clockToday()) throw new ServiceError('VALIDATION', 'dueDate: errors.form.invalidDate');
    return transact((t) => {
      const material = t.materials.find((m) => m.id === data.materialId);
      if (!material) throw new ServiceError('VALIDATION', 'materialId: errors.form.required');
      if (data.classIds.some((id) => !t.classes.some((c) => c.id === id))) throw new ServiceError('VALIDATION', 'classIds');
      const assignment: LearningAssignment = {
        id: newId('asg'),
        materialId: data.materialId,
        classIds: [...new Set(data.classIds)],
        dueDate: data.dueDate,
        note: data.note,
        createdAt: new Date().toISOString(),
        byStaffId: actor.staffId,
      };
      t.assignments.push(assignment);
      const names = assignment.classIds.map((id) => t.classes.find((c) => c.id === id)?.name ?? id).join(', ');
      writeAudit(t, actor, 'LEARNING', 'learning.assign', `"${material.title}" tayinlandi: ${names}`, assignment.id, null, assignment, {
        title: material.title,
        classes: names,
      });
      return assignment;
    });
  },

  async deleteAssignment(id: string): Promise<void> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'learning.assign');
    transact((t) => {
      const assignment = t.assignments.find((a) => a.id === id);
      if (!assignment) throw new ServiceError('NOT_FOUND', id);
      if (!canDeleteAssignment(actor, assignment)) throw new ServiceError('FORBIDDEN', id);
      t.assignments = t.assignments.filter((a) => a.id !== id);
      writeAudit(t, actor, 'LEARNING', 'learning.unassign', 'Topshiriq o\'chirildi', id, assignment, null, {});
    });
  },
};
