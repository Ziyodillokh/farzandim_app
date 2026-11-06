// Kirish (K1): SCHOOL kanalidagi tiklash so'rovi maktab xodimlariga saqlangan bildirishnoma sifatida boradi — FAQAT ish qila
// oladiganlarga: o'quvchining maktabidagi FAOL xodimlar, `students.manage` ruxsatiga ega va doirasi o'quvchini qamraydi
// (DIRECTOR, ADMIN; sinf rahbari — faqat unga `students.manage` berilgan bo'lsa). Hech kim mos kelmasa — direktor(lar)ga.
// Lenta elementi `href` bilan aniq o'quvchi kartasining «Kirish» bo'limini ochadi (bir xil ismli o'quvchilar adashmaydi).

import { SchoolStaffRole } from '@prisma/client';
import { ChildRecoveryService } from '../../src/modules/child-auth/child-recovery.service';
import { resetDb } from './db';
import { createChild } from './factories';
import { api, issueAsParent, IssuedCredential, patchRolePermissions, restoreClock } from './kirish-fixtures';
import { seedWorld, staffSession, World } from './school-attendance-fixtures';
import { schoolReq } from './school-child-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('Kirish K1: tiklash so\'rovi — maktab xodimlariga bildirishnoma', () => {
  let t: TestApp;
  let w: World;
  let cred: IssuedCredential;
  let testSeq = 0;
  const restores: Array<() => void> = [];

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    w = await seedWorld(t);
    // Har testga o'z logini: kunlik limit (3/login) throttler xotirasida testlar orasida yig'ilmasin.
    cred = await issueAsParent(t, w.parent, w.child.childId, { login: `notify.t${(testSeq += 1)}` });
  });

  afterEach(() => {
    while (restores.length) restores.pop()!();
    jest.restoreAllMocks();
    restoreClock(t);
  });

  afterAll(() => t.close());

  const grant = (role: SchoolStaffRole, change: { add?: string[]; remove?: string[] }) => restores.push(patchRolePermissions(role, change));
  const requestSchool = async (login = cred.login) => {
    const res = await api(t, 'POST', '/auth/child-recovery', { payload: { login, channel: 'SCHOOL' } });
    expect(res.statusCode).toBe(202);
    await t.app.get(ChildRecoveryService).drainEffects();
    return res.json() as { requestId: string; pollToken: string };
  };
  const stored = () => t.prisma.schoolStaffNotification.findMany({ where: { kind: 'CHILD_RECOVERY_REQUEST' } });
  const feed = async (s: World['director']) => {
    const res = await schoolReq(t, s, 'GET', '/notifications/feed');
    expect(res.statusCode).toBe(200);
    return (res.json() as Array<{ kind: string; params: Record<string, unknown>; subject: unknown; href: unknown; tone: string }>).filter(
      (n) => n.kind === 'CHILD_RECOVERY_REQUEST',
    );
  };
  const detail = (s: World['director'], studentId = w.vali) => schoolReq(t, s, 'GET', `/students/${studentId}`);
  const sorted = (values: readonly string[]) => [...values].sort();
  /** Panelga nisbatan yo'l (boshqa lenta turlari kabi `/school` prefiksisiz). */
  const accessHref = (studentId: string) => `/students/view?id=${studentId}&tab=access`;

  it('stores one notification for the staff who hold students.manage (DIRECTOR and ADMIN), with only the student name and class', async () => {
    const r = await requestSchool();

    const rows = await stored();
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({
      id: `child-recovery:${r.requestId}`,
      schoolId: w.schoolId,
      kind: 'CHILD_RECOVERY_REQUEST',
      classIds: [w.classA],
      params: { studentName: 'Aliyev Vali', className: '7-A' },
      subject: null,
      href: accessHref(w.vali),
    });
    expect(sorted(rows[0]!.roles)).toEqual(['ADMIN', 'DIRECTOR']);
    expect(sorted(rows[0]!.staffIds)).toEqual(sorted([w.director.staffId, w.admin.staffId]));
    expect(Object.keys(rows[0]!.params as object).sort()).toEqual(['className', 'studentName']);
    expect(JSON.stringify(rows[0])).not.toContain(w.child.childId);
    expect(JSON.stringify(rows[0])).not.toContain(cred.login);
    expect(t.fcm.sent.filter((p) => p.payload.data?.type === 'CHILD_RECOVERY_REQUEST')).toEqual([]);
  });

  it('shows up in the feed of the director and the administrator, with the warning tone and the student card link', async () => {
    await requestSchool();

    for (const session of [w.director, w.admin]) {
      const items = await feed(session);
      expect(items).toHaveLength(1);
      expect(items[0]).toMatchObject({
        params: { studentName: 'Aliyev Vali', className: '7-A' },
        subject: null,
        href: `/students/view?id=${w.vali}&tab=access`,
        tone: 'warning',
      });
      expect(Object.keys(items[0]!.params).sort()).toEqual(['className', 'studentName']);
    }
  });

  it('the link names the exact student: a second student with the same name and class gets a different link', async () => {
    const twin = await t.prisma.schoolStudent.create({
      data: {
        schoolId: w.schoolId,
        classId: w.classA,
        lastName: 'Aliyev',
        firstName: 'Vali',
        gender: 'MALE',
        birthDate: '2014-03-03',
        studentCode: 'P-9999',
        enrolledAt: '2026-09-01',
      },
    });
    const twinChild = await createChild(t.prisma, w.parent, { name: 'Aliyev Vali' });
    await t.prisma.schoolStudent.update({ where: { id: twin.id }, data: { childId: twinChild.childId } });
    const twinCred = await issueAsParent(t, w.parent, twinChild.childId, { login: `twin.t${testSeq}` });

    await requestSchool();
    await requestSchool(twinCred.login);

    const items = await feed(w.director);
    expect(items.map((n) => n.href).sort()).toEqual([accessHref(w.vali), accessHref(twin.id)].sort());
    for (const n of items) expect(n.params).toEqual({ studentName: 'Aliyev Vali', className: '7-A' });
  });

  it("a homeroom teacher WITHOUT students.manage gets nothing (not even for their own class)", async () => {
    await requestSchool();

    const [row] = await stored();
    expect(row!.staffIds).not.toContain(w.homeroom.staffId);
    expect(row!.roles).not.toContain('HOMEROOM');
    expect(await feed(w.homeroom)).toHaveLength(0);
    for (const session of [w.duty, w.teacher, w.psych]) expect(await feed(session)).toHaveLength(0);
  });

  it('a homeroom teacher WITH students.manage gets the notification for their own class — and only for their own class', async () => {
    grant('HOMEROOM', { add: ['students.manage'] });
    const otherHomeroom = await staffSession(t, w.schoolId, 'HOMEROOM', 'homeroom-b', [w.classB]);

    await requestSchool();

    const [row] = await stored();
    expect(sorted(row!.roles)).toEqual(['ADMIN', 'DIRECTOR', 'HOMEROOM']);
    expect(sorted(row!.staffIds)).toEqual(sorted([w.director.staffId, w.admin.staffId, w.homeroom.staffId]));
    const items = await feed(w.homeroom);
    expect(items).toHaveLength(1);
    expect(items[0]).toMatchObject({ params: { studentName: 'Aliyev Vali', className: '7-A' }, tone: 'warning' });
    expect(await feed(otherHomeroom)).toHaveLength(0);
    expect(await feed(w.director)).toHaveLength(1);
    expect(await feed(w.admin)).toHaveLength(1);
  });

  it('follows the permission matrix, not role names: any role granted students.manage whose scope covers the class is notified', async () => {
    grant('TEACHER', { add: ['students.manage'] });
    const teacherOfA = await staffSession(t, w.schoolId, 'TEACHER', 'teacher-a', [w.classA]);

    await requestSchool();

    const [row] = await stored();
    expect(row!.staffIds).toContain(teacherOfA.staffId);
    expect(row!.staffIds).not.toContain(w.teacher.staffId); // 8-B sinf o'qituvchisi
    expect(await feed(teacherOfA)).toHaveLength(1);
    expect(await feed(w.teacher)).toHaveLength(0);
  });

  it('a student without a class is covered only by whole-school roles, even if the homeroom role holds students.manage', async () => {
    grant('HOMEROOM', { add: ['students.manage'] });
    await t.prisma.schoolStudent.update({ where: { id: w.vali }, data: { classId: null } });

    await requestSchool();

    const [row] = await stored();
    expect(sorted(row!.roles)).toEqual(['ADMIN', 'DIRECTOR']);
    expect(sorted(row!.staffIds)).toEqual(sorted([w.director.staffId, w.admin.staffId]));
    expect(row).toMatchObject({ classIds: [], params: { studentName: 'Aliyev Vali', className: '' } });
    expect(await feed(w.homeroom)).toHaveLength(0);
    expect(await feed(w.admin)).toHaveLength(1);
  });

  it('skips inactive staff', async () => {
    await t.prisma.schoolStaff.update({ where: { id: w.admin.staffId }, data: { active: false } });

    await requestSchool();

    const [row] = await stored();
    expect(row!.staffIds).toEqual([w.director.staffId]);
    expect(row!.roles).toEqual(['DIRECTOR']);
  });

  it('falls back to the director(s) when nobody holds students.manage', async () => {
    grant('DIRECTOR', { remove: ['students.manage'] });
    grant('ADMIN', { remove: ['students.manage'] });

    await requestSchool();

    const [row] = await stored();
    expect(row).toMatchObject({ roles: ['DIRECTOR'], staffIds: [], classIds: [w.classA], params: { studentName: 'Aliyev Vali', className: '7-A' } });
    expect(await feed(w.director)).toHaveLength(1);
    expect(await feed(w.admin)).toHaveLength(0);
    expect(await feed(w.homeroom)).toHaveLength(0);
  });

  it("does not notify another school's staff", async () => {
    const other = await seedWorld(t, 'other-school');

    await requestSchool();

    const [row] = await stored();
    expect(row!.staffIds).not.toContain(other.admin.staffId);
    expect(row!.staffIds).not.toContain(other.director.staffId);
    expect(await feed(other.admin)).toHaveLength(0);
    expect(await feed(other.director)).toHaveLength(0);
  });

  describe("o'quvchi kartasi va rad etish: xuddi shu doira", () => {
    it('the student detail lists the open school requests only for staff who can answer them', async () => {
      const r = await requestSchool();

      for (const session of [w.director, w.admin]) {
        expect((await detail(session)).json().recoveryRequests).toEqual([
          { id: r.requestId, channel: 'SCHOOL', status: 'RECEIVED', createdAt: expect.any(String) },
        ]);
      }
      expect((await detail(w.homeroom)).statusCode).toBe(200);
      expect((await detail(w.homeroom)).json().recoveryRequests).toEqual([]);
      expect((await detail(w.psych)).json().recoveryRequests).toEqual([]);
    });

    it('a homeroom teacher with students.manage sees the request on the card and can reject it for their own class only', async () => {
      grant('HOMEROOM', { add: ['students.manage'] });
      const r = await requestSchool();

      expect((await detail(w.homeroom)).json().recoveryRequests).toHaveLength(1);
      const rejected = await schoolReq(t, w.homeroom, 'POST', `/students/${w.vali}/recovery-requests/${r.requestId}/reject`);
      expect(rejected.statusCode).toBe(200);
      expect(rejected.json()).toMatchObject({ id: r.requestId, status: 'REJECTED' });
      expect(await stored()).toEqual([]);

      // Boshqa sinf o'quvchisi uchun doiradan tashqari.
      const other = await schoolReq(t, w.homeroom, 'POST', `/students/${w.bek}/recovery-requests/${r.requestId}/reject`);
      expect(other.statusCode).toBe(403);
    });

    it('a homeroom teacher without students.manage cannot reject', async () => {
      const r = await requestSchool();

      const res = await schoolReq(t, w.homeroom, 'POST', `/students/${w.vali}/recovery-requests/${r.requestId}/reject`);

      expect(res.statusCode).toBe(403);
      expect((await t.prisma.childRecoveryRequest.findUniqueOrThrow({ where: { id: r.requestId } })).status).toBe('RECEIVED');
    });
  });
});
