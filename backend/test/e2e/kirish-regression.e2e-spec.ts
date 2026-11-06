// Kirish (K1): "mavjud hech narsa buzilmasin" regressiyasi — oila kodi bilan juftlash, qayta ulash QR'i,
// eski (sid'siz) token yangilash, ota-ona kirishi/sessiyalari/2-qurilma limiti avvalgidek ishlaydi; login/parol
// bilan kirish esa juftlangan qurilmaga tegmaydi (D2/D4).

import * as bcrypt from 'bcryptjs';
import { resetDb } from './db';
import { consumerToken } from './factories';
import {
  api,
  captureRealtime,
  childLogin,
  decode,
  device,
  issueAsParent,
  legacyRefreshToken,
  loginPlain,
  loginThroughSetup,
  OWN_PASSWORD,
  restoreClock,
} from './kirish-fixtures';
import { createTestApp, TestApp } from './test-app';

const PARENT_PASSWORD = 'Ota-ona-parol1';

describe('Kirish K1: mavjud oqimlar buzilmasligi (regressiya)', () => {
  let t: TestApp;
  let rt: ReturnType<typeof captureRealtime>;
  let seq = 0;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    rt = captureRealtime(t);
  });

  afterEach(() => {
    jest.restoreAllMocks();
    restoreClock(t);
  });

  afterAll(() => t.close());

  /** Parol bilan kira oladigan ota-ona (email + parol). */
  async function passwordParent() {
    const email = `parent-${(seq += 1)}-${Date.now()}@e2e.test`;
    const user = await t.prisma.user.create({
      data: { role: 'PARENT', email, name: 'Ota', passwordHash: await bcrypt.hash(PARENT_PASSWORD, 4) },
    });
    return { user, email, token: consumerToken(user.id, 'PARENT') };
  }

  const parentLogin = (email: string, deviceModel = 'Pixel 7') =>
    api(t, 'POST', '/auth/login', { payload: { identifier: email, password: PARENT_PASSWORD, deviceModel, platform: 'android' } });

  async function createChildVia(parentToken: string, name = 'Aziza Karimova') {
    const res = await api(t, 'POST', '/children', { token: parentToken, payload: { name, age: 9 } });
    expect(res.statusCode).toBe(201);
    return res.json() as { id: string; familyCode: string; name: string };
  }

  describe('oila kodi bilan juftlash (/auth/child-pair)', () => {
    it('pairs a fresh child (201), issues sid-less tokens, and blocks a second device (409 ALREADY_PAIRED)', async () => {
      const parent = await passwordParent();
      const created = await createChildVia(parent.token);

      const paired = await api(t, 'POST', '/auth/child-pair', { payload: { familyCode: created.familyCode, deviceInfo: { model: 'Redmi' } } });

      expect(paired.statusCode).toBe(201);
      const body = paired.json();
      expect(Object.keys(body).sort()).toEqual(['accessToken', 'child', 'refreshToken', 'user']);
      expect(body.child).toMatchObject({ id: created.id, name: 'Aziza Karimova' });
      expect(body.user.role).toBe('CHILD');
      const access = decode(t, body.accessToken);
      expect(access.sid).toBeUndefined();
      expect(access).toMatchObject({ role: 'CHILD', tokenVersion: 0 });
      expect(decode(t, body.refreshToken).sid).toBeUndefined();
      const profile = await t.prisma.child.findUniqueOrThrow({ where: { id: created.id } });
      expect(profile).toMatchObject({ childUserId: body.user.id, isConnected: true, deviceModel: 'Redmi' });
      expect(profile.pairedAt).not.toBeNull();
      expect(await t.prisma.userSession.count({ where: { userId: body.user.id } })).toBe(0);

      const second = await api(t, 'POST', '/auth/child-pair', { payload: { familyCode: created.familyCode } });
      expect(second.statusCode).toBe(409);
      expect(second.json()).toMatchObject({ error: 'ALREADY_PAIRED' });
      expect((await api(t, 'POST', '/auth/child-pair', { payload: { familyCode: '00000' } })).statusCode).toBe(404);
    });

    it('the paired device refreshes its sid-less token as before (and tokenVersion revocation still works)', async () => {
      const parent = await passwordParent();
      const created = await createChildVia(parent.token);
      const paired = (await api(t, 'POST', '/auth/child-pair', { payload: { familyCode: created.familyCode } })).json();

      const refreshed = await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: paired.refreshToken } });

      expect(refreshed.statusCode).toBe(200);
      expect(decode(t, refreshed.json().accessToken).sid).toBeUndefined();
      // Eski token yangilangan tokenlar bilan birga ishlashda davom etadi (sid yo'q — aylanish yo'q).
      expect((await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: paired.refreshToken } })).statusCode).toBe(200);
      expect((await api(t, 'GET', `/children/${created.id}`, { token: refreshed.json().accessToken })).statusCode).toBe(200);

      await t.prisma.user.update({ where: { id: paired.user.id }, data: { tokenVersion: { increment: 1 } } });
      const revoked = await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: paired.refreshToken } });
      expect(revoked.statusCode).toBe(401);
      expect(revoked.json()).toMatchObject({ message: 'Token revoked' });
    });

    it('a legacy refresh token of an inactive user is refused as before', async () => {
      const parent = await passwordParent();
      const created = await createChildVia(parent.token);
      const paired = (await api(t, 'POST', '/auth/child-pair', { payload: { familyCode: created.familyCode } })).json();
      await t.prisma.user.update({ where: { id: paired.user.id }, data: { isActive: false } });

      const res = await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: paired.refreshToken } });

      expect(res.statusCode).toBe(401);
      expect(res.json()).toMatchObject({ message: 'User not found or inactive' });
    });

    it('regenerating the family code still unpairs the device and frees the profile for pairing', async () => {
      const parent = await passwordParent();
      const created = await createChildVia(parent.token);
      await api(t, 'POST', '/auth/child-pair', { payload: { familyCode: created.familyCode } });

      const regenerated = await api(t, 'POST', `/children/${created.id}/pair-code`, { token: parent.token });
      expect(regenerated.statusCode).toBe(200);

      const again = await api(t, 'POST', '/auth/child-pair', { payload: { familyCode: regenerated.json().familyCode } });
      expect(again.statusCode).toBe(201);
    });
  });

  describe('qayta ulash QR (repair-qr / repair-redeem)', () => {
    async function pairedFamily() {
      const parent = await passwordParent();
      const created = await createChildVia(parent.token);
      const paired = (await api(t, 'POST', '/auth/child-pair', { payload: { familyCode: created.familyCode } })).json();
      return { parent, created, paired };
    }

    it('works as before: QR token, redeem (200), new user, old device signed out, single-use', async () => {
      const { parent, created, paired } = await pairedFamily();

      const qr = await api(t, 'POST', `/auth/child/${created.id}/repair-qr`, { token: parent.token });
      expect(qr.statusCode).toBe(201);
      expect(Object.keys(qr.json()).sort()).toEqual(['expiresInSec', 'token']);
      const redeemed = await api(t, 'POST', '/auth/repair-redeem', {
        payload: { token: qr.json().token, deviceModel: 'New phone', platform: 'android' },
      });

      expect(redeemed.statusCode).toBe(200);
      const body = redeemed.json();
      expect(Object.keys(body).sort()).toEqual(['accessToken', 'child', 'refreshToken', 'user']);
      expect(body.user.id).not.toBe(paired.user.id);
      expect(decode(t, body.accessToken).sid).toBeUndefined();
      const old = await t.prisma.user.findUniqueOrThrow({ where: { id: paired.user.id } });
      expect(old).toMatchObject({ isActive: false, tokenVersion: 1 });
      expect((await t.prisma.child.findUniqueOrThrow({ where: { id: created.id } })).childUserId).toBe(body.user.id);
      expect((await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: paired.refreshToken } })).statusCode).toBe(401);
      expect((await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: body.refreshToken } })).statusCode).toBe(200);
      expect(rt.of(parent.user.id, 'child:repaired')).toHaveLength(1);
      expect(rt.of(paired.user.id, 'child:unpaired')[0]?.payload).toMatchObject({ reason: 'QR_REPAIR_REDEEMED' });
      expect((await api(t, 'POST', '/auth/repair-redeem', { payload: { token: qr.json().token } })).statusCode).toBe(401);
    });

    it('only the parent of the child can create the QR', async () => {
      const { created } = await pairedFamily();
      const stranger = await passwordParent();

      expect((await api(t, 'POST', `/auth/child/${created.id}/repair-qr`, { token: stranger.token })).statusCode).toBe(401);
    });

    it('closes the credential (LOGIN) sessions of the replaced device with PERMISSIONS_CHANGED and announces it', async () => {
      const { parent, created, paired } = await pairedFamily();
      const cred = await issueAsParent(t, { userId: parent.user.id, token: parent.token }, created.id);
      const session = await loginThroughSetup(t, cred, device('dev-a'));
      expect(session.userId).toBe(paired.user.id);
      rt.clear();

      const qr = await api(t, 'POST', `/auth/child/${created.id}/repair-qr`, { token: parent.token });
      await api(t, 'POST', '/auth/repair-redeem', { payload: { token: qr.json().token } });

      const closed = await t.prisma.userSession.findUniqueOrThrow({ where: { id: session.sessionId } });
      expect(closed.revokedReason).toBe('PERMISSIONS_CHANGED');
      expect(closed.revokedAt).not.toBeNull();
      expect(rt.of(paired.user.id, 'session:closed')[0]?.payload).toEqual({ sessionIds: [session.sessionId], reason: 'PERMISSIONS_CHANGED' });
      expect((await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: session.refreshToken } })).json()).toEqual({
        statusCode: 401,
        code: 'SESSION_REVOKED',
        reason: 'PERMISSIONS_CHANGED',
        message: 'Session revoked',
      });
      // Bola login bilan qayta kiradi: yangi (faol) bola foydalanuvchisi, ya'ni yangi juftlangan qurilma bilan bir xil.
      const again = await loginPlain(t, cred.login, device('dev-a'));
      const profile = await t.prisma.child.findUniqueOrThrow({ where: { id: created.id } });
      expect(again.userId).toBe(profile.childUserId);
      expect(again.userId).not.toBe(paired.user.id);
    });

    it('the QR re-paired device becomes the main device: later logins are SECONDARY', async () => {
      const { parent, created } = await pairedFamily();
      const cred = await issueAsParent(t, { userId: parent.user.id, token: parent.token }, created.id);
      const qr = await api(t, 'POST', `/auth/child/${created.id}/repair-qr`, { token: parent.token });
      await api(t, 'POST', '/auth/repair-redeem', { payload: { token: qr.json().token, deviceModel: 'New phone' } });

      const res = await childLogin(t, cred.login, cred.temporaryPassword, device('dev-a'));
      const setup = await api(t, 'POST', '/auth/child-setup', {
        payload: { setupToken: res.json().setupToken, newPassword: OWN_PASSWORD, device: device('dev-a') },
      });

      expect(setup.json()).toMatchObject({ status: 'OK', deviceRole: 'SECONDARY' });
      expect(await t.prisma.userSession.count({ where: { isMain: true } })).toBe(0);
    });
  });

  describe('qurilma almashtirish so\'rovi (pair-requests/approve)', () => {
    it('keeps working and closes the credential sessions of the replaced device with PERMISSIONS_CHANGED', async () => {
      const parent = await passwordParent();
      const created = await createChildVia(parent.token);
      const paired = (await api(t, 'POST', '/auth/child-pair', { payload: { familyCode: created.familyCode } })).json();
      const cred = await issueAsParent(t, { userId: parent.user.id, token: parent.token }, created.id);
      const session = await loginThroughSetup(t, cred, device('dev-a'));
      const pairRequest = await t.prisma.childPairRequest.create({
        data: { childId: created.id, deviceInfo: { model: 'New phone' }, expiresAt: new Date(Date.now() + 600_000) },
      });
      rt.clear();

      const res = await api(t, 'POST', `/children/${created.id}/pair-requests/${pairRequest.id}/approve`, { token: parent.token });

      expect(res.statusCode).toBe(201);
      expect(await t.prisma.user.findUniqueOrThrow({ where: { id: paired.user.id } })).toMatchObject({ isActive: false, tokenVersion: 1 });
      expect(await t.prisma.userSession.findUniqueOrThrow({ where: { id: session.sessionId } })).toMatchObject({
        revokedReason: 'PERMISSIONS_CHANGED',
      });
      expect(rt.of(paired.user.id, 'session:closed')[0]?.payload).toEqual({
        sessionIds: [session.sessionId],
        reason: 'PERMISSIONS_CHANGED',
      });
      expect((await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: session.refreshToken } })).json()).toMatchObject({
        code: 'SESSION_REVOKED',
        reason: 'PERMISSIONS_CHANGED',
      });
    });
  });

  describe('eski token yangilash (sid yo\'q)', () => {
    it('keeps issuing sid-less tokens for sid-less refresh tokens and refuses a stale tokenVersion', async () => {
      const parent = await passwordParent();
      const created = await createChildVia(parent.token);
      const user = await t.prisma.user.create({ data: { role: 'CHILD' } });
      await t.prisma.child.update({ where: { id: created.id }, data: { childUserId: user.id, pairedAt: new Date() } });

      const ok = await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: legacyRefreshToken(user.id, 0) } });
      expect(ok.statusCode).toBe(200);
      expect(decode(t, ok.json().refreshToken).sid).toBeUndefined();
      expect(decode(t, ok.json().refreshToken).rjti).toBeUndefined();

      const stale = await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: legacyRefreshToken(user.id, 5) } });
      expect(stale.statusCode).toBe(401);
      expect((await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: 'garbage' } })).statusCode).toBe(401);
    });
  });

  describe('ota-ona kirishi va sessiyalari', () => {
    it('login returns tokens with sid, refresh rotates, logout revokes that session only (reason stored)', async () => {
      const parent = await passwordParent();
      const login = await parentLogin(parent.email);

      expect(login.statusCode).toBe(200);
      const body = login.json();
      expect(Object.keys(body).sort()).toEqual(['accessToken', 'refreshToken', 'user']);
      const claims = decode(t, body.accessToken);
      expect(claims.sid).toEqual(expect.any(String));
      const session = await t.prisma.userSession.findUniqueOrThrow({ where: { id: claims.sid as string } });
      expect(session).toMatchObject({ userId: parent.user.id, deviceModel: 'Pixel 7', platform: 'android', kind: null, deviceId: null });

      const refreshed = await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: body.refreshToken } });
      expect(refreshed.statusCode).toBe(200);
      expect((await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: body.refreshToken } })).statusCode).toBe(401);

      expect((await api(t, 'POST', '/auth/logout', { token: refreshed.json().accessToken })).statusCode).toBe(200);
      const closed = await t.prisma.userSession.findUniqueOrThrow({ where: { id: claims.sid as string } });
      expect(closed.revokedAt).not.toBeNull();
      expect(closed.revokedReason).toBe('SIGNED_OUT');
      const after = await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: refreshed.json().refreshToken } });
      expect(after.statusCode).toBe(401);
      expect(after.json()).toMatchObject({ statusCode: 401, code: 'SESSION_REVOKED', reason: 'SIGNED_OUT', message: 'Session revoked' });
    });

    it('wrong parent password still answers the same generic 401', async () => {
      const parent = await passwordParent();

      const res = await api(t, 'POST', '/auth/login', { payload: { identifier: parent.email, password: 'wrong-password1' } });

      expect(res.statusCode).toBe(401);
      expect(res.json()).toMatchObject({ message: "Login yoki parol noto'g'ri" });
    });

    it('lists and revokes sessions through the existing endpoints; a missing one is still 404', async () => {
      const parent = await passwordParent();
      const first = (await parentLogin(parent.email, 'Phone A')).json();
      const second = (await parentLogin(parent.email, 'Phone B')).json();
      const secondSid = decode(t, second.accessToken).sid as string;

      const list = await api(t, 'GET', '/auth/sessions', { token: first.accessToken });
      expect(list.statusCode).toBe(200);
      expect(list.json()).toHaveLength(2);
      expect(list.json().filter((s: { isCurrent: boolean }) => s.isCurrent)).toHaveLength(1);
      expect(Object.keys(list.json()[0]).sort()).toEqual([
        'city', 'country', 'createdAt', 'deviceModel', 'id', 'ipAddress', 'isCurrent', 'lastSeenAt', 'platform',
      ]);

      expect((await api(t, 'DELETE', `/auth/sessions/${secondSid}`, { token: first.accessToken })).json()).toEqual({ ok: true });
      expect((await api(t, 'DELETE', `/auth/sessions/${secondSid}`, { token: first.accessToken })).statusCode).toBe(404);
      expect((await t.prisma.userSession.findUniqueOrThrow({ where: { id: secondSid } })).revokedReason).toBe('SIGNED_OUT');
    });

    it('still limits a parent to 2 devices (409 DEVICE_LIMIT_REACHED with a pending token)', async () => {
      const parent = await passwordParent();
      await parentLogin(parent.email, 'Phone A');
      await parentLogin(parent.email, 'Phone B');

      const third = await parentLogin(parent.email, 'Phone C');

      expect(third.statusCode).toBe(409);
      expect(third.json()).toMatchObject({ error: 'DEVICE_LIMIT_REACHED', maxDevices: 2, pendingToken: expect.any(String) });
    });

    it('child login sessions do not touch the parent device limit or the parent sessions', async () => {
      const parent = await passwordParent();
      const created = await createChildVia(parent.token);
      const user = await t.prisma.user.create({ data: { role: 'CHILD' } });
      await t.prisma.child.update({ where: { id: created.id }, data: { childUserId: user.id } });
      const cred = await issueAsParent(t, { userId: parent.user.id, token: parent.token }, created.id);
      await loginThroughSetup(t, cred, device('dev-a'));
      await loginPlain(t, cred.login, device('dev-b'));
      await loginPlain(t, cred.login, device('dev-c'));

      expect((await parentLogin(parent.email, 'Phone A')).statusCode).toBe(200);
      expect((await parentLogin(parent.email, 'Phone B')).statusCode).toBe(200);
      expect((await parentLogin(parent.email, 'Phone C')).statusCode).toBe(409);
    });

    it('the 2-device QR link keeps the owner and signs the other device out (reason SIGNED_IN_ELSEWHERE)', async () => {
      const parent = await passwordParent();
      const owner = (await parentLogin(parent.email, 'Owner')).json();
      const other = (await parentLogin(parent.email, 'Other')).json();
      const otherSid = decode(t, other.accessToken).sid as string;
      const link = await api(t, 'POST', '/auth/device-link/create', { token: owner.accessToken });
      expect(link.statusCode).toBe(201);

      const redeemed = await api(t, 'POST', '/auth/device-link/redeem', {
        payload: { code: link.json().code, deviceModel: 'Third', platform: 'ios' },
      });

      expect(redeemed.statusCode).toBe(200);
      expect((await t.prisma.userSession.findUniqueOrThrow({ where: { id: otherSid } })).revokedReason).toBe('SIGNED_IN_ELSEWHERE');
      expect((await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: owner.refreshToken } })).statusCode).toBe(200);
    });
  });

  describe('login/parol va juftlangan qurilma birga ishlaydi (D2, D4)', () => {
    async function pairedWithCredential() {
      const parent = await passwordParent();
      const created = await createChildVia(parent.token);
      const paired = (await api(t, 'POST', '/auth/child-pair', { payload: { familyCode: created.familyCode } })).json();
      const cred = await issueAsParent(t, { userId: parent.user.id, token: parent.token }, created.id);
      return { parent, created, paired, cred };
    }

    it('issuing credentials leaves the paired device signed in; a login on another device shares the same child user', async () => {
      const { created, paired, cred } = await pairedWithCredential();

      expect((await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: paired.refreshToken } })).statusCode).toBe(200);
      const session = await loginThroughSetup(t, cred, device('tablet'));

      expect(session.userId).toBe(paired.user.id);
      expect((await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: paired.refreshToken } })).statusCode).toBe(200);
      // Ikkala token ham bola endpoint'lariga kiradi.
      for (const token of [paired.accessToken, session.accessToken]) {
        expect((await api(t, 'GET', `/children/${created.id}`, { token })).statusCode).toBe(200);
        expect(
          (await api(t, 'POST', `/children/${created.id}/device-info`, { token, payload: { batteryLevel: 80 } })).statusCode,
        ).toBe(200);
      }
    });

    it('the paired device is reported by /auth/child/devices next to the login sessions', async () => {
      const { paired, cred } = await pairedWithCredential();
      const session = await loginThroughSetup(t, cred, device('tablet'));

      const list = (await api(t, 'GET', '/auth/child/devices', { token: paired.accessToken })).json() as Array<{ paired: boolean; current: boolean; sessionId: string | null }>;

      expect(list.map((d) => d.sessionId).sort()).toEqual([session.sessionId, null].sort());
      expect(list.find((d) => d.paired)).toMatchObject({ current: true });
    });

    it('a reset signs the paired device out too (the contract), but it can come back with the new password', async () => {
      const { parent, created, paired, cred } = await pairedWithCredential();
      await loginThroughSetup(t, cred, device('tablet'));

      const next = await issueAsParent(t, { userId: parent.user.id, token: parent.token }, created.id);

      expect((await api(t, 'POST', '/auth/refresh', { payload: { refreshToken: paired.refreshToken } })).statusCode).toBe(401);
      const back = await loginThroughSetup(t, next, device('tablet'));
      expect(back.userId).toBe(paired.user.id);
      expect(rt.of(paired.user.id, 'child:unpaired').length).toBeGreaterThan(0);
    });

    it('a login created user keeps the family code blocked (409 ALREADY_PAIRED) until the parent re-pairs by QR', async () => {
      const parent = await passwordParent();
      const created = await createChildVia(parent.token);
      const cred = await issueAsParent(t, { userId: parent.user.id, token: parent.token }, created.id);
      const session = await loginThroughSetup(t, cred, device('tablet'));
      const profile = await t.prisma.child.findUniqueOrThrow({ where: { id: created.id } });
      expect(profile.childUserId).toBe(session.userId);
      expect(profile.pairedAt).toBeNull();

      const pair = await api(t, 'POST', '/auth/child-pair', { payload: { familyCode: created.familyCode } });
      expect(pair.statusCode).toBe(409);

      const qr = await api(t, 'POST', `/auth/child/${created.id}/repair-qr`, { token: parent.token });
      const redeemed = await api(t, 'POST', '/auth/repair-redeem', { payload: { token: qr.json().token } });
      expect(redeemed.statusCode).toBe(200);
    });

    it('credentials survive pair-code regeneration: the next login creates a new child user', async () => {
      const { parent, created, paired, cred } = await pairedWithCredential();
      const regenerated = await api(t, 'POST', `/children/${created.id}/pair-code`, { token: parent.token });
      expect(regenerated.statusCode).toBe(200);

      const session = await loginThroughSetup(t, cred, device('tablet'));

      expect(session.userId).not.toBe(paired.user.id);
      expect((await t.prisma.child.findUniqueOrThrow({ where: { id: created.id } })).childUserId).toBe(session.userId);
      expect((await childLogin(t, cred.login, OWN_PASSWORD, device('tablet-2'))).statusCode).toBe(200);
    });
  });
});
