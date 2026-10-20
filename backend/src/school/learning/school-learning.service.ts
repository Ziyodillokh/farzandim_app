// Growth Learning — maktab tomoni (panel `learningService`). Faollik faqat
// SINF darajasida (shaxsiy reyting yo'q): ota-ona maktabga bog'lagan
// bolalarning Daily Learning natijalaridan (bog'lash — ota-ona roziligi).
// Sinf rahbari — faqat o'z sinfi (ko'rish va topshiriq berish).

import { Injectable } from '@nestjs/common';
import { LearningSubject } from '@prisma/client';
import { z } from 'zod';
import { PrismaService } from '../../common/database/prisma.service';
import { addDays, isoWeekday, tashkentDay, tashkentDayStart } from '../../common/time/tashkent';
import { actorCan, allowedClassIds, assertCan, assertClassInScope, SchoolActor } from '../auth/school-actor';
import { compareClasses, matchesSearch } from '../common/list-query';
import { SchoolAuditService } from '../common/school-audit.service';
import { forbidden, invalid, notFound } from '../common/school-errors';
import { isoDateSchema, msg, optionalText, parseOrThrow } from '../common/school-zod';
import { loadCatalog, PANEL_SUBJECT } from './school-learning-catalog';

/** Faollik grafigi — oxirgi shuncha hafta. */
const ACTIVITY_WEEKS = 8;
const percent = (part: number, total: number) => (total > 0 ? Math.round((part / total) * 100) : 0);
const mondayOf = (day: string) => addDays(day, 1 - isoWeekday(day));

const materialFilterSchema = z.object({
  kind: z.enum(['AUDIOBOOK', 'VIDEO', 'TEST']).optional(),
  subject: z.string().max(20).optional(),
  grade: z.coerce.number().int().min(1).max(11).optional(),
  search: z.string().trim().max(80).optional(),
});

const assignmentInputSchema = z.object({
  materialId: z.string({ error: msg.required }).min(1, msg.required).max(80),
  classIds: z.array(z.string().min(1)).min(1, msg.atLeastOne).max(60),
  dueDate: isoDateSchema,
  note: optionalText(300),
});

/** Foizlarni yaxlitlash (eng katta qoldiq usuli) — jami aniq 100. */
function toPercents(weights: number[]): number[] {
  const total = weights.reduce((a, b) => a + b, 0);
  if (total === 0) return weights.map(() => 0);
  const raw = weights.map((w) => (w / total) * 100);
  const floors = raw.map(Math.floor);
  const order = raw.map((v, i) => ({ i, rest: v - Math.floor(v) })).sort((a, b) => b.rest - a.rest);
  const bump = new Set(order.slice(0, 100 - floors.reduce((a, b) => a + b, 0)).map((o) => o.i));
  return floors.map((f, i) => (bump.has(i) ? f + 1 : f));
}

