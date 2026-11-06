// Kirish (K1): bola login/parol bilan kirishi, birinchi kirishda parol o'rnatish (bir martalik setupToken),
// brute-force himoyasi (blok, IP limiti, mavjudlik fosh bo'lmasligi), LOGIN sessiyalari (3 ta chegara),
// "sessiya yopildi" sabablari (A12), parol almashtirish va qurilmalar ro'yxati.

import { JwtService } from '@nestjs/jwt';
import { resetDb } from './db';
import { TestChild, TestParent } from './factories';
import {
  api,
  captureRealtime,
  childLogin,
  controlClock,
  decode,
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

const MIN = 60_000;
const INVALID = { statusCode: 401, code: 'INVALID_CREDENTIALS', message: 'Invalid credentials' };

describe('Kirish K1: bola login/parol bilan kirishi', () => {
  let t: TestApp;
  let parent: TestParent;
  let child: TestChild;
  let cred: IssuedCredential;
  let rt: ReturnType<typeof captureRealtime>;
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

  describe('setupToken: 15 daqiqa, bir martalik', () => {
    const setup = (setupToken: string, newPassword = OWN_PASSWORD, dev = device()) =>
      api(t, 'POST', '/auth/child-setup', { payload: { setupToken, newPassword, device: dev } });
    const tokenOf = async () => (await childLogin(t, cred.login, cred.temporaryPassword)).json().setupToken as string;

    it('cannot be used twice', async () => {
      const token = await tokenOf();
      expect((await setup(token)).statusCode).toBe(200);

      const again = await setup(token, 'Boshqa-parol9');

      expect(again.statusCode).toBe(401);
      expect(again.json()).toMatchObject({ code: 'SETUP_TOKEN_INVALID' });
      expect((await childLogin(t, cred.login, OWN_PASSWORD)).statusCode).toBe(200);
      expect((await childLogin(t, cred.login, 'Boshqa-parol9')).statusCode).toBe(401);
    });

    it('lets exactly one of two parallel uses win', async () => {
      const token = await tokenOf();

      const results = await Promise.all([setup(token, 'Birinchi-parol1'), setup(token, 'Ikkinchi-parol2')]);

      expect(results.map((r) => r.statusCode).sort()).toEqual([200, 401]);
      expect(await activeSessions()).toHaveLength(1);
    });

    it('is not consumed by a rejected weak password', async () => {
      const token = await tokenOf();

      const weak = await setup(token, 'abc');
      expect(weak.statusCode).toBe(400);
      expect(weak.json()).toMatchObject({ statusCode: 400, code: 'WEAK_PASSWORD', reason: 'TOO_SHORT' });

      expect((await setup(token)).statusCode).toBe(200);
    });

    it.each([
      ['Ab1', 'TOO_SHORT'],
      ['faqat-harflar', 'NEEDS_DIGIT'],
      ['1234567890', 'NEEDS_LETTER'],
      ['Qwerty123', 'TOO_COMMON'],
      ['a'.repeat(70) + '1', 'TOO_LONG'],
    ])('applies the password policy to %s (%s)', async (newPassword, reason) => {
      const res = await setup(await tokenOf(), newPassword);

      expect(res.statusCode).toBe(400);
      expect(res.json()).toMatchObject({ code: 'WEAK_PASSWORD', reason });
    });

    it('refuses to reuse the login as the password', async () => {
      const res = await setup(await tokenOf(), cred.login);

      expect(res.statusCode).toBe(400);
      expect(res.json()).toMatchObject({ code: 'WEAK_PASSWORD', reason: 'SAME_AS_LOGIN' });
    });

    it('refuses to keep the temporary password as the own password', async () => {
      // Vaqtincha parolni siyosatdan o'tadigan aniq qiymatga qo'yamiz (tasodifiy parol siyosatni buzishi mumkin).
      const bcrypt = jest.requireActual<typeof import('bcryptjs')>('bcryptjs');
      await t.prisma.childCredential.update({
        where: { childId: child.childId },
        data: { passwordHash: bcrypt.hashSync('Vaqtincha7', 4) },
      });
      const token = (await childLogin(t, cred.login, 'Vaqtincha7')).json().setupToken as string;

      const res = await setup(token, 'Vaqtincha7');

      expect(res.statusCode).toBe(400);
      expect(res.json()).toMatchObject({ code: 'WEAK_PASSWORD', reason: 'SAME_AS_CURRENT' });
      expect((await setup(token, OWN_PASSWORD)).statusCode).toBe(200);
    });

    it('expires after 15 minutes', async () => {
      const token = await tokenOf();
      const realNow = Date.now();
      jest.spyOn(Date, 'now').mockReturnValue(realNow + 15 * MIN + 5_000);

      const res = await setup(token);

      expect(res.statusCode).toBe(401);
      expect(res.json()).toMatchObject({ code: 'SETUP_TOKEN_INVALID' });
    });

    it('is invalidated by a credential reset (a token from before the reset is useless)', async () => {
      const token = await tokenOf();
      await issueAsParent(t, parent, child.childId);

      const res = await setup(token);

      expect(res.statusCode).toBe(401);
      expect(res.json()).toMatchObject({ code: 'SETUP_TOKEN_INVALID' });
    });

    it('is not usable once setup is done through another token, and garbage is refused', async () => {
      const first = await tokenOf();
      const second = await tokenOf();
      expect((await setup(first)).statusCode).toBe(200);

      expect((await setup(second)).statusCode).toBe(401);
      expect((await setup('garbage')).statusCode).toBe(401);
      expect((await api(t, 'POST', '/auth/child-setup', { payload: { newPassword: OWN_PASSWORD, device: device() } })).statusCode).toBe(400);
    });

    it('cannot be used as a Bearer access token, a refresh token, or on the WebSocket', async () => {
      const token = await tokenOf();

      expect((await api(t, 'GET', '/children/me', { token })).statusCode).toBe(401);
      expect((await api(t, 'GET', `/children/${child.childId}`, { token })).statusCode).toBe(401);
      expect((await refresh(token)).statusCode).toBe(401);
      expect(() =>
        t.app.get(JwtService).verify(token, { secret: process.env.JWT_ACCESS_SECRET }),
      ).toThrow();
    });

    it('an access or refresh token cannot be used as a setup token', async () => {
      const session = await loginThroughSetup(t, cred);

      expect((await setup(session.accessToken)).statusCode).toBe(401);
      expect((await setup(session.refreshToken)).statusCode).toBe(401);
    });

    it('a token for one child cannot set up another child', async () => {
      const other = await familyOf(t, 'Bobur Aliyev');
      const otherCred = await issueAsParent(t, other.parent, other.child.childId);
      const mine = await tokenOf();
      const theirs = (await childLogin(t, otherCred.login, otherCred.temporaryPassword)).json().setupToken as string;

      expect((await setup(mine)).statusCode).toBe(200);

      expect((await childLogin(t, otherCred.login, OWN_PASSWORD)).statusCode).toBe(401);
      expect((await setup(theirs, 'Boshqa-parol9')).statusCode).toBe(200);
    });
  });

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

  describe('GET /auth/child/devices', () => {
    it('lists the LOGIN sessions (current flagged) plus the family-code paired device', async () => {
      const a = await loginThroughSetup(t, cred, device('dev-a', 'android', 'Redmi'));
      const b = await loginPlain(t, cred.login, device('dev-b', 'ios', 'iPhone'));
      await t.prisma.child.update({
        where: { id: child.childId },
        data: { deviceModel: 'Samsung A52', androidVersion: '13', lastSeenAt: new Date('2026-11-01T10:00:00.000Z') },
      });

      const res = await api(t, 'GET', '/auth/child/devices', { token: a.accessToken });

      expect(res.statusCode).toBe(200);
      const list = res.json() as Array<Record<string, unknown>>;
      expect(list).toHaveLength(3);
      const byId = new Map(list.map((d) => [d.sessionId, d]));
      expect(byId.get(a.sessionId)).toEqual({
        sessionId: a.sessionId,
        model: 'Redmi',
        platform: 'android',
        lastSeenAt: expect.any(String),
        current: true,
        paired: false,
        main: false,
      });
      expect(byId.get(b.sessionId)).toMatchObject({ model: 'iPhone', platform: 'ios', current: false, paired: false, main: false });
      expect(byId.get(null)).toEqual({
        sessionId: null,
        model: 'Samsung A52',
        platform: 'android',
        lastSeenAt: '2026-11-01T10:00:00.000Z',
        current: false,
        paired: true,
        main: true,
      });
    });

    it('marks the paired device as current when asked with a legacy (sid-less) token', async () => {
      await loginThroughSetup(t, cred, device('dev-a'));

      const res = await api(t, 'GET', '/auth/child/devices', { token: child.token });

      const list = res.json() as Array<{ sessionId: string | null; current: boolean; paired: boolean }>;
      expect(list.find((d) => d.paired)).toMatchObject({ sessionId: null, current: true });
      expect(list.filter((d) => d.current)).toHaveLength(1);
    });

    it('shows no paired device for a child that only signs in with a login', async () => {
      const lone = await familyOf(t, 'Zilola Rashidova');
      await t.prisma.child.update({ where: { id: lone.child.childId }, data: { childUserId: null, pairedAt: null } });
      const loneCred = await issueAsParent(t, lone.parent, lone.child.childId);
      const session = await loginThroughSetup(t, loneCred);

      const list = (await api(t, 'GET', '/auth/child/devices', { token: session.accessToken })).json() as Array<{ paired: boolean }>;

      expect(list).toHaveLength(1);
      expect(list[0]!.paired).toBe(false);
    });

    it('drops a revoked session from the list and never shows other children', async () => {
      const a = await loginThroughSetup(t, cred, device('dev-a'));
      const b = await loginPlain(t, cred.login, device('dev-b'));
      await api(t, 'POST', '/auth/logout', { token: b.accessToken });
      const other = await familyOf(t, 'Bobur Aliyev');
      const otherCred = await issueAsParent(t, other.parent, other.child.childId);
      await loginThroughSetup(t, otherCred, device('dev-x'));

      const list = (await api(t, 'GET', '/auth/child/devices', { token: a.accessToken })).json() as Array<{ sessionId: string | null }>;

      expect(list.map((d) => d.sessionId).sort()).toEqual([a.sessionId, null].sort());
    });

    it('is CHILD-only and needs a token', async () => {
      expect((await api(t, 'GET', '/auth/child/devices', { token: parent.token })).statusCode).toBe(403);
      expect((await api(t, 'GET', '/auth/child/devices')).statusCode).toBe(401);
    });
  });

  describe('qurilma roli: deviceRole MAIN | SECONDARY', () => {
    /** Hech qachon juftlanmagan bola (faqat login bilan kiradi). */
    async function loginOnlyChild(name = 'Zilola Rashidova') {
      const lone = await familyOf(t, name);
      await t.prisma.child.update({ where: { id: lone.child.childId }, data: { childUserId: null, pairedAt: null } });
      const loneCred = await issueAsParent(t, lone.parent, lone.child.childId);
      return { ...lone, cred: loneCred };
    }
    const roleOf = async (sessionId: string) => (await t.prisma.userSession.findUniqueOrThrow({ where: { id: sessionId } })).isMain;
    const login = async (loginName: string, id: string) => {
      const res = await childLogin(t, loginName, OWN_PASSWORD, device(id));
      expect(res.statusCode).toBe(200);
      return res.json() as { deviceRole: 'MAIN' | 'SECONDARY'; sessionId: string; user: { id: string } };
    };

    it('the first login of a child without a paired device is MAIN (setup response), the second is SECONDARY', async () => {
      const lone = await loginOnlyChild();
      const first = (await childLogin(t, lone.cred.login, lone.cred.temporaryPassword)).json();
      const setup = await api(t, 'POST', '/auth/child-setup', {
        payload: { setupToken: first.setupToken, newPassword: OWN_PASSWORD, device: device('dev-a') },
      });

      expect(setup.json()).toMatchObject({ status: 'OK', deviceRole: 'MAIN' });
      expect(await roleOf(setup.json().sessionId)).toBe(true);
      const second = await login(lone.cred.login, 'dev-b');
      expect(second.deviceRole).toBe('SECONDARY');
      expect(await roleOf(second.sessionId)).toBe(false);
      expect((await t.prisma.user.findUniqueOrThrow({ where: { id: second.user.id } })).createdVia).toBe('LOGIN');
    });

    it('is SECONDARY when a family-code / QR paired device is present (it stays the main)', async () => {
      const session = await loginThroughSetup(t, cred, device('dev-a'));
      const res = await childLogin(t, cred.login, OWN_PASSWORD, device('dev-b'));

      expect(res.json().deviceRole).toBe('SECONDARY');
      expect(await roleOf(session.sessionId)).toBe(false);
      expect((await t.prisma.user.findUniqueOrThrow({ where: { id: child.userId } })).createdVia).toBeNull();
      const list = (await api(t, 'GET', '/auth/child/devices', { token: session.accessToken })).json() as Array<{ paired: boolean; main: boolean }>;
      expect(list.filter((d) => d.main).map((d) => d.paired)).toEqual([true]);
    });

    it('lists main: true for the MAIN login session and false for the others', async () => {
      const lone = await loginOnlyChild();
      const a = await loginThroughSetup(t, lone.cred, device('dev-a'));
      const b = await loginPlain(t, lone.cred.login, device('dev-b'));

      const list = (await api(t, 'GET', '/auth/child/devices', { token: b.accessToken })).json() as Array<{ sessionId: string; main: boolean; current: boolean }>;

      expect(list).toHaveLength(2);
      expect(list.find((d) => d.sessionId === a.sessionId)).toMatchObject({ main: true, current: false });
      expect(list.find((d) => d.sessionId === b.sessionId)).toMatchObject({ main: false, current: true });
    });

    it('frees the role when the MAIN session is signed out: the next login becomes MAIN, the others stay SECONDARY', async () => {
      const lone = await loginOnlyChild();
      const a = await loginThroughSetup(t, lone.cred, device('dev-a'));
      const b = await loginPlain(t, lone.cred.login, device('dev-b'));
      await api(t, 'POST', '/auth/logout', { token: a.accessToken });
      expect((await t.prisma.userSession.findUniqueOrThrow({ where: { id: a.sessionId } })).isMain).toBe(false);

      const c = await login(lone.cred.login, 'dev-c');
      const d = await login(lone.cred.login, 'dev-d');

      expect(c.deviceRole).toBe('MAIN');
      expect(d.deviceRole).toBe('SECONDARY');
      expect(await roleOf(b.sessionId)).toBe(false);
    });

    it('frees the role when the MAIN session is evicted by the 4th login (the newcomer becomes MAIN)', async () => {
      const lone = await loginOnlyChild();
      const a = await loginThroughSetup(t, lone.cred, device('dev-a'));
      await login(lone.cred.login, 'dev-b');
      await login(lone.cred.login, 'dev-c');
      expect(await roleOf(a.sessionId)).toBe(true);

      const d = await login(lone.cred.login, 'dev-d');

      expect((await t.prisma.userSession.findUniqueOrThrow({ where: { id: a.sessionId } })).revokedReason).toBe('SIGNED_IN_ELSEWHERE');
      expect(d.deviceRole).toBe('MAIN');
    });

    it('keeps MAIN when the main device signs in again (its old session is replaced)', async () => {
      const lone = await loginOnlyChild();
      await loginThroughSetup(t, lone.cred, device('dev-a'));
      const b = await loginPlain(t, lone.cred.login, device('dev-b'));

      const again = await login(lone.cred.login, 'dev-a');

      expect(again.deviceRole).toBe('MAIN');
      expect(await roleOf(b.sessionId)).toBe(false);
      expect(await t.prisma.userSession.count({ where: { userId: again.user.id, isMain: true, revokedAt: null } })).toBe(1);
    });

    it('makes exactly one of several parallel first logins MAIN', async () => {
      const lone = await loginOnlyChild();
      await loginThroughSetup(t, lone.cred, device('dev-0'));
      await t.prisma.userSession.updateMany({ data: { isMain: false } });

      const results = await Promise.all([1, 2, 3].map((i) => login(lone.cred.login, `dev-${i}`)));

      expect(results.filter((r) => r.deviceRole === 'MAIN')).toHaveLength(1);
      expect(await t.prisma.userSession.count({ where: { isMain: true, revokedAt: null } })).toBe(1);
    });

    it('a credential reset with signOutDevices clears the main marker: the next login is MAIN again', async () => {
      const lone = await loginOnlyChild();
      const a = await loginThroughSetup(t, lone.cred, device('dev-a'));
      await loginPlain(t, lone.cred.login, device('dev-b'));

      const next = await issueAsParent(t, lone.parent, lone.child.childId);

      expect(await t.prisma.userSession.count({ where: { isMain: true } })).toBe(0);
      expect((await t.prisma.userSession.findUniqueOrThrow({ where: { id: a.sessionId } })).revokedReason).toBe('RECOVERED');
      const back = (await childLogin(t, next.login, next.temporaryPassword)).json();
      const setup = await api(t, 'POST', '/auth/child-setup', {
        payload: { setupToken: back.setupToken, newPassword: OWN_PASSWORD, device: device('dev-c') },
      });
      expect(setup.json().deviceRole).toBe('MAIN');
      expect((await login(next.login, 'dev-d')).deviceRole).toBe('SECONDARY');
    });

    it('a reset with signOutDevices also vacates a legacy paired main (it is signed out): the next login is MAIN', async () => {
      await loginThroughSetup(t, cred, device('dev-a')); // SECONDARY: juftlangan qurilma bor
      const next = await issueAsParent(t, parent, child.childId);

      expect((await t.prisma.user.findUniqueOrThrow({ where: { id: child.userId } })).createdVia).toBe('RECOVERED');
      const first = (await childLogin(t, next.login, next.temporaryPassword)).json();
      const setup = await api(t, 'POST', '/auth/child-setup', {
        payload: { setupToken: first.setupToken, newPassword: OWN_PASSWORD, device: device('dev-a') },
      });

      expect(setup.json()).toMatchObject({ status: 'OK', deviceRole: 'MAIN' });
      // Endi juftlangan qurilma ro'yxatda yo'q (u chiqarilgan), asosiy — yangi sessiya.
      const list = (await api(t, 'GET', '/auth/child/devices', { token: setup.json().accessToken })).json() as Array<{ paired: boolean; main: boolean }>;
      expect(list).toHaveLength(1);
      expect(list[0]).toMatchObject({ paired: false, main: true });
      expect((await login(next.login, 'dev-b')).deviceRole).toBe('SECONDARY');
    });

    it('a reset WITHOUT signOutDevices keeps the main marker (login main and legacy main alike)', async () => {
      const lone = await loginOnlyChild();
      const a = await loginThroughSetup(t, lone.cred, device('dev-a'));
      const kept = await issueAsParent(t, lone.parent, lone.child.childId, { signOutDevices: false });
      expect(await roleOf(a.sessionId)).toBe(true);
      const setup = (await childLogin(t, kept.login, kept.temporaryPassword)).json();
      const second = await api(t, 'POST', '/auth/child-setup', {
        payload: { setupToken: setup.setupToken, newPassword: OWN_PASSWORD, device: device('dev-b') },
      });
      expect(second.json().deviceRole).toBe('SECONDARY');

      await loginThroughSetup(t, cred, device('dev-p')); // juftlangan bola
      await issueAsParent(t, parent, child.childId, { signOutDevices: false });
      expect((await t.prisma.user.findUniqueOrThrow({ where: { id: child.userId } })).createdVia).toBeNull();
    });

    it('a password change keeps the current session\'s role and clears the others', async () => {
      const lone = await loginOnlyChild();
      const a = await loginThroughSetup(t, lone.cred, device('dev-a'));
      const b = await loginPlain(t, lone.cred.login, device('dev-b'));

      await api(t, 'POST', '/auth/child/password', {
        token: a.accessToken,
        payload: { currentPassword: OWN_PASSWORD, newPassword: 'Yangi-parol-77' },
      });

      expect(await roleOf(a.sessionId)).toBe(true);
      expect((await t.prisma.userSession.findUniqueOrThrow({ where: { id: b.sessionId } })).revokedAt).not.toBeNull();
      const list = (await api(t, 'GET', '/auth/child/devices', { token: a.accessToken })).json() as Array<{ main: boolean }>;
      expect(list).toEqual([expect.objectContaining({ main: true })]);
    });

    it('creates a MAIN session for a child whose old user was deactivated (no legacy main any more)', async () => {
      await t.prisma.user.update({ where: { id: child.userId }, data: { isActive: false } });

      const session = await loginThroughSetup(t, cred, device('dev-a'));

      expect(await roleOf(session.sessionId)).toBe(true);
    });
  });

  describe('boshqa ota-ona bolasi', () => {
    it("a credential of one family never signs in as another family's child", async () => {
      const other = await familyOf(t, 'Bobur Aliyev');
      const otherCred = await issueAsParent(t, other.parent, other.child.childId);

      const mine = await loginThroughSetup(t, cred);
      const theirs = await loginThroughSetup(t, otherCred);

      expect(mine.userId).toBe(child.userId);
      expect(theirs.userId).toBe(other.child.userId);
      const meMine = (await api(t, 'GET', '/children/me', { token: mine.accessToken })).json();
      const meTheirs = (await api(t, 'GET', '/children/me', { token: theirs.accessToken })).json();
      expect(meMine.id).toBe(child.childId);
      expect(meTheirs.id).toBe(other.child.childId);
      // Tokenlar bir-birining bolasini ocholmaydi.
      expect((await api(t, 'GET', `/children/${other.child.childId}`, { token: mine.accessToken })).statusCode).toBe(403);
    });
  });
});
