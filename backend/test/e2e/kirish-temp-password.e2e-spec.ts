// Kirish (K1): vaqtinchalik parol 14 kun amal qiladi. To'g'ri, lekin muddati o'tgan vaqtinchalik parol -> 401
// TEMP_PASSWORD_EXPIRED (setupToken YO'Q); noto'g'ri parol baribir INVALID_CREDENTIALS va blokka sanaladi (muddat
// parolni bilmaydiganga fosh bo'lmaydi). Qayta tiklash muddatni yangilaydi; o'z paroliga muddat tegishli emas.

import { resetDb } from './db';
import { TestChild, TestParent } from './factories';
import {
  api,
  childLogin,
  controlClock,
  DAY_MS,
  device,
  familyOf,
  issueAsParent,
  IssuedCredential,
  loginPlain,
  loginThroughSetup,
  OWN_PASSWORD,
  restoreClock,
  TEMP_PASSWORD_TTL_DAYS,
} from './kirish-fixtures';
import { createTestApp, TestApp } from './test-app';

const MIN = 60_000;
const EXPIRED = { statusCode: 401, code: 'TEMP_PASSWORD_EXPIRED', message: 'Temporary password has expired' };

describe('Kirish K1: vaqtinchalik parol muddati (14 kun)', () => {
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

  const row = () => t.prisma.childCredential.findUniqueOrThrow({ where: { childId: child.childId } });
  const expiry = () => Date.parse(cred.temporaryPasswordExpiresAt);
  const at = (ms: number) => controlClock(t, new Date(ms));
  const setup = (setupToken: string) =>
    api(t, 'POST', '/auth/child-setup', { payload: { setupToken, newPassword: OWN_PASSWORD, device: device() } });

  it('the issue response carries temporaryPasswordExpiresAt = issuedAt + 14 days', () => {
    expect(Date.parse(cred.temporaryPasswordExpiresAt) - Date.parse(cred.issuedAt)).toBe(TEMP_PASSWORD_TTL_DAYS * DAY_MS);
  });

  it('still works 1 ms before the expiry: SETUP_REQUIRED', async () => {
    at(expiry() - 1);

    const res = await childLogin(t, cred.login, cred.temporaryPassword);

    expect(res.statusCode).toBe(200);
    expect(res.json().status).toBe('SETUP_REQUIRED');
  });

  it('answers 401 TEMP_PASSWORD_EXPIRED from the expiry instant: no setupToken, no session, no counter change', async () => {
    at(expiry());

    const res = await childLogin(t, cred.login, cred.temporaryPassword);

    expect(res.statusCode).toBe(401);
    expect(res.json()).toEqual(EXPIRED);
    expect(res.body).not.toContain('setupToken');
    expect(await t.prisma.userSession.count({ where: { userId: child.userId } })).toBe(0);
    expect(await row()).toMatchObject({ failedLogins: 0, lockedUntil: null, mustChangePassword: true });
  });

  it('never locks the account: any number of expired attempts answer the same', async () => {
    at(expiry() + DAY_MS);
    const answers = [];
    for (let i = 0; i < 6; i++) answers.push(await childLogin(t, cred.login, cred.temporaryPassword));

    for (const res of answers) {
      expect(res.statusCode).toBe(401);
      expect(res.json()).toEqual(EXPIRED);
    }
    expect(await row()).toMatchObject({ failedLogins: 0, lockedUntil: null });
  });

  it('a WRONG password after the expiry is still INVALID_CREDENTIALS and counts toward the lock (the expiry is not revealed)', async () => {
    at(expiry() + DAY_MS);
    const statuses: Array<{ status: number; code: string }> = [];

    for (let i = 0; i < 5; i++) {
      const res = await childLogin(t, cred.login, 'Noto-togri1');
      statuses.push({ status: res.statusCode, code: res.json().code });
    }

    expect(statuses).toEqual([
      { status: 401, code: 'INVALID_CREDENTIALS' },
      { status: 401, code: 'INVALID_CREDENTIALS' },
      { status: 401, code: 'INVALID_CREDENTIALS' },
      { status: 401, code: 'INVALID_CREDENTIALS' },
      { status: 429, code: 'LOCKED' },
    ]);
  });

  it('a setupToken obtained before the expiry cannot finish the setup after it (the 15 minute token does not extend the 14 days)', async () => {
    const clock = at(expiry() - MIN);
    const token = (await childLogin(t, cred.login, cred.temporaryPassword)).json().setupToken as string;
    clock.advance(2 * MIN);

    const res = await setup(token);

    expect(res.statusCode).toBe(401);
    expect(res.json()).toEqual(EXPIRED);
    expect(await t.prisma.userSession.count({ where: { userId: child.userId } })).toBe(0);
    expect(await row()).toMatchObject({ mustChangePassword: true });
  });

  it('the parent reset renews the temporary password: the new one works, the expired one is gone', async () => {
    at(expiry() + DAY_MS);
    expect((await childLogin(t, cred.login, cred.temporaryPassword)).json().code).toBe('TEMP_PASSWORD_EXPIRED');

    const next = await issueAsParent(t, parent, child.childId);

    expect(Date.parse(next.temporaryPasswordExpiresAt)).toBe(expiry() + DAY_MS + TEMP_PASSWORD_TTL_DAYS * DAY_MS);
    expect(next.login).toBe(cred.login);
    const fresh = await childLogin(t, next.login, next.temporaryPassword);
    expect(fresh.statusCode).toBe(200);
    expect(fresh.json().status).toBe('SETUP_REQUIRED');
    expect((await childLogin(t, cred.login, cred.temporaryPassword)).json().code).toBe('INVALID_CREDENTIALS');
  });

  it('does not apply to an own password: it works long after the 14 days, with the same session rules', async () => {
    await loginThroughSetup(t, cred, device('dev-a'));
    at(expiry() + 100 * DAY_MS);

    const session = await loginPlain(t, cred.login, device('dev-b'));

    expect(session.userId).toBe(child.userId);
    expect(await row()).toMatchObject({ mustChangePassword: false });
  });

  it('the child can ask for a new password after the expiry (recovery request), which is the way back', async () => {
    at(expiry() + DAY_MS);

    const res = await api(t, 'POST', '/auth/child-recovery', { payload: { login: cred.login, channel: 'PARENT' } });

    expect(res.statusCode).toBe(202);
  });
});
