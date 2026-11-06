// Kirish (K1): birinchi kirishdagi parol o'rnatish tokeni — 15 daqiqa, bir martalik, access / refresh tokenlaridan
// ajratilgan, boshqa bolaga o'tmaydi, siyosat buzilsa sarflanmaydi.

import { JwtService } from '@nestjs/jwt';
import { resetDb } from './db';
import { TestChild, TestParent } from './factories';
import {
  api,
  childLogin,
  device,
  familyOf,
  issueAsParent,
  IssuedCredential,
  loginThroughSetup,
  OWN_PASSWORD,
  restoreClock,
} from './kirish-fixtures';
import { createTestApp, TestApp } from './test-app';

const MIN = 60_000;

describe('Kirish K1: setupToken', () => {
  let t: TestApp;
  let parent: TestParent;
  let child: TestChild;
  let cred: IssuedCredential;

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

  const activeSessions = () =>
    t.prisma.userSession.findMany({ where: { userId: child.userId, kind: 'LOGIN', revokedAt: null }, orderBy: { createdAt: 'asc' } });
  const refresh = (refreshToken: string) => api(t, 'POST', '/auth/refresh', { payload: { refreshToken } });

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

});
