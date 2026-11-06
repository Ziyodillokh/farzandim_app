// Kirish (K1): kirish maʼlumotlarini tiklash so'rovlari (A03/A04). Ommaviy so'rov DOIM bir xil 202 (mavjudlik
// fosh bo'lmaydi), poll tokeni faqat xesh sifatida saqlanadi, limitlar (3/sutka login, 10/sutka IP), ota-onaga
// neytral push yoki maktab xodimlariga saqlangan bildirishnoma, rad etish va tiklash holatlari, tozalash.

import { createHash } from 'node:crypto';
import { ChildRecoveryService } from '../../src/modules/child-auth/child-recovery.service';
import { resetDb } from './db';
import { createChild, createParent } from './factories';
import { api, controlClock, dbContains, issueAsParent, IssuedCredential, restoreClock } from './kirish-fixtures';
import { seedWorld, staffSession, World } from './school-attendance-fixtures';
import { schoolReq } from './school-child-fixtures';
import { createTestApp, TestApp } from './test-app';

const DAY = 24 * 60 * 60 * 1000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

interface Requested {
  requestId: string;
  pollToken: string;
}

describe('Kirish K1: tiklash so\'rovlari', () => {
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

  describe('POST /auth/child-recovery', () => {
    it('answers 202 { requestId, pollToken } and stores only the hash of the poll token', async () => {
      const res = await request(cred.login);

      expect(res.statusCode).toBe(202);
      expect(res.headers['cache-control']).toBe('no-store');
      const body = res.json();
      expect(Object.keys(body).sort()).toEqual(['pollToken', 'requestId']);
      expect(body.requestId).toMatch(UUID);
      expect(body.pollToken).toMatch(/^[A-Za-z0-9_-]{43}$/);
      const row = await t.prisma.childRecoveryRequest.findUniqueOrThrow({ where: { id: body.requestId } });
      expect(row).toMatchObject({
        childId: w.child.childId,
        channel: 'PARENT',
        status: 'RECEIVED',
        restoredAt: null,
        signedOutAt: null,
        rejectedAt: null,
      });
      expect(row.pollTokenHash).toBe(createHash('sha256').update(body.pollToken).digest('hex'));
      expect(await dbContains(t, body.pollToken)).toEqual([]);
    });

    it('answers the same 202 shape for an unknown login, a malformed login and a normalized login', async () => {
      const shapes = [
        await request(cred.login),
        await request(unknownLogin()),
        await request('N o!'),
        await request(`  ${cred.login.toUpperCase()} `),
        await request('x'),
      ].map((r) => ({ status: r.statusCode, keys: Object.keys(r.json()).sort(), cc: r.headers['cache-control'] }));

      for (const shape of shapes) expect(shape).toEqual({ status: 202, keys: ['pollToken', 'requestId'], cc: 'no-store' });
    });

    it('stores an unknown login as a dead request without a child that never resolves', async () => {
      const dead = await requested(unknownLogin());

      const row = await t.prisma.childRecoveryRequest.findUniqueOrThrow({ where: { id: dead.requestId } });
      expect(row.childId).toBeNull();
      expect(await poll(dead)).toMatchObject({ statusCode: 200 });
      expect((await poll(dead)).json()).toMatchObject({ status: 'RECEIVED', restoredAt: null, signedOutAt: null });
      // Hech qanday xabar ketmagan.
      expect(t.fcm.sent).toEqual([]);
      expect(await stored()).toEqual([]);
    });

    it('rejects malformed bodies with 400', async () => {
      const post = (payload: object) => api(t, 'POST', '/auth/child-recovery', { payload });

      expect((await post({ login: cred.login })).statusCode).toBe(400);
      expect((await post({ channel: 'PARENT' })).statusCode).toBe(400);
      expect((await post({ login: cred.login, channel: 'EMAIL' })).statusCode).toBe(400);
      expect((await post({ login: cred.login, channel: 'PARENT', extra: 1 })).statusCode).toBe(400);
      expect((await post({ login: 'a'.repeat(65), channel: 'PARENT' })).statusCode).toBe(400);
    });

    it('returns before the push is delivered (a slow FCM must not make existing logins slower)', async () => {
      jest.spyOn(t.fcm, 'sendPushToUser').mockImplementation(
        () => new Promise((resolve) => setTimeout(() => resolve({ sent: 1, failed: 0, invalidTokens: [] }), 2_000)),
      );

      const start = Date.now();
      const res = await request(cred.login);
      const elapsed = Date.now() - start;

      expect(res.statusCode).toBe(202);
      expect(elapsed).toBeLessThan(1_200);
      await settle();
    });

    it('still answers 202 and stores the request when the push fails', async () => {
      jest.spyOn(t.fcm, 'sendPushToUser').mockRejectedValue(new Error('fcm down'));

      const res = await request(cred.login);
      await settle();

      expect(res.statusCode).toBe(202);
      expect(await t.prisma.childRecoveryRequest.count({ where: { childId: w.child.childId } })).toBe(1);
    });
  });

  describe('PARENT kanali: ota-onaga neytral push', () => {
    it('pushes only a neutral message with the type and childId (no child name, no login)', async () => {
      await requested();

      expect(recoveryPushes()).toEqual([
        {
          title: 'Parvoz',
          body: 'Farzandingiz kirish maʼlumotlarini tiklashni soʻradi',
          data: { type: 'CHILD_RECOVERY_REQUEST', childId: w.child.childId },
        },
      ]);
      const dump = JSON.stringify(t.fcm.sent);
      expect(dump).not.toContain('Vali');
      expect(dump).not.toContain(cred.login);
    });

    it('speaks the language of the parent', async () => {
      await t.prisma.user.update({ where: { id: w.parent.userId }, data: { language: 'ru' } });

      await requested();

      expect(recoveryPushes()[0]?.body).toBe('Ваш ребёнок просит восстановить данные для входа');
    });

    it('pushes only the parent of that child (never another family)', async () => {
      const other = await createParent(t.prisma);

      await requested();

      expect(t.fcm.pushesTo(other.userId)).toEqual([]);
      expect(t.fcm.sent.every((p) => p.userId === w.parent.userId)).toBe(true);
    });

    it('SCHOOL falls back to the parent when the child is not linked to a school', async () => {
      const lone = await createParent(t.prisma);
      const loneChild = await createChild(t.prisma, lone, { name: 'Yolgiz Bola' });
      const loneCred = await issueAsParent(t, lone, loneChild.childId);

      const r = await requested(loneCred.login, 'SCHOOL');

      expect(t.fcm.pushesTo(lone.userId).filter((p) => p.data?.type === 'CHILD_RECOVERY_REQUEST')).toHaveLength(1);
      expect(await stored()).toEqual([]);
      expect((await poll(r)).json()).toMatchObject({ channel: 'PARENT', status: 'RECEIVED' });
      expect((await t.prisma.childRecoveryRequest.findUniqueOrThrow({ where: { id: r.requestId } })).channel).toBe('PARENT');
    });

    it.each([
      ['an archived student', () => t.prisma.schoolStudent.update({ where: { id: w.vali }, data: { archived: true } })],
      ['a suspended school', () => t.prisma.school.update({ where: { id: w.schoolId }, data: { status: 'SUSPENDED' } })],
    ])('SCHOOL falls back to the parent for %s', async (_name, change) => {
      await change();

      const r = await requested(cred.login, 'SCHOOL');

      expect(recoveryPushes()).toHaveLength(1);
      expect(await stored()).toEqual([]);
      expect((await poll(r)).json().channel).toBe('PARENT');
    });
  });

  describe('SCHOOL kanali: xodimlarga saqlangan bildirishnoma', () => {
    it('stores one notification for the class HOMEROOM and ADMIN with only the student name and class', async () => {
      const r = await requested(cred.login, 'SCHOOL');

      const rows = await stored();
      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({
        id: `child-recovery:${r.requestId}`,
        schoolId: w.schoolId,
        kind: 'CHILD_RECOVERY_REQUEST',
        roles: ['HOMEROOM', 'ADMIN'],
        classIds: [w.classA],
        staffIds: [],
        params: { studentName: 'Aliyev Vali', className: '7-A' },
        subject: null,
        href: null,
      });
      expect(Object.keys(rows[0]!.params as object).sort()).toEqual(['className', 'studentName']);
      expect(JSON.stringify(rows[0])).not.toContain(w.child.childId);
      expect(JSON.stringify(rows[0])).not.toContain(cred.login);
      expect(recoveryPushes()).toEqual([]);
      expect((await poll(r)).json().channel).toBe('SCHOOL');
    });

    it("shows up in the feed of that class's homeroom teacher and the administrator only", async () => {
      await requested(cred.login, 'SCHOOL');
      const otherHomeroom = await staffSession(t, w.schoolId, 'HOMEROOM', 'homeroom-b', [w.classB]);

      for (const session of [w.homeroom, w.admin]) {
        const items = await feed(session);
        expect(items).toHaveLength(1);
        expect(items[0]).toMatchObject({ params: { studentName: 'Aliyev Vali', className: '7-A' }, subject: null, href: null, tone: 'warning' });
      }
      for (const session of [w.director, w.duty, w.teacher, w.psych, otherHomeroom]) {
        expect(await feed(session)).toHaveLength(0);
      }
    });

    it('goes to the administrator only when the student has no class', async () => {
      await t.prisma.schoolStudent.update({ where: { id: w.vali }, data: { classId: null } });

      await requested(cred.login, 'SCHOOL');

      const [row] = await stored();
      expect(row).toMatchObject({ roles: ['ADMIN'], classIds: [], params: { studentName: 'Aliyev Vali', className: '' } });
      expect(await feed(w.admin)).toHaveLength(1);
      expect(await feed(w.homeroom)).toHaveLength(0);
    });

    it("does not notify another school's staff", async () => {
      const other = await seedWorld(t, 'other-school');
      await requested(cred.login, 'SCHOOL');

      expect(await feed(other.admin)).toHaveLength(0);
      expect(await feed(other.director)).toHaveLength(0);
    });
  });

  describe('GET /auth/child-recovery/:requestId?token=', () => {
    it('returns exactly { status, channel, createdAt, restoredAt, signedOutAt }', async () => {
      const r = await requested();

      const res = await poll(r);

      expect(res.statusCode).toBe(200);
      expect(res.headers['cache-control']).toBe('no-store');
      expect(Object.keys(res.json()).sort()).toEqual(['channel', 'createdAt', 'restoredAt', 'signedOutAt', 'status']);
      expect(res.json()).toEqual({
        status: 'RECEIVED',
        channel: 'PARENT',
        createdAt: expect.stringMatching(/^\d{4}-\d\d-\d\dT.*Z$/),
        restoredAt: null,
        signedOutAt: null,
      });
    });

    it('answers the identical 404 for a wrong token, a wrong id, a missing token and an unrelated token', async () => {
      const a = await requested();
      const b = await requested(unknownLogin());

      const answers = [
        await poll(a, 'wrong-token'),
        await poll({ ...a, requestId: '00000000-0000-4000-8000-000000000000' }),
        await api(t, 'GET', `/auth/child-recovery/${a.requestId}`),
        await poll(a, b.pollToken),
        await poll(a, ''),
        await poll({ requestId: 'not-an-id', pollToken: a.pollToken }),
      ];

      for (const res of answers) {
        expect(res.statusCode).toBe(404);
        expect(res.json()).toEqual({ statusCode: 404, code: 'NOT_FOUND', message: 'Request not found' });
      }
    });

    it('turns RESTORED after a credential reset, with signedOutAt only when devices were signed out', async () => {
      const first = await requested();
      await issueAsParent(t, w.parent, w.child.childId, { signOutDevices: false });
      const second = await requested();
      await issueAsParent(t, w.parent, w.child.childId, { signOutDevices: true });

      const a = (await poll(first)).json();
      const b = (await poll(second)).json();

      expect(a).toMatchObject({ status: 'RESTORED', signedOutAt: null });
      expect(a.restoredAt).toEqual(expect.any(String));
      expect(b).toMatchObject({ status: 'RESTORED' });
      expect(b.signedOutAt).toEqual(expect.any(String));
    });

    it('turns REJECTED after a rejection', async () => {
      const r = await requested();
      const list = (await api(t, 'GET', `/children/${w.child.childId}/recovery-requests`, { token: w.parent.token })).json();
      await api(t, 'POST', `/children/${w.child.childId}/recovery-requests/${list[0].id}/reject`, { token: w.parent.token });

      expect((await poll(r)).json()).toMatchObject({ status: 'REJECTED', restoredAt: null });
    });

    it('stops answering when the child profile is deleted', async () => {
      const r = await requested();
      await api(t, 'DELETE', `/children/${w.child.childId}`, { token: w.parent.token });

      expect((await poll(r)).statusCode).toBe(404);
    });
  });

  describe('limitlar', () => {
    it('allows 3 requests per day for one login text (any IP, any casing) and answers 429 RATE_LIMITED after that', async () => {
      const results = [];
      for (const login of [cred.login, cred.login.toUpperCase(), ` ${cred.login} `, cred.login]) results.push(await request(login));

      expect(results.map((r) => r.statusCode)).toEqual([202, 202, 202, 429]);
      expect(results[3]!.json()).toMatchObject({ statusCode: 429, code: 'RATE_LIMITED', retryAfterSeconds: expect.any(Number) });
    });

    it('limits an unknown login exactly like an existing one (no enumeration through the limit)', async () => {
      const sequence = async (login: string) => {
        const out = [];
        for (let i = 0; i < 5; i++) {
          const r = await request(login);
          out.push({ status: r.statusCode, code: r.statusCode === 429 ? r.json().code : undefined });
        }
        return out;
      };

      expect(await sequence(cred.login)).toEqual(await sequence(unknownLogin()));
      expect((await sequence(unknownLogin())).map((x) => x.status)).toEqual([202, 202, 202, 429, 429]);
    });

    it('allows 10 requests per day per IP and then answers 429', async () => {
      const ip = '198.51.100.20';
      const statuses: number[] = [];
      for (let i = 0; i < 11; i++) statuses.push((await request(unknownLogin(), 'PARENT', ip)).statusCode);

      expect(statuses).toEqual([...Array<number>(10).fill(202), 429]);
      expect((await request(unknownLogin(), 'PARENT', '198.51.100.21')).statusCode).toBe(202);
    });

    it('stops sending notifications after 3 requests for the same child in a day, but still answers 202 (the cap survives a restart)', async () => {
      for (let i = 0; i < 3; i++) {
        await t.prisma.childRecoveryRequest.create({
          data: { childId: w.child.childId, channel: 'PARENT', pollTokenHash: `h${i}`, createdAt: new Date(Date.now() - i * 1000) },
        });
      }

      const r = await requested();

      expect(r.requestId).toMatch(UUID);
      expect(recoveryPushes()).toEqual([]);
      expect((await poll(r)).statusCode).toBe(200);
    });

    it('does not count requests older than a day toward that cap', async () => {
      for (let i = 0; i < 3; i++) {
        await t.prisma.childRecoveryRequest.create({
          data: { childId: w.child.childId, channel: 'PARENT', pollTokenHash: `h${i}`, createdAt: new Date(Date.now() - DAY - 60_000) },
        });
      }

      await requested();

      expect(recoveryPushes()).toHaveLength(1);
    });
  });

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

    it('includes the open school requests in the student detail for staff who can see guardians', async () => {
      const parentOnly = await requested();
      const mine = await requested(cred.login, 'SCHOOL');

      for (const session of [w.director, w.admin, w.homeroom]) {
        const res = await detail(session);
        expect(res.statusCode).toBe(200);
        expect(res.json().recoveryRequests).toEqual([{ id: mine.requestId, channel: 'SCHOOL', status: 'RECEIVED', createdAt: expect.any(String) }]);
      }
      expect(JSON.stringify((await detail(w.director)).json().recoveryRequests)).not.toContain(parentOnly.requestId);
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
