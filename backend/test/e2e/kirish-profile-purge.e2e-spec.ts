// Kirish (K1): A06 profil maydonlari (jins, ta'lim tili) va bola ma'lumotlari o'chirilganda kirish maʼlumotlarining
// ketishi — to'rt o'chirish yo'lida ham: bola o'z akkauntini, ota-ona bola profilini / o'z akkauntini, admin foydalanuvchini.

import { ChildRecoveryService } from '../../src/modules/child-auth/child-recovery.service';
import { resetDb } from './db';
import { consumerToken, createModerator } from './factories';
import {
  api,
  controlClock,
  familyOf,
  issueAsParent,
  loginThroughSetup,
  restoreClock,
} from './kirish-fixtures';
import { seedWorld, World } from './school-attendance-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('Kirish K1: A06 profil maydonlari', () => {
  let t: TestApp;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
  });

  afterAll(() => t.close());

  const put = (token: string, payload: object) => api(t, 'PUT', '/children/me', { token, payload });

  it('PUT /children/me saves gender and educationLanguage and returns the updated child', async () => {
    const { child } = await familyOf(t);

    const res = await put(child.token, { gender: 'female', educationLanguage: 'kaa', age: 9 });

    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({ id: child.childId, gender: 'female', educationLanguage: 'kaa', age: 9 });
    expect(await t.prisma.child.findUniqueOrThrow({ where: { id: child.childId } })).toMatchObject({
      gender: 'female',
      educationLanguage: 'kaa',
      age: 9,
    });
  });

  it.each(['male', 'female'])('accepts gender %s', async (gender) => {
    const { child } = await familyOf(t);

    expect((await put(child.token, { gender })).statusCode).toBe(200);
    expect((await t.prisma.child.findUniqueOrThrow({ where: { id: child.childId } })).gender).toBe(gender);
  });

  it.each(['uz', 'ru', 'kaa'])('accepts educationLanguage %s', async (educationLanguage) => {
    const { child } = await familyOf(t);

    expect((await put(child.token, { educationLanguage })).statusCode).toBe(200);
    expect((await t.prisma.child.findUniqueOrThrow({ where: { id: child.childId } })).educationLanguage).toBe(educationLanguage);
  });

  it.each([
    [{ gender: 'other' }],
    [{ gender: 'MALE' }],
    [{ gender: null }],
    [{ gender: 1 }],
    [{ educationLanguage: 'en' }],
    [{ educationLanguage: 'UZ' }],
    [{ educationLanguage: null }],
    [{ educationLanguage: '' }],
    [{ unknownField: true }],
  ])('rejects %j with 400 and changes nothing', async (payload) => {
    const { child } = await familyOf(t);
    await put(child.token, { gender: 'male', educationLanguage: 'ru' });

    const res = await put(child.token, payload);

    expect(res.statusCode).toBe(400);
    expect(await t.prisma.child.findUniqueOrThrow({ where: { id: child.childId } })).toMatchObject({
      gender: 'male',
      educationLanguage: 'ru',
    });
  });

  it('updates one field without touching the others', async () => {
    const { child } = await familyOf(t);
    await put(child.token, { gender: 'female', educationLanguage: 'uz', region: 'Toshkent' });

    await put(child.token, { educationLanguage: 'ru' });

    expect(await t.prisma.child.findUniqueOrThrow({ where: { id: child.childId } })).toMatchObject({
      gender: 'female',
      educationLanguage: 'ru',
      region: 'Toshkent',
    });
  });

  it.each([6, 18, 12])('accepts age %i; the existing 1–25 range is unchanged', async (age) => {
    const { child } = await familyOf(t);

    expect((await put(child.token, { age })).statusCode).toBe(200);
    expect((await put(child.token, { age: 26 })).statusCode).toBe(400);
  });

  it('only the child can edit its own profile; a parent token is refused', async () => {
    const { parent, child } = await familyOf(t);

    expect((await put(parent.token, { gender: 'male' })).statusCode).toBe(403);
    expect((await api(t, 'PUT', '/children/me', { payload: { gender: 'male' } })).statusCode).toBe(401);
    expect((await t.prisma.child.findUniqueOrThrow({ where: { id: child.childId } })).gender).toBeNull();
  });

  it('a child can edit only its own record (two families stay separate)', async () => {
    const a = await familyOf(t, 'Aziza');
    const b = await familyOf(t, 'Bobur');

    await put(a.child.token, { gender: 'female', educationLanguage: 'uz' });
    await put(b.child.token, { gender: 'male', educationLanguage: 'ru' });

    expect(await t.prisma.child.findUniqueOrThrow({ where: { id: a.child.childId } })).toMatchObject({ gender: 'female', educationLanguage: 'uz' });
    expect(await t.prisma.child.findUniqueOrThrow({ where: { id: b.child.childId } })).toMatchObject({ gender: 'male', educationLanguage: 'ru' });
  });

  describe('GET /children/me', () => {
    it('returns the own record with educationLanguage (null until chosen)', async () => {
      const { child } = await familyOf(t, 'Aziza Karimova');

      const before = await api(t, 'GET', '/children/me', { token: child.token });
      expect(before.statusCode).toBe(200);
      expect(before.json()).toMatchObject({ id: child.childId, name: 'Aziza Karimova', educationLanguage: null, gender: null });

      await put(child.token, { educationLanguage: 'ru', gender: 'female' });
      const after = await api(t, 'GET', '/children/me', { token: child.token });
      expect(after.json()).toMatchObject({ educationLanguage: 'ru', gender: 'female' });
    });

    it('returns the same record as PUT /children/me', async () => {
      const { child } = await familyOf(t);

      const updated = (await put(child.token, { educationLanguage: 'uz' })).json();
      const read = (await api(t, 'GET', '/children/me', { token: child.token })).json();

      expect(read).toEqual(updated);
    });

    it('is child-only (parent 403, no token 401) and 404 when the user has no profile', async () => {
      const { parent } = await familyOf(t);
      const orphan = await t.prisma.user.create({ data: { role: 'CHILD' } });

      expect((await api(t, 'GET', '/children/me', { token: parent.token })).statusCode).toBe(403);
      expect((await api(t, 'GET', '/children/me')).statusCode).toBe(401);
      expect((await api(t, 'GET', '/children/me', { token: consumerToken(orphan.id, 'CHILD') })).statusCode).toBe(404);
    });

    it('does not shadow GET /children/:id for the parent, which also exposes educationLanguage', async () => {
      const { parent, child } = await familyOf(t);
      await put(child.token, { educationLanguage: 'kaa' });

      const res = await api(t, 'GET', `/children/${child.childId}`, { token: parent.token });

      expect(res.statusCode).toBe(200);
      expect(res.json()).toMatchObject({ id: child.childId, educationLanguage: 'kaa' });
    });
  });
});

