// Yozma vazifa topshirig'i: xodim yaratishi (WRITTEN, sarlavha, taxminiy vaqt) va bola ro'yxatidagi
// yangi maydonlar (title, estimatedMinutes, teacherName, materialKind, submission, done).

import { resetDb } from './db';
import { TestChild } from './factories';
import { at, DAY, seedWorld, setNow, World } from './school-attendance-fixtures';
import { appReq, createWritten, jpeg, linkNewChild, schoolReq, submitHomework, unlinkedChild } from './school-child-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School homework: topshiriqlar va bola ro\'yxati', () => {
  let t: TestApp;
  let w: World;
  let bekChild: TestChild;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    w = await seedWorld(t);
    setNow(t, at(DAY, '09:00'));
    bekChild = await linkNewChild(t, w.bek);
  });

  afterAll(() => t.close());

  const submit = (assignmentId: string, files: Parameters<typeof submitHomework>[3], fields: Record<string, string> = {}, token = w.child.token) =>
    submitHomework(t, token, assignmentId, files, fields);
  const list = (token = w.child.token) => appReq(t, token, 'GET', '/child/school/assignments');

  describe('staff creates a written assignment', () => {
    it('stores title and estimated minutes, lists them and writes an audit entry', async () => {
      const res = await schoolReq(t, w.admin, 'POST', '/learning/assignments', {
        materialId: 'written',
        title: '  Masala 5, 6, 7  ',
        estimatedMinutes: 25,
        classIds: [w.classA],
        dueDate: '2099-01-01',
        note: 'Daftarga',
      });

      expect(res.statusCode).toBe(201);
      expect(res.json()).toMatchObject({ materialId: 'written', materialKind: 'WRITTEN', title: 'Masala 5, 6, 7', estimatedMinutes: 25 });
      const row = await t.prisma.schoolLearningAssignment.findUniqueOrThrow({ where: { id: res.json().id } });
      expect(row).toMatchObject({ materialKind: 'WRITTEN', materialId: 'written', title: 'Masala 5, 6, 7', estimatedMinutes: 25 });

      const mine = (await schoolReq(t, w.admin, 'GET', '/learning/assignments')).json();
      expect(mine[0]).toMatchObject({ materialKind: 'WRITTEN', materialTitle: 'Masala 5, 6, 7', title: 'Masala 5, 6, 7', estimatedMinutes: 25, subject: null, classNames: ['7-A'] });
      expect(await t.prisma.schoolAuditLog.count({ where: { action: 'learning.assign', entityId: row.id } })).toBe(1);
    });

    it('accepts materialKind WRITTEN without materialId', async () => {
      const res = await schoolReq(t, w.admin, 'POST', '/learning/assignments', {
        materialKind: 'WRITTEN',
        title: 'Insho',
        classIds: [w.classA],
        dueDate: '2099-01-01',
      });

      expect(res.statusCode).toBe(201);
      expect(res.json()).toMatchObject({ materialId: 'written', estimatedMinutes: null });
    });

    it('validates: title required for WRITTEN, 1-240 minutes, scope and permission', async () => {
      const post = (body: object, s = w.admin) => schoolReq(t, s, 'POST', '/learning/assignments', { classIds: [w.classA], dueDate: '2099-01-01', ...body });

      expect((await post({ materialId: 'written' })).json()).toMatchObject({ code: 'VALIDATION', message: 'title: errors.form.required' });
      expect((await post({ materialId: 'written', title: '   ' })).statusCode).toBe(400);
      expect((await post({ materialId: 'written', title: 'x'.repeat(121) })).statusCode).toBe(400);
      expect((await post({ materialId: 'written', title: 'ok', estimatedMinutes: 0 })).statusCode).toBe(400);
      expect((await post({ materialId: 'written', title: 'ok', estimatedMinutes: 241 })).statusCode).toBe(400);
      expect((await post({ materialId: 'written', title: 'ok', estimatedMinutes: 240 })).statusCode).toBe(201);
      expect((await post({ materialKind: 'WRITTEN', materialId: 'test:MATH', title: 'ok' })).statusCode).toBe(400);
      expect((await post({ materialId: 'written', title: 'ok', dueDate: '2020-01-01' })).statusCode).toBe(400);
      expect((await post({})).json()).toMatchObject({ message: 'materialId: errors.form.required' });

      expect((await post({ materialId: 'written', title: 'ok' }, w.homeroom)).statusCode).toBe(201);
      expect((await post({ materialId: 'written', title: 'ok', classIds: [w.classB] }, w.homeroom)).statusCode).toBe(403);
      expect((await post({ materialId: 'written', title: 'ok' }, w.director)).statusCode).toBe(403);
    });

    it('TEST assignments are unchanged; estimatedMinutes is allowed on any kind, a title is ignored', async () => {
      const res = await schoolReq(t, w.admin, 'POST', '/learning/assignments', {
        materialId: 'test:MATH',
        title: 'Boshqa nom',
        estimatedMinutes: 10,
        classIds: [w.classA],
        dueDate: '2099-01-01',
      });

      expect(res.statusCode).toBe(201);
      const row = await t.prisma.schoolLearningAssignment.findUniqueOrThrow({ where: { id: res.json().id } });
      expect(row).toMatchObject({ materialKind: 'TEST', materialId: 'test:MATH', title: null, estimatedMinutes: 10 });
    });
  });

  describe('child assignment list', () => {
    it('adds title, estimatedMinutes, teacherName, materialKind and submission (WRITTEN only)', async () => {
      const written = await createWritten(t, w.admin, [w.classA]);
      await schoolReq(t, w.admin, 'POST', '/learning/assignments', { materialId: 'test:MATH', classIds: [w.classA], dueDate: '2099-01-01' });

      const items = (await list()).json();
      const w1 = items.find((i: { id: string }) => i.id === written.id);
      const test = items.find((i: { materialId: string }) => i.materialId === 'test:MATH');

      expect(w1).toMatchObject({
        kind: 'WRITTEN',
        materialKind: 'WRITTEN',
        title: 'Masala 5',
        estimatedMinutes: 30,
        teacherName: 'ADMIN xodim',
        subject: null,
        note: 'Daftarga yozing',
        overdue: false,
        done: false,
        submission: null,
      });
      expect(test).toMatchObject({ kind: 'TEST', materialKind: 'TEST', title: 'Kunlik test: Matematika', estimatedMinutes: null, teacherName: 'ADMIN xodim', subject: 'MATH', submission: null });
      expect(test.done).toBe(false);
    });

    it("reflects the child's own submission and done only after ACCEPTED", async () => {
      const a = await createWritten(t, w.admin, [w.classA]);
      await submit(a.id, [{ data: jpeg('1') }, { data: jpeg('2') }]);

      let item = (await list()).json()[0];
      expect(item.submission).toMatchObject({ status: 'SUBMITTED', photoCount: 2, reviewedAt: null, reviewNote: null });
      expect(item.submission.submittedAt).toEqual(expect.any(String));
      expect(item.done).toBe(false);

      const sub = await t.prisma.schoolHomeworkSubmission.findFirstOrThrow({ where: { assignmentId: a.id } });
      expect((await schoolReq(t, w.admin, 'POST', `/learning/submissions/${sub.id}/review`, { status: 'ACCEPTED', note: 'Zo\'r' })).statusCode).toBe(200);

      item = (await list()).json()[0];
      expect(item.submission).toMatchObject({ status: 'ACCEPTED', reviewNote: 'Zo\'r' });
      expect(item.submission.reviewedAt).toEqual(expect.any(String));
      expect(item.done).toBe(true);
    });

    it("shows only the child's class assignments, never other classes or schools", async () => {
      const other = await seedWorld(t, 'other-school');
      await createWritten(t, w.admin, [w.classB], { title: '8-B uchun' });
      await createWritten(t, other.admin, [other.classA], { title: 'Boshqa maktab' });
      await createWritten(t, w.admin, [w.classA, w.classB], { title: 'Ikkalasi' });

      expect((await list()).json().map((i: { title: string }) => i.title)).toEqual(['Ikkalasi']);
      expect((await list(bekChild.token)).json().map((i: { title: string }) => i.title).sort()).toEqual(['8-B uchun', 'Ikkalasi']);
    });

    it('stays an empty list for a child without a school (existing behaviour)', async () => {
      const lonely = await unlinkedChild(t);

      expect((await list(lonely.token)).json()).toEqual([]);
    });
  });
});