@Injectable()
export class SchoolLearningService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  /** Sinflar bo'yicha haftalik faollik (oxirgi 8 hafta) va oxirgi hafta jadvali. */
  async activity(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'learning.view');
    const { classId } = parseOrThrow(z.object({ classId: z.string().min(1).optional() }), query ?? {});
    if (classId) assertClassInScope(actor, classId);
    const classes = (await this.scopedClasses(actor)).filter((c) => !classId || c.id === classId);
    const ids = classes.map((c) => c.id);
    const students = await this.prisma.schoolStudent.findMany({
      where: { schoolId: actor.schoolId, archived: false, classId: { in: ids } },
      select: { id: true, classId: true, childId: true },
    });
    const thisWeek = mondayOf(tashkentDay());
    const from = addDays(thisWeek, -7 * (ACTIVITY_WEEKS - 1));
    const childClass = new Map(students.flatMap((s) => (s.childId && s.classId ? [[s.childId, s.classId] as const] : [])));
    const attempts = childClass.size
      ? await this.prisma.learningAttempt.findMany({
          where: { childId: { in: [...childClass.keys()] }, status: 'COMPLETED', day: { gte: from } },
          select: { childId: true, day: true, correct: true, total: true, donEarned: true },
        })
      : [];
    type Cell = { active: Set<string>; tasks: number; scoreSum: number; don: number };
    const cells = new Map<string, Cell>();
    for (const a of attempts) {
      const cls = childClass.get(a.childId);
      if (!cls) continue;
      const key = `${cls}|${mondayOf(a.day)}`;
      const cell = cells.get(key) ?? { active: new Set<string>(), tasks: 0, scoreSum: 0, don: 0 };
      cell.active.add(a.childId);
      cell.tasks += 1;
      cell.scoreSum += percent(a.correct, a.total);
      cell.don += a.donEarned;
      cells.set(key, cell);
    }
    const weekKeys = Array.from({ length: ACTIVITY_WEEKS }, (_, i) => addDays(from, 7 * i));
    const cellOf = (cls: string, week: string) => cells.get(`${cls}|${week}`);
    const weeks = weekKeys.map((week) => {
      const own = ids.map((id) => cellOf(id, week)).filter((c): c is Cell => Boolean(c));
      const tasks = own.reduce((n, c) => n + c.tasks, 0);
      return {
        weekStart: week,
        activeStudents: own.reduce((n, c) => n + c.active.size, 0),
        completedTasks: tasks,
        avgScore: tasks ? Math.round(own.reduce((n, c) => n + c.scoreSum, 0) / tasks) : 0,
        donPoints: own.reduce((n, c) => n + c.don, 0),
      };
    });
    const sizes = new Map<string, number>();
    for (const s of students) if (s.classId) sizes.set(s.classId, (sizes.get(s.classId) ?? 0) + 1);
    const prevWeek = addDays(thisWeek, -7);
    return {
      latestWeek: thisWeek,
      weeks,
      classes: classes.map((c) => {
        const cell = cellOf(c.id, thisWeek);
        const size = sizes.get(c.id) ?? 0;
        const active = cell?.active.size ?? 0;
        return {
          classId: c.id,
          className: c.name,
          grade: c.grade,
          size,
          activeStudents: active,
          activeRate: percent(active, size),
          completedTasks: cell?.tasks ?? 0,
          avgScore: cell?.tasks ? Math.round(cell.scoreSum / cell.tasks) : 0,
          donPoints: cell?.don ?? 0,
          activeDelta: active - (cellOf(c.id, prevWeek)?.active.size ?? 0),
        };
      }),
    };
  }

  /** Qiziqishlar: bolalar Daily Learning profilida tanlagan fanlar ulushi (sinf darajasi bo'yicha). */
  async interests(actor: SchoolActor) {
    assertCan(actor, 'learning.view');
    const classes = await this.scopedClasses(actor);
    const students = await this.prisma.schoolStudent.findMany({
      where: { schoolId: actor.schoolId, archived: false, classId: { in: classes.map((c) => c.id) }, childId: { not: null } },
      select: { classId: true, child: { select: { learningProfile: { select: { subjects: true } } } } },
    });
    const gradeOf = new Map(classes.map((c) => [c.id, c.grade]));
    const counts = new Map<number, Map<string, number>>();
    for (const s of students) {
      const grade = s.classId ? gradeOf.get(s.classId) : undefined;
      const subjects = s.child?.learningProfile?.subjects ?? [];
      if (grade === undefined || subjects.length === 0) continue;
      const byGrade = counts.get(grade) ?? new Map<string, number>();
      for (const subject of subjects) {
        const key = PANEL_SUBJECT[subject as LearningSubject];
        byGrade.set(key, (byGrade.get(key) ?? 0) + 1);
      }
      counts.set(grade, byGrade);
    }
    return [...counts.keys()].sort((a, b) => a - b).map((grade) => {
      const entries = [...(counts.get(grade) ?? new Map<string, number>()).entries()];
      const shares = toPercents(entries.map(([, n]) => n));
      return {
        grade,
        shares: entries.map(([subject], i) => ({ subject, percent: shares[i] ?? 0 })).sort((a, b) => b.percent - a.percent),
      };
    });
  }

  async materials(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'learning.view');
    const f = parseOrThrow(materialFilterSchema, query ?? {});
    const [catalog, assignments] = await Promise.all([
      loadCatalog(this.prisma),
      this.prisma.schoolLearningAssignment.findMany({ where: { schoolId: actor.schoolId }, select: { materialId: true, classIds: true } }),
    ]);
    const allowed = allowedClassIds(actor);
    return catalog
      .filter(
        (m) =>
          (!f.kind || m.kind === f.kind) &&
          (!f.subject || m.subject === f.subject) &&
          (!f.grade || m.grades.includes(f.grade)) &&
          (!f.search || matchesSearch(m.title, f.search)),
      )
      .map((m) => ({
        ...m,
        assignedClasses: new Set(
          assignments.filter((a) => a.materialId === m.id).flatMap((a) => a.classIds.filter((id) => !allowed || allowed.includes(id))),
        ).size,
      }));
  }

  async assignments(actor: SchoolActor) {
    assertCan(actor, 'learning.view');
    const allowed = allowedClassIds(actor);
    const [rows, catalog, classes, staff] = await Promise.all([
      this.prisma.schoolLearningAssignment.findMany({
        where: { schoolId: actor.schoolId, ...(allowed && { classIds: { hasSome: allowed } }) },
        orderBy: { dueDate: 'asc' },
      }),
      loadCatalog(this.prisma),
      this.prisma.schoolClass.findMany({ where: { schoolId: actor.schoolId }, select: { id: true, name: true, grade: true, letter: true } }),
      this.prisma.schoolStaff.findMany({ where: { schoolId: actor.schoolId }, select: { id: true, fullName: true } }),
    ]);
    const material = new Map(catalog.map((m) => [m.id, m]));
    const classById = new Map(classes.map((c) => [c.id, c]));
    const staffName = new Map(staff.map((s) => [s.id, s.fullName]));
    const today = tashkentDay();
    return rows.map((a) => {
      const m = material.get(a.materialId);
      return {
        id: a.id,
        materialId: a.materialId,
        classIds: a.classIds,
        dueDate: a.dueDate,
        note: a.note,
        createdAt: a.createdAt.toISOString(),
        byStaffId: a.byStaffId,
        materialTitle: m?.title ?? '—',
        materialKind: m?.kind ?? null,
        subject: m?.subject ?? null,
        classNames: a.classIds
          .filter((id) => !allowed || allowed.includes(id))
          .flatMap((id) => (classById.get(id) ? [classById.get(id)!] : []))
          .sort(compareClasses)
          .map((c) => c.name),
        byName: staffName.get(a.byStaffId) ?? '—',
        overdue: a.dueDate < today,
        canDelete: actorCan(actor, 'learning.assign') && (!allowed || a.classIds.every((id) => allowed.includes(id))),
      };
    });
  }

  /** Bosh sahifa: joriy hafta faolligi va 7 kun ichidagi topshiriqlar. */
  async summary(actor: SchoolActor) {
    const act = await this.activity(actor, {});
    const latest = act.weeks.at(-1);
    const allowed = allowedClassIds(actor);
    const today = tashkentDay();
    const dueThisWeek = await this.prisma.schoolLearningAssignment.count({
      where: { schoolId: actor.schoolId, dueDate: { gte: today, lte: addDays(today, 7) }, ...(allowed && { classIds: { hasSome: allowed } }) },
    });
    return {
      activeStudents: latest?.activeStudents ?? 0,
      totalStudents: act.classes.reduce((n, c) => n + c.size, 0),
      completedTasks: latest?.completedTasks ?? 0,
      avgScore: latest?.avgScore ?? 0,
      dueThisWeek,
    };
  }

  /** Oylik hisobot: haftalik o'rtacha faollar, yakunlangan testlar, o'rtacha natija, topshiriqlar. */
  async monthSummary(actor: SchoolActor, first: string, last: string) {
    const students = await this.prisma.schoolStudent.findMany({
      where: { schoolId: actor.schoolId, archived: false, childId: { not: null } },
      select: { childId: true },
    });
    const childIds = students.flatMap((s) => (s.childId ? [s.childId] : []));
    const [attempts, assignments] = await Promise.all([
      childIds.length
        ? this.prisma.learningAttempt.findMany({
            where: { childId: { in: childIds }, status: 'COMPLETED', day: { gte: first, lte: last } },
            select: { childId: true, day: true, correct: true, total: true },
          })
        : [],
      this.prisma.schoolLearningAssignment.count({
        where: { schoolId: actor.schoolId, createdAt: { gte: tashkentDayStart(first), lt: tashkentDayStart(addDays(last, 1)) } },
      }),
    ]);
    const weekly = new Map<string, Set<string>>();
    for (const a of attempts) {
      const week = mondayOf(a.day);
      weekly.set(week, (weekly.get(week) ?? new Set<string>()).add(a.childId));
    }
    const weeks = [...weekly.values()];
    return {
      avgActiveStudents: weeks.length ? Math.round(weeks.reduce((n, w) => n + w.size, 0) / weeks.length) : 0,
      completedTasks: attempts.length,
      avgScore: attempts.length ? Math.round(attempts.reduce((n, a) => n + percent(a.correct, a.total), 0) / attempts.length) : 0,
      assignments,
    };
  }

  async classOptions(actor: SchoolActor) {
    assertCan(actor, 'learning.view');
    return (await this.scopedClasses(actor)).map((c) => ({ id: c.id, name: c.name, grade: c.grade }));
  }

  async createAssignment(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'learning.assign');
    const data = parseOrThrow(assignmentInputSchema, input);
    for (const classId of data.classIds) assertClassInScope(actor, classId);
    if (data.dueDate < tashkentDay()) throw invalid('dueDate: errors.form.invalidDate');
    const material = (await loadCatalog(this.prisma)).find((m) => m.id === data.materialId);
    if (!material) throw invalid('materialId: errors.form.required');
    const classIds = [...new Set(data.classIds)];
    const classes = await this.prisma.schoolClass.findMany({ where: { schoolId: actor.schoolId, id: { in: classIds } }, select: { id: true, name: true, grade: true, letter: true } });
    if (classes.length !== classIds.length) throw invalid('classIds: errors.form.required');
    return this.prisma.$transaction(async (tx) => {
      const created = await tx.schoolLearningAssignment.create({
        data: { schoolId: actor.schoolId, materialKind: material.kind, materialId: material.id, classIds, dueDate: data.dueDate, note: data.note, byStaffId: actor.staffId },
      });
      const names = [...classes].sort(compareClasses).map((c) => c.name).join(', ');
      await this.audit.write(
        actor,
        {
          module: 'LEARNING',
          action: 'learning.assign',
          summary: `"${material.title}" tayinlandi: ${names}`,
          entityId: created.id,
          after: { materialId: material.id, classIds, dueDate: data.dueDate },
          params: { title: material.title, classes: names },
        },
        tx,
      );
      return { id: created.id, materialId: created.materialId, classIds, dueDate: created.dueDate, note: created.note, createdAt: created.createdAt.toISOString(), byStaffId: actor.staffId };
    });
  }

  async deleteAssignment(actor: SchoolActor, id: string): Promise<void> {
    assertCan(actor, 'learning.assign');
    const assignment = await this.prisma.schoolLearningAssignment.findFirst({ where: { id, schoolId: actor.schoolId } });
    if (!assignment) throw notFound(id);
    const allowed = allowedClassIds(actor);
    if (allowed && !assignment.classIds.every((c) => allowed.includes(c))) throw forbidden(id);
    await this.prisma.$transaction(async (tx) => {
      await tx.schoolLearningAssignment.delete({ where: { id } });
      await this.audit.write(actor, { module: 'LEARNING', action: 'learning.unassign', summary: 'Topshiriq o\'chirildi', entityId: id, before: assignment, params: {} }, tx);
    });
  }

  private scopedClasses(actor: SchoolActor) {
    const allowed = allowedClassIds(actor);
    return this.prisma.schoolClass
      .findMany({ where: { schoolId: actor.schoolId, ...(allowed && { id: { in: allowed } }) }, select: { id: true, name: true, grade: true, letter: true } })
      .then((rows) => rows.sort(compareClasses));
  }
}
