// Bola ovozi — mutaxassis tayinlagan SHAXSIY (STUDENTS) test: tanlangan o'quvchilargina ko'radi,
// tekshiruvlar, tenant izolyatsiyasi, bola ro'yxatidagi yangi maydonlar.

import { PARVOZ_IQ_TEST_ID } from '../../src/school/assessments/assessments-iq.service';
import { AssessmentsStore } from '../../src/school/assessments/assessments-store';
import { resetDb } from './db';
import { createTestApp, TestApp } from './test-app';
import { AssessWorld, buildWorld, careStaff, createRequest, Kid, psychologist } from './school-care-fixtures';
import { childApi, openWindow, sampleInput, staffApi } from './school-assessments-fixtures';
import { createClass, createStudent } from './school-students-fixtures';

const ANSWERS = { q1: 'a', q2: 'b', q3: 'a', q4: 'b' };

describe('Bola ovozi — shaxsiy test tayinlash (STUDENTS)', () => {
  let t: TestApp;
  let w: AssessWorld;
  let api: ReturnType<typeof staffApi>;
  let child: ReturnType<typeof childApi>;
  let care: ReturnType<typeof careStaff>;
  let testId: string;

  beforeAll(async () => {
    t = await createTestApp();
    api = staffApi(t);
    child = childApi(t);
    care = careStaff(t);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    w = await buildWorld(t);
    testId = (await api(w.psych, 'POST', '/tests', sampleInput())).json().id;
    await api(w.psych, 'POST', `/tests/${testId}/publish`);
  });

  afterAll(() => t.close());

  const assign = (target: unknown, over: Record<string, unknown> = {}, who = w.psych) =>
    api(who, 'POST', '/assignments', { testId, target, ...openWindow(), consent: true, ...over });
  const personal = (...kids: Kid[]) => ({ kind: 'STUDENTS', studentIds: kids.map((k) => k.studentId) });
  const listOf = async (kid: Kid) => (await child(kid, 'GET', '')).json().assignments as Array<Record<string, unknown>>;

  it('tayinlash: faqat tanlangan o\'quvchi ko\'radi va topshiradi; sinfdoshi va boshqa sinf ko\'rmaydi', async () => {
    const [a, b] = w.kids7a as [Kid, Kid];
    const res = await assign(personal(a));
    expect(res.statusCode).toBe(201);
    const assignment = res.json();
    expect(assignment).toMatchObject({ target: { kind: 'STUDENTS', studentIds: [a.studentId] }, classIds: [], studentIds: [a.studentId], careRequestId: null, invited: 1, status: 'OPEN', consent: 'PARENTS_INFORMED' });

    const rows = await listOf(a);
    expect(rows).toEqual([
      {
        assignmentId: assignment.id,
        testId,
        kind: 'CUSTOM',
        title: 'Sinov testi',
        description: 'Tavsif',
        itemCount: 4,
        timeLimitMin: 10,
        closesAt: expect.any(String),
        personal: true,
        assignedBy: { name: 'PSYCHOLOGIST xodim' },
        questionCount: 4,
        estimatedMinutes: 1,
      },
    ]);
    expect(await listOf(b)).toEqual([]);
    expect(await listOf(w.kids7b[0]!)).toEqual([]);

    expect((await child(a, 'GET', `/${assignment.id}`)).statusCode).toBe(200);
    expect((await child(b, 'GET', `/${assignment.id}`)).json().code).toBe('ASSIGNMENT_NOT_FOUND');
    expect((await child(b, 'POST', `/${assignment.id}/submit`, { answers: ANSWERS })).statusCode).toBe(404);
    expect((await child(a, 'POST', `/${assignment.id}/submit`, { answers: ANSWERS })).statusCode).toBe(201);
    expect(await listOf(a)).toEqual([]);
    expect(await t.prisma.schoolPsychResult.count()).toBe(1);
  });

  it('xodim ro\'yxati va natijalar: taklif qilinganlar = tanlangan o\'quvchilar, yakunlaganlar soni', async () => {
    const [a, b] = w.kids7a as [Kid, Kid];
    const assignment = (await assign(personal(a, b))).json();
    await child(a, 'POST', `/${assignment.id}/submit`, { answers: ANSWERS });

    const row = (await api(w.psych, 'GET', '/assignments')).json().find((x: { id: string }) => x.id === assignment.id);
    expect(row).toMatchObject({ studentIds: [a.studentId, b.studentId], classNames: [], completed: 1, invited: 2, state: 'ACTIVE' });
    const results = (await api(w.psych, 'GET', `/tests/${testId}/results?assignmentId=${assignment.id}`)).json();
    expect(results.participation).toEqual({ invited: 2, completed: 1 });
  });

  it('shaxsiy natijalar sinf rahbariga va rivojlanish indeksiga chiqmaydi, psixologga ko\'rinadi', async () => {
    const [a, b] = w.kids7a as [Kid, Kid];
    const personalAssignment = (await assign(personal(a))).json();
    const classWide = (await assign({ kind: 'CLASSES', classIds: [w.classes.c7a] })).json();
    await child(a, 'POST', `/${personalAssignment.id}/submit`, { answers: ANSWERS });
    await child(b, 'POST', `/${classWide.id}/submit`, { answers: ANSWERS });

    const names = (res: { json: () => { rows: Array<{ studentName: string }> } }) => res.json().rows.map((r) => r.studentName).sort();
    const forPsych = await api(w.psych, 'GET', `/tests/${testId}/results`);
    expect(names(forPsych)).toEqual(['Alfaov Alfa0', 'Alfaov Alfa1']);
    const forHomeroom = await api(w.homeroom, 'GET', `/tests/${testId}/results`);
    expect(forHomeroom.statusCode).toBe(200);
    expect(forHomeroom.body).not.toContain('Alfa0');
    expect(forHomeroom.json().rows).toHaveLength(1);
    const direct = await api(w.homeroom, 'GET', `/tests/${testId}/results?assignmentId=${personalAssignment.id}`);
    expect(direct.json()).toMatchObject({ rows: [], participation: { invited: 0, completed: 0 } });

    const scored = await t.app.get(AssessmentsStore).scoredResults(w.schoolId);
    expect(scored.map((r) => r.studentId)).toEqual([b.studentId]);
  });

  it('sinf tayinlashi bilan birga: personal=false', async () => {
    const [a] = w.kids7a as [Kid];
    await assign({ kind: 'CLASSES', classIds: [w.classes.c7a] });
    await assign(personal(a));
    const rows = await listOf(a);
    expect(rows.map((r) => r.personal).sort()).toEqual([false, true]);
    expect((await listOf(w.kids7a[1]!)).map((r) => r.personal)).toEqual([false]);
  });

  it('tekshiruvlar: bo\'sh / 30 dan ko\'p / noma\'lum / begona maktab / arxivlangan / daraja mos emas / rozilik', async () => {
    const other = await buildWorld(t, 'other-school');
    const archived = w.kids7a[1]!;
    await t.prisma.schoolStudent.update({ where: { id: archived.studentId }, data: { archived: true } });
    const c10 = await createClass(t.prisma, w.schoolId, 10, 'A');
    const senior = await createStudent(t.prisma, w.schoolId, c10.id, { firstName: 'Katta' });
    const bad = (target: unknown, over: Record<string, unknown> = {}) => assign(target, over);
    const withIds = (...studentIds: string[]) => ({ kind: 'STUDENTS', studentIds });

    expect((await bad(withIds())).json().message).toBe('target.studentIds: errors.form.selectAtLeastOne');
    expect((await bad(withIds(...Array.from({ length: 31 }, (_, i) => `s${i}`)))).json().message).toBe('target.studentIds: errors.form.tooLong');
    for (const ids of [['no-such-student'], [other.kids7a[0]!.studentId], [archived.studentId], [senior.id], [w.kids7a[0]!.studentId, 'no-such-student']]) {
      const res = await bad(withIds(...ids));
      expect([res.statusCode, res.json().message]).toEqual([400, 'target.studentIds: assessments.validation.noStudents']);
    }
    expect((await bad(personal(w.kids7a[0]!), { consent: false })).statusCode).toBe(400);
    expect((await bad({ kind: 'STUDENTS', studentIds: [w.kids7a[0]!.studentId], extra: 1 })).statusCode).toBe(400);
    expect((await bad(personal(w.kids7a[0]!), { careRequestId: 'no-such-request' })).json().message).toBe('careRequestId: errors.form.invalid');
    expect(await t.prisma.schoolPsychAssignment.count()).toBe(0);
  });

  it('aniq 30 ta o\'quvchi qabul qilinadi; takrorlangan id bir marta hisoblanadi', async () => {
    const extra = await Promise.all(Array.from({ length: 28 }, (_, i) => createStudent(t.prisma, w.schoolId, w.classes.c7a, { firstName: `Qoshimcha${i}` })));
    const ids = [...w.kids7a.map((k) => k.studentId), ...extra.map((s) => s.id)];
    expect(ids).toHaveLength(31);
    expect((await assign({ kind: 'STUDENTS', studentIds: ids })).statusCode).toBe(400);
    const thirty = await assign({ kind: 'STUDENTS', studentIds: ids.slice(0, 30) });
    expect(thirty.statusCode).toBe(201);
    expect(thirty.json()).toMatchObject({ invited: 30 });

    const dup = await assign({ kind: 'STUDENTS', studentIds: [ids[0], ids[0]] });
    expect(dup.statusCode).toBe(201);
    expect(dup.json()).toMatchObject({ studentIds: [ids[0]], invited: 1 });
  });

  it('careRequestId: o\'z maktab murojaati saqlanadi (target ichida ham qabul qilinadi), begonasi rad etiladi', async () => {
    const [a] = w.kids7a as [Kid];
    const mine = await createRequest(t, a);
    const other = await buildWorld(t, 'other-school');
    const theirs = await createRequest(t, other.kids7a[0]!);

    const viaBody = await assign(personal(a), { careRequestId: mine.id });
    expect(viaBody.json().careRequestId).toBe(mine.id);
    const viaTarget = await assign({ ...personal(a), careRequestId: mine.id });
    expect(viaTarget.json()).toMatchObject({ careRequestId: mine.id, target: { kind: 'STUDENTS', studentIds: [a.studentId] } });
    expect(JSON.stringify(viaTarget.json().target)).not.toContain('careRequestId');
    const foreign = await assign(personal(a), { careRequestId: theirs.id });
    expect([foreign.statusCode, foreign.json().message]).toEqual([400, 'careRequestId: errors.form.invalid']);
  });

  it('faqat assessments.manage: direktor, sinf rahbari va boshqa maktab xodimi tayinlay olmaydi', async () => {
    const other = await buildWorld(t, 'other-school');
    const target = personal(w.kids7a[0]!);
    for (const who of [w.director, w.homeroom, w.admin, w.duty]) expect((await assign(target, {}, who)).statusCode).toBe(403);
    // Boshqa maktab xodimi uchun bu maktabning testi ham, o'quvchisi ham ko'rinmaydi.
    expect((await assign(target, {}, other.psych)).statusCode).toBe(404);
    const ownTest = (await api(other.psych, 'POST', '/tests', sampleInput())).json().id;
    await api(other.psych, 'POST', `/tests/${ownTest}/publish`);
    const res = await assign(target, { testId: ownTest }, other.psych);
    expect([res.statusCode, res.json().message]).toEqual([400, 'target.studentIds: assessments.validation.noStudents']);
    expect(await t.prisma.schoolPsychAssignment.count()).toBe(0);
  });

  it('assignedBy: sozlangan mas\'ul psixologning ko\'rsatiladigan ismi; boshqa mutaxassis — F.I.Sh.', async () => {
    const [a] = w.kids7a as [Kid];
    const second = await psychologist(t, w.schoolId, 'ikkinchi', 'Ikkinchi Psixolog');
    await care(w.psych, 'PUT', '/settings', { psychologistStaffId: w.psych.staffId, psychologistDisplayName: 'Dilnoza opa' });
    await assign(personal(a));
    await assign(personal(a), {}, second);

    const names = (await listOf(a)).map((r) => (r.assignedBy as { name: string }).name).sort();
    expect(names).toEqual(['Dilnoza opa', 'Ikkinchi Psixolog']);
  });

  it('assignedBy null: yaratuvchi xodim topilmasa', async () => {
    const [a] = w.kids7a as [Kid];
    const gone = await psychologist(t, w.schoolId, 'ketgan', 'Ketgan');
    await assign(personal(a), {}, gone);
    await t.prisma.schoolStaff.delete({ where: { id: gone.id } });

    expect((await listOf(a))[0]).toMatchObject({ personal: true, assignedBy: null });
  });

  it('Parvoz IQ ham shaxsiy tayinlanadi; yakunlaganlar hisobi o\'quvchilar bo\'yicha', async () => {
    const [a] = w.kids7a as [Kid];
    const res = await assign(personal(a), { testId: PARVOZ_IQ_TEST_ID });
    expect(res.statusCode).toBe(201);
    const row = (await api(w.psych, 'GET', '/assignments')).json().find((x: { id: string }) => x.id === res.json().id);
    expect(row).toMatchObject({ studentIds: [a.studentId], completed: 0, invited: 1 });
    const mine = (await listOf(a)).find((r) => r.kind === 'IQ');
    expect(mine).toMatchObject({ personal: true, questionCount: expect.any(Number), estimatedMinutes: expect.any(Number) });
    expect((await listOf(w.kids7a[1]!)).some((r) => r.kind === 'IQ')).toBe(false);
  });
});
