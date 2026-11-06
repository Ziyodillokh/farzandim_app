// Kirish (K1): maktab xodimi o'quvchining bola ilovasi kirish maʼlumotlarini beradi / qayta tiklaydi
// (`/school/students/:studentId/credentials`): ruxsat (`students.manage`), sinf doirasi, maktab izolyatsiyasi,
// faqat Parvoz bola profiliga bog'langan o'quvchi (409 NOT_LINKED), audit (parolsiz) va oqibatlari.

import { ChildRecoveryService } from '../../src/modules/child-auth/child-recovery.service';
import { SCHOOL_ROLES } from '../../src/school/auth/permissions';
import { resetDb } from './db';
import { createChild } from './factories';
import {
  api,
  captureRealtime,
  dbContains,
  loginThroughSetup,
  restoreClock,
} from './kirish-fixtures';
import { seedWorld, World } from './school-attendance-fixtures';
import { schoolReq } from './school-child-fixtures';
import { createTestApp, TestApp } from './test-app';

const TEMP_PASSWORD = /^[abcdefghjkmnpqrstuvwxyz23456789]{8}$/;

describe('Kirish K1: maktab — o\'quvchi kirish maʼlumotlari', () => {
  let t: TestApp;
  let w: World;
  let rt: ReturnType<typeof captureRealtime>;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    w = await seedWorld(t);
    rt = captureRealtime(t);
  });

  afterEach(() => {
    jest.restoreAllMocks();
    restoreClock(t);
  });

  afterAll(() => t.close());

  const url = (childId = w.child.childId) => `/children/${childId}/credentials`;
  const get = (token = w.parent.token, childId?: string) => api(t, 'GET', url(childId), { token });
  const credentialRow = (childId = w.child.childId) => t.prisma.childCredential.findUniqueOrThrow({ where: { childId } });

  describe('GET/POST /school/students/:studentId/credentials', () => {
    const sUrl = (studentId = w.vali) => `/students/${studentId}/credentials`;

    it('DIRECTOR and ADMIN can issue and read (same shapes as the parent)', async () => {
      for (const [session, studentId] of [
        [w.director, w.vali],
        [w.admin, w.vali],
      ] as const) {
        expect((await schoolReq(t, session, 'GET', sUrl(studentId))).statusCode).toBe(200);
      }

      const issued = await schoolReq(t, w.director, 'POST', sUrl(), {});

      expect(issued.statusCode).toBe(201);
      const body = issued.json();
      expect(Object.keys(body).sort()).toEqual(['issuedAt', 'login', 'temporaryPassword']);
      expect(body.login).toMatch(/^vali\.a\d{2}$/);
      expect(body.temporaryPassword).toMatch(TEMP_PASSWORD);
      expect(issued.headers['cache-control']).toBe('no-store');

      const view = await schoolReq(t, w.admin, 'GET', sUrl());
      expect(view.json()).toEqual({
        login: body.login,
        issuedBy: 'SCHOOL',
        issuedAt: body.issuedAt,
        mustChangePassword: true,
        lastLoginAt: null,
      });
      // Ota-ona ham xuddi shu maʼlumotni ko'radi.
      expect((await get()).json()).toEqual(view.json());
    });

    it('builds the suggestion from the student first name and last initial', async () => {
      const res = await schoolReq(t, w.director, 'POST', sUrl(), {});

      expect(res.json().login).toMatch(/^vali\.a\d{2}$/);
    });

    it('records the issuing staff member and the school issuer', async () => {
      await schoolReq(t, w.admin, 'POST', sUrl(), {});

      expect(await credentialRow()).toMatchObject({
        issuedBy: 'SCHOOL',
        issuedByStaffId: w.admin.staffId,
        issuedByUserId: null,
      });
    });

    it.each(['homeroom', 'duty', 'teacher', 'psych'] as const)('%s gets 403 (no students.manage) on GET and POST', async (key) => {
      expect((await schoolReq(t, w[key], 'GET', sUrl())).statusCode).toBe(403);
      expect((await schoolReq(t, w[key], 'POST', sUrl(), {})).statusCode).toBe(403);
      expect(await t.prisma.childCredential.count()).toBe(0);
    });

    it('requires a staff token', async () => {
      expect((await t.app.inject({ method: 'GET', url: `/api/school${sUrl()}` })).statusCode).toBe(401);
      expect((await t.app.inject({ method: 'POST', url: `/api/school${sUrl()}`, payload: {} })).statusCode).toBe(401);
    });

    it('answers 409 NOT_LINKED for a student without a Parvoz child profile (GET and POST) and creates nothing', async () => {
      for (const method of ['GET', 'POST'] as const) {
        const res = await schoolReq(t, w.director, method, sUrl(w.malika), method === 'POST' ? {} : undefined);
        expect(res.statusCode).toBe(409);
        expect(res.json()).toMatchObject({ statusCode: 409, code: 'NOT_LINKED' });
      }
      expect(await t.prisma.childCredential.count()).toBe(0);
    });

    it('answers 404 for a student of another school and for an unknown id', async () => {
      const other = await seedWorld(t, 'other-school');

      expect((await schoolReq(t, w.director, 'GET', sUrl(other.vali))).statusCode).toBe(404);
      expect((await schoolReq(t, w.director, 'POST', sUrl(other.vali), {})).statusCode).toBe(404);
      expect((await schoolReq(t, w.director, 'GET', sUrl('00000000-0000-4000-8000-000000000000'))).statusCode).toBe(404);
      expect(await t.prisma.childCredential.count()).toBe(0);
    });

    it('a staff member of another school cannot touch this school student either', async () => {
      const other = await seedWorld(t, 'other-school');

      expect((await schoolReq(t, other.director, 'POST', sUrl(w.vali), {})).statusCode).toBe(404);
      expect((await schoolReq(t, other.director, 'GET', sUrl(w.vali))).statusCode).toBe(404);
    });

    it('does not issue for an archived student (409 STUDENT_ARCHIVED) but still shows the existing credential', async () => {
      await schoolReq(t, w.director, 'POST', sUrl(), {});
      await t.prisma.schoolStudent.update({ where: { id: w.vali }, data: { archived: true, archivedAt: new Date() } });

      const post409 = await schoolReq(t, w.director, 'POST', sUrl(), {});

      expect(post409.statusCode).toBe(409);
      expect(post409.json()).toMatchObject({ code: 'STUDENT_ARCHIVED' });
      expect((await schoolReq(t, w.director, 'GET', sUrl())).statusCode).toBe(200);
    });

    it('reset by the school signs the devices out and resolves the school recovery requests', async () => {
      const cred = (await schoolReq(t, w.director, 'POST', sUrl(), {})).json();
      const session = await loginThroughSetup(t, cred);
      const request = await api(t, 'POST', '/auth/child-recovery', { payload: { login: cred.login, channel: 'SCHOOL' } });
      await t.app.get(ChildRecoveryService).drainEffects();
      rt.clear();

      const next = (await schoolReq(t, w.admin, 'POST', sUrl(), { signOutDevices: true })).json();

      expect(next.login).toBe(cred.login);
      expect(next.temporaryPassword).not.toBe(cred.temporaryPassword);
      expect((await t.prisma.userSession.findUniqueOrThrow({ where: { id: session.sessionId } })).revokedReason).toBe('RECOVERED');
      expect(rt.of(w.child.userId, 'child:unpaired')).toHaveLength(1);
      const poll = await api(t, 'GET', `/auth/child-recovery/${request.json().requestId}?token=${request.json().pollToken}`);
      expect(poll.json()).toMatchObject({ status: 'RESTORED', channel: 'SCHOOL' });
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'CHILD_RECOVERY_REQUEST' } })).toBe(0);
    });

    it('writes school audit entries without the password or the login', async () => {
      const first = (await schoolReq(t, w.director, 'POST', sUrl(), {})).json();
      const second = (await schoolReq(t, w.director, 'POST', sUrl(), {})).json();

      const rows = await t.prisma.schoolAuditLog.findMany({
        where: { module: 'STUDENTS', action: { startsWith: 'student.credential' } },
        orderBy: { at: 'asc' },
      });
      expect(rows.map((r) => r.action)).toEqual(['student.credential.issue', 'student.credential.reset']);
      expect(rows[0]).toMatchObject({ entityId: w.vali, actorId: w.director.staffId, schoolId: w.schoolId });
      const dump = JSON.stringify(rows);
      for (const secret of [first.temporaryPassword, second.temporaryPassword, first.login]) expect(dump).not.toContain(secret);
      expect(await dbContains(t, first.temporaryPassword)).toEqual([]);
      expect(await dbContains(t, second.temporaryPassword)).toEqual([]);
    });

    describe('sinf doirasi (ruxsat berilgan rolga o\'tkazilsa ham)', () => {
      const original = [...SCHOOL_ROLES.HOMEROOM.permissions];

      beforeEach(() => {
        (SCHOOL_ROLES.HOMEROOM as unknown as { permissions: string[] }).permissions = [...original, 'students.manage'];
      });
      afterEach(() => {
        (SCHOOL_ROLES.HOMEROOM as unknown as { permissions: string[] }).permissions = original;
      });

      it("a class-scoped staff member can issue for a student of their own class but not another class", async () => {
        const own = await schoolReq(t, w.homeroom, 'POST', sUrl(w.vali), {});
        expect(own.statusCode).toBe(201);

        // 8-B sinfdagi o'quvchi (boshqa sinf) — bog'langan bo'lsa ham doiradan tashqari.
        const child = await createChild(t.prisma, w.parent, { name: 'Bek' });
        await t.prisma.schoolStudent.update({ where: { id: w.bek }, data: { childId: child.childId } });
        const other = await schoolReq(t, w.homeroom, 'POST', sUrl(w.bek), {});
        expect(other.statusCode).toBe(403);
        expect((await schoolReq(t, w.homeroom, 'GET', sUrl(w.bek))).statusCode).toBe(403);
        expect(await t.prisma.childCredential.count({ where: { childId: child.childId } })).toBe(0);
        // Butun maktab doirasidagi rol uchun esa ruxsat bor.
        expect((await schoolReq(t, w.director, 'POST', sUrl(w.bek), {})).statusCode).toBe(201);
      });
    });
  });
});
