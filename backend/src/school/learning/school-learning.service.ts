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
import { buildCells, cellKey, LEARNING_MIN_COHORT, LearningCell, mondayOf, totalsOf } from './learning-cells';
import { loadCatalog, PANEL_SUBJECT } from './school-learning-catalog';

/** Faollik grafigi — oxirgi shuncha hafta (panel: "oxirgi 6 hafta"). */
const ACTIVITY_WEEKS = 6;
const percent = (part: number, total: number) => (total > 0 ? Math.round((part / total) * 100) : 0);
/** Kunga teng yoki undan keyingi birinchi dushanba. */
const mondayOnOrAfter = (day: string) => (isoWeekday(day) === 1 ? day : addDays(mondayOf(day), 7));


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

  /**
   * Sinflar bo'yicha haftalik faollik: oxirgi 6 YAKUNLANGAN hafta va oxirgisining
   * sinflar jadvali. Natijalar (topshiriq, ball, DON) — faqat ≥5 faol bolali
   * kataklardan (learning-cells). Davom etayotgan hafta — faqat faollar soni:
   * jonli katak har yangi urinishda o'zgarib, ikki o'qish farqi bolaning natijasini ochardi.
   */
  async activity(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'learning.view');
    const { classId } = parseOrThrow(z.object({ classId: z.string().min(1).optional() }), query ?? {});
    if (classId) assertClassInScope(actor, classId);
    const classes = (await this.scopedClasses(actor)).filter((c) => !classId || c.id === classId);
    const ids = classes.map((c) => c.id);
    const students = await this.prisma.schoolStudent.findMany({
      where: { schoolId: actor.schoolId, archived: false, classId: { in: ids } },
      select: { classId: true },
    });
    const currentWeek = mondayOf(tashkentDay());
    const latestWeek = addDays(currentWeek, -7);
    const from = addDays(latestWeek, -7 * (ACTIVITY_WEEKS - 1));
    const cells = await this.loadCells(ids, from);
    const cellOf = (cls: string, week: string) => cells.get(cellKey(cls, week));
    const sizes = new Map<string, number>();
    for (const s of students) if (s.classId) sizes.set(s.classId, (sizes.get(s.classId) ?? 0) + 1);
    const prevWeek = addDays(latestWeek, -7);
    return {
      latestWeek,
      weeks: Array.from({ length: ACTIVITY_WEEKS }, (_, i) => addDays(from, 7 * i)).map((week) => ({
        weekStart: week,
        ...totalsOf(ids.map((id) => cellOf(id, week))),
      })),
      classes: classes.map((c) => {
        const totals = totalsOf([cellOf(c.id, latestWeek)]);
        const size = sizes.get(c.id) ?? 0;
        return {
          classId: c.id,
          className: c.name,
          grade: c.grade,
          size,
          ...totals,
          // Snapshot faollar (o'sha haftada boshqa sinfdan kelgan ham) — 100% dan oshmaydi.
          activeRate: Math.min(100, percent(totals.activeStudents, size)),
          activeDelta: totals.activeStudents - (cellOf(c.id, prevWeek)?.active.size ?? 0),
        };
      }),
      current: { weekStart: currentWeek, activeStudents: ids.reduce((n, id) => n + (cellOf(id, currentWeek)?.active.size ?? 0), 0) },
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
    const byGrade = new Map<number, { children: number; subjects: Map<string, number> }>();
    for (const s of students) {
      const grade = s.classId ? gradeOf.get(s.classId) : undefined;
      const subjects = s.child?.learningProfile?.subjects ?? [];
      if (grade === undefined || subjects.length === 0) continue;
      const entry = byGrade.get(grade) ?? { children: 0, subjects: new Map<string, number>() };
      entry.children += 1;
      for (const subject of subjects) {
        const key = PANEL_SUBJECT[subject as LearningSubject];
        entry.subjects.set(key, (entry.subjects.get(key) ?? 0) + 1);
      }
      byGrade.set(grade, entry);
    }
    // 5 nafardan kam bolali daraja ko'rsatilmaydi — ulushlardan bolaning tanlovi tiklanmasin.
    return [...byGrade.entries()]
      .filter(([, e]) => e.children >= LEARNING_MIN_COHORT)
      .sort(([a], [b]) => a - b)
      .map(([grade, e]) => {
        const entries = [...e.subjects.entries()];
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

  /** Bosh sahifa: oxirgi yakunlangan hafta faolligi va 7 kun ichidagi topshiriqlar. */
  async summary(actor: SchoolActor) {
    const act = await this.activity(actor, {});
    const latest = act.weeks.at(-1) ?? totalsOf([]);
    const allowed = allowedClassIds(actor);
    const today = tashkentDay();
    const dueThisWeek = await this.prisma.schoolLearningAssignment.count({
      where: { schoolId: actor.schoolId, dueDate: { gte: today, lte: addDays(today, 7) }, ...(allowed && { classIds: { hasSome: allowed } }) },
    });
    return {
      weekStart: act.latestWeek,
      activeStudents: latest.activeStudents,
      totalStudents: act.classes.reduce((n, c) => n + c.size, 0),
      completedTasks: latest.completedTasks,
      avgScore: latest.avgScore,
      suppressed: latest.suppressed,
      dueThisWeek,
    };
  }

  /**
   * Oylik hisobot: haftalik o'rtacha faollar, yakunlangan testlar, o'rtacha natija, topshiriqlar.
   * Hafta — dushanbasi shu oyga tushgan, YAKUNLANGAN butun hafta: natijalar faollik
   * grafigidagi kataklar bilan bir xil bo'linishda (ayirib kichik guruh tiklanmaydi).
   */
  async monthSummary(actor: SchoolActor, first: string, last: string) {
    const currentWeek = mondayOf(tashkentDay());
    const weeks: string[] = [];
    for (let week = mondayOnOrAfter(first); week <= last && week < currentWeek; week = addDays(week, 7)) weeks.push(week);
    const [classes, assignments] = await Promise.all([
      this.prisma.schoolClass.findMany({ where: { schoolId: actor.schoolId }, select: { id: true } }),
      this.prisma.schoolLearningAssignment.count({
        where: { schoolId: actor.schoolId, createdAt: { gte: tashkentDayStart(first), lt: tashkentDayStart(addDays(last, 1)) } },
      }),
    ]);
    const ids = classes.map((c) => c.id);
    const cells = weeks.length ? [...(await this.loadCells(ids, weeks[0], addDays(weeks[weeks.length - 1], 6))).values()] : [];
    const totals = totalsOf(cells);
    return {
      /** Hisobga olingan yakunlangan haftalar (0 — oyning birinchi haftasi hali tugamagan). */
      weeks: weeks.length,
      avgActiveStudents: weeks.length ? Math.round(totals.activeStudents / weeks.length) : 0,
      completedTasks: totals.completedTasks,
      avgScore: totals.avgScore,
      suppressed: totals.suppressed,
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

  /** (urinish paytidagi sinf, hafta) kataklari — barcha hisobotlarda bir xil bo'linish (learning-cells). */
  private async loadCells(classIds: readonly string[], from: string, to?: string): Promise<Map<string, LearningCell>> {
    if (classIds.length === 0) return new Map();
    const attempts = await this.prisma.learningAttempt.findMany({
      where: { schoolClassId: { in: [...classIds] }, status: 'COMPLETED', day: { gte: from, ...(to && { lte: to }) } },
      select: { childId: true, schoolClassId: true, day: true, correct: true, total: true, donEarned: true },
    });
    return buildCells(attempts);
  }

  private scopedClasses(actor: SchoolActor) {
    const allowed = allowedClassIds(actor);
    return this.prisma.schoolClass
      .findMany({ where: { schoolId: actor.schoolId, ...(allowed && { id: { in: allowed } }) }, select: { id: true, name: true, grade: true, letter: true } })
      .then((rows) => rows.sort(compareClasses));
  }
}
