// Maktab paneli kirishi: login, bloklash, refresh rotatsiyasi va o'g'irlik
// aniqlanishi, chiqish, parol almashtirish, 2FA, tenant izolyatsiyasi.

import * as speakeasy from 'speakeasy';
import { MAX_FAILED_LOGINS, REFRESH_GRACE_MS } from '../../src/school/auth/school-auth.service';
import { resetDb } from './db';
import { createSchool, createStaff, login, PASSWORD } from './school-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School auth', () => {
  let t: TestApp;

  const post = (url: string, payload?: object, headers: Record<string, string> = {}) =>
    t.app.inject({ method: 'POST', url: `/api/school/auth${url}`, payload, headers });
  const me = (token: string) =>
    t.app.inject({ method: 'GET', url: '/api/school/auth/me', headers: { authorization: `Bearer ${token}` } });

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    await createSchool(t.prisma);
  });

  afterAll(() => t.close());

  it('kirish: token, httpOnly cookie, ruxsatlar va audit', async () => {
    const res = await post('/login', { school: 'TEST-school', username: 'Direktor', password: PASSWORD });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.accessToken).toEqual(expect.any(String));
    expect(body.me).toMatchObject({
      staff: { role: 'DIRECTOR', username: 'direktor' },
      school: { code: 'test-school' },
      scope: 'SCHOOL',
    });
    expect(body.me.permissions).toContain('staff.manage');
    const cookie = res.cookies.find((c) => c.name === 'parvoz_school_rt')!;
    expect(cookie.httpOnly).toBe(true);
    expect(cookie.path).toBe('/api/school/auth');
    expect(cookie.sameSite).toBe('Strict');

    expect((await me(body.accessToken)).json().staff.fullName).toBe('Karimov Akmal');
    expect(await t.prisma.schoolAuditLog.count({ where: { action: 'auth.login' } })).toBe(1);
  });

  it('noto\'g\'ri parol / login / maktab — bir xil 401', async () => {
    for (const payload of [
      { school: 'test-school', username: 'direktor', password: 'wrong-password' },
      { school: 'test-school', username: 'nobody', password: PASSWORD },
      { school: 'no-school', username: 'direktor', password: PASSWORD },
    ]) {
      const res = await post('/login', payload);
      expect(res.statusCode).toBe(401);
      expect(res.json().code).toBe('INVALID_CREDENTIALS');
    }
    expect((await post('/login', { school: 'x' })).statusCode).toBe(400);
  });

  it(`${MAX_FAILED_LOGINS} ta xatodan keyin hisob vaqtincha bloklanadi`, async () => {
    for (let i = 0; i < MAX_FAILED_LOGINS; i++) {
      await post('/login', { school: 'test-school', username: 'direktor', password: 'nope-nope' });
    }
    const locked = await post('/login', { school: 'test-school', username: 'direktor', password: PASSWORD });
    expect(locked.statusCode).toBe(429);
    expect(locked.json().code).toBe('LOCKED');
  });

  const rtCookie = (res: { cookies: { name: string; value: string }[] }) => {
    const c = res.cookies.find((x) => x.name === 'parvoz_school_rt');
    return c && `parvoz_school_rt=${c.value}`;
  };
  /** Oxirgi rotatsiyani imtiyoz oynasidan tashqariga surish. */
  const expireGrace = () =>
    t.prisma.schoolStaffSession.updateMany({
      data: { rotatedAt: new Date(Date.now() - REFRESH_GRACE_MS - 1000) },
    });

  it('refresh rotatsiyasi; eski cookie imtiyozdan keyin ishlatilsa sessiya yopiladi', async () => {
    const session = await login(t.app, 'direktor');
    const first = await post('/refresh', undefined, { cookie: session.cookie });
    expect(first.statusCode).toBe(200);
    const rotated = rtCookie(first)!;
    expect(rotated).not.toBe(session.cookie);

    // O'g'irlangan (eski) cookie — sessiya yopiladi, yangi cookie ham ishlamaydi.
    await expireGrace();
    expect((await post('/refresh', undefined, { cookie: session.cookie })).statusCode).toBe(401);
    expect((await post('/refresh', undefined, { cookie: rotated })).statusCode).toBe(401);
    expect((await me(first.json().accessToken)).statusCode).toBe(401);
  });

  it('parallel refresh (ikki tab): ikkalasi ham 200, cookie bitta marta aylanadi', async () => {
    const session = await login(t.app, 'direktor');
    const [a, b] = await Promise.all([
      post('/refresh', undefined, { cookie: session.cookie }),
      post('/refresh', undefined, { cookie: session.cookie }),
    ]);
    expect([a.statusCode, b.statusCode]).toEqual([200, 200]);
    const issued = [rtCookie(a), rtCookie(b)].filter(Boolean);
    expect(issued).toHaveLength(1);
    for (const res of [a, b]) expect((await me(res.json().accessToken)).statusCode).toBe(200);

    // Yangi cookie bilan sessiya davom etadi.
    const next = await post('/refresh', undefined, { cookie: issued[0]! });
    expect(next.statusCode).toBe(200);
    expect(rtCookie(next)).toEqual(expect.any(String));
  });

  it('imtiyoz oynasida eski cookie access beradi, lekin cookie\'ni almashtirmaydi', async () => {
    const session = await login(t.app, 'direktor');
    const first = await post('/refresh', undefined, { cookie: session.cookie });
    const late = await post('/refresh', undefined, { cookie: session.cookie });
    expect(late.statusCode).toBe(200);
    expect(rtCookie(late)).toBeUndefined();
    expect((await me(late.json().accessToken)).statusCode).toBe(200);
    // Ikki rotatsiya oldingi sir — imtiyoz oynasida ham o'g'irlik.
    const second = await post('/refresh', undefined, { cookie: rtCookie(first)! });
    expect(second.statusCode).toBe(200);
    expect((await post('/refresh', undefined, { cookie: session.cookie })).statusCode).toBe(401);
    expect((await post('/refresh', undefined, { cookie: rtCookie(second)! })).statusCode).toBe(401);
  });

  it('chiqish — access token ham yaroqsiz bo\'ladi', async () => {
    const session = await login(t.app, 'direktor');
    expect((await post('/logout', undefined, { cookie: session.cookie })).statusCode).toBe(204);
    expect((await me(session.token)).statusCode).toBe(401);
  });

  it('faolsizlantirilgan xodim kira olmaydi va tokeni ishlamaydi', async () => {
    const session = await login(t.app, 'direktor');
    await t.prisma.schoolStaff.updateMany({ data: { active: false } });
    expect((await me(session.token)).statusCode).toBe(401);
    expect((await post('/login', { school: 'test-school', username: 'direktor', password: PASSWORD })).statusCode).toBe(401);
  });

  it('parol almashtirish: boshqa sessiyalar yopiladi, joriysi qoladi', async () => {
    const a = await login(t.app, 'direktor');
    const b = await login(t.app, 'direktor');
    const auth = { authorization: `Bearer ${a.token}` };

    const short = await post('/password', { current: PASSWORD, next: 'short' }, auth);
    expect(short.statusCode).toBe(400);
    expect(short.json()).toMatchObject({ code: 'VALIDATION', message: 'next: errors.form.tooShort' });
    expect((await post('/password', { current: 'wrong', next: 'New-Password-2026' }, auth)).statusCode).toBe(400);

    expect((await post('/password', { current: PASSWORD, next: 'New-Password-2026' }, auth)).statusCode).toBe(204);
    expect((await me(a.token)).statusCode).toBe(200);
    expect((await me(b.token)).statusCode).toBe(401);
    expect((await login(t.app, 'direktor', 'test-school', 'New-Password-2026')).token).toBeTruthy();
  });

  it('2FA: yoqilgandan keyin kod talab qilinadi', async () => {
    const session = await login(t.app, 'direktor');
    const auth = { authorization: `Bearer ${session.token}` };
    const setup = (await post('/2fa/setup', undefined, auth)).json();
    expect(setup.otpauthUrl).toContain('otpauth://');
    expect((await post('/2fa/enable', { code: '000000' }, auth)).statusCode).toBe(400);
    const code = speakeasy.totp({ secret: setup.secret, encoding: 'base32' });
    expect((await post('/2fa/enable', { code }, auth)).statusCode).toBe(204);

    const noCode = await post('/login', { school: 'test-school', username: 'direktor', password: PASSWORD });
    expect(noCode.json().code).toBe('TOTP_REQUIRED');
    const ok = await post('/login', {
      school: 'test-school',
      username: 'direktor',
      password: PASSWORD,
      totp: speakeasy.totp({ secret: setup.secret, encoding: 'base32' }),
    });
    expect(ok.statusCode).toBe(200);
  });

  it('tenant: boshqa maktab xodimi, rol va sinf doirasi /me da', async () => {
    const other = await createSchool(t.prisma, 'other-school');
    await createStaff(t.prisma, other.school.id, 'DUTY', 'navbatchi');
    // Bir xil login boshqa maktabda — boshqa hisob.
    expect((await post('/login', { school: 'test-school', username: 'navbatchi', password: PASSWORD })).statusCode).toBe(401);
    const duty = await login(t.app, 'navbatchi', 'other-school');
    expect(duty.me.permissions).toEqual(['dashboard.view', 'attendance.view', 'attendance.mark', 'attendance.kiosk']);
  });
});
