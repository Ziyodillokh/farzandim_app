// Kirish (K1): bola kirishining IP limiti — FAQAT xato urinishlar sanaladi (10 daqiqada 30 ta). Muvaffaqiyatli kirish
// limitni yemaydi (maktab Wi-Fi'sida NAT ortidagi ko'p bola), parallel "portlash" bir IP'dan 50 ta bir vaqtdagi urinish bilan
// cheklanadi. child-login: INVALID_CREDENTIALS va LOCKED javoblari; child-setup: faqat SETUP_TOKEN_INVALID.

import { resetDb } from './db';
import { TestChild, TestParent } from './factories';
import {
  api,
  childLogin,
  controlClock,
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
const IP_LIMIT = 30;

/** Har test uchun o'z IP'si: limit holati ilova ichida (spec fayli davomida) saqlanadi. */
let ipSeq = 0;
const nextIp = () => `198.18.${Math.floor(ipSeq / 250)}.${(ipSeq += 1) % 250}`;

describe('Kirish K1: IP limiti (faqat xato urinishlar)', () => {
  let t: TestApp;
  let parent: TestParent;
  let child: TestChild;
  let cred: IssuedCredential;
  let unknownSeq = 0;
  let wifi: string;
  const unknownLogin = () => `nobody.ip${(unknownSeq += 1)}`;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    ({ parent, child } = await familyOf(t, 'Aziza Karimova'));
    cred = await issueAsParent(t, parent, child.childId);
    wifi = nextIp();
  });

  afterEach(() => {
    jest.restoreAllMocks();
    restoreClock(t);
  });

  afterAll(() => t.close());

  const wrongLogin = (login: string, ip: string) => childLogin(t, login, 'Noto-togri1', device(), ip);
  const setup = (setupToken: string, ip: string, newPassword = OWN_PASSWORD) =>
    api(t, 'POST', '/auth/child-setup', { payload: { setupToken, newPassword, device: device() }, ip });
  const rateLimited = { statusCode: 429, code: 'RATE_LIMITED', message: 'Too many requests', retryAfterSeconds: expect.any(Number) };

  describe('POST /auth/child-login', () => {
    it('successful logins never use the limit: 31 logins of one IP (a school Wi-Fi) are all answered, and a wrong one is still a plain 401', async () => {
      const statuses: number[] = [];
      for (let i = 0; i <= IP_LIMIT; i++) {
        statuses.push((await childLogin(t, cred.login, cred.temporaryPassword, device(), wifi)).statusCode);
      }

      expect(statuses.every((s) => s === 200)).toBe(true);
      expect((await wrongLogin(unknownLogin(), wifi)).statusCode).toBe(401);
    }, 180_000);

    it('counts wrong passwords AND lock answers: the 31st attempt of one IP is 429 RATE_LIMITED before any password is checked', async () => {
      controlClock(t);
      const first = [];
      for (let i = 0; i < 5; i++) first.push((await wrongLogin(cred.login, wifi)).statusCode);
      // 5. xato blokni qo'yadi (429 LOCKED); qolgan urinishlar parol tekshirmasdan LOCKED qaytaradi — ular ham sanaladi.
      const locked = [];
      for (let i = 0; i < IP_LIMIT - 5; i++) locked.push((await wrongLogin(cred.login, wifi)).statusCode);
      expect(first).toEqual([401, 401, 401, 401, 429]);
      expect(locked.every((s) => s === 429)).toBe(true);

      const compare = jest.spyOn(jest.requireActual<typeof import('bcryptjs')>('bcryptjs'), 'compare');
      const blocked = await childLogin(t, cred.login, cred.temporaryPassword, device(), wifi);

      expect(blocked.statusCode).toBe(429);
      expect(blocked.json()).toEqual({ ...rateLimited, retryAfterSeconds: 600 });
      expect(compare).not.toHaveBeenCalled();
      // Boshqa IP ta'sirlanmaydi; bloklangan IP uchun ham mavjud bo'lmagan login endi "RATE_LIMITED" (401 emas).
      expect((await wrongLogin(unknownLogin(), nextIp())).statusCode).toBe(401);
      expect((await wrongLogin(unknownLogin(), wifi)).json().code).toBe('RATE_LIMITED');
    }, 180_000);

    it('unblocks after 10 minutes (sliding window), to the millisecond', async () => {
      const clock = controlClock(t);
      for (let i = 0; i < IP_LIMIT; i++) await wrongLogin(unknownLogin(), wifi);
      expect((await wrongLogin(unknownLogin(), wifi)).statusCode).toBe(429);

      clock.advance(10 * MIN - 1);
      const stillBlocked = await wrongLogin(unknownLogin(), wifi);
      expect(stillBlocked.statusCode).toBe(429);
      expect(stillBlocked.json().retryAfterSeconds).toBe(1);

      clock.advance(1);
      expect((await wrongLogin(unknownLogin(), wifi)).statusCode).toBe(401);
    }, 180_000);

    it('a blocked IP cannot sign in even with the correct password, while other IPs can', async () => {
      await loginThroughSetup(t, cred, device('dev-a'));
      for (let i = 0; i < IP_LIMIT; i++) await wrongLogin(unknownLogin(), wifi);

      const blocked = await childLogin(t, cred.login, OWN_PASSWORD, device('dev-b'), wifi);
      const elsewhere = await childLogin(t, cred.login, OWN_PASSWORD, device('dev-b'), nextIp());

      expect(blocked.statusCode).toBe(429);
      expect(blocked.json().code).toBe('RATE_LIMITED');
      expect(elsewhere.statusCode).toBe(200);
    }, 180_000);

    it('an expired temporary password is not a failure of the IP (correct credentials never count)', async () => {
      controlClock(t, new Date(Date.parse(cred.temporaryPasswordExpiresAt) + MIN));
      const statuses: Array<{ status: number; code: string }> = [];
      for (let i = 0; i <= IP_LIMIT; i++) {
        const res = await childLogin(t, cred.login, cred.temporaryPassword, device(), wifi);
        statuses.push({ status: res.statusCode, code: res.json().code });
      }

      expect(statuses.every((s) => s.status === 401 && s.code === 'TEMP_PASSWORD_EXPIRED')).toBe(true);
    }, 180_000);

    it('caps simultaneous attempts of one IP (a burst cannot beat the failure counter): the surplus is 429 RATE_LIMITED', async () => {
      const burst = 60;

      const results = await Promise.all(Array.from({ length: burst }, () => wrongLogin(unknownLogin(), wifi)));

      const limited = results.filter((r) => r.statusCode === 429 && r.json().code === 'RATE_LIMITED');
      const plain = results.filter((r) => r.statusCode === 401);
      expect(limited.length).toBeGreaterThanOrEqual(1);
      expect(plain.length).toBeLessThanOrEqual(50);
      expect(plain.length + limited.length).toBe(burst);
      expect(limited.some((r) => r.json().retryAfterSeconds === 1)).toBe(true);
      for (const r of limited) expect(r.json()).toEqual({ ...rateLimited, retryAfterSeconds: r.json().retryAfterSeconds });
    }, 240_000);

    it('keeps counting per IP only: an IP that sent 29 failures is not blocked, and a success does not clear its failures', async () => {
      await loginThroughSetup(t, cred);
      for (let i = 0; i < IP_LIMIT - 1; i++) await wrongLogin(unknownLogin(), wifi);

      expect((await childLogin(t, cred.login, OWN_PASSWORD, device('dev-c'), wifi)).statusCode).toBe(200);
      expect((await wrongLogin(unknownLogin(), wifi)).statusCode).toBe(401); // 30-xato
      expect((await wrongLogin(unknownLogin(), wifi)).statusCode).toBe(429); // 31-urinish
    }, 240_000);
  });

  describe('POST /auth/child-setup', () => {
    it('counts only SETUP_TOKEN_INVALID: rejected weak passwords (400) and the successful setup never use the limit', async () => {
      const token = (await childLogin(t, cred.login, cred.temporaryPassword)).json().setupToken as string;

      const weak: number[] = [];
      for (let i = 0; i <= IP_LIMIT + 4; i++) weak.push((await setup(token, wifi, 'abc')).statusCode);

      expect(weak.every((s) => s === 400)).toBe(true);
      expect((await setup(token, wifi)).statusCode).toBe(200);
    }, 120_000);

    it('30 invalid setup tokens block the 31st with 429 RATE_LIMITED; other IPs and the login endpoint of the same IP are unaffected', async () => {
      const clock = controlClock(t);
      const statuses: number[] = [];
      for (let i = 0; i < IP_LIMIT; i++) statuses.push((await setup(`garbage-${i}`, wifi)).statusCode);

      const blocked = await setup('garbage-final', wifi);

      expect(statuses.every((s) => s === 401)).toBe(true);
      expect(blocked.statusCode).toBe(429);
      expect(blocked.json()).toEqual({ ...rateLimited, retryAfterSeconds: 600 });
      expect((await setup('garbage-other', nextIp())).statusCode).toBe(401);
      // child-login va child-setup hisoblari alohida.
      expect((await wrongLogin(unknownLogin(), wifi)).statusCode).toBe(401);
      // Bloklangan IP to'g'ri token bilan ham o'ta olmaydi, 10 daqiqadan keyin o'tadi.
      const token = (await childLogin(t, cred.login, cred.temporaryPassword, device(), nextIp())).json().setupToken as string;
      expect((await setup(token, wifi)).statusCode).toBe(429);
      clock.advance(10 * MIN);
      expect((await setup(token, wifi)).statusCode).toBe(200);
    }, 120_000);

    it('a used (consumed) token counts as a failure like any other invalid token', async () => {
      const token = (await childLogin(t, cred.login, cred.temporaryPassword)).json().setupToken as string;
      expect((await setup(token, wifi)).statusCode).toBe(200);

      for (let i = 0; i < IP_LIMIT; i++) expect((await setup(token, wifi)).json().code).toBe('SETUP_TOKEN_INVALID');

      expect((await setup(token, wifi)).json().code).toBe('RATE_LIMITED');
    }, 120_000);
  });
});
