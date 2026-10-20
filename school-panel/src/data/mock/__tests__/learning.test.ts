import { beforeEach, describe, expect, it } from 'vitest';

import type { ClassActivity } from '@/data/contracts';
import { getTables, transact } from '../db';
import { dashboardService } from '../services/dashboard';
import { developmentService } from '../services/development';
import { ACTIVITY_WEEKS, LEARNING_MIN_COHORT, lastClosedWeek, learningService, learningTotals } from '../services/learning';
import { reportsService } from '../services/reports';
import { freshDb, loginAs } from './helpers';

const DUE = '2026-10-20';
/** Test kuni 2026-10-12 (dushanba): joriy hafta hali tugamagan, oxirgi yopiq hafta — 5-oktabr. */
const CURRENT_WEEK = '2026-10-12';
const LAST_CLOSED = '2026-10-05';

/** Sinfning oxirgi YOPIQ haftasidagi faollar sonini o'zgartiradi (natija ustunlari seed'dagicha qoladi). */
function setLatestActive(classId: string, activeStudents: number): void {
  transact((t) => {
    t.activity = t.activity.map((a) => (a.classId === classId && a.weekStart === LAST_CLOSED ? { ...a, activeStudents } : a));
  });
}

/** Joriy (tugallanmagan) hafta kataklarini katta natijalar bilan to'ldiradi — ular hech qayerda ko'rinmasligi kerak. */
function inflateCurrentWeek(activeStudents: number): void {
  transact((t) => {
    t.activity = t.activity.map((a) => (a.weekStart === CURRENT_WEEK ? { ...a, activeStudents, completedTasks: 9999, avgScore: 99, donPoints: 99999 } : a));
  });
}

const cell = (activeStudents: number, avgScore: number): ClassActivity => ({
  classId: 'cls-x',
  weekStart: '2026-10-12',
  activeStudents,
  completedTasks: activeStudents * 2,
  avgScore,
  donPoints: activeStudents * 10,
});

