// Kirish (K1): GET /auth/child/devices, qurilma roli (deviceRole MAIN | SECONDARY) va oilalar o'rtasidagi izolyatsiya.

import { resetDb } from './db';
import { TestChild, TestParent } from './factories';
import {
  api,
  childLogin,
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

describe('Kirish K1: bola qurilmalari', () => {
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

  const refresh = (refreshToken: string) => api(t, 'POST', '/auth/refresh', { payload: { refreshToken } });

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
