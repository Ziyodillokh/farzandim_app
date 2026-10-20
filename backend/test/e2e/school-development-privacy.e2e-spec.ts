// Rivojlanish — xavfsizlik ko'rigi regressiyalari: (1) guruhlar natijadagi sinf / daraja
// nusxasidan (sinf darajasini tahrirlash yoki sinfni o'chirish direktor kesimini
// o'zgartirmaydi); (2) direktor jonli o'zgarishni ko'rmaydi — ochiq tayinlashda bolalar
// birma-bir topshirsa ham kesim bir xil, yopilgandan keyin bir partiya bo'lib qo'shiladi.
// Tenant izolyatsiyasi va bosh sahifa xulosasi.

import { tashkentDay } from '../../src/common/time/tashkent';
import { termOf } from '../../src/school/assessments/psych/terms';
import { resetDb } from './db';
import { childApi, openWindow, staffApi, staffWith } from './school-assessments-fixtures';
import { buildDevWorld, DAY_MS, devApi, DevWorld, schoolApi, seedBatch } from './school-development-fixtures';
import { createSchool } from './school-fixtures';
import { createClass, createStudent } from './school-students-fixtures';
import { createTestApp, TestApp } from './test-app';

const termAt = (at: Date) => termOf(tashkentDay(at)).key;
const q = (term: string) => `?termKey=${encodeURIComponent(term)}`;

