// Bola ilovasi (Parvoz Growth): ochiq testlar, savollar (to'g'ri javoblarsiz,
// bola tilida), yuborish — server baholaydi, javoblar shifrlangan va bir marta;
// psixologga "test yakunlandi" bildirishnomasi (ismsiz, faqat son).

import { SchoolCryptoService } from '../../src/school/common/school-crypto.service';
import { resetDb } from './db';
import { createChild, createParent } from './factories';
import { AssessWorld, buildWorld, childApi, enroll, localInput, openWindow, publishedAssignment, staffApi } from './school-assessments-fixtures';
import { createClass } from './school-students-fixtures';
import { createTestApp, TestApp } from './test-app';

const ALL_A = { q1: 'a', q2: 'b', q3: 'a', q4: 'b' };

describe('School assessments — bola ilovasi', () => {
  let t: TestApp;
  let w: AssessWorld;
  let api: ReturnType<typeof staffApi>;
  let child: ReturnType<typeof childApi>;

  beforeAll(async () => {
    t = await createTestApp();
    api = staffApi(t);
    child = childApi(t);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    w = await buildWorld(t);
  });

  afterAll(() => t.close());

  it('ro\'yxat: faqat o\'z sinfi, ochiq oynada va hali yechilmagan', async () => {
    const { testId, assignment } = await publishedAssignment(t, w, [w.classes.c7a]);
    const future = (
      await api(w.psych, 'POST', '/assignments', {
        testId: 'tpl-logic',
        target: { kind: 'CLASSES', classIds: [w.classes.c7a] },
        opensAt: localInput(new Date(Date.now() + 86_400_000)),
        closesAt: localInput(new Date(Date.now() + 3 * 86_400_000)),
        consent: true,
      })
    ).json();
    expect(future.id).toBeDefined();
    const kid = w.kids7a[0]!;
    const list = (await child(kid, 'GET', '')).json();
    expect(list).toEqual({
      enrolled: true,
      assignments: [
        {
          assignmentId: assignment.id,
          testId,
          kind: 'CUSTOM',
          title: 'Sinov testi',
          description: 'Tavsif',
          itemCount: 4,
          timeLimitMin: 10,
          closesAt: expect.any(String),
        },
      ],
    });
    expect((await child(w.kids7b[0]!, 'GET', '')).json()).toEqual({ enrolled: true, assignments: [] });
    await child(kid, 'POST', `/${assignment.id}/submit`, { answers: ALL_A });
    expect((await child(kid, 'GET', '')).json().assignments).toEqual([]);
    expect((await child(w.kids7a[1]!, 'GET', '')).json().assignments).toHaveLength(1);
  });

  it('savollar: to\'g\'ri javob, shkala va teskari belgisi yuborilmaydi; bola tilida', async () => {
    const a = (await api(w.psych, 'POST', '/assignments', { testId: 'tpl-attention', target: { kind: 'GRADES', grades: [7] }, ...openWindow(), consent: true })).json();
    const uz = await child(w.kids7a[0]!, 'GET', `/${a.id}`);
    expect(uz.statusCode).toBe(200);
    const body = uz.json();
    expect(body).toMatchObject({ assignmentId: a.id, testId: 'tpl-attention', kind: 'ATTENTION', title: 'Diqqat va xotira', timeLimitMin: 15, likert: { min: 1, max: 5 } });
    expect(body.items).toHaveLength(14);
    expect(uz.body).not.toMatch(/"correct"|"scale"|"reverse"/);
    expect(body.items.find((i: { stimulus?: unknown }) => i.stimulus)?.stimulus).toEqual({ text: expect.any(String), showSec: expect.any(Number) });
    const ru = (await child(w.kids7b[0]!, 'GET', `/${a.id}`)).json();
    expect(ru.title).toBe('Внимание и память');

    const emotion = (await api(w.psych, 'POST', '/assignments', { testId: 'tpl-emotion', target: { kind: 'GRADES', grades: [7] }, ...openWindow(), consent: true })).json();
    const likert = await child(w.kids7a[0]!, 'GET', `/${emotion.id}`);
    expect(likert.json().items[0]).toEqual({ id: 'em1', type: 'LIKERT', text: expect.any(String) });
    expect(likert.body).not.toContain('reverse');

    expect((await child(w.kids7a[0]!, 'GET', '/7b0a9a3e-0000-4000-8000-000000000000')).json().code).toBe('ASSIGNMENT_NOT_FOUND');
    expect((await child(w.kids7a[0]!, 'GET', '/not-a-uuid')).statusCode).toBe(400);
  });

  it('yuborish: server baholaydi, javoblar shifrlangan, takror — 409; bildirishnoma soni', async () => {
    const a = (await api(w.psych, 'POST', '/assignments', { testId: 'tpl-logic', target: { kind: 'CLASSES', classIds: [w.classes.c7a] }, ...openWindow(), consent: true })).json();
    const view = (await child(w.kids7a[0]!, 'GET', `/${a.id}`)).json();
    const answers = Object.fromEntries(view.items.map((it: { id: string; options: Array<{ key: string }> }) => [it.id, it.options[1]!.key]));
    const res = await child(w.kids7a[0]!, 'POST', `/${a.id}/submit`, { answers, durationSec: 321 });
    expect({ status: res.statusCode, body: res.json() }).toEqual({ status: 201, body: { ok: true } });
    const again = await child(w.kids7a[0]!, 'POST', `/${a.id}/submit`, { answers, durationSec: 1 });
    expect({ status: again.statusCode, code: again.json().code }).toEqual({ status: 409, code: 'ALREADY_SUBMITTED' });
    expect((await child(w.kids7a[0]!, 'GET', `/${a.id}`)).json().code).toBe('ALREADY_SUBMITTED');

    const stored = await t.prisma.schoolPsychResult.findFirstOrThrow({ where: { assignmentId: a.id } });
    expect(stored).toMatchObject({ origin: 'APP', testId: 'tpl-logic', version: 1, classId: w.classes.c7a, grade: 7, ageBand: 'A13_14', durationSec: 321 });
    const plain = '1'.repeat(16);
    expect(stored.answersEnc).toMatch(/^v1\.[\w-]+\.[\w-]+$/);
    expect(stored.answersEnc).not.toContain(plain);
    expect(t.app.get(SchoolCryptoService).decrypt(stored.answersEnc!)).toBe(plain);
    const raw = stored.raw as Record<string, number>;
    const full = (await api(w.psych, 'GET', '/tests/tpl-logic/results')).json();
    expect(full.rows[0]).toMatchObject({ answers: plain, durationSec: 321, scales: [{ key: 'total', raw: raw.total, max: 16 }] });

    await child(w.kids7a[1]!, 'POST', `/${a.id}/submit`, { answers: { lg1: 'b' } });
    const notes = await t.prisma.schoolStaffNotification.findMany({ where: { kind: 'TEST_COMPLETED' } });
    expect(notes).toHaveLength(1);
    expect(notes[0]).toMatchObject({ params: { count: 2 }, roles: ['PSYCHOLOGIST'], subject: { uz: 'Mantiqiy fikrlash', ru: 'Логическое мышление' } });
    expect(notes[0]!.id).toMatch(new RegExp(`^ntf-test-${a.id}-\\d{4}-\\d{2}-\\d{2}$`));
  });

  it('parallel ikki marta yuborish — bittasi 201, ikkinchisi 409', async () => {
    const { assignment } = await publishedAssignment(t, w, [w.classes.c7a]);
    const kid = w.kids7a[0]!;
    const results = await Promise.all([1, 2, 3].map(() => child(kid, 'POST', `/${assignment.id}/submit`, { answers: ALL_A })));
    expect(results.map((r) => r.statusCode).sort()).toEqual([201, 409, 409]);
    expect(await t.prisma.schoolPsychResult.count({ where: { assignmentId: assignment.id } })).toBe(1);
  });

  it('javoblar tekshiriladi: noma\'lum savol, noto\'g\'ri variant, Likert oralig\'i, bo\'sh', async () => {
    const { assignment } = await publishedAssignment(t, w, [w.classes.c7a]);
    const send = (answers: unknown) => child(w.kids7a[0]!, 'POST', `/${assignment.id}/submit`, { answers });
    expect((await send({ zz: 'a' })).json().message).toBe('answers.zz: assessments.validation.answer');
    expect((await send({ q1: 'c' })).json().message).toBe('answers.q1: assessments.validation.answer');
    expect((await send({ q1: 3 })).json().message).toBe('answers.q1: assessments.validation.answer');
    expect((await send({ q1: null })).json().message).toBe('answers: errors.form.selectAtLeastOne');
    expect((await send('x')).statusCode).toBe(400);
    expect((await child(w.kids7a[0]!, 'POST', `/${assignment.id}/submit`, { answers: ALL_A, durationSec: -1 })).statusCode).toBe(400);

    const emotion = (await api(w.psych, 'POST', '/assignments', { testId: 'tpl-emotion', target: { kind: 'GRADES', grades: [7] }, ...openWindow(), consent: true })).json();
    const likert = (answers: unknown) => child(w.kids7a[0]!, 'POST', `/${emotion.id}/submit`, { answers });
    expect((await likert({ em1: 6 })).json().message).toBe('answers.em1: assessments.validation.answer');
    expect((await likert({ em1: 2.5 })).json().message).toBe('answers.em1: assessments.validation.answer');
    expect((await likert({ em1: 'a' })).statusCode).toBe(400);
    expect(await t.prisma.schoolPsychResult.count()).toBe(0);
    expect((await likert({ em1: 5, mo3: 1 })).statusCode).toBe(201);
    expect((await t.prisma.schoolPsychResult.findFirstOrThrow()).raw).toEqual({ worry: 5, mood: 5 });
  });

  it('kasbiy qiziqish (MULTI): variant kalitlari → RIASEC xom ballar, takrorlangan kalit — xato', async () => {
    const c9a = await createClass(t.prisma, w.schoolId, 9, 'A');
    const [kid] = await enroll(t, w.schoolId, c9a.id, 1, 'uz', 'Gamma');
    const a = (await api(w.psych, 'POST', '/assignments', { testId: 'tpl-career', target: { kind: 'GRADES', grades: [9] }, ...openWindow(), consent: true })).json();
    const view = (await child(kid!, 'GET', `/${a.id}`)).json();
    expect(view.items[0]).toEqual({ id: expect.any(String), type: 'MULTI', text: expect.any(String), options: expect.any(Array) });
    expect(JSON.stringify(view.items[0].options)).not.toContain('scale');
    const first = view.items[0];
    expect((await child(kid!, 'POST', `/${a.id}/submit`, { answers: { [first.id]: ['a', 'a'] } })).statusCode).toBe(400);
    expect((await child(kid!, 'POST', `/${a.id}/submit`, { answers: { [first.id]: ['a', 'c'], [view.items[1].id]: [] } })).statusCode).toBe(201);
    const stored = await t.prisma.schoolPsychResult.findFirstOrThrow();
    const raw = stored.raw as Record<string, number>;
    expect(Object.values(raw).reduce((s, v) => s + v, 0)).toBe(2);
    const row = (await api(w.psych, 'GET', '/tests/tpl-career/results')).json().rows[0];
    expect(row.topCodes).toHaveLength(3);
  });

  it('yopilgan, bekor qilingan va boshqa sinf tayinlashi — 404; ulanmagan bola; ota-ona tokeni', async () => {
    const { assignment } = await publishedAssignment(t, w, [w.classes.c7a]);
    expect((await child(w.kids7b[0]!, 'POST', `/${assignment.id}/submit`, { answers: ALL_A })).json().code).toBe('ASSIGNMENT_NOT_FOUND');
    await api(w.psych, 'POST', `/assignments/${assignment.id}/close`);
    expect((await child(w.kids7a[0]!, 'POST', `/${assignment.id}/submit`, { answers: ALL_A })).json().code).toBe('ASSIGNMENT_NOT_FOUND');
    expect((await child(w.kids7a[0]!, 'GET', `/${assignment.id}`)).statusCode).toBe(404);

    const parent = await createParent(t.prisma);
    const loner = await createChild(t.prisma, parent);
    expect((await child(loner, 'GET', '')).json()).toEqual({ enrolled: false, assignments: [] });
    expect((await child(loner, 'POST', `/${assignment.id}/submit`, { answers: ALL_A })).json().code).toBe('NOT_ENROLLED');
    const asParent = await t.app.inject({ method: 'GET', url: '/api/child/school/assessments', headers: { authorization: `Bearer ${parent.token}` } });
    expect(asParent.statusCode).toBe(403);
  });

  it('yopilish vaqtidan keyin test vaqti chegarasi ichida topshirish qabul qilinadi, keyin — yo\'q', async () => {
    const { assignment } = await publishedAssignment(t, w, [w.classes.c7a]);
    const closedAgo = (minutes: number) =>
      t.prisma.schoolPsychAssignment.update({
        where: { id: assignment.id },
        data: { opensAt: new Date(Date.now() - 86_400_000), closesAt: new Date(Date.now() - minutes * 60_000) },
      });
    await closedAgo(5);
    expect((await child(w.kids7a[0]!, 'GET', '')).json().assignments).toEqual([]);
    expect((await child(w.kids7a[0]!, 'POST', `/${assignment.id}/submit`, { answers: ALL_A })).statusCode).toBe(201);
    await closedAgo(11);
    expect((await child(w.kids7a[1]!, 'POST', `/${assignment.id}/submit`, { answers: ALL_A })).json().code).toBe('ASSIGNMENT_NOT_FOUND');
  });
});
