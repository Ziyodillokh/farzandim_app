// Kirish (K1): bola kirish maʼlumotlarini ota-ona berishi / qayta tiklashi (`/children/:childId/credentials`).
// Parol hech qayerda saqlanmaydi / loglanmaydi, kirish huquqlari (boshqa ota-ona, bola tokeni) va oqibatlari
// (sessiyalar, tokenVersion, WebSocket, push tokenlar, tiklash so'rovlari). Maktab tomoni:
// `kirish-credentials-school.e2e-spec.ts`.

import { resetDb } from './db';
import { createParent, TestChild, TestParent } from './factories';
import {
  api,
  captureRealtime,
  childLogin,
  controlClock,
  dbContains,
  familyOf,
  issueAsParent,
  legacyRefreshToken,
  loginPlain,
  loginThroughSetup,
  OWN_PASSWORD,
  restoreClock,
} from './kirish-fixtures';
import { createTestApp, TestApp } from './test-app';

const LOGIN_FORMAT = /^[a-z][a-z0-9._]{3,23}$/;
const TEMP_PASSWORD = /^[abcdefghjkmnpqrstuvwxyz23456789]{8}$/;

describe('Kirish K1: kirish maʼlumotlarini berish va tiklash', () => {
  let t: TestApp;
  let w: { parent: TestParent; child: TestChild };
  let rt: ReturnType<typeof captureRealtime>;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    w = await familyOf(t, 'Vali');
    rt = captureRealtime(t);
  });

  afterEach(() => {
    jest.restoreAllMocks();
    restoreClock(t);
  });

  afterAll(() => t.close());

  const url = (childId = w.child.childId) => `/children/${childId}/credentials`;
  const get = (token = w.parent.token, childId?: string) => api(t, 'GET', url(childId), { token });
  const post = (payload: object = {}, token = w.parent.token, childId?: string) =>
    api(t, 'POST', url(childId), { token, payload });
  const credentialRow = (childId = w.child.childId) => t.prisma.childCredential.findUniqueOrThrow({ where: { childId } });

  describe('ota-ona: GET/POST /children/:childId/credentials', () => {
    it('GET returns JSON null while nothing is issued', async () => {
      const res = await get();

      expect(res.statusCode).toBe(200);
      expect(res.body).toBe('null');
    });

    it('POST issues credentials (201) with exactly the contract shape and no-store caching', async () => {
      const res = await post();

      expect(res.statusCode).toBe(201);
      const body = res.json();
      expect(Object.keys(body).sort()).toEqual(['issuedAt', 'login', 'temporaryPassword']);
      expect(body.login).toMatch(/^vali\.\d{2}$/);
      expect(body.temporaryPassword).toMatch(TEMP_PASSWORD);
      expect(new Date(body.issuedAt).toISOString()).toBe(body.issuedAt);
      expect(res.headers['cache-control']).toBe('no-store');
    });

    it('suggests the transliterated first name + "." + last initial + two digits', async () => {
      const { parent, child } = await familyOf(t, 'Aziza Karimova');

      const cred = await issueAsParent(t, parent, child.childId);

      expect(cred.login).toMatch(/^aziza\.k\d{2}$/);
      expect(cred.login).toMatch(LOGIN_FORMAT);
    });

    it('transliterates a Cyrillic name', async () => {
      const { parent, child } = await familyOf(t, 'Азиза Каримова');

      const cred = await issueAsParent(t, parent, child.childId);

      expect(cred.login).toMatch(/^aziza\.k\d{2}$/);
    });

    it('falls back to parvoz + 4 digits when the name cannot be turned into a login', async () => {
      const { parent, child } = await familyOf(t, '你好');

      const cred = await issueAsParent(t, parent, child.childId);

      expect(cred.login).toMatch(/^parvoz\d{4}$/);
    });

    it('stores only a bcrypt hash: the temporary password and the login appear nowhere in the database', async () => {
      const cred = await issueAsParent(t, w.parent, w.child.childId);

      const row = await credentialRow();
      expect(row.passwordHash).toMatch(/^\$2[aby]\$12\$/);
      expect(row).toMatchObject({
        login: cred.login,
        mustChangePassword: true,
        issuedBy: 'PARENT',
        issuedByUserId: w.parent.userId,
        issuedByStaffId: null,
        failedLogins: 0,
        lockedUntil: null,
        lastLoginAt: null,
      });
      expect(await dbContains(t, cred.temporaryPassword)).toEqual([]);
    });

    it('keeps the password and the login out of the audit log', async () => {
      const cred = await issueAsParent(t, w.parent, w.child.childId);

      const rows = await t.prisma.auditLog.findMany({ where: { action: 'CHILD_CREDENTIAL_ISSUE' } });
      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({ userId: w.parent.userId, resourceType: 'child', resourceId: w.child.childId });
      expect(JSON.stringify(rows)).not.toContain(cred.temporaryPassword);
      expect(JSON.stringify(rows)).not.toContain(cred.login);
    });

    it('GET shows login, issuer, issuance time, temporary flag and last login — never the hash or password', async () => {
      const cred = await issueAsParent(t, w.parent, w.child.childId);

      const res = await get();

      expect(res.statusCode).toBe(200);
      expect(res.json()).toEqual({
        login: cred.login,
        issuedBy: 'PARENT',
        issuedAt: cred.issuedAt,
        mustChangePassword: true,
        lastLoginAt: null,
      });
      expect(res.body).not.toContain('passwordHash');
      expect(res.body).not.toContain(cred.temporaryPassword);
    });

    it('uses a requested login when it is valid and free (normalized to lower case)', async () => {
      const cred = await issueAsParent(t, w.parent, w.child.childId, { login: '  My.Login_7 ' });

      expect(cred.login).toBe('my.login_7');
    });

    it('answers 409 LOGIN_TAKEN when the requested login belongs to another child', async () => {
      const { parent: other, child: otherChild } = await familyOf(t, 'Bobur');
      await issueAsParent(t, other, otherChild.childId, { login: 'shared.name1' });

      const res = await post({ login: 'Shared.Name1' });

      expect(res.statusCode).toBe(409);
      expect(res.json()).toMatchObject({ statusCode: 409, code: 'LOGIN_TAKEN' });
      expect(await t.prisma.childCredential.count({ where: { childId: w.child.childId } })).toBe(0);
    });

    it.each(['ab', '1abcd', 'has space', 'ÄÖÜ.test', 'x'.repeat(30)])(
      'ignores an invalid requested login (%s) and suggests one instead',
      async (login) => {
        const res = await post({ login });

        expect(res.statusCode).toBe(201);
        expect(res.json().login).toMatch(/^vali\.\d{2}$/);
      },
    );

    it('rejects unknown body fields and a non-boolean signOutDevices (400)', async () => {
      expect((await post({ foo: 'bar' })).statusCode).toBe(400);
      expect((await post({ signOutDevices: 'yes' })).statusCode).toBe(400);
      expect((await post({ login: 12 })).statusCode).toBe(400);
    });

    it('never hands the same login to two children, even for identical names', async () => {
      const logins = new Set<string>();
      for (let i = 0; i < 6; i++) {
        const { parent, child } = await familyOf(t, 'Aziza Karimova');
        logins.add((await issueAsParent(t, parent, child.childId)).login);
      }

      expect(logins.size).toBe(6);
    });
  });

  describe('qayta tiklash (reset)', () => {
    it('issues a NEW temporary password, keeps the login, re-requires setup and clears failures and the lock', async () => {
      const first = await issueAsParent(t, w.parent, w.child.childId);
      await loginThroughSetup(t, first);
      await t.prisma.childCredential.update({
        where: { childId: w.child.childId },
        data: { failedLogins: 3, failedWindowStartedAt: new Date(), lockedUntil: new Date(Date.now() + 600_000) },
      });

      const second = await issueAsParent(t, w.parent, w.child.childId, { login: 'ignored.name9' });

      expect(second.login).toBe(first.login);
      expect(second.temporaryPassword).not.toBe(first.temporaryPassword);
      expect(await credentialRow()).toMatchObject({
        mustChangePassword: true,
        failedLogins: 0,
        failedWindowStartedAt: null,
        lockedUntil: null,
      });
      // Eski vaqtinchalik va o'z paroli ishlamaydi, yangisi o'rnatishni talab qiladi.
      expect((await childLogin(t, first.login, first.temporaryPassword)).statusCode).toBe(401);
      expect((await childLogin(t, first.login, OWN_PASSWORD)).statusCode).toBe(401);
      const again = await childLogin(t, second.login, second.temporaryPassword);
      expect(again.json().status).toBe('SETUP_REQUIRED');
    });

    it('audits a reset separately from the first issue', async () => {
      await issueAsParent(t, w.parent, w.child.childId);
      const second = await issueAsParent(t, w.parent, w.child.childId);

      const actions = (await t.prisma.auditLog.findMany({ where: { resourceId: w.child.childId }, orderBy: { createdAt: 'asc' } })).map((r) => r.action);
      expect(actions).toEqual(['CHILD_CREDENTIAL_ISSUE', 'CHILD_CREDENTIAL_RESET']);
      expect(JSON.stringify(await t.prisma.auditLog.findMany())).not.toContain(second.temporaryPassword);
    });

    it('the first issue never signs anybody out (the already paired device keeps working)', async () => {
      const before = await t.prisma.user.findUniqueOrThrow({ where: { id: w.child.userId } });

      await issueAsParent(t, w.parent, w.child.childId, { signOutDevices: true });

      const after = await t.prisma.user.findUniqueOrThrow({ where: { id: w.child.userId } });
      expect(after.tokenVersion).toBe(before.tokenVersion);
      expect(rt.events).toEqual([]);
      const refresh = await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: legacyRefreshToken(w.child.userId) } });
      expect(refresh.statusCode).toBe(200);
    });

    describe('signOutDevices (default true)', () => {
      let session: Awaited<ReturnType<typeof loginThroughSetup>>;
      let second: Awaited<ReturnType<typeof loginThroughSetup>>;

      beforeEach(async () => {
        const cred = await issueAsParent(t, w.parent, w.child.childId);
        session = await loginThroughSetup(t, cred, { id: 'install-a', platform: 'android', model: 'Redmi' });
        second = await loginPlain(t, cred.login, { id: 'install-b', platform: 'ios', model: 'iPhone' });
        await t.prisma.fcmToken.create({ data: { userId: w.child.userId, token: 'fcm-old-device', deviceType: 'android' } });
        rt.clear();
      });

      it('revokes ALL the child sessions with reason RECOVERED, bumps tokenVersion and drops push tokens', async () => {
        const tokenVersionBefore = (await t.prisma.user.findUniqueOrThrow({ where: { id: w.child.userId } })).tokenVersion;

        await issueAsParent(t, w.parent, w.child.childId);

        const sessions = await t.prisma.userSession.findMany({ where: { userId: w.child.userId } });
        expect(sessions).toHaveLength(2);
        for (const s of sessions) {
          expect(s.revokedAt).not.toBeNull();
          expect(s.revokedReason).toBe('RECOVERED');
        }
        expect((await t.prisma.user.findUniqueOrThrow({ where: { id: w.child.userId } })).tokenVersion).toBe(tokenVersionBefore + 1);
        expect(await t.prisma.fcmToken.count({ where: { userId: w.child.userId } })).toBe(0);
      });

      it('emits the legacy child:unpaired {reason: RECOVERED} AND session:closed to the child user room', async () => {
        await issueAsParent(t, w.parent, w.child.childId);

        const unpaired = rt.of(w.child.userId, 'child:unpaired');
        expect(unpaired).toHaveLength(1);
        expect(unpaired[0]!.payload).toMatchObject({ childId: w.child.childId, reason: 'RECOVERED' });
        const closed = rt.of(w.child.userId, 'session:closed');
        expect(closed).toHaveLength(1);
        expect(closed[0]!.payload.reason).toBe('RECOVERED');
        expect([...(closed[0]!.payload.sessionIds as string[])].sort()).toEqual([session.sessionId, second.sessionId].sort());
      });

      it('refresh with a revoked session answers 401 SESSION_REVOKED + reason (so the app can show A12 without the socket)', async () => {
        await issueAsParent(t, w.parent, w.child.childId);

        const res = await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: session.refreshToken } });

        expect(res.statusCode).toBe(401);
        expect(res.json()).toEqual({ statusCode: 401, code: 'SESSION_REVOKED', reason: 'RECOVERED', message: 'Session revoked' });
      });

      it('signs out the legacy paired device too: its refresh token no longer works', async () => {
        const before = await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: legacyRefreshToken(w.child.userId, 0) } });
        expect(before.statusCode).toBe(200);

        await issueAsParent(t, w.parent, w.child.childId);

        const after = await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: legacyRefreshToken(w.child.userId, 0) } });
        expect(after.statusCode).toBe(401);
      });

      it('lets the child sign in again with the new temporary password on any device', async () => {
        const next = await issueAsParent(t, w.parent, w.child.childId);

        const back = await loginThroughSetup(t, next, { id: 'install-a', platform: 'android' });

        expect(back.userId).toBe(w.child.userId);
        expect((await api(t, 'GET', '/children/me', { token: back.accessToken })).statusCode).toBe(200);
      });

      it('keeps everything when signOutDevices is false', async () => {
        const tokenVersionBefore = (await t.prisma.user.findUniqueOrThrow({ where: { id: w.child.userId } })).tokenVersion;

        const next = await issueAsParent(t, w.parent, w.child.childId, { signOutDevices: false });

        expect(next.temporaryPassword).toMatch(TEMP_PASSWORD);
        expect(await t.prisma.userSession.count({ where: { userId: w.child.userId, revokedAt: null } })).toBe(2);
        expect((await t.prisma.user.findUniqueOrThrow({ where: { id: w.child.userId } })).tokenVersion).toBe(tokenVersionBefore);
        expect(await t.prisma.fcmToken.count({ where: { userId: w.child.userId } })).toBe(1);
        expect(rt.events).toEqual([]);
        const refresh = await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: session.refreshToken } });
        expect(refresh.statusCode).toBe(200);
      });
    });

    it('resolves the open recovery requests: RESTORED, with signedOutAt only when devices were signed out', async () => {
      const cred = await issueAsParent(t, w.parent, w.child.childId, { login: 'resolve.case1' });
      const open = async () => {
        const res = await api(t, 'POST', '/auth/child-recovery', { payload: { login: cred.login, channel: 'PARENT' } });
        expect(res.statusCode).toBe(202);
        return res.json() as { requestId: string; pollToken: string };
      };
      const first = await open();

      await issueAsParent(t, w.parent, w.child.childId, { signOutDevices: false });
      const second = await open();
      await issueAsParent(t, w.parent, w.child.childId, { signOutDevices: true });

      const poll = async (r: { requestId: string; pollToken: string }) =>
        (await api(t, 'GET', `/auth/child-recovery/${r.requestId}?token=${encodeURIComponent(r.pollToken)}`)).json();
      expect(await poll(first)).toMatchObject({ status: 'RESTORED', channel: 'PARENT', signedOutAt: null, restoredAt: expect.any(String) });
      expect(await poll(second)).toMatchObject({ status: 'RESTORED', signedOutAt: expect.any(String), restoredAt: expect.any(String) });
    });

    it('lifts the lock so the child can sign in again immediately after a reset', async () => {
      const clock = controlClock(t);
      const cred = await issueAsParent(t, w.parent, w.child.childId);
      for (let i = 0; i < 5; i++) await childLogin(t, cred.login, 'Noto-togri1');
      expect((await childLogin(t, cred.login, cred.temporaryPassword)).statusCode).toBe(429);

      const next = await issueAsParent(t, w.parent, w.child.childId);

      expect((await childLogin(t, next.login, next.temporaryPassword)).statusCode).toBe(200);
      expect(clock.now()).toBeInstanceOf(Date);
    });
  });

  describe('kirish huquqlari (ota-ona)', () => {
    it('another parent gets 403 on GET and POST and nothing is created', async () => {
      const stranger = await createParent(t.prisma);

      expect((await get(stranger.token)).statusCode).toBe(403);
      expect((await post({}, stranger.token)).statusCode).toBe(403);
      expect(await t.prisma.childCredential.count()).toBe(0);
    });

    it("another parent cannot reset a child's existing credential", async () => {
      const cred = await issueAsParent(t, w.parent, w.child.childId);
      const stranger = await createParent(t.prisma);

      expect((await post({}, stranger.token)).statusCode).toBe(403);

      const row = await credentialRow();
      expect(row.login).toBe(cred.login);
      expect((await childLogin(t, cred.login, cred.temporaryPassword)).statusCode).toBe(200);
    });

    it('an unknown child answers 404', async () => {
      const missing = '00000000-0000-4000-8000-000000000000';

      expect((await get(w.parent.token, missing)).statusCode).toBe(404);
      expect((await post({}, w.parent.token, missing)).statusCode).toBe(404);
    });

    it("a child token cannot read or issue credentials (not even its own)", async () => {
      expect((await get(w.child.token)).statusCode).toBe(403);
      expect((await post({}, w.child.token)).statusCode).toBe(403);
    });

    it('requires a token', async () => {
      expect((await api(t, 'GET', url())).statusCode).toBe(401);
      expect((await api(t, 'POST', url(), { payload: {} })).statusCode).toBe(401);
    });

    it('does not leak credentials through the existing child endpoints', async () => {
      const cred = await issueAsParent(t, w.parent, w.child.childId);

      const bodies = [
        (await api(t, 'GET', `/children/${w.child.childId}`, { token: w.parent.token })).body,
        (await api(t, 'GET', '/children', { token: w.parent.token })).body,
        (await api(t, 'GET', `/children/${w.child.childId}`, { token: w.child.token })).body,
      ];
      for (const body of bodies) {
        expect(body).not.toContain(cred.login);
        expect(body).not.toContain('passwordHash');
        expect(body).not.toContain(cred.temporaryPassword);
      }
    });
  });
});
