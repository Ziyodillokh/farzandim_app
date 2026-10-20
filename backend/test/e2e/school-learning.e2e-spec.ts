// Maktab uchun Growth: sinf faolligi (bog'langan bolalarning Daily Learning
// natijalari, faqat sinf darajasi), qiziqishlar, materiallar, topshiriqlar va
// bola ilovasidagi "maktab topshiriqlari".

import { LearningSubject } from '@prisma/client';
import { addDays, isoWeekday, tashkentDay } from '../../src/common/time/tashkent';
import { createChild, createParent, TestChild } from './factories';
import { resetDb } from './db';
import { createSchool, createStaff, login, LoggedIn } from './school-fixtures';
import { createClass, createStudent } from './school-students-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School learning (Growth)', () => {
  let t: TestApp;
  let schoolId: string;
  let classA: string;
  let classB: string;
  let director: LoggedIn;

  const call = (who: LoggedIn, method: 'GET' | 'POST' | 'DELETE', url: string, payload?: unknown) =>
    t.app.inject({ method, url: `/api/school/learning${url}`, payload: payload as object, headers: { authorization: `Bearer ${who.token}` } });
  const monday = () => addDays(tashkentDay(), 1 - isoWeekday(tashkentDay()));

  async function linkedKid(classId: string, subjects: LearningSubject[] = ['MATH']): Promise<TestChild> {
    const parent = await createParent(t.prisma);
    const kid = await createChild(t.prisma, parent);
    await createStudent(t.prisma, schoolId, classId, { childId: kid.childId, firstName: kid.childId.slice(0, 5) });
    await t.prisma.learningProfile.create({ data: { childId: kid.childId, grade: 7, subjects } });
    return kid;
  }

  const attempt = (kid: TestChild, day: string, correct: number, subject: LearningSubject = 'MATH') =>
    t.prisma.learningAttempt.create({
      data: { childId: kid.childId, subject, day, isDaily: true, status: 'COMPLETED', questionIds: [], correct, total: 5, donEarned: correct * 2, completedAt: new Date() },
    });

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    schoolId = (await createSchool(t.prisma)).school.id;
    classA = (await createClass(t.prisma, schoolId, 7, 'A')).id;
    classB = (await createClass(t.prisma, schoolId, 7, 'B')).id;
    director = await login(t.app, 'direktor');
  });

  afterAll(() => t.close());

  it('faollik: faqat bog\'langan bolalar, sinf darajasida; doira', async () => {
    const k1 = await linkedKid(classA);
    const k2 = await linkedKid(classA, ['ENGLISH', 'MATH']);
    await createStudent(t.prisma, schoolId, classA, { firstName: 'Ulanmagan' });
    await attempt(k1, monday(), 5);
    await attempt(k2, monday(), 3);
    await attempt(k1, addDays(monday(), -7), 4);

    const act = (await call(director, 'GET', '/activity')).json();
    expect(act.latestWeek).toBe(monday());
    expect(act.weeks).toHaveLength(8);
    expect(act.weeks.at(-1)).toMatchObject({ activeStudents: 2, completedTasks: 2, avgScore: 80, donPoints: 16 });
    expect(act.classes.find((c: { classId: string }) => c.classId === classA)).toMatchObject({
      size: 3, activeStudents: 2, activeRate: 67, completedTasks: 2, avgScore: 80, activeDelta: 1,
    });
    expect(JSON.stringify(act)).not.toContain(k1.childId);

    await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar', [classB]);
    const homeroom = await login(t.app, 'rahbar');
    expect((await call(homeroom, 'GET', '/activity')).json().classes.map((c: { classId: string }) => c.classId)).toEqual([classB]);
    expect((await call(homeroom, 'GET', `/activity?classId=${classA}`)).statusCode).toBe(403);
    await createStaff(t.prisma, schoolId, 'DUTY', 'navbatchi');
    expect((await call(await login(t.app, 'navbatchi'), 'GET', '/activity')).statusCode).toBe(403);

    const interests = (await call(director, 'GET', '/interests')).json();
    expect(interests).toEqual([{ grade: 7, shares: [{ subject: 'MATH', percent: 67 }, { subject: 'ENGLISH', percent: 33 }] }]);

    const dash = (await t.app.inject({ method: 'GET', url: '/api/school/dashboard/overview', headers: { authorization: `Bearer ${director.token}` } })).json();
    expect(dash.learning).toMatchObject({ activeStudents: 2, totalStudents: 3, completedTasks: 2, avgScore: 80, dueThisWeek: 0 });
  });

  it('materiallar: fan testlari va tasdiqlangan audiokitoblar', async () => {
    await t.prisma.audiobook.createMany({
      data: [
        { title: 'O‘tkan kunlar', author: 'Abdulla Qodiriy', audioUrl: 'x', status: 'approved', ageFrom: 13, ageTo: 18, durationSec: 3600 },
        { title: 'Qoralama', author: 'X', audioUrl: 'y', status: 'pending' },
      ],
    });
    const all = (await call(director, 'GET', '/materials')).json();
    expect(all.filter((m: { kind: string }) => m.kind === 'TEST')).toHaveLength(10);
    const book = all.find((m: { kind: string }) => m.kind === 'AUDIOBOOK');
    expect(book).toMatchObject({ subject: 'LITERATURE', durationMin: 60, title: 'O‘tkan kunlar — Abdulla Qodiriy' });
    expect(book.grades).toContain(7);
    expect(book.grades).not.toContain(3);
    const chem = (await call(director, 'GET', '/materials?subject=CHEMISTRY')).json();
    expect(chem[0]).toMatchObject({ id: 'test:CHEMISTRY', grades: [7, 8, 9, 10, 11] });
    expect((await call(director, 'GET', '/materials?grade=1&kind=TEST')).json().map((m: { id: string }) => m.id).sort()).toEqual(
      ['test:ENGLISH', 'test:MATH', 'test:NATIVE', 'test:RUSSIAN'],
    );
  });

  it('topshiriqlar: validatsiya, doira, audit va bola ilovasida "bajarildi"', async () => {
    const kid = await linkedKid(classA);
    const due = addDays(tashkentDay(), 3);
    // Topshiriq berish — administrator va sinf rahbari (direktorda `learning.assign` yo'q).
    expect((await call(director, 'POST', '/assignments', { materialId: 'test:MATH', classIds: [classA], dueDate: due })).statusCode).toBe(403);
    await createStaff(t.prisma, schoolId, 'ADMIN', 'admin');
    const admin = await login(t.app, 'admin');
    expect((await call(admin, 'POST', '/assignments', { materialId: 'test:MATH', classIds: [classA], dueDate: addDays(tashkentDay(), -1) })).json().message).toBe('dueDate: errors.form.invalidDate');
    expect((await call(admin, 'POST', '/assignments', { materialId: 'test:LATIN', classIds: [classA], dueDate: due })).json().message).toBe('materialId: errors.form.required');
    const other = await createSchool(t.prisma, 'other-school');
    const foreign = await createClass(t.prisma, other.school.id, 7, 'A');
    expect((await call(admin, 'POST', '/assignments', { materialId: 'test:MATH', classIds: [foreign.id], dueDate: due })).statusCode).toBe(400);

    await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar', [classA]);
    const homeroom = await login(t.app, 'rahbar');
    expect((await call(homeroom, 'POST', '/assignments', { materialId: 'test:MATH', classIds: [classB], dueDate: due })).statusCode).toBe(403);
    const created = await call(homeroom, 'POST', '/assignments', { materialId: 'test:MATH', classIds: [classA], dueDate: due, note: 'Har kuni' });
    expect(created.statusCode).toBe(201);
    const both = (await call(admin, 'POST', '/assignments', { materialId: 'test:ENGLISH', classIds: [classA, classB], dueDate: due })).json();

    const list = (await call(homeroom, 'GET', '/assignments')).json();
    expect(list).toHaveLength(2);
    expect(list.find((a: { id: string }) => a.id === both.id)).toMatchObject({ classNames: ['7-A'], canDelete: false, materialKind: 'TEST' });
    expect((await call(homeroom, 'DELETE', `/assignments/${both.id}`)).statusCode).toBe(403);
    expect(await t.prisma.schoolAuditLog.count({ where: { action: 'learning.assign' } })).toBe(2);

    const childList = async () =>
      (await t.app.inject({ method: 'GET', url: '/api/child/school/assignments', headers: { authorization: `Bearer ${kid.token}` } })).json();
    const before = await childList();
    expect(before.find((a: { subject: string }) => a.subject === 'MATH')).toMatchObject({ title: 'Kunlik test: Matematika', done: false, note: 'Har kuni' });
    await attempt(kid, tashkentDay(), 4);
    expect((await childList()).find((a: { subject: string }) => a.subject === 'MATH').done).toBe(true);

    expect((await call(admin, 'DELETE', `/assignments/${created.json().id}`)).statusCode).toBe(204);
    expect(await childList()).toHaveLength(1);
  });
});
