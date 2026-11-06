// Kirish (K1): bola login/parol bilan kirishi (child-login + child-setup), noto'g'ri login / parol uchun bir xil javob,
// brute-force himoyasi (15 daqiqada 5 xato blok, soxta soat, mavjud bo'lmagan loginlar, IP limiti).

import { resetDb } from './db';
import { TestChild, TestParent } from './factories';
import {
  api,
  childLogin,
  controlClock,
  decode,
  device,
  familyOf,
  issueAsParent,
  IssuedCredential,
  loginPlain,
  loginThroughSetup,
  OWN_PASSWORD,
  restoreClock,
} from './kirish-fixtures';
import { createTestApp, TestApp } from './test-app';

const MIN = 60_000;
const INVALID = { statusCode: 401, code: 'INVALID_CREDENTIALS', message: 'Invalid credentials' };

describe('Kirish K1: bola kirishi (login / parol)', () => {
  let t: TestApp;
  let parent: TestParent;
  let child: TestChild;
  let cred: IssuedCredential;
  let unknownSeq = 0;
  const unknownLogin = () => `nobody.u${(unknownSeq += 1)}`;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    ({ parent, child } = await familyOf(t, 'Aziza Karimova'));
    cred = await issueAsParent(t, parent, child.childId);
  });

  afterEach(() => {
    jest.restoreAllMocks();
    restoreClock(t);
  });

  afterAll(() => t.close());

  const row = () => t.prisma.childCredential.findUniqueOrThrow({ where: { childId: child.childId } });
  const refresh = (refreshToken: string) => api(t, 'POST', '/auth/refresh', { payload: { refreshToken } });
  const wrongLogin = (login = cred.login, ip?: string) => childLogin(t, login, 'Noto-togri1', device(), ip);

  describe('POST /auth/child-login + /auth/child-setup', () => {
    it('answers SETUP_REQUIRED for the temporary password: setupToken and the child, but no session or tokens', async () => {
      const res = await childLogin(t, cred.login, cred.temporaryPassword);

      expect(res.statusCode).toBe(200);
      expect(res.headers['cache-control']).toBe('no-store');
      const body = res.json();
      expect(Object.keys(body).sort()).toEqual(['child', 'setupToken', 'status']);
      expect(body).toMatchObject({ status: 'SETUP_REQUIRED', child: { id: child.childId, name: 'Aziza Karimova' } });
      expect(Object.keys(body.child).sort()).toEqual(['id', 'name']);
      expect(await t.prisma.userSession.count()).toBe(0);
      // Setup tokeni 15 daqiqalik, access tokendan boshqa maqsad va auditoriya bilan.
      const claims = decode(t, body.setupToken) as { exp: number; iat: number; aud: string; purpose: string };
      expect(claims.exp - claims.iat).toBe(900);
      expect(claims).toMatchObject({ aud: 'farzandim-child-setup', purpose: 'child-setup' });
    });

    it('setup sets the own password and returns the OK body with the contract shape', async () => {
      const first = (await childLogin(t, cred.login, cred.temporaryPassword)).json();

      const res = await api(t, 'POST', '/auth/child-setup', {
        payload: { setupToken: first.setupToken, newPassword: OWN_PASSWORD, device: device('install-a', 'ios', 'iPhone 14') },
      });

      expect(res.statusCode).toBe(200);
      expect(res.headers['cache-control']).toBe('no-store');
      const body = res.json();
      expect(Object.keys(body).sort()).toEqual(['accessToken', 'child', 'deviceRole', 'refreshToken', 'sessionId', 'status', 'user']);
      expect(body).toMatchObject({
        status: 'OK',
        child: { id: child.childId, name: 'Aziza Karimova' },
        user: { id: child.userId },
      });
      expect(Object.keys(body.user)).toEqual(['id']);
      expect(await row()).toMatchObject({ mustChangePassword: false, failedLogins: 0, lockedUntil: null });
      expect((await row()).passwordChangedAt).not.toBeNull();
      expect((await row()).lastLoginAt).not.toBeNull();
    });

    it('stores the LOGIN session without IP or user agent (child data minimization)', async () => {
      const session = await loginThroughSetup(t, cred, device('install-a', 'ios', 'iPhone 14'));

      const stored = await t.prisma.userSession.findUniqueOrThrow({ where: { id: session.sessionId } });
      expect(stored).toMatchObject({
        userId: child.userId,
        kind: 'LOGIN',
        deviceId: 'install-a',
        deviceModel: 'iPhone 14',
        platform: 'ios',
        ipAddress: null,
        userAgent: null,
        city: null,
        country: null,
        revokedAt: null,
        revokedReason: null,
      });
    });

    it('issues tokens with sid and the child role that work on child endpoints', async () => {
      const session = await loginThroughSetup(t, cred);

      expect(decode(t, session.accessToken)).toMatchObject({
        userId: child.userId,
        role: 'CHILD',
        tokenVersion: 0,
        sid: session.sessionId,
        aud: 'farzandim-consumer',
      });
      const me = await api(t, 'GET', '/children/me', { token: session.accessToken });
      expect(me.statusCode).toBe(200);
      expect(me.json()).toMatchObject({ id: child.childId, educationLanguage: null });
    });

    it('rotates the refresh token (same sid); a reused old refresh token is refused', async () => {
      const session = await loginThroughSetup(t, cred);

      const next = await refresh(session.refreshToken);

      expect(next.statusCode).toBe(200);
      expect(decode(t, next.json().accessToken)).toMatchObject({ sid: session.sessionId, role: 'CHILD' });
      const reused = await refresh(session.refreshToken);
      expect(reused.statusCode).toBe(401);
      expect((await refresh(next.json().refreshToken)).statusCode).toBe(200);
    });

    it('later logins with the own password return OK directly and keep one user for all devices', async () => {
      const first = await loginThroughSetup(t, cred, device('install-a'));

      const second = await loginPlain(t, cred.login, device('install-b', 'ios', 'iPad'));

      expect(second.userId).toBe(first.userId);
      expect(second.userId).toBe(child.userId);
      expect(second.sessionId).not.toBe(first.sessionId);
      expect((await row()).lastLoginAt).not.toBeNull();
    });

    it('treats the login case- and whitespace-insensitively', async () => {
      const res = await childLogin(t, `  ${cred.login.toUpperCase()} `, cred.temporaryPassword);

      expect(res.statusCode).toBe(200);
      expect(res.json().status).toBe('SETUP_REQUIRED');
    });

    it('the temporary password stops working once the own password is set', async () => {
      await loginThroughSetup(t, cred);

      expect((await childLogin(t, cred.login, cred.temporaryPassword)).statusCode).toBe(401);
    });

    it.each([
      ['missing device', { login: 'aziza.k24', password: 'x' }],
      ['unknown field', { login: 'aziza.k24', password: 'x', device: device(), extra: 1 }],
      ['unknown platform', { login: 'aziza.k24', password: 'x', device: { id: 'a', platform: 'web' } }],
      ['device id too long', { login: 'aziza.k24', password: 'x', device: { id: 'a'.repeat(65), platform: 'ios' } }],
      ['model too long', { login: 'aziza.k24', password: 'x', device: { id: 'a', model: 'm'.repeat(61), platform: 'ios' } }],
      ['empty password', { login: 'aziza.k24', password: '', device: device() }],
      ['non-string login', { login: 5, password: 'x', device: device() }],
      ['oversized login', { login: 'a'.repeat(65), password: 'x', device: device() }],
    ])('rejects a malformed body (%s) with 400', async (_name, payload) => {
      const res = await api(t, 'POST', '/auth/child-login', { payload });

      expect(res.statusCode).toBe(400);
    });
  });

  describe('noto\'g\'ri login / parol: bir xil javob, mavjudlik fosh bo\'lmaydi', () => {
    it('wrong password, unknown login and malformed login all answer the identical 401 body', async () => {
      const answers = [
        await wrongLogin(),
        await wrongLogin(unknownLogin()),
        await wrongLogin('N o!'),
        await wrongLogin('x'),
        await wrongLogin('Азиза.к24'),
      ];

      for (const res of answers) {
        expect(res.statusCode).toBe(401);
        expect(res.json()).toEqual(INVALID);
      }
    });

    it('does a bcrypt comparison for unknown logins too (no early return that leaks timing)', async () => {
      const bcrypt = jest.requireActual<typeof import('bcryptjs')>('bcryptjs');
      const compare = jest.spyOn(bcrypt, 'compare');

      await wrongLogin(unknownLogin());
      await wrongLogin('!!');

      expect(compare).toHaveBeenCalledTimes(2);
    });

    it('takes a comparable time for an unknown and a known login (same order of magnitude)', async () => {
      const timed = async (login: string) => {
        const start = process.hrtime.bigint();
        await wrongLogin(login);
        return Number(process.hrtime.bigint() - start) / 1e6;
      };
      await timed(cred.login); // isitish
      const known = await timed(cred.login);
      const unknown = await timed(unknownLogin());

      expect(unknown).toBeGreaterThan(known / 4);
      expect(known).toBeGreaterThan(unknown / 4);
    });
  });

  describe('blok: 15 daqiqada 5 xato -> 15 daqiqaga', () => {
    it('locks on the 5th wrong password (that answer is already 429 LOCKED with retryAfterSeconds)', async () => {
      const clock = controlClock(t);
      const statuses: number[] = [];
      for (let i = 0; i < 5; i++) {
        statuses.push((await wrongLogin()).statusCode);
        clock.advance(1_000);
      }

      expect(statuses).toEqual([401, 401, 401, 401, 429]);
      const locked = await wrongLogin();
      expect(locked.statusCode).toBe(429);
      expect(locked.json()).toMatchObject({ statusCode: 429, code: 'LOCKED', retryAfterSeconds: expect.any(Number) });
      expect(locked.json().retryAfterSeconds).toBeGreaterThan(14 * 60);
      expect(locked.json().retryAfterSeconds).toBeLessThanOrEqual(15 * 60);
      expect((await row()).lockedUntil).not.toBeNull();
    });

    it('keeps rejecting even the correct password while locked, then unlocks after 15 minutes', async () => {
      const clock = controlClock(t);
      await loginThroughSetup(t, cred);
      for (let i = 0; i < 5; i++) await wrongLogin();

      expect((await childLogin(t, cred.login, OWN_PASSWORD)).statusCode).toBe(429);
      clock.advance(14 * MIN);
      expect((await childLogin(t, cred.login, OWN_PASSWORD)).statusCode).toBe(429);
      clock.advance(2 * MIN);

      const ok = await childLogin(t, cred.login, OWN_PASSWORD);
      expect(ok.statusCode).toBe(200);
      expect(await row()).toMatchObject({ failedLogins: 0, lockedUntil: null });
    });

    it('counts only failures inside one 15 minute window, and a success clears them', async () => {
      const clock = controlClock(t);
      await loginThroughSetup(t, cred);
      for (let i = 0; i < 4; i++) await wrongLogin();
      clock.advance(16 * MIN);
      for (let i = 0; i < 4; i++) expect((await wrongLogin()).statusCode).toBe(401);

      expect((await childLogin(t, cred.login, OWN_PASSWORD)).statusCode).toBe(200);
      for (let i = 0; i < 4; i++) expect((await wrongLogin()).statusCode).toBe(401);
      expect((await childLogin(t, cred.login, OWN_PASSWORD)).statusCode).toBe(200);
    });

    it('counts parallel wrong attempts atomically (no extra guesses slip past the lock)', async () => {
      const results = await Promise.all(Array.from({ length: 12 }, () => wrongLogin()));

      expect(results.filter((r) => r.statusCode === 429).length).toBeGreaterThanOrEqual(8);
      expect((await row()).lockedUntil).not.toBeNull();
      expect((await childLogin(t, cred.login, cred.temporaryPassword)).statusCode).toBe(429);
    });

    it('a locked account does not affect other children', async () => {
      const other = await familyOf(t, 'Bobur Aliyev');
      const otherCred = await issueAsParent(t, other.parent, other.child.childId);
      for (let i = 0; i < 5; i++) await wrongLogin();

      expect((await childLogin(t, otherCred.login, otherCred.temporaryPassword)).statusCode).toBe(200);
    });

    it('unknown logins get the same lock behaviour: 429 from the 5th failure, so existence is not revealed', async () => {
      const clock = controlClock(t);
      const login = unknownLogin();
      const statuses: number[] = [];
      for (let i = 0; i < 6; i++) statuses.push((await wrongLogin(login)).statusCode);

      expect(statuses).toEqual([401, 401, 401, 401, 429, 429]);
      const locked = await wrongLogin(login);
      expect(locked.json()).toMatchObject({ code: 'LOCKED', retryAfterSeconds: expect.any(Number) });
      clock.advance(16 * MIN);
      expect((await wrongLogin(login)).statusCode).toBe(401);
    });

    it('known and unknown logins are indistinguishable by status sequence and body shape', async () => {
      const sequence = async (login: string) => {
        const out: Array<{ status: number; keys: string[] }> = [];
        for (let i = 0; i < 6; i++) {
          const res = await wrongLogin(login);
          out.push({ status: res.statusCode, keys: Object.keys(res.json()).sort() });
        }
        return out;
      };

      expect(await sequence(cred.login)).toEqual(await sequence(unknownLogin()));
    });

    it('writes one audit entry when a lock starts, without the login', async () => {
      for (let i = 0; i < 6; i++) await wrongLogin();

      const rows = await t.prisma.auditLog.findMany({ where: { action: 'AUTH_CHILD_LOGIN_LOCKED' } });
      expect(rows).toHaveLength(1);
      expect(JSON.stringify(rows)).not.toContain(cred.login);
      expect(rows[0]!.ipAddress).toBeNull();
    });
  });

  describe('IP limiti: 10 daqiqada 30 ta', () => {
    it('answers a structured 429 RATE_LIMITED from the 31st request of one IP, other IPs are unaffected', async () => {
      const ip = '203.0.113.9';
      const results: number[] = [];
      for (let i = 0; i < 31; i++) results.push((await wrongLogin(unknownLogin(), ip)).statusCode);

      expect(results.slice(0, 30).every((s) => s === 401)).toBe(true);
      expect(results[30]).toBe(429);
      const blocked = await wrongLogin(unknownLogin(), ip);
      expect(blocked.json()).toMatchObject({ statusCode: 429, code: 'RATE_LIMITED', retryAfterSeconds: expect.any(Number) });
      expect((await wrongLogin(unknownLogin(), '203.0.113.10')).statusCode).toBe(401);
    }, 60_000);
  });

});
