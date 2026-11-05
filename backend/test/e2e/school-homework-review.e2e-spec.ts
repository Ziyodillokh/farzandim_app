// Yozma vazifa (xodim tomoni): topshiriq bo'yicha o'quvchilar ro'yxati, qabul qilish / qaytarish,
// sinf doirasi va maktab izolyatsiyasi, hamda ma'lumotlarni o'chirish (topshiriq, bola profili).

import { ChildDataPurgeService } from '../../src/modules/child-data-purge/child-data-purge.service';
import { BUCKETS } from '../../src/common/storage/storage.constants';
import { resetDb } from './db';
import { createModerator, TestChild } from './factories';
import { at, DAY, seedWorld, setNow, World } from './school-attendance-fixtures';
import { appReq, createWritten, jpeg, linkNewChild, memoryStorage, MemoryStorage, schoolReq, submitHomework } from './school-child-fixtures';
import { createTestApp, TestApp } from './test-app';

const bucketKeys = (storage: MemoryStorage) => [...storage.objects.keys()].filter((k) => k.startsWith(`${BUCKETS.schoolHomework}/`));

describe('School homework: xodim tomoni va ma\'lumotlarni o\'chirish', () => {
  let t: TestApp;
  let storage: MemoryStorage;
  let w: World;
  let bekChild: TestChild;

  beforeAll(async () => {
    storage = memoryStorage();
    t = await createTestApp({ storage });
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    storage.objects.clear();
    w = await seedWorld(t);
    setNow(t, at(DAY, '09:00'));
    bekChild = await linkNewChild(t, w.bek);
  });

  afterAll(() => t.close());

  const submit = (assignmentId: string, token: string, count = 1, fields: Record<string, string> = {}) =>
    submitHomework(t, token, assignmentId, Array.from({ length: count }, (_, i) => ({ data: jpeg(`${token.slice(-6)}-${i}`) })), fields);
  const submissions = (s: World['admin'], assignmentId: string) => schoolReq(t, s, 'GET', `/learning/assignments/${assignmentId}/submissions`);
  const review = (s: World['admin'], id: string, body: object) => schoolReq(t, s, 'POST', `/learning/submissions/${id}/review`, body);

  describe('submissions list', () => {
    it('lists the students of the assigned classes with their submission (or null) and signed photo URLs', async () => {
      const a = await createWritten(t, w.admin, [w.classA, w.classB]);
      await submit(a.id, w.child.token, 2, { comment: 'Tayyor' });
      await t.prisma.schoolStudent.create({
        data: { schoolId: w.schoolId, classId: w.classA, lastName: 'Arxiv', firstName: 'Ali', gender: 'MALE', birthDate: '2013-01-01', studentCode: 'P-9001', enrolledAt: '2026-09-02', archived: true },
      });
      const classC = await t.prisma.schoolClass.create({ data: { schoolId: w.schoolId, grade: 9, letter: 'C', name: '9-C', shiftId: w.shiftId } });
      await t.prisma.schoolStudent.create({
        data: { schoolId: w.schoolId, classId: classC.id, lastName: 'Boshqa', firstName: 'Sinf', gender: 'MALE', birthDate: '2013-01-01', studentCode: 'P-9002', enrolledAt: '2026-09-02' },
      });

      const res = await submissions(w.admin, a.id);

      expect(res.statusCode).toBe(200);
      const body = res.json();
      expect(body.assignment).toMatchObject({ id: a.id, title: 'Masala 5', dueDate: '2099-01-01', estimatedMinutes: 30, classIds: [w.classA, w.classB] });
      expect(body.counts).toEqual({ total: 3, submitted: 1, accepted: 0, returned: 0, missing: 2 });
      expect(body.students.map((s: { name: string; className: string }) => [s.className, s.name])).toEqual([
        ['7-A', 'Aliyev Vali'],
        ['7-A', 'Karimova Malika'],
        ['8-B', 'Rasulov Bek'],
      ]);
      const vali = body.students[0];
      expect(vali.submission).toMatchObject({ status: 'SUBMITTED', comment: 'Tayyor', reviewedByStaffId: null });
      expect(vali.submission.photos).toHaveLength(2);
      expect(body.students[1].submission).toBeNull();
      const photo = await t.app.inject({ method: 'GET', url: new URL(vali.submission.photos[0].url).pathname + new URL(vali.submission.photos[0].url).search });
      expect(photo.statusCode).toBe(200);
    });

    it('scopes by role: HOMEROOM sees only own classes, DIRECTOR and ADMIN everything, others denied', async () => {
      const both = await createWritten(t, w.admin, [w.classA, w.classB]);
      const onlyB = await createWritten(t, w.admin, [w.classB]);
      await submit(both.id, w.child.token);
      await submit(both.id, bekChild.token);

      const own = (await submissions(w.homeroom, both.id)).json();
      expect(own.assignment.classIds).toEqual([w.classA]);
      expect(own.students.map((s: { name: string }) => s.name)).toEqual(['Aliyev Vali', 'Karimova Malika']);
      expect(JSON.stringify(own)).not.toContain('Rasulov');
      expect((await submissions(w.homeroom, onlyB.id)).statusCode).toBe(403);

      expect((await submissions(w.director, both.id)).json().students).toHaveLength(3);
      expect((await submissions(w.admin, onlyB.id)).json().students).toHaveLength(1);
      for (const denied of [w.teacher, w.duty, w.psych]) expect((await submissions(denied, both.id)).statusCode).toBe(403);
      expect((await t.app.inject({ method: 'GET', url: `/api/school/learning/assignments/${both.id}/submissions` })).statusCode).toBe(401);
    });

    it('404 for TEST assignments, unknown ids and other schools', async () => {
      const other = await seedWorld(t, 'other-school');
      const test = (await schoolReq(t, w.admin, 'POST', '/learning/assignments', { materialId: 'test:MATH', classIds: [w.classA], dueDate: '2099-01-01' })).json();
      const written = await createWritten(t, w.admin, [w.classA]);

      expect((await submissions(w.admin, test.id)).statusCode).toBe(404);
      expect((await submissions(w.admin, 'no-such-id')).statusCode).toBe(404);
      expect((await submissions(other.admin, written.id)).statusCode).toBe(404);
    });
  });

  describe('review', () => {
    async function submitted() {
      const a = await createWritten(t, w.admin, [w.classA, w.classB]);
      const mine = (await submit(a.id, w.child.token, 2)).json();
      const bek = (await submit(a.id, bekChild.token)).json();
      return { a, mine, bek };
    }

    it('accepts with a note: status, reviewer and time stored, photos kept, audit written', async () => {
      const { a, mine } = await submitted();

      const res = await review(w.admin, mine.id, { status: 'ACCEPTED', note: '  Barakalla  ' });

      expect(res.statusCode).toBe(200);
      expect(res.json()).toMatchObject({ id: mine.id, assignmentId: a.id, status: 'ACCEPTED', reviewNote: 'Barakalla', reviewedByStaffId: w.admin.staffId });
      expect(res.json().reviewedAt).toEqual(expect.any(String));
      expect(res.json().photos).toHaveLength(2);
      const log = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'homework.review' } });
      expect(log).toMatchObject({ module: 'LEARNING', entityId: mine.id, actorId: w.admin.staffId });
      expect(JSON.stringify(log)).not.toContain('Barakalla');
    });

    it('returns with and without a note, and a returned submission can be re-reviewed', async () => {
      const { mine } = await submitted();

      expect((await review(w.admin, mine.id, { status: 'RETURNED' })).json()).toMatchObject({ status: 'RETURNED', reviewNote: null });
      expect((await review(w.admin, mine.id, { status: 'RETURNED', note: 'Aniqroq' })).json()).toMatchObject({ reviewNote: 'Aniqroq' });
      expect((await review(w.admin, mine.id, { status: 'ACCEPTED' })).json()).toMatchObject({ status: 'ACCEPTED', reviewNote: null });
      expect((await submissions(w.admin, mine.assignmentId)).json().counts).toMatchObject({ accepted: 1, submitted: 1 });
    });

    it('validates the body', async () => {
      const { mine } = await submitted();

      expect((await review(w.admin, mine.id, { status: 'SUBMITTED' })).statusCode).toBe(400);
      expect((await review(w.admin, mine.id, {})).statusCode).toBe(400);
      expect((await review(w.admin, mine.id, { status: 'ACCEPTED', note: 'x'.repeat(501) })).json()).toMatchObject({ message: 'note: errors.form.tooLong' });
      expect((await review(w.admin, mine.id, { status: 'ACCEPTED', note: 'x'.repeat(500) })).statusCode).toBe(200);
    });

    it('enforces permission and class scope', async () => {
      const { mine, bek } = await submitted();

      expect((await review(w.homeroom, mine.id, { status: 'ACCEPTED' })).statusCode).toBe(200);
      expect((await review(w.homeroom, bek.id, { status: 'ACCEPTED' })).statusCode).toBe(403);
      expect((await review(w.director, mine.id, { status: 'ACCEPTED' })).statusCode).toBe(403); // learning.assign yo'q
      for (const denied of [w.teacher, w.duty, w.psych]) expect((await review(denied, mine.id, { status: 'ACCEPTED' })).statusCode).toBe(403);
      expect(await t.prisma.schoolHomeworkSubmission.count({ where: { id: bek.id, status: 'SUBMITTED' } })).toBe(1);
    });

    it('isolates schools and ignores unknown or non-written ids', async () => {
      const other = await seedWorld(t, 'other-school');
      const { mine } = await submitted();

      expect((await review(other.admin, mine.id, { status: 'ACCEPTED' })).statusCode).toBe(404);
      expect((await review(w.admin, 'no-such-id', { status: 'ACCEPTED' })).statusCode).toBe(404);
      expect(await t.prisma.schoolHomeworkSubmission.count({ where: { id: mine.id, status: 'SUBMITTED' } })).toBe(1);
    });

    it('a re-submission after RETURNED goes back to SUBMITTED and clears the review', async () => {
      const { a, mine } = await submitted();
      await review(w.admin, mine.id, { status: 'RETURNED', note: 'Qayta' });

      await submit(a.id, w.child.token, 1, { requestId: 'c0ffee00-1111-4222-8333-444455556666' });

      const row = (await submissions(w.admin, a.id)).json().students[0].submission;
      expect(row).toMatchObject({ id: mine.id, status: 'SUBMITTED', reviewNote: null, reviewedAt: null, reviewedByStaffId: null });
    });
  });

  describe('data deletion', () => {
    it('deleting an assignment removes its submissions and photo objects, nothing else', async () => {
      const a = await createWritten(t, w.admin, [w.classA]);
      const keep = await createWritten(t, w.admin, [w.classA], { title: 'Qoladi' });
      await submit(a.id, w.child.token, 2);
      await submit(keep.id, w.child.token, 1);
      expect(bucketKeys(storage)).toHaveLength(3);

      const res = await schoolReq(t, w.admin, 'DELETE', `/learning/assignments/${a.id}`);

      expect(res.statusCode).toBe(204);
      expect(await t.prisma.schoolHomeworkSubmission.count()).toBe(1);
      expect(await t.prisma.schoolHomeworkPhoto.count()).toBe(1);
      expect(bucketKeys(storage)).toHaveLength(1);
    });

    it("purging the parent's child profile deletes that child's submissions and objects only", async () => {
      const a = await createWritten(t, w.admin, [w.classA, w.classB]);
      await submit(a.id, w.child.token, 2);
      await submit(a.id, bekChild.token, 1);
      const purge = t.app.get(ChildDataPurgeService, { strict: false });
      const child = await t.prisma.child.findUniqueOrThrow({ where: { id: w.child.childId } });

      await purge.purgeChildProfile({ id: child.id, parentId: child.parentId, name: child.name, childUserId: child.childUserId, photoPath: child.photoPath });

      expect(await t.prisma.schoolHomeworkSubmission.count({ where: { studentId: w.vali } })).toBe(0);
      expect(await t.prisma.schoolHomeworkSubmission.count({ where: { studentId: w.bek } })).toBe(1);
      expect(bucketKeys(storage)).toHaveLength(1);
      expect(await t.prisma.schoolStudent.findUniqueOrThrow({ where: { id: w.vali } })).toMatchObject({ childId: null });
    });

    it("a parent deleting their account deletes their children's submissions and objects (other families untouched)", async () => {
      const a = await createWritten(t, w.admin, [w.classA, w.classB]);
      await submit(a.id, w.child.token, 2);
      await submit(a.id, bekChild.token, 1);

      const res = await appReq(t, w.parent.token, 'DELETE', '/users/me');

      expect(res.statusCode).toBe(200);
      expect(await t.prisma.schoolHomeworkSubmission.count({ where: { studentId: w.vali } })).toBe(0);
      expect(await t.prisma.schoolHomeworkSubmission.count({ where: { studentId: w.bek } })).toBe(1);
      expect(bucketKeys(storage)).toHaveLength(1);
    });

    it("an admin hard-deleting a parent or a child device user removes the linked child's submissions and objects", async () => {
      const moderator = await createModerator(t.prisma, ['manage_users']);
      const a = await createWritten(t, w.admin, [w.classA, w.classB]);
      await submit(a.id, w.child.token, 2);
      await submit(a.id, bekChild.token, 1);
      const del = (userId: string) =>
        t.app.inject({ method: 'DELETE', url: `/api/admin/users/${userId}`, headers: { authorization: `Bearer ${moderator.token}` } });

      expect((await del(w.parent.userId)).statusCode).toBe(200);
      expect(await t.prisma.schoolHomeworkSubmission.count({ where: { studentId: w.vali } })).toBe(0);
      expect(bucketKeys(storage)).toHaveLength(1);

      expect((await del(bekChild.userId)).statusCode).toBe(200);
      expect(await t.prisma.schoolHomeworkSubmission.count()).toBe(0);
      expect(bucketKeys(storage)).toHaveLength(0);
    });

    it('the child deleting their own account deletes their submissions and objects, keeps the student record', async () => {
      const a = await createWritten(t, w.admin, [w.classA, w.classB]);
      await submit(a.id, w.child.token, 2);
      await submit(a.id, bekChild.token, 1);
      const purge = t.app.get(ChildDataPurgeService, { strict: false });

      await purge.deleteChildAccount(w.child.userId);

      expect(await t.prisma.schoolHomeworkSubmission.count({ where: { studentId: w.vali } })).toBe(0);
      expect(await t.prisma.schoolHomeworkSubmission.count({ where: { studentId: w.bek } })).toBe(1);
      expect(bucketKeys(storage)).toHaveLength(1);
      expect(await t.prisma.schoolStudent.findUnique({ where: { id: w.vali } })).not.toBeNull();
    });
  });
});