describe('Growth Learning — tayinlash doirasi', () => {
  beforeEach(freshDb);

  it('sinf rahbari faqat o\'z sinfiga tayinlaydi', async () => {
    loginAs('HOMEROOM');
    const created = await learningService.createAssignment({ materialId: 'mat-2', classIds: ['cls-7a'], dueDate: DUE, note: '' });
    expect(created.classIds).toEqual(['cls-7a']);
    expect(getTables().audit.at(-1)?.action).toBe('learning.assign');
    await expect(
      learningService.createAssignment({ materialId: 'mat-2', classIds: ['cls-7a', 'cls-8b'], dueDate: DUE, note: '' }),
    ).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('direktor faqat ko\'radi, tayinlay olmaydi; psixolog umuman kira olmaydi', async () => {
    loginAs('DIRECTOR');
    await expect(
      learningService.createAssignment({ materialId: 'mat-2', classIds: ['cls-7a'], dueDate: DUE, note: '' }),
    ).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('PSYCHOLOGIST');
    await expect(learningService.activity()).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('o\'tgan muddat va noma\'lum material rad etiladi', async () => {
    loginAs('ADMIN');
    await expect(
      learningService.createAssignment({ materialId: 'mat-2', classIds: ['cls-7a'], dueDate: '2026-10-01', note: '' }),
    ).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(
      learningService.createAssignment({ materialId: 'mat-x', classIds: ['cls-7a'], dueDate: DUE, note: '' }),
    ).rejects.toMatchObject({ code: 'VALIDATION' });
  });

  it('sinf rahbari boshqa sinflarga ham tegishli topshiriqni o\'chira olmaydi', async () => {
    loginAs('HOMEROOM');
    const rows = await learningService.assignments();
    const shared = rows.find((r) => r.classIds.length > 1);
    expect(shared?.canDelete).toBe(false);
    await expect(learningService.deleteAssignment(shared!.id)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    const own = rows.find((r) => r.classIds.length === 1 && r.classIds[0] === 'cls-7a');
    await learningService.deleteAssignment(own!.id);
    expect(getTables().assignments.some((a) => a.id === own!.id)).toBe(false);
  });
});

describe('Growth Learning — faollik doirasi', () => {
  beforeEach(freshDb);

  it('sinf rahbari faqat o\'z sinfi faolligini ko\'radi', async () => {
    loginAs('HOMEROOM');
    const activity = await learningService.activity();
    expect(activity.classes.map((c) => c.classId)).toEqual(['cls-7a']);
    expect(activity.weeks.length).toBeGreaterThan(1);
    await expect(learningService.activity({ classId: 'cls-8b' })).rejects.toMatchObject({ code: 'FORBIDDEN' });
    const assignments = await learningService.assignments();
    for (const a of assignments) expect(a.classIds).toContain('cls-7a');
    for (const a of assignments) expect(a.classNames).toEqual(['7-A']);
  });

  it('direktor butun maktab faolligini ko\'radi', async () => {
    loginAs('DIRECTOR');
    const activity = await learningService.activity();
    expect(activity.classes.length).toBe(getTables().classes.length);
    const last = activity.weeks.at(-1);
    expect(last?.activeStudents).toBe(activity.classes.reduce((s, c) => s + c.activeStudents, 0));
  });

  it('qiziqishlar taqsimoti deterministik va har sinf darajasida 100%', async () => {
    loginAs('ADMIN');
    const first = await learningService.interests();
    const second = await learningService.interests();
    expect(first).toEqual(second);
    expect(first.length).toBe(11);
    for (const row of first) expect(row.shares.reduce((s, x) => s + x.percent, 0)).toBe(100);
  });

  it('materiallar filtri ishlaydi', async () => {
    loginAs('ADMIN');
    const tests = await learningService.materials({ kind: 'TEST' });
    expect(tests.length).toBeGreaterThan(0);
    expect(tests.every((m) => m.kind === 'TEST')).toBe(true);
    const grade1 = await learningService.materials({ grade: 1 });
    expect(grade1.every((m) => m.grades.includes(1))).toBe(true);
  });
});

describe('Growth Learning — K=5 kataklar (backend bilan bir xil)', () => {
  beforeEach(freshDb);

  it('learningTotals: natijalar faqat ochiq (≥ 5 faol) kataklardan, ball faollar bo\'yicha tortilgan', () => {
    expect(LEARNING_MIN_COHORT).toBe(5);
    // 4 faolli katak natijaga qo'shilmaydi, faollar sonida esa qoladi.
    expect(learningTotals([cell(10, 80), cell(5, 50), cell(4, 100), cell(0, 0)])).toEqual({
      activeStudents: 19,
      completedTasks: 30,
      avgScore: 70,
      donPoints: 150,
      suppressed: false,
    });
    // Jami 5 bo'lsa ham, birorta katak ochiq emas — yashirin.
    expect(learningTotals([cell(4, 90), cell(1, 60), cell(0, 0)])).toEqual({
      activeStudents: 5,
      completedTasks: null,
      avgScore: null,
      donPoints: null,
      suppressed: true,
    });
    expect(learningTotals([cell(0, 0)])).toEqual({ activeStudents: 0, completedTasks: 0, avgScore: null, donPoints: 0, suppressed: false });
    expect(learningTotals([])).toEqual({ activeStudents: 0, completedTasks: 0, avgScore: null, donPoints: 0, suppressed: false });
  });

  it('demo seed: har yopiq katakda kamida 5 faol — hech narsa yashirilmaydi', async () => {
    const closed = getTables().activity.filter((a) => a.weekStart <= LAST_CLOSED);
    expect(Math.min(...closed.map((a) => a.activeStudents))).toBeGreaterThanOrEqual(LEARNING_MIN_COHORT);
    loginAs('DIRECTOR');
    const { weeks, classes } = await learningService.activity();
    expect(weeks.every((w) => !w.suppressed && w.avgScore !== null && w.completedTasks !== null)).toBe(true);
    expect(classes.every((c) => !c.suppressed && c.avgScore !== null && c.donPoints !== null)).toBe(true);
  });

  it('3 faolli sinf: natijalar null va yashirin; hafta jami uni chiqarib tashlaydi, faollar soni esa qoladi', async () => {
    setLatestActive('cls-7a', 3);
    loginAs('DIRECTOR');
    const { weeks, classes } = await learningService.activity();
    expect(classes.find((c) => c.classId === 'cls-7a')).toMatchObject({ activeStudents: 3, suppressed: true, completedTasks: null, avgScore: null, donPoints: null });
    const open = classes.filter((c) => c.classId !== 'cls-7a');
    const openActive = open.reduce((s, c) => s + c.activeStudents, 0);
    expect(weeks.at(-1)).toEqual({
      weekStart: weeks.at(-1)?.weekStart,
      activeStudents: openActive + 3,
      completedTasks: open.reduce((s, c) => s + (c.completedTasks ?? 0), 0),
      avgScore: Math.round(open.reduce((s, c) => s + (c.avgScore ?? 0) * c.activeStudents, 0) / openActive),
      donPoints: open.reduce((s, c) => s + (c.donPoints ?? 0), 0),
      suppressed: false,
    });
  });

  it('sinf rahbari: yagona sinfi 5 dan kam — hafta ham yashirin; 0 faol — 0 / null / 0', async () => {
    setLatestActive('cls-7a', 4);
    loginAs('HOMEROOM');
    const small = await learningService.activity();
    expect(small.weeks.at(-1)).toMatchObject({ activeStudents: 4, suppressed: true, completedTasks: null, avgScore: null, donPoints: null });
    expect(small.weeks.at(-2)?.suppressed).toBe(false);
    setLatestActive('cls-7a', 0);
    const none = await learningService.activity();
    expect(none.classes[0]).toMatchObject({ activeStudents: 0, suppressed: false, completedTasks: 0, avgScore: null, donPoints: 0 });
    expect(none.weeks.at(-1)).toMatchObject({ activeStudents: 0, suppressed: false, completedTasks: 0, avgScore: null, donPoints: 0 });
  });

  it('bosh sahifa va o\'quvchi profili ham shu qoidada', async () => {
    loginAs('DIRECTOR');
    const before = await dashboardService.overview();
    const week = (await learningService.activity()).weeks.at(-1);
    // Bosh sahifa /learning bilan bir xil hisob (tortilgan ball).
    expect(before.learning).toMatchObject({ activeStudents: week?.activeStudents, completedTasks: week?.completedTasks, avgScore: week?.avgScore, suppressed: false });

    setLatestActive('cls-7a', 3);
    loginAs('HOMEROOM');
    expect((await dashboardService.overview()).learning).toMatchObject({ activeStudents: 3, completedTasks: null, avgScore: null, suppressed: true });
    const student = getTables().students.find((s) => !s.archived && s.classId === 'cls-7a');
    const profile = await developmentService.studentProfile(student?.id ?? '');
    expect(profile.context.classLearning).toMatchObject({ avgScore: null, suppressed: true });
  });

  it('oylik hisobot: kichik kataklar natijaga kirmaydi; hammasi kichik bo\'lsa — yashirin', async () => {
    setLatestActive('cls-7a', 3);
    loginAs('DIRECTOR');
    // Oktabrning yopiq haftalari (joriy 12-oktabr haftasi hisobotga kirmaydi).
    const october = getTables().activity.filter((a) => a.weekStart.startsWith('2026-10') && a.weekStart <= LAST_CLOSED);
    const open = october.filter((a) => a.activeStudents >= LEARNING_MIN_COHORT);
    const partial = await reportsService.monthly('2026-10');
    expect(open.length).toBe(october.length - 1);
    expect(partial.learning).toMatchObject({ completedTasks: open.reduce((s, a) => s + a.completedTasks, 0), suppressed: false });

    transact((t) => {
      t.activity = t.activity.map((a) => (a.weekStart.startsWith('2026-10') ? { ...a, activeStudents: 3 } : a));
    });
    const hidden = await reportsService.monthly('2026-10');
    expect(hidden.learning).toMatchObject({ avgActiveStudents: getTables().classes.length * 3, completedTasks: null, avgScore: null, suppressed: true });
  });
});

describe('Growth Learning — natijalar faqat yopiq haftalardan (backend bilan bir xil)', () => {
  beforeEach(freshDb);

  const cellsOf = (week: string) => getTables().activity.filter((a) => a.weekStart === week);
  const activeIn = (week: string, classId?: string) =>
    cellsOf(week).filter((a) => !classId || a.classId === classId).reduce((s, a) => s + a.activeStudents, 0);

  it('oxirgi yopiq hafta — o\'tgan haftaning dushanbasi (yakshanba kuni ham joriy hafta hali ochiq)', () => {
    expect(lastClosedWeek('2026-10-12')).toBe(LAST_CLOSED);
    expect(lastClosedWeek('2026-10-18')).toBe(LAST_CLOSED);
    expect(lastClosedWeek('2026-10-19')).toBe(CURRENT_WEEK);
  });

  it('demo seed: 6 yopiq hafta + joriy (tugallanmagan) hafta', () => {
    const weeks = [...new Set(getTables().activity.map((a) => a.weekStart))].sort();
    expect(weeks).toHaveLength(ACTIVITY_WEEKS + 1);
    expect(weeks.slice(-2)).toEqual([LAST_CLOSED, CURRENT_WEEK]);
  });

  it('/learning: 6 yopiq hafta (eskisi birinchi), sinflar — oxirgi yopiq hafta; joriy haftadan faqat faollar soni', async () => {
    loginAs('DIRECTOR');
    const a = await learningService.activity();
    expect(a.latestWeek).toBe(LAST_CLOSED);
    expect(a.weeks.map((w) => w.weekStart)).toEqual(['2026-08-31', '2026-09-07', '2026-09-14', '2026-09-21', '2026-09-28', LAST_CLOSED]);
    expect(a.weeks.at(-1)?.activeStudents).toBe(activeIn(LAST_CLOSED));
    expect(a.current).toEqual({ weekStart: CURRENT_WEEK, activeStudents: activeIn(CURRENT_WEEK) });
    expect(a.current.activeStudents).toBeGreaterThan(0);
    expect(a.classes.find((c) => c.classId === 'cls-7a')).toMatchObject({
      activeStudents: activeIn(LAST_CLOSED, 'cls-7a'),
      activeDelta: activeIn(LAST_CLOSED, 'cls-7a') - activeIn('2026-09-28', 'cls-7a'),
    });
  });

  it('joriy hafta natijalari hech qayerda ko\'rinmaydi: /learning, bosh sahifa, oylik hisobot, o\'quvchi profili', async () => {
    const student = getTables().students.find((s) => !s.archived && s.classId === 'cls-7a');
    const snapshot = async () => {
      loginAs('DIRECTOR');
      const activity = await learningService.activity();
      const dashboard = (await dashboardService.overview()).learning;
      const report = (await reportsService.monthly('2026-10')).learning;
      loginAs('HOMEROOM');
      const profile = await developmentService.studentProfile(student?.id ?? '');
      return { activity, dashboard, report, classLearning: profile.context.classLearning };
    };
    const before = await snapshot();
    inflateCurrentWeek(30);
    const after = await snapshot();
    expect(after.activity.weeks).toEqual(before.activity.weeks);
    expect(after.activity.classes).toEqual(before.activity.classes);
    expect(after.dashboard).toEqual(before.dashboard);
    expect(after.report).toEqual(before.report);
    expect(after.classLearning).toEqual(before.classLearning);
    // Joriy hafta — faqat faollar soni (yangilanadi).
    expect(after.activity.current).toEqual({ weekStart: CURRENT_WEEK, activeStudents: getTables().classes.length * 30 });
  });

  it('bosh sahifa: weekStart — oxirgi yopiq hafta, raqamlar /learning bilan bir xil (sinf rahbari — o\'z sinfi)', async () => {
    loginAs('HOMEROOM');
    const learning = (await dashboardService.overview()).learning;
    const activity = await learningService.activity();
    const week = activity.weeks.at(-1);
    expect(learning?.weekStart).toBe(LAST_CLOSED);
    expect(learning).toMatchObject({ activeStudents: week?.activeStudents, completedTasks: week?.completedTasks, avgScore: week?.avgScore, suppressed: false });
    expect(activity.current.activeStudents).toBe(activeIn(CURRENT_WEEK, 'cls-7a'));
  });

  it('faollar sinfning bugungi tarkibidan ko\'p bo\'lsa ham ulush 100% dan oshmaydi', async () => {
    const keep = new Set(getTables().students.filter((s) => !s.archived && s.classId === 'cls-7a').slice(0, 3).map((s) => s.id));
    transact((t) => {
      t.students = t.students.map((s) => (s.classId === 'cls-7a' && !keep.has(s.id) ? { ...s, archived: true } : s));
    });
    loginAs('HOMEROOM');
    expect((await learningService.activity()).classes[0]?.activeRate).toBe(100);
    const profile = await developmentService.studentProfile([...keep][0] ?? '');
    expect(profile.context.classLearning?.activeRate).toBe(100);
  });
});
