// Parvoz IQ maktabda (docs/IQ-REJA.md §7): psixolog `parvoz-iq` ni sinfga
// tayinlaydi → bola maktab topshiriqlarida ko'radi → odatdagi /iq oqimida
// yechadi (umumiy tarix) → psixolog va o'z sinfi rahbari ism bilan, direktor
// faqat K=5 taqsimotni ko'radi; boshqa rollar — 403.

import { PrismaClient } from '@prisma/client';
import { buildIqBankRows } from '../../scripts/iq/build-bank-migration';
import { resetDb } from './db';
import { caller } from './kelajak-fixtures';
import { AssessWorld, buildWorld, childApi, enroll, Kid, openWindow, staffApi } from './school-assessments-fixtures';
import { createTestApp, TestApp } from './test-app';

async function seedIqBank(prisma: PrismaClient): Promise<void> {
  await prisma.iqItem.createMany({ data: buildIqBankRows().map(({ options, ...row }) => ({ ...row, options })) });
}

describe('School IQ (parvoz-iq)', () => {
  let t: TestApp;
  let w: AssessWorld;
  let extra: Kid[];
  const api = () => staffApi(t);

  /** Bola odatdagi /iq oqimida testni yakunlaydi (`correct` ta to'g'ri). */
  async function solve(kid: Kid, correct: number): Promise<void> {
    const call = caller(t);
    const session = (await call(kid.token, 'POST', '/iq/sessions')).json();
    const keys = await t.prisma.iqItem.findMany({ where: { id: { in: session.items.map((i: { id: string }) => i.id) } } });
    const answerOf = new Map(keys.map((k) => [k.id, k.answer]));
    for (const [i, item] of (session.items as Array<{ id: string }>).entries()) {
      const right = answerOf.get(item.id) as string;
      const choice = i < correct ? right : right === 'A' ? 'B' : 'A';
      expect((await call(kid.token, 'PUT', `/iq/sessions/${session.id}/answers/${item.id}`, { choice })).statusCode).toBe(200);
    }
    expect((await call(kid.token, 'POST', `/iq/sessions/${session.id}/complete`)).statusCode).toBe(200);
  }

  const assignIq = (classIds: string[]) =>
    api()(w.psych, 'POST', '/assignments', { testId: 'parvoz-iq', target: { kind: 'CLASSES', classIds }, ...openWindow(), consent: true });
  const childTasks = async (kid: Kid) => (await childApi(t)(kid, 'GET', '')).json().assignments as Array<{ testId: string; kind: string }>;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    await seedIqBank(t.prisma);
    w = await buildWorld(t);
    extra = await enroll(t, w.schoolId, w.classes.c7a, 3, 'uz', 'Gamma');
  });

  afterAll(() => t.close());

  it('tayinlash → bola ko\'radi → yechadi → topshiriq yo\'qoladi, yakunlaganlar soni', async () => {
    const res = await assignIq([w.classes.c7a]);
    expect(res.statusCode).toBe(201);
    expect(res.json()).toMatchObject({ testId: 'parvoz-iq', classIds: [w.classes.c7a] });

    const kid = w.kids7a[0];
    expect(await childTasks(kid)).toEqual([expect.objectContaining({ testId: 'parvoz-iq', kind: 'IQ' })]);
    expect(await childTasks(w.kids7b[0])).toEqual([]);

    await solve(kid, 14);
    expect(await childTasks(kid)).toEqual([]);

    const list = (await api()(w.psych, 'GET', '/assignments')).json();
    expect(list).toEqual([expect.objectContaining({ testId: 'parvoz-iq', completed: 1, testKind: 'COGNITIVE', testTitle: expect.objectContaining({ uz: expect.stringContaining('Parvoz IQ') }) })]);
  });

  it('umumiy tarix: tayinlovdan oldin (180 kun ichida) yechgan bola topshiriqni ko\'rmaydi', async () => {
    await solve(w.kids7a[1], 10);
    await assignIq([w.classes.c7a]);
    expect(await childTasks(w.kids7a[1])).toEqual([]);
    expect(await childTasks(w.kids7a[0])).toHaveLength(1);
  });

  it('natijalar: psixolog va o\'z sinfi rahbari — ism bilan; direktor — K=5; boshqalar — 403', async () => {
    await assignIq([w.classes.c7a]);
    await solve(w.kids7a[0], 16);
    const url = `/iq/results?classId=${w.classes.c7a}`;

    const psych = (await api()(w.psych, 'GET', url)).json();
    expect(psych).toMatchObject({ mode: 'INDIVIDUAL', students: 6, linked: 6, completed: 1, suppressed: false });
    const row = psych.rows.find((r: { result: unknown }) => r.result);
    expect(row.result).toMatchObject({ correct: 16, total: 20, status: 'PROVISIONAL' });
    expect(JSON.stringify(psych)).not.toContain('"answer"');

    expect((await api()(w.homeroom, 'GET', url)).json()).toMatchObject({ mode: 'INDIVIDUAL', completed: 1 });
    expect((await api()(w.homeroom, 'GET', `/iq/results?classId=${w.classes.c7b}`)).statusCode).toBe(403);

    const director = (await api()(w.director, 'GET', url)).json();
    expect(director).toMatchObject({ mode: 'AGGREGATE', completed: 1, suppressed: true, bands: null, rows: [] });

    for (const kid of [...w.kids7a.slice(1), ...extra.slice(0, 1)]) await solve(kid, 12);
    const open = (await api()(w.director, 'GET', url)).json();
    expect(open).toMatchObject({ mode: 'AGGREGATE', completed: 4, suppressed: true });
    await solve(extra[1], 12);
    const visible = (await api()(w.director, 'GET', url)).json();
    expect(visible.suppressed).toBe(false);
    expect(Object.values(visible.bands as Record<string, number>).reduce((a, b) => a + b, 0)).toBe(5);
    expect(visible.rows).toEqual([]);

    expect((await api()(w.teacher, 'GET', url)).statusCode).toBe(403);
    expect((await api()(w.duty, 'GET', url)).statusCode).toBe(403);
  });

  it('natija bor — yopiladi (CLOSED), yo\'q — bekor (CANCELLED)', async () => {
    const empty = (await assignIq([w.classes.c7b])).json();
    expect((await api()(w.psych, 'POST', `/assignments/${empty.id}/unassign`)).json()).toMatchObject({ status: 'CANCELLED' });
    const used = (await assignIq([w.classes.c7a])).json();
    await solve(w.kids7a[0], 10);
    expect((await api()(w.psych, 'POST', `/assignments/${used.id}/unassign`)).json()).toMatchObject({ status: 'CLOSED' });
  });

  it('IQ tayinlovi faqat psixolog — boshqa rol 403; maktab testi oqimi o\'zgarmagan', async () => {
    const res = await api()(w.homeroom, 'POST', '/assignments', { testId: 'parvoz-iq', target: { kind: 'CLASSES', classIds: [w.classes.c7a] }, ...openWindow(), consent: true });
    expect(res.statusCode).toBe(403);
    // Psixologik test yo'li IQ'ni ochmaydi (id formati / topilmaydi) — IQ faqat /iq oqimida.
    expect([400, 404]).toContain((await childApi(t)(w.kids7a[0], 'GET', '/parvoz-iq')).statusCode);
  });
});
