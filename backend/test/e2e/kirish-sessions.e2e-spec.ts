// Kirish (K1): LOGIN sessiyalari (3 ta chegara, bola foydalanuvchisi), "sessiya yopildi" sabablari (A12) va
// bola parolini almashtirish (POST /auth/child/password).

import { resetDb } from './db';
import { TestChild, TestParent } from './factories';
import {
  api,
  captureRealtime,
  childLogin,
  device,
  familyOf,
  issueAsParent,
  IssuedCredential,
  legacyRefreshToken,
  loginPlain,
  loginThroughSetup,
  OWN_PASSWORD,
  restoreClock,
} from './kirish-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('Kirish K1: bola sessiyalari', () => {
  let t: TestApp;
  let parent: TestParent;
  let child: TestChild;
  let cred: IssuedCredential;
  let rt: ReturnType<typeof captureRealtime>;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    ({ parent, child } = await familyOf(t, 'Aziza Karimova'));
    cred = await issueAsParent(t, parent, child.childId);
    rt = captureRealtime(t);
  });

  afterEach(() => {
    jest.restoreAllMocks();
    restoreClock(t);
  });

  afterAll(() => t.close());

  const row = () => t.prisma.childCredential.findUniqueOrThrow({ where: { childId: child.childId } });
  const activeSessions = () =>
    t.prisma.userSession.findMany({ where: { userId: child.userId, kind: 'LOGIN', revokedAt: null }, orderBy: { createdAt: 'asc' } });
  const refresh = (refreshToken: string) => api(t, 'POST', '/auth/refresh', { payload: { refreshToken } });

  describe('LOGIN sessiyalari: ko\'pi bilan 3 ta', () => {
    it('the 4th login revokes the OLDEST session (SIGNED_IN_ELSEWHERE) and announces it', async () => {
      const a = await loginThroughSetup(t, cred, device('dev-a'));
      const b = await loginPlain(t, cred.login, device('dev-b'));
      const c = await loginPlain(t, cred.login, device('dev-c'));
      rt.clear();

      const d = await loginPlain(t, cred.login, device('dev-d'));

      const oldest = await t.prisma.userSession.findUniqueOrThrow({ where: { id: a.sessionId } });
      expect(oldest.revokedAt).not.toBeNull();
      expect(oldest.revokedReason).toBe('SIGNED_IN_ELSEWHERE');
      expect((await activeSessions()).map((s) => s.id)).toEqual([b.sessionId, c.sessionId, d.sessionId]);
      const closed = rt.of(child.userId, 'session:closed');
      expect(closed).toHaveLength(1);
      expect(closed[0]!.payload).toEqual({ sessionIds: [a.sessionId], reason: 'SIGNED_IN_ELSEWHERE' });
    });

    it('the evicted device learns the reason on refresh (A12 even when the socket message was missed)', async () => {
      const a = await loginThroughSetup(t, cred, device('dev-a'));
      await loginPlain(t, cred.login, device('dev-b'));
      await loginPlain(t, cred.login, device('dev-c'));
      await loginPlain(t, cred.login, device('dev-d'));

      const res = await refresh(a.refreshToken);

      expect(res.statusCode).toBe(401);
      expect(res.json()).toEqual({ statusCode: 401, code: 'SESSION_REVOKED', reason: 'SIGNED_IN_ELSEWHERE', message: 'Session revoked' });
    });

    it('a login from the SAME device replaces its old session instead of using a slot', async () => {
      const a1 = await loginThroughSetup(t, cred, device('dev-a'));
      const b = await loginPlain(t, cred.login, device('dev-b'));
      rt.clear();

      const a2 = await loginPlain(t, cred.login, device('dev-a'));

      expect(a2.sessionId).not.toBe(a1.sessionId);
      const old = await t.prisma.userSession.findUniqueOrThrow({ where: { id: a1.sessionId } });
      expect(old.revokedReason).toBe('SIGNED_OUT');
      expect((await activeSessions()).map((s) => s.id)).toEqual([b.sessionId, a2.sessionId]);
      expect(rt.of(child.userId, 'session:closed')[0]!.payload).toEqual({ sessionIds: [a1.sessionId], reason: 'SIGNED_OUT' });
    });

    it('keeps exactly 3 sessions when several devices sign in at the same moment', async () => {
      await loginThroughSetup(t, cred, device('dev-0'));

      const results = await Promise.all(
        [1, 2, 3, 4, 5].map((i) => childLogin(t, cred.login, OWN_PASSWORD, device(`dev-${i}`))),
      );

      expect(results.every((r) => r.statusCode === 200)).toBe(true);
      expect(await activeSessions()).toHaveLength(3);
      expect(await t.prisma.userSession.count({ where: { userId: child.userId, revokedAt: { not: null } } })).toBe(3);
    });

    it('does not count the legacy paired device or the parent sessions toward the cap', async () => {
      const parentSession = await t.prisma.userSession.create({
        data: { userId: parent.userId, jti: 'parent-jti', kind: null, deviceModel: 'Parent phone' },
      });
      for (const id of ['dev-a', 'dev-b', 'dev-c']) {
        if (id === 'dev-a') await loginThroughSetup(t, cred, device(id));
        else await loginPlain(t, cred.login, device(id));
      }

      expect(await activeSessions()).toHaveLength(3);
      expect((await t.prisma.userSession.findUniqueOrThrow({ where: { id: parentSession.id } })).revokedAt).toBeNull();
      expect((await refresh(legacyRefreshToken(child.userId))).statusCode).toBe(200);
    });

    it('creates the child user when the child has none yet and links it to the profile', async () => {
      const lone = await familyOf(t, 'Zilola Rashidova');
      await t.prisma.child.update({ where: { id: lone.child.childId }, data: { childUserId: null, pairedAt: null } });
      const loneCred = await issueAsParent(t, lone.parent, lone.child.childId);

      const session = await loginThroughSetup(t, loneCred);

      const profile = await t.prisma.child.findUniqueOrThrow({ where: { id: lone.child.childId } });
      expect(profile.childUserId).toBe(session.userId);
      expect(session.userId).not.toBe(lone.child.userId);
      const user = await t.prisma.user.findUniqueOrThrow({ where: { id: session.userId } });
      expect(user).toMatchObject({ role: 'CHILD', isActive: true, name: 'Zilola Rashidova' });
      expect(profile.pairedAt).toBeNull();
    });

    it('creates a fresh child user when the previous one was deactivated (re-paired or unpaired)', async () => {
      await t.prisma.user.update({ where: { id: child.userId }, data: { isActive: false } });

      const session = await loginThroughSetup(t, cred);

      expect(session.userId).not.toBe(child.userId);
      expect((await t.prisma.child.findUniqueOrThrow({ where: { id: child.childId } })).childUserId).toBe(session.userId);
    });

    it('does not create two child users when the first sign-ins race', async () => {
      const lone = await familyOf(t, 'Zilola Rashidova');
      await t.prisma.child.update({ where: { id: lone.child.childId }, data: { childUserId: null, pairedAt: null } });
      const loneCred = await issueAsParent(t, lone.parent, lone.child.childId);
      await loginThroughSetup(t, loneCred, device('dev-0'));
      await t.prisma.child.update({ where: { id: lone.child.childId }, data: { childUserId: null } });

      const results = await Promise.all(
        [1, 2, 3].map((i) => childLogin(t, loneCred.login, OWN_PASSWORD, device(`dev-${i}`))),
      );

      const userIds = new Set(results.map((r) => r.json().user.id));
      expect(userIds.size).toBe(1);
      expect((await t.prisma.child.findUniqueOrThrow({ where: { id: lone.child.childId } })).childUserId).toBe([...userIds][0]);
    });
  });

  describe('sessiyani yopish sabablari (A12)', () => {
    it('POST /auth/logout ends only that LOGIN session (SIGNED_OUT) and tells the room', async () => {
      const a = await loginThroughSetup(t, cred, device('dev-a'));
      const b = await loginPlain(t, cred.login, device('dev-b'));
      rt.clear();

      const res = await api(t, 'POST', '/auth/logout', { token: a.accessToken });

      expect(res.statusCode).toBe(200);
      const closed = await t.prisma.userSession.findUniqueOrThrow({ where: { id: a.sessionId } });
      expect(closed).toMatchObject({ revokedReason: 'SIGNED_OUT' });
      expect(closed.revokedAt).not.toBeNull();
      expect((await t.prisma.userSession.findUniqueOrThrow({ where: { id: b.sessionId } })).revokedAt).toBeNull();
      expect(rt.of(child.userId, 'session:closed')[0]!.payload).toEqual({ sessionIds: [a.sessionId], reason: 'SIGNED_OUT' });
      expect((await refresh(a.refreshToken)).json()).toMatchObject({ code: 'SESSION_REVOKED', reason: 'SIGNED_OUT' });
      expect((await refresh(b.refreshToken)).statusCode).toBe(200);
      expect((await t.prisma.user.findUniqueOrThrow({ where: { id: child.userId } })).tokenVersion).toBe(0);
    });

    it('DELETE /auth/sessions/:id from another device closes that session as SIGNED_OUT', async () => {
      const a = await loginThroughSetup(t, cred, device('dev-a'));
      const b = await loginPlain(t, cred.login, device('dev-b'));

      const res = await api(t, 'DELETE', `/auth/sessions/${a.sessionId}`, { token: b.accessToken });

      expect(res.statusCode).toBe(200);
      expect((await t.prisma.userSession.findUniqueOrThrow({ where: { id: a.sessionId } })).revokedReason).toBe('SIGNED_OUT');
      expect((await refresh(a.refreshToken)).json()).toMatchObject({ code: 'SESSION_REVOKED', reason: 'SIGNED_OUT' });
    });

    it('DELETE /auth/sessions/others keeps the current session and closes the rest as SIGNED_OUT', async () => {
      const a = await loginThroughSetup(t, cred, device('dev-a'));
      const b = await loginPlain(t, cred.login, device('dev-b'));
      const c = await loginPlain(t, cred.login, device('dev-c'));

      const res = await api(t, 'DELETE', '/auth/sessions/others', { token: c.accessToken });

      expect(res.json()).toEqual({ count: 2 });
      for (const closed of [a, b]) {
        expect((await t.prisma.userSession.findUniqueOrThrow({ where: { id: closed.sessionId } })).revokedReason).toBe('SIGNED_OUT');
      }
      expect((await refresh(c.refreshToken)).statusCode).toBe(200);
    });

    it('a session revoked before this release (no reason) answers SESSION_REVOKED with reason null', async () => {
      const a = await loginThroughSetup(t, cred);
      await t.prisma.userSession.update({ where: { id: a.sessionId }, data: { revokedAt: new Date(), revokedReason: null } });

      const res = await refresh(a.refreshToken);

      expect(res.json()).toEqual({ statusCode: 401, code: 'SESSION_REVOKED', reason: null, message: 'Session revoked' });
    });

    it('a missing session (deleted) is also SESSION_REVOKED', async () => {
      const a = await loginThroughSetup(t, cred);
      await t.prisma.userSession.delete({ where: { id: a.sessionId } });

      expect((await refresh(a.refreshToken)).json()).toMatchObject({ code: 'SESSION_REVOKED', reason: null });
    });
  });

  describe('POST /auth/child/password', () => {
    const change = (token: string, currentPassword: string, newPassword: string) =>
      api(t, 'POST', '/auth/child/password', { token, payload: { currentPassword, newPassword } });

    it('changes the password (204), closes the OTHER login sessions and keeps the current one', async () => {
      const a = await loginThroughSetup(t, cred, device('dev-a'));
      const b = await loginPlain(t, cred.login, device('dev-b'));
      const c = await loginPlain(t, cred.login, device('dev-c'));
      rt.clear();

      const res = await change(a.accessToken, OWN_PASSWORD, 'Yangi-parol-77');

      expect(res.statusCode).toBe(204);
      expect(res.body).toBe('');
      for (const closed of [b, c]) {
        expect(await t.prisma.userSession.findUniqueOrThrow({ where: { id: closed.sessionId } })).toMatchObject({
          revokedReason: 'SIGNED_OUT',
        });
      }
      expect((await t.prisma.userSession.findUniqueOrThrow({ where: { id: a.sessionId } })).revokedAt).toBeNull();
      const event = rt.of(child.userId, 'session:closed');
      expect(event).toHaveLength(1);
      expect([...(event[0]!.payload.sessionIds as string[])].sort()).toEqual([b.sessionId, c.sessionId].sort());
      expect((await childLogin(t, cred.login, OWN_PASSWORD)).statusCode).toBe(401);
      expect((await childLogin(t, cred.login, 'Yangi-parol-77')).statusCode).toBe(200);
      expect((await refresh(a.refreshToken)).statusCode).toBe(200);
      expect((await row()).passwordChangedAt).not.toBeNull();
    });

    it('a wrong current password answers 400 WRONG_PASSWORD and counts toward the lock', async () => {
      const a = await loginThroughSetup(t, cred);

      const res = await change(a.accessToken, 'Xato-parol-1', 'Yangi-parol-77');

      expect(res.statusCode).toBe(400);
      expect(res.json()).toMatchObject({ statusCode: 400, code: 'WRONG_PASSWORD' });
      expect((await row()).failedLogins).toBe(1);
      expect((await childLogin(t, cred.login, OWN_PASSWORD)).statusCode).toBe(200);
    });

    it('locks like a login when the current password is guessed with a stolen access token', async () => {
      const a = await loginThroughSetup(t, cred);
      const answers: number[] = [];
      for (let i = 0; i < 5; i++) answers.push((await change(a.accessToken, 'Xato-parol-1', 'Yangi-parol-77')).statusCode);

      expect(answers).toEqual([400, 400, 400, 400, 429]);
      expect((await change(a.accessToken, OWN_PASSWORD, 'Yangi-parol-77')).json()).toMatchObject({ code: 'LOCKED' });
      expect((await childLogin(t, cred.login, OWN_PASSWORD)).statusCode).toBe(429);
    });

    /** `bcrypt.compare` parolni tekshirib bo'lgach darvozada kutadi: parallel o'zgarish aynan shu oynada bo'ladi. */
    function gateCompare() {
      const bcrypt = jest.requireActual<typeof import('bcryptjs')>('bcryptjs');
      const realCompare = bcrypt.compare.bind(bcrypt) as (...args: unknown[]) => Promise<boolean>;
      let reached!: () => void;
      let open!: () => void;
      const atGate = new Promise<void>((resolve) => (reached = resolve));
      const gate = new Promise<void>((resolve) => (open = resolve));
      jest.spyOn(bcrypt, 'compare').mockImplementation((async (...args: unknown[]) => {
        const ok = await realCompare(...args);
        reached();
        await gate;
        return ok;
      }) as never);
      return { atGate, open, restore: () => jest.restoreAllMocks() };
    }

    it('re-checks the lock after the slow comparison: a correct guess that finishes after the lock is refused (429 LOCKED)', async () => {
      const a = await loginThroughSetup(t, cred);
      const gate = gateCompare();

      const pending = change(a.accessToken, OWN_PASSWORD, 'Yangi-parol-77');
      await gate.atGate;
      await t.prisma.childCredential.update({
        where: { childId: child.childId },
        data: { failedLogins: 5, failedWindowStartedAt: new Date(), lockedUntil: new Date(Date.now() + 600_000) },
      });
      gate.open();
      const res = await pending;
      gate.restore();

      expect(res.statusCode).toBe(429);
      expect(res.json()).toMatchObject({ statusCode: 429, code: 'LOCKED' });
      await t.prisma.childCredential.update({
        where: { childId: child.childId },
        data: { failedLogins: 0, failedWindowStartedAt: null, lockedUntil: null },
      });
      expect((await childLogin(t, cred.login, OWN_PASSWORD)).statusCode).toBe(200); // parol o'zgarmagan
      expect((await childLogin(t, cred.login, 'Yangi-parol-77')).statusCode).toBe(401);
    });

    it('refuses with 409 PASSWORD_CHANGED when a credential reset lands while the password is being verified', async () => {
      const a = await loginThroughSetup(t, cred);
      const gate = gateCompare();

      const pending = change(a.accessToken, OWN_PASSWORD, 'Yangi-parol-77');
      await gate.atGate;
      const next = await issueAsParent(t, parent, child.childId, { signOutDevices: false });
      gate.open();
      const res = await pending;
      gate.restore();

      expect(res.statusCode).toBe(409);
      expect(res.json()).toMatchObject({ statusCode: 409, code: 'PASSWORD_CHANGED' });
      const fresh = await childLogin(t, next.login, next.temporaryPassword);
      expect(fresh.json().status).toBe('SETUP_REQUIRED'); // yangi vaqtinchalik parol buzilmagan
    });

    it('limits the attempts to 10 per 15 minutes per user (structured 429 RATE_LIMITED); other children are unaffected', async () => {
      const a = await loginThroughSetup(t, cred);
      const statuses: number[] = [];

      // To'g'ri joriy parol + zaif yangi parol: blokka sanalmaydi, lekin har urinish bcrypt (CPU) — throttle kerak.
      for (let i = 0; i < 11; i++) statuses.push((await change(a.accessToken, OWN_PASSWORD, 'Ab1')).statusCode);

      expect(statuses).toEqual([...Array<number>(10).fill(400), 429]);
      const blocked = await change(a.accessToken, OWN_PASSWORD, 'Ab1');
      expect(blocked.json()).toEqual({ statusCode: 429, code: 'RATE_LIMITED', message: 'Too many requests', retryAfterSeconds: expect.any(Number) });
      const other = await familyOf(t, 'Bobur Aliyev');
      const otherCred = await issueAsParent(t, other.parent, other.child.childId);
      const own = await loginThroughSetup(t, otherCred);
      expect((await change(own.accessToken, OWN_PASSWORD, 'Yangi-parol-77')).statusCode).toBe(204);
    }, 120_000);

    it.each([
      ['too short', 'Ab1', 'TOO_SHORT'],
      ['same as the current password', OWN_PASSWORD, 'SAME_AS_CURRENT'],
      ['common', 'Password1', 'TOO_COMMON'],
    ])('rejects a new password that is %s', async (_name, newPassword, reason) => {
      const a = await loginThroughSetup(t, cred);

      const res = await change(a.accessToken, OWN_PASSWORD, newPassword);

      expect(res.statusCode).toBe(400);
      expect(res.json()).toMatchObject({ code: 'WEAK_PASSWORD', reason });
      expect((await childLogin(t, cred.login, OWN_PASSWORD)).statusCode).toBe(200);
    });

    it('answers 404 NO_CREDENTIAL for a child paired by family code that has no login', async () => {
      const lone = await familyOf(t, 'Bobur Aliyev');

      const res = await change(lone.child.token, 'Eski-parol-1', 'Yangi-parol-77');

      expect(res.statusCode).toBe(404);
      expect(res.json()).toMatchObject({ code: 'NO_CREDENTIAL' });
    });

    it('is CHILD-only and needs a token', async () => {
      expect((await change(parent.token, OWN_PASSWORD, 'Yangi-parol-77')).statusCode).toBe(403);
      expect((await api(t, 'POST', '/auth/child/password', { payload: { currentPassword: 'a', newPassword: 'b' } })).statusCode).toBe(401);
    });

    it("another child's token cannot change this child's password", async () => {
      const other = await familyOf(t, 'Bobur Aliyev');
      await issueAsParent(t, other.parent, other.child.childId);

      const res = await change(other.child.token, OWN_PASSWORD, 'Yangi-parol-77');

      expect(res.statusCode).toBe(400); // o'z credential'iga qarab tekshiriladi, boshqasiga emas
      await loginThroughSetup(t, cred);
      expect((await childLogin(t, cred.login, OWN_PASSWORD)).statusCode).toBe(200);
    });
  });

});
