// Kirish (K1): tiklash so'rovlarini ota-ona (ro'yxat / rad etish) va maktab xodimi (o'quvchi kartasi / rad etish) boshqaradi;
// saqlash muddati bo'yicha tozalash.

import { ChildRecoveryService } from '../../src/modules/child-auth/child-recovery.service';
import { resetDb } from './db';
import { createChild, createParent } from './factories';
import {
  api,
  controlClock,
  issueAsParent,
  IssuedCredential,
  restoreClock,
} from './kirish-fixtures';
import { seedWorld, World } from './school-attendance-fixtures';
import { schoolReq } from './school-child-fixtures';
import { createTestApp, TestApp } from './test-app';

const DAY = 24 * 60 * 60 * 1000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

interface Requested {
  requestId: string;
  pollToken: string;
}

describe('Kirish K1: tiklash so\'rovlarini boshqarish', () => {
  let t: TestApp;
  let w: World;
  let cred: IssuedCredential;
  let unknownSeq = 0;
  let testSeq = 0;
  const unknownLogin = () => `nobody.r${(unknownSeq += 1)}`;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    w = await seedWorld(t);
    // Har testga o'z logini: kunlik limit (3/login) throttler xotirasida testlar orasida yig'ilmasin.
    cred = await issueAsParent(t, w.parent, w.child.childId, { login: `vali.t${(testSeq += 1)}` });
  });

  afterEach(() => {
    jest.restoreAllMocks();
    restoreClock(t);
  });

  afterAll(() => t.close());

  const service = () => t.app.get(ChildRecoveryService);
  const settle = () => service().drainEffects();
  const request = (login: string, channel: 'PARENT' | 'SCHOOL' = 'PARENT', ip?: string) =>
    api(t, 'POST', '/auth/child-recovery', { payload: { login, channel }, ip });
  const requested = async (login = cred.login, channel: 'PARENT' | 'SCHOOL' = 'PARENT'): Promise<Requested> => {
    const res = await request(login, channel);
    expect(res.statusCode).toBe(202);
    await settle();
    return res.json();
  };
  const poll = (r: Requested, token = r.pollToken) =>
    api(t, 'GET', `/auth/child-recovery/${r.requestId}?token=${encodeURIComponent(token)}`);
  const recoveryPushes = () => t.fcm.pushesTo(w.parent.userId).filter((p) => p.data?.type === 'CHILD_RECOVERY_REQUEST');
  const stored = () => t.prisma.schoolStaffNotification.findMany({ where: { kind: 'CHILD_RECOVERY_REQUEST' } });
  const feed = async (s: World['director']) => {
    const res = await schoolReq(t, s, 'GET', '/notifications/feed');
    expect(res.statusCode).toBe(200);
    return (res.json() as Array<{ kind: string; params: Record<string, unknown>; subject: unknown; href: unknown; tone: string }>).filter(
      (n) => n.kind === 'CHILD_RECOVERY_REQUEST',
    );
  };

  describe('ota-ona: /children/:childId/recovery-requests', () => {
    const list = (token = w.parent.token, childId = w.child.childId) =>
      api(t, 'GET', `/children/${childId}/recovery-requests`, { token });
    const reject = (id: string, token = w.parent.token, childId = w.child.childId) =>
      api(t, 'POST', `/children/${childId}/recovery-requests/${id}/reject`, { token });

    it('lists only the open requests sent to the parent, newest first, without secrets', async () => {
      const clock = controlClock(t);
      const first = await requested();
      clock.advance(60_000);
      const second = await requested();
      await requested(cred.login, 'SCHOOL');

      const res = await list();

      expect(res.statusCode).toBe(200);
      const items = res.json() as Array<Record<string, unknown>>;
      expect(items.map((i) => i.id)).toEqual([second.requestId, first.requestId]);
      expect(items[0]).toEqual({ id: second.requestId, channel: 'PARENT', status: 'RECEIVED', createdAt: expect.any(String) });
      expect(res.body).not.toContain('pollTokenHash');
      expect(res.body).not.toContain(first.pollToken);
    });

    it('returns an empty list when nothing is open and drops resolved requests', async () => {
      expect((await list()).json()).toEqual([]);
      await requested();
      await issueAsParent(t, w.parent, w.child.childId);

      expect((await list()).json()).toEqual([]);
    });

    it('rejects an open request (200, the REJECTED view) and a second rejection answers 409 ALREADY_RESOLVED', async () => {
      const r = await requested();

      const res = await reject(r.requestId);

      expect(res.statusCode).toBe(200);
      expect(res.json()).toEqual({ id: r.requestId, channel: 'PARENT', status: 'REJECTED', createdAt: expect.any(String) });
      const row = await t.prisma.childRecoveryRequest.findUniqueOrThrow({ where: { id: r.requestId } });
      expect(row.status).toBe('REJECTED');
      expect(row.rejectedAt).not.toBeNull();
      expect((await reject(r.requestId)).statusCode).toBe(409);
      expect((await reject(r.requestId)).json()).toMatchObject({ code: 'ALREADY_RESOLVED' });
      expect((await list()).json()).toEqual([]);
    });

    it('does not reject a RESTORED request', async () => {
      const r = await requested();
      await issueAsParent(t, w.parent, w.child.childId);

      expect((await reject(r.requestId)).statusCode).toBe(409);
      expect((await t.prisma.childRecoveryRequest.findUniqueOrThrow({ where: { id: r.requestId } })).status).toBe('RESTORED');
    });

    it('answers 404 for a school-channel request, an unknown id and a request of another child', async () => {
      const school = await requested(cred.login, 'SCHOOL');
      const other = await createParent(t.prisma);
      const otherChild = await createChild(t.prisma, other, { name: 'Boshqa Bola' });
      const otherCred = await issueAsParent(t, other, otherChild.childId);
      const foreign = await requested(otherCred.login);

      expect((await reject(school.requestId)).statusCode).toBe(404);
      expect((await reject('00000000-0000-4000-8000-000000000000')).statusCode).toBe(404);
      expect((await reject(foreign.requestId)).statusCode).toBe(404);
      expect((await t.prisma.childRecoveryRequest.findUniqueOrThrow({ where: { id: foreign.requestId } })).status).toBe('RECEIVED');
      expect((await t.prisma.childRecoveryRequest.findUniqueOrThrow({ where: { id: school.requestId } })).status).toBe('RECEIVED');
    });

    it("another parent gets 403, and cannot reject through their own child's URL either", async () => {
      const r = await requested();
      const stranger = await createParent(t.prisma);
      const strangerChild = await createChild(t.prisma, stranger, { name: 'Begona' });

      expect((await list(stranger.token)).statusCode).toBe(403);
      expect((await reject(r.requestId, stranger.token)).statusCode).toBe(403);
      expect((await reject(r.requestId, stranger.token, strangerChild.childId)).statusCode).toBe(404);
      expect((await t.prisma.childRecoveryRequest.findUniqueOrThrow({ where: { id: r.requestId } })).status).toBe('RECEIVED');
    });

    it('answers 404 for an unknown child, 403 for a child token and 401 without a token', async () => {
      expect((await list(w.parent.token, '00000000-0000-4000-8000-000000000000')).statusCode).toBe(404);
      expect((await list(w.child.token)).statusCode).toBe(403);
      expect((await reject('x', w.child.token)).statusCode).toBe(403);
      expect((await api(t, 'GET', `/children/${w.child.childId}/recovery-requests`)).statusCode).toBe(401);
    });

    it('audits the rejection with only the request id', async () => {
      const r = await requested();
      await reject(r.requestId);

      const rows = await t.prisma.auditLog.findMany({ where: { action: 'CHILD_RECOVERY_REJECT' } });
      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({ userId: w.parent.userId, resourceId: w.child.childId });
      expect(rows[0]!.data).toEqual({ requestId: r.requestId });
    });
  });

  describe('maktab: o\'quvchi kartasi va rad etish', () => {
    const detail = (s: World['director'], studentId = w.vali) => schoolReq(t, s, 'GET', `/students/${studentId}`);
    const reject = (s: World['director'], requestId: string, studentId = w.vali) =>
      schoolReq(t, s, 'POST', `/students/${studentId}/recovery-requests/${requestId}/reject`);

    it('includes only the open SCHOOL-channel requests in the student detail for staff who can answer them (students.manage)', async () => {
      const parentOnly = await requested();
      const mine = await requested(cred.login, 'SCHOOL');

      for (const session of [w.director, w.admin]) {
        const res = await detail(session);
        expect(res.statusCode).toBe(200);
        expect(res.json().recoveryRequests).toEqual([{ id: mine.requestId, channel: 'SCHOOL', status: 'RECEIVED', createdAt: expect.any(String) }]);
      }
      expect(JSON.stringify((await detail(w.director)).json().recoveryRequests)).not.toContain(parentOnly.requestId);
      // Sinf rahbari kartani ko'radi, lekin unga javob bera olmaydi (students.manage yo'q) — ro'yxat bo'sh.
      expect((await detail(w.homeroom)).json().recoveryRequests).toEqual([]);
    });

    it('shows an empty list for a psychologist (minimal view), an unlinked student and a student without requests', async () => {
      await requested(cred.login, 'SCHOOL');

      expect((await detail(w.psych)).json().recoveryRequests).toEqual([]);
      expect((await detail(w.director, w.malika)).json().recoveryRequests).toEqual([]);
      await t.prisma.childRecoveryRequest.deleteMany();
      expect((await detail(w.director)).json().recoveryRequests).toEqual([]);
    });

    it('drops resolved requests from the detail', async () => {
      await requested(cred.login, 'SCHOOL');
      await issueAsParent(t, w.parent, w.child.childId);

      expect((await detail(w.director)).json().recoveryRequests).toEqual([]);
    });

    it('DIRECTOR and ADMIN reject a school request: REJECTED view, notification removed, audit written', async () => {
      const r = await requested(cred.login, 'SCHOOL');
      expect(await stored()).toHaveLength(1);

      const res = await reject(w.admin, r.requestId);

      expect(res.statusCode).toBe(200);
      expect(res.json()).toEqual({ id: r.requestId, channel: 'SCHOOL', status: 'REJECTED', createdAt: expect.any(String) });
      expect(await stored()).toEqual([]);
      expect((await poll(r)).json().status).toBe('REJECTED');
      const audit = await t.prisma.schoolAuditLog.findMany({ where: { action: 'student.recovery.reject' } });
      expect(audit).toHaveLength(1);
      expect(audit[0]).toMatchObject({ module: 'STUDENTS', entityId: w.vali, actorId: w.admin.staffId });
      expect((await reject(w.director, r.requestId)).statusCode).toBe(409);
    });

    it.each(['homeroom', 'duty', 'teacher', 'psych'] as const)('%s cannot reject (403)', async (key) => {
      const r = await requested(cred.login, 'SCHOOL');

      expect((await reject(w[key], r.requestId)).statusCode).toBe(403);
      expect((await t.prisma.childRecoveryRequest.findUniqueOrThrow({ where: { id: r.requestId } })).status).toBe('RECEIVED');
    });

    it('answers 404 for a parent-channel request, an unknown id and a student of another school', async () => {
      const parentChannel = await requested();
      const school = await requested(cred.login, 'SCHOOL');
      const other = await seedWorld(t, 'other-school');

      expect((await reject(w.director, parentChannel.requestId)).statusCode).toBe(404);
      expect((await reject(w.director, '00000000-0000-4000-8000-000000000000')).statusCode).toBe(404);
      expect((await reject(other.director, school.requestId, w.vali)).statusCode).toBe(404);
      expect((await reject(w.director, school.requestId, w.malika)).statusCode).toBe(409);
      expect((await t.prisma.childRecoveryRequest.findUniqueOrThrow({ where: { id: school.requestId } })).status).toBe('RECEIVED');
    });

    it('a credential reset by the school resolves the request and clears the staff notification', async () => {
      const r = await requested(cred.login, 'SCHOOL');

      const res = await schoolReq(t, w.director, 'POST', `/students/${w.vali}/credentials`, {});

      expect(res.statusCode).toBe(201);
      expect((await poll(r)).json()).toMatchObject({ status: 'RESTORED' });
      expect(await stored()).toEqual([]);
      expect(await feed(w.admin)).toEqual([]);
    });
  });

  describe('tozalash (saqlash muddati)', () => {
    it('purgeExpired removes requests older than 30 days with their staff notifications and keeps the rest', async () => {
      const old = await requested(cred.login, 'SCHOOL');
      const fresh = await requested(cred.login, 'SCHOOL');
      await t.prisma.childRecoveryRequest.update({ where: { id: old.requestId }, data: { createdAt: new Date(Date.now() - 31 * DAY) } });
      const dead = await requested(unknownLogin());
      await t.prisma.childRecoveryRequest.update({ where: { id: dead.requestId }, data: { createdAt: new Date(Date.now() - 45 * DAY) } });

      await service().purgeExpired();

      expect(await t.prisma.childRecoveryRequest.findMany({ select: { id: true } })).toEqual([{ id: fresh.requestId }]);
      expect((await stored()).map((n) => n.id)).toEqual([`child-recovery:${fresh.requestId}`]);
    });
  });
});