describe('School development — maxfiylik regressiyalari', () => {
  let t: TestApp;
  let w: DevWorld;
  let api: ReturnType<typeof devApi>;
  const prev = new Date(Date.now() - 200 * DAY_MS);
  const recent = new Date(Date.now() - 3 * DAY_MS);

  async function seedPast() {
    const all = [...w.pupils7a, ...w.pupils7b, ...w.pupils8a];
    for (const at of [prev, recent]) {
      await seedBatch(t, w, { testId: 'tpl-logic', at, pupils: all, raw: (i) => ({ total: 5 + (i % 9) }) });
      await seedBatch(t, w, { testId: 'tpl-attention', at: new Date(at.getTime() + 5000), pupils: all, raw: (i) => ({ attention: 2 + (i % 5), memory: 1 + (i % 6) }) });
    }
  }

  /** Direktor ko'radigan hamma narsa: standart kesim, har chorak kesimi, choraklar, bosh sahifa. */
  async function directorView() {
    const terms = (await api(w.director, '/term-options')).json() as Array<{ key: string }>;
    const overviews = await Promise.all(terms.map(async (x) => (await api(w.director, `/school/overview${q(x.key)}`)).json()));
    const dashboard = (await schoolApi(t)(w.director, 'GET', '/dashboard/overview')).json().development;
    return { terms, overviews, standard: (await api(w.director, '/school/overview')).json(), dashboard };
  }

  beforeAll(async () => {
    t = await createTestApp();
    api = devApi(t);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    w = await buildDevWorld(t);
  });

  afterAll(() => t.close());

  it('(1) sinf darajasini tahrirlash va sinfni o\'chirish direktor guruhlarini o\'zgartirmaydi', async () => {
    await seedPast();
    const before = await directorView();
    expect(before.overviews.length).toBe(2);
    expect(before.overviews[0].heat.filter((h: { n: number }) => h.n > 0).length).toBe(2);

    await t.prisma.schoolClass.update({ where: { id: w.classes.c7b }, data: { grade: 9 } });
    expect(await directorView()).toEqual(before);

    await t.prisma.schoolStudent.updateMany({ where: { classId: w.classes.c7b }, data: { classId: null } });
    await t.prisma.schoolClass.delete({ where: { id: w.classes.c7b } });
    const after = await directorView();
    for (const [i, o] of after.overviews.entries()) {
      const b = before.overviews[i];
      expect([o.domainAverages, o.trend, o.cognitiveByGrade, o.cognitiveCoarse, o.participation.assessed]).toEqual([
        b.domainAverages,
        b.trend,
        b.cognitiveByGrade,
        b.cognitiveCoarse,
        b.participation.assessed,
      ]);
      expect(o.heat.find((h: { classId: string }) => h.classId === w.classes.c7b)).toBeUndefined();
    }
  });

  it('(2) ochiq tayinlashda bolalar birma-bir topshiradi — direktor kesimi o\'zgarmaydi; yopilgach bir partiya', async () => {
    await seedPast();
    const staff = staffApi(t);
    const child = childApi(t);
    const a = (await staff(w.psych, 'POST', '/assignments', { testId: 'tpl-emotion', target: { kind: 'CLASSES', classIds: [w.classes.c7a] }, ...openWindow(), consent: true })).json();
    const current = termAt(new Date());
    const baseline = await directorView();
    const psychAssessed = async () => (await api(w.psych, `/school/overview${q(current)}`)).json().domainAverages.find((d: { domain: string }) => d.domain === 'EMOTIONAL')?.n ?? 0;

    for (const [i, kid] of w.kids7a.entries()) {
      expect((await child(kid, 'POST', `/${a.id}/submit`, { answers: { em1: 1 + (i % 5), mo1: 3, em2: 2 } })).statusCode).toBe(201);
      expect(await directorView()).toEqual(baseline);
      expect(await psychAssessed()).toBe(i + 1);
    }
    const releasedBefore = baseline.overviews.find((o: { termKey: string }) => o.termKey === current);
    expect(releasedBefore?.domainAverages.find((d: { domain: string }) => d.domain === 'EMOTIONAL')).toBeUndefined();

    expect((await staff(w.psych, 'POST', `/assignments/${a.id}/close`)).statusCode).toBe(200);
    const released = await directorView();
    const now = released.overviews.find((o: { termKey: string }) => o.termKey === current);
    expect(now.domainAverages.find((d: { domain: string }) => d.domain === 'EMOTIONAL')).toMatchObject({ n: 6, index: expect.any(Number) });
    expect(await directorView()).toEqual(released);
    expect(JSON.stringify(released)).not.toMatch(/Alfa|Beta|Gamma/);
  });

  it('tenant izolyatsiyasi: boshqa maktab ID\'lari — 404, natijalari ko\'rinmaydi', async () => {
    await seedPast();
    const other = (await createSchool(t.prisma, 'other-school')).school;
    const otherClass = await createClass(t.prisma, other.id, 7, 'A');
    await createStudent(t.prisma, other.id, otherClass.id);
    const foreign = await staffWith(t, other.id, 'PSYCHOLOGIST', 'psixolog2');
    expect((await api(foreign, `/students/${w.pupils7a[0]!.id}/profile`)).statusCode).toBe(404);
    expect((await api(foreign, `/classes/${w.classes.c7a}/overview`)).statusCode).toBe(404);
    expect((await api(foreign, '/attention')).json()).toEqual([]);
    expect((await api(foreign, '/term-options')).json()).toEqual([]);
    expect((await api(foreign, '/class-options')).json().map((c: { id: string }) => c.id)).toEqual([otherClass.id]);
    const o = (await api(foreign, '/school/overview')).json();
    expect(o).toMatchObject({ participation: { assessed: 0 }, trend: [], heat: [], cognitiveByGrade: [] });
    expect((await api(foreign, `/school/overview${q(termAt(prev))}`)).statusCode).toBe(400);
  });

  it('bosh sahifa: direktor — AGGREGATE (ID yo\'q), sinf rahbari — CLASS, psixolog — PSYCHOLOGIST, navbatchi — null', async () => {
    const dash = schoolApi(t);
    const empty = (await dash(w.director, 'GET', '/dashboard/overview')).json().development;
    expect(empty).toEqual({ mode: 'AGGREGATE', termKey: termAt(new Date()), participation: 0, domains: expect.any(Array) });
    expect(empty.domains.every((d: { index: unknown }) => d.index === null)).toBe(true);

    await seedPast();
    await seedBatch(t, w, { testId: 'tpl-logic', at: new Date(Date.now() - 60_000), pupils: w.pupils7a, raw: () => ({ total: 1 }), kind: 'OPEN' });
    const agg = (await dash(w.director, 'GET', '/dashboard/overview')).json().development;
    expect(agg).toMatchObject({ mode: 'AGGREGATE', termKey: termAt(recent), participation: 80 });
    expect(agg.domains.find((d: { domain: string }) => d.domain === 'REASONING').index).toEqual(expect.any(Number));
    expect(JSON.stringify(agg)).not.toMatch(/Alfa|Beta|Gamma|[0-9a-f]{8}-[0-9a-f]{4}-/);

    const cls = (await dash(w.homeroom, 'GET', '/dashboard/overview')).json().development;
    expect(cls).toMatchObject({ mode: 'CLASS', classId: w.classes.c7a, className: '7-A', assessed: 6, total: 6 });
    const psych = (await dash(w.psych, 'GET', '/dashboard/overview')).json().development;
    // 6 ta 7-A (ochiq tayinlashdagi past mantiq — psixolog jonli ko'radi) + past diqqat / xotira (ATT_LOW).
    expect(psych).toMatchObject({ mode: 'PSYCHOLOGIST', activeAssignments: 1 });
    expect(psych.attention).toBe((await api(w.psych, '/attention')).json().length);
    expect(psych.attention).toBeGreaterThanOrEqual(6);
    expect(psych.completedThisWeek).toBeGreaterThanOrEqual(6);
    expect((await dash(w.duty, 'GET', '/dashboard/overview')).json().development).toBeNull();
    expect((await dash(w.teacher, 'GET', '/dashboard/overview')).json().development).toBeNull();
  });
});