describe('Kirish K1: bola ma\'lumotlari o\'chirilganda kirish maʼlumotlari ham ketadi', () => {
  let t: TestApp;
  let w: World;
  // Har testga o'z loginlari: tiklash so'rovining kunlik limiti (3/login) testlar orasida yig'ilmasin.
  let seq = 0;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    w = await seedWorld(t);
    seq += 1;
  });

  afterEach(() => restoreClock(t));

  afterAll(() => t.close());

  /** Bolaning login/parol, LOGIN sessiyasi va tiklash so'rovlari (ota-ona + maktab kanali, xodim bildirishnomasi bilan). */
  async function seedAuthData(parent = w.parent, childId = w.child.childId, login = `vali.purge${seq}`) {
    const cred = await issueAsParent(t, parent, childId, { login });
    const session = await loginThroughSetup(t, cred);
    for (const channel of ['PARENT', 'SCHOOL'] as const) {
      const res = await api(t, 'POST', '/auth/child-recovery', { payload: { login: cred.login, channel } });
      expect(res.statusCode).toBe(202);
    }
    await t.app.get(ChildRecoveryService).drainEffects();
    return { cred, session };
  }

  const counts = async (childId: string) => ({
    credentials: await t.prisma.childCredential.count({ where: { childId } }),
    requests: await t.prisma.childRecoveryRequest.count({ where: { childId } }),
  });
  const staffNotifications = () => t.prisma.schoolStaffNotification.count({ where: { kind: 'CHILD_RECOVERY_REQUEST' } });

  /** Boshqa oila — o'chirish unga tegmasligi kerak. */
  async function seedBystander() {
    const other = await familyOf(t, 'Boshqa Bola');
    const cred = await issueAsParent(t, other.parent, other.child.childId, { login: `boshqa.bola${seq}` });
    const dead = await api(t, 'POST', '/auth/child-recovery', { payload: { login: `nobody.purge${seq}`, channel: 'PARENT' } });
    expect(dead.statusCode).toBe(202);
    await t.prisma.childRecoveryRequest.create({
      data: { childId: other.child.childId, channel: 'PARENT', pollTokenHash: 'bystander' },
    });
    return { other, cred };
  }

  async function expectBystanderIntact(other: Awaited<ReturnType<typeof seedBystander>>['other']) {
    expect(await counts(other.child.childId)).toEqual({ credentials: 1, requests: 1 });
    expect(await t.prisma.childRecoveryRequest.count({ where: { childId: null } })).toBe(1);
  }

  it('seed sanity: credentials, a LOGIN session, two requests and one staff notification exist', async () => {
    await seedAuthData();

    expect(await counts(w.child.childId)).toEqual({ credentials: 1, requests: 2 });
    expect(await staffNotifications()).toBe(1);
    expect(await t.prisma.userSession.count({ where: { userId: w.child.userId, kind: 'LOGIN' } })).toBe(1);
  });

  it('the child deleting its own account removes the login, the requests and the staff notification; the parent profile stays', async () => {
    const { session } = await seedAuthData();
    const { other } = await seedBystander();

    const res = await api(t, 'DELETE', '/users/me', { token: session.accessToken });

    expect(res.statusCode).toBe(200);
    expect(await t.prisma.child.findUnique({ where: { id: w.child.childId } })).toMatchObject({ childUserId: null });
    expect(await counts(w.child.childId)).toEqual({ credentials: 0, requests: 0 });
    expect(await staffNotifications()).toBe(0);
    expect(await t.prisma.userSession.count({ where: { userId: w.child.userId } })).toBe(0);
    await expectBystanderIntact(other);
  });

  it('the parent deleting the child profile removes everything of that child (and keeps the school student)', async () => {
    await seedAuthData();
    const { other } = await seedBystander();

    const res = await api(t, 'DELETE', `/children/${w.child.childId}`, { token: w.parent.token });

    expect(res.statusCode).toBe(200);
    expect(await t.prisma.child.count({ where: { id: w.child.childId } })).toBe(0);
    expect(await counts(w.child.childId)).toEqual({ credentials: 0, requests: 0 });
    expect(await staffNotifications()).toBe(0);
    expect(await t.prisma.schoolStudent.findUniqueOrThrow({ where: { id: w.vali } })).toMatchObject({ childId: null });
    await expectBystanderIntact(other);
  });

  it('the parent deleting their own account removes all their children\'s logins and requests', async () => {
    await seedAuthData();
    const { other } = await seedBystander();

    const res = await api(t, 'DELETE', '/users/me', { token: w.parent.token });

    expect(res.statusCode).toBe(200);
    expect(await t.prisma.child.count({ where: { parentId: w.parent.userId } })).toBe(0);
    expect(await counts(w.child.childId)).toEqual({ credentials: 0, requests: 0 });
    expect(await staffNotifications()).toBe(0);
    await expectBystanderIntact(other);
  });

  it('an admin deleting the child user removes the login and the requests', async () => {
    await seedAuthData();
    const { other } = await seedBystander();
    const admin = await createModerator(t.prisma, ['manage_users']);

    const res = await api(t, 'DELETE', `/admin/users/${w.child.userId}`, { token: admin.token });

    expect(res.statusCode).toBe(200);
    expect(await counts(w.child.childId)).toEqual({ credentials: 0, requests: 0 });
    expect(await staffNotifications()).toBe(0);
    await expectBystanderIntact(other);
  });

  it('an admin deleting the parent user removes the whole family\'s logins and requests', async () => {
    await seedAuthData();
    const { other } = await seedBystander();
    const admin = await createModerator(t.prisma, ['manage_users']);

    const res = await api(t, 'DELETE', `/admin/users/${w.parent.userId}`, { token: admin.token });

    expect(res.statusCode).toBe(200);
    expect(await counts(w.child.childId)).toEqual({ credentials: 0, requests: 0 });
    expect(await staffNotifications()).toBe(0);
    await expectBystanderIntact(other);
  });

  it('after the parent profile is deleted the old login stops working (no ghost account)', async () => {
    const { cred } = await seedAuthData();
    await api(t, 'DELETE', `/children/${w.child.childId}`, { token: w.parent.token });
    controlClock(t);

    const res = await api(t, 'POST', '/auth/child-login', {
      payload: { login: cred.login, password: 'Kitob2026', device: { id: 'x', platform: 'android' } },
    });

    expect(res.statusCode).toBe(401);
    expect(res.json().code).toBe('INVALID_CREDENTIALS');
  });
});
