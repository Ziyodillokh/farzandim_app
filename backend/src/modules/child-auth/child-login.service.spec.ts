import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { ChildAuthClock } from './child-auth-clock';
import { FAILURE_WINDOW_MS, LOCK_MS, MAX_FAILED_LOGINS } from './child-auth.constants';
import { ChildLoginService } from './child-login.service';
import { ChildSetupTokens } from './child-setup-token';
import { lockRemainingSeconds, registerFailure } from './child-login-lock';

// `jose` faqat ESM — AuthService importi zanjirida keladi, test uchun kerak emas.
jest.mock('jose', () => ({ createRemoteJWKSet: jest.fn(), jwtVerify: jest.fn() }));

const PASSWORD = 'Kitob2026';
const T0 = new Date('2026-11-09T09:00:00.000Z');
const DEVICE = { id: 'install-1', model: 'Redmi', platform: 'android' as const };

/** Tezlik uchun 4 raund (xesh formati haqiqiy bilan bir xil). */
const HASH = bcrypt.hashSync(PASSWORD, 4);

interface Cred {
  childId: string;
  login: string;
  passwordHash: string;
  mustChangePassword: boolean;
  failedLogins: number;
  failedWindowStartedAt: Date | null;
  lockedUntil: Date | null;
  child: { id: string; name: string };
}

const credential = (over: Partial<Cred> = {}): Cred => ({
  childId: 'child-1',
  login: 'aziza.k24',
  passwordHash: HASH,
  mustChangePassword: false,
  failedLogins: 0,
  failedWindowStartedAt: null,
  lockedUntil: null,
  child: { id: 'child-1', name: 'Aziza' },
  ...over,
});

function setup(initial: Cred | null = credential()) {
  const clock = new ChildAuthClock();
  let now = T0;
  clock.now = () => now;

  const state = { cred: initial };
  const prisma = {
    childCredential: {
      findUnique: jest.fn(async ({ where }: { where: { login?: string; childId?: string } }) => {
        const c = state.cred;
        if (!c) return null;
        if (where.login !== undefined) return where.login === c.login ? c : null;
        return where.childId === c.childId ? c : null;
      }),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    child: { findUnique: jest.fn() },
  };
  const attempts = {
    recordFailure: jest.fn(async () => {
      const before = {
        failedLogins: state.cred!.failedLogins,
        failedWindowStartedAt: state.cred!.failedWindowStartedAt,
        lockedUntil: state.cred!.lockedUntil,
      };
      const next = registerFailure(before, now);
      state.cred = { ...state.cred!, ...next };
      return { state: next, justLocked: lockRemainingSeconds(before, now) === 0 && lockRemainingSeconds(next, now) > 0 };
    }),
    recordSuccess: jest.fn(async () => ({ mustChangePassword: state.cred!.mustChangePassword })),
  };
  const sessions = { open: jest.fn().mockResolvedValue({ user: { id: 'user-1', tokenVersion: 0 }, sessionId: 'sid-1', rjti: 'rjti-1' }) };
  const auth = { issueSessionTokens: jest.fn().mockReturnValue({ accessToken: 'access', refreshToken: 'refresh' }) };
  const audit = { log: jest.fn().mockResolvedValue(undefined) };
  const realtime = { emitToUser: jest.fn() };
  const config = { get: jest.fn().mockReturnValue('unit-access-secret-'.padEnd(48, 'a')) };
  const setupTokens = new ChildSetupTokens(new JwtService({}), config as unknown as ConfigService<never, true>);
  const service = new ChildLoginService(
    prisma as never,
    auth as never,
    sessions as never,
    attempts as never,
    setupTokens,
    audit as never,
    realtime as never,
    clock,
  );
  return {
    service,
    prisma,
    attempts,
    sessions,
    auth,
    audit,
    setupTokens,
    state,
    advance: (ms: number) => {
      now = new Date(now.getTime() + ms);
    },
  };
}

const login = (service: ChildLoginService, over: Record<string, unknown> = {}) =>
  service.login({ login: 'aziza.k24', password: PASSWORD, device: DEVICE, ...over });

const status = (err: unknown) => (err as { getStatus(): number }).getStatus();
const body = (err: unknown) => (err as { getResponse(): Record<string, unknown> }).getResponse();
const caught = async (promise: Promise<unknown>) => promise.then(() => null, (e: unknown) => e);

describe('ChildLoginService.login', () => {
  let compare: jest.SpyInstance;

  beforeEach(() => {
    // `import * as` interop obyekti muzlatilgan — asl modulni kuzatamiz (servis xuddi shu modulni o'qiydi).
    compare = jest.spyOn(jest.requireActual<typeof bcrypt>('bcryptjs'), 'compare') as unknown as jest.SpyInstance;
  });
  afterEach(() => jest.restoreAllMocks());

  it('opens a session and returns the OK body for a correct password', async () => {
    const t = setup();

    const res = await login(t.service);

    expect(res).toEqual({
      status: 'OK',
      accessToken: 'access',
      refreshToken: 'refresh',
      sessionId: 'sid-1',
      child: { id: 'child-1', name: 'Aziza' },
      user: { id: 'user-1' },
    });
    expect(t.sessions.open).toHaveBeenCalledWith('child-1', DEVICE, T0);
    expect(t.auth.issueSessionTokens).toHaveBeenCalledWith(
      { userId: 'user-1', role: 'CHILD', tokenVersion: 0, sid: 'sid-1' },
      'rjti-1',
    );
  });

  it('is case- and whitespace-insensitive for the login', async () => {
    const t = setup();

    const res = await login(t.service, { login: '  Aziza.K24 ' });

    expect(res.status).toBe('OK');
  });

  it('asks for the first-time setup (no session yet) while the password is temporary', async () => {
    const t = setup(credential({ mustChangePassword: true }));

    const res = await login(t.service);

    expect(res).toMatchObject({ status: 'SETUP_REQUIRED', child: { id: 'child-1', name: 'Aziza' } });
    expect((res as { setupToken: string }).setupToken).toEqual(expect.any(String));
    expect(t.setupTokens.verify((res as { setupToken: string }).setupToken)).toEqual({
      childId: 'child-1',
      fingerprint: t.setupTokens.fingerprint(HASH),
    });
    expect(t.sessions.open).not.toHaveBeenCalled();
    expect(t.auth.issueSessionTokens).not.toHaveBeenCalled();
  });

  it('answers a wrong password and an unknown login identically (401 INVALID_CREDENTIALS)', async () => {
    const wrong = await caught(login(setup().service, { password: 'Boshqa2026' }));
    const unknown = await caught(login(setup().service, { login: 'nobody.x00' }));
    const malformed = await caught(login(setup().service, { login: 'N o!' }));

    for (const err of [wrong, unknown, malformed]) {
      expect(status(err)).toBe(401);
      expect(body(err)).toEqual({ code: 'INVALID_CREDENTIALS', message: 'Invalid credentials' });
    }
  });

  it('still runs a bcrypt comparison for an unknown or malformed login (no timing difference)', async () => {
    const t = setup();

    await caught(login(t.service, { login: 'nobody.x00' }));
    await caught(login(t.service, { login: '!!' }));
    await caught(login(t.service, { password: 'Boshqa2026' }));

    expect(compare).toHaveBeenCalledTimes(3);
    for (const call of compare.mock.calls) expect(String(call[1])).toMatch(/^\$2[aby]\$\d\d\$/);
    // Noma'lum loginlar uchun DB'da hisob yuritilmaydi (qator yo'q).
    expect(t.attempts.recordFailure).toHaveBeenCalledTimes(1);
  });

  it('locks on the 5th wrong password: that attempt already answers 429 LOCKED with retryAfterSeconds', async () => {
    const t = setup();
    const results: unknown[] = [];
    for (let i = 0; i < MAX_FAILED_LOGINS; i++) {
      results.push(await caught(login(t.service, { password: 'Boshqa2026' })));
      t.advance(1_000);
    }

    expect(results.slice(0, 4).map(status)).toEqual([401, 401, 401, 401]);
    expect(status(results[4])).toBe(429);
    expect(body(results[4])).toMatchObject({ code: 'LOCKED', retryAfterSeconds: 900 });
  });

  it('keeps the account locked even for the correct password, without comparing the password', async () => {
    const t = setup(credential({ lockedUntil: new Date(T0.getTime() + 10 * 60_000) }));

    const err = await caught(login(t.service));

    expect(status(err)).toBe(429);
    expect(body(err)).toMatchObject({ code: 'LOCKED', retryAfterSeconds: 600 });
    expect(compare).not.toHaveBeenCalled();
    expect(t.sessions.open).not.toHaveBeenCalled();
  });

  it('unlocks after 15 minutes (fake clock) and the correct password works again', async () => {
    const t = setup();
    for (let i = 0; i < MAX_FAILED_LOGINS; i++) await caught(login(t.service, { password: 'Boshqa2026' }));
    expect(status(await caught(login(t.service)))).toBe(429);

    t.advance(LOCK_MS - 1_000);
    expect(status(await caught(login(t.service)))).toBe(429);
    t.advance(2_000);
    const res = await login(t.service);

    expect(res.status).toBe('OK');
  });

  it('counts failures within a 15 minute window only', async () => {
    const t = setup();
    for (let i = 0; i < MAX_FAILED_LOGINS - 1; i++) await caught(login(t.service, { password: 'Boshqa2026' }));
    t.advance(FAILURE_WINDOW_MS + 1_000);

    const err = await caught(login(t.service, { password: 'Boshqa2026' }));

    expect(status(err)).toBe(401);
  });

  it('rate-limits unknown logins the same way: 429 from the fifth failure, 401 after the lock expires', async () => {
    const t = setup();
    const answers: number[] = [];
    for (let i = 0; i < MAX_FAILED_LOGINS + 1; i++) {
      answers.push(status(await caught(login(t.service, { login: 'nobody.x00' }))));
    }
    expect(answers).toEqual([401, 401, 401, 401, 429, 429]);

    // 6-urinishda parol tekshirilmagan (xuddi haqiqiy blok kabi tez).
    const callsBefore = compare.mock.calls.length;
    await caught(login(t.service, { login: 'nobody.x00' }));
    expect(compare.mock.calls.length).toBe(callsBefore);

    t.advance(LOCK_MS + 1_000);
    expect(status(await caught(login(t.service, { login: 'nobody.x00' })))).toBe(401);
    expect(t.attempts.recordFailure).not.toHaveBeenCalled();
  });

  it('writes an audit entry without IP / user agent and without credentials', async () => {
    const t = setup();

    await login(t.service);

    expect(t.audit.log).toHaveBeenCalledTimes(1);
    const args = t.audit.log.mock.calls[0]!;
    expect(args).toHaveLength(5);
    expect(JSON.stringify(args)).not.toContain(PASSWORD);
    expect(JSON.stringify(args)).not.toContain('aziza.k24');
  });
});

describe('ChildLoginService.setup', () => {
  afterEach(() => jest.restoreAllMocks());

  const withTemp = () => setup(credential({ mustChangePassword: true }));
  const tokenFor = (t: ReturnType<typeof setup>) => t.setupTokens.sign('child-1', HASH);
  const dto = (t: ReturnType<typeof setup>, over: Record<string, unknown> = {}) => ({
    setupToken: tokenFor(t),
    newPassword: 'Yangi-parol7',
    device: DEVICE,
    ...over,
  });

  it('sets the password and opens a session', async () => {
    const t = withTemp();

    const res = await t.service.setup(dto(t));

    expect(res).toMatchObject({ status: 'OK', sessionId: 'sid-1', child: { id: 'child-1' } });
    expect(t.prisma.childCredential.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { childId: 'child-1', passwordHash: HASH, mustChangePassword: true },
        data: expect.objectContaining({ mustChangePassword: false, failedLogins: 0, lockedUntil: null }),
      }),
    );
    const data = t.prisma.childCredential.updateMany.mock.calls[0]![0].data as { passwordHash: string };
    expect(data.passwordHash).not.toBe(HASH);
    expect(bcrypt.compareSync('Yangi-parol7', data.passwordHash)).toBe(true);
    expect(data.passwordHash).not.toContain('Yangi-parol7');
  });

  it.each([
    ['garbage', 'not-a-token'],
    ['empty', ''],
  ])('rejects a %s setup token', async (_label, token) => {
    const t = withTemp();

    const err = await caught(t.service.setup(dto(t, { setupToken: token })));

    expect(status(err)).toBe(401);
    expect(body(err)).toMatchObject({ code: 'SETUP_TOKEN_INVALID' });
    expect(t.sessions.open).not.toHaveBeenCalled();
  });

  it('rejects a token issued for an older password (already used or the credential was reset)', async () => {
    const t = withTemp();
    const stale = t.setupTokens.sign('child-1', 'an-older-hash');

    const err = await caught(t.service.setup(dto(t, { setupToken: stale })));

    expect(status(err)).toBe(401);
    expect(body(err)).toMatchObject({ code: 'SETUP_TOKEN_INVALID' });
  });

  it('rejects the token once the password is no longer temporary', async () => {
    const t = setup(credential({ mustChangePassword: false }));

    const err = await caught(t.service.setup(dto(t)));

    expect(body(err)).toMatchObject({ code: 'SETUP_TOKEN_INVALID' });
  });

  it('loses a race: a concurrent use of the same token makes the conditional update match nothing', async () => {
    const t = withTemp();
    t.prisma.childCredential.updateMany.mockResolvedValueOnce({ count: 0 });

    const err = await caught(t.service.setup(dto(t)));

    expect(status(err)).toBe(401);
    expect(body(err)).toMatchObject({ code: 'SETUP_TOKEN_INVALID' });
    expect(t.sessions.open).not.toHaveBeenCalled();
  });

  it.each([
    ['short', 'Ab1', 'TOO_SHORT'],
    ['no digit', 'Faqat-harflar', 'NEEDS_DIGIT'],
    ['no letter', '1234567890', 'NEEDS_LETTER'],
    ['the login', 'aziza.k24', 'SAME_AS_LOGIN'],
    ['common', 'Qwerty123', 'TOO_COMMON'],
  ])('rejects a weak password (%s) with 400 WEAK_PASSWORD and a reason', async (_label, newPassword, reason) => {
    const t = withTemp();

    const err = await caught(t.service.setup(dto(t, { newPassword })));

    expect(status(err)).toBe(400);
    expect(body(err)).toMatchObject({ code: 'WEAK_PASSWORD', reason });
    expect(t.prisma.childCredential.updateMany).not.toHaveBeenCalled();
  });

  it('refuses to keep the temporary password as the new password', async () => {
    const t = setup(credential({ mustChangePassword: true, passwordHash: bcrypt.hashSync('Vaqtincha7', 4) }));
    const token = t.setupTokens.sign('child-1', t.state.cred!.passwordHash);

    const err = await caught(t.service.setup({ setupToken: token, newPassword: 'Vaqtincha7', device: DEVICE }));

    expect(body(err)).toMatchObject({ code: 'WEAK_PASSWORD', reason: 'SAME_AS_CURRENT' });
  });
});

describe('ChildLoginService.changePassword', () => {
  afterEach(() => jest.restoreAllMocks());

  const user = { userId: 'user-1', role: 'CHILD' as const, sid: 'sid-1' };

  function withChild(cred: Cred | null = credential()) {
    const t = setup(cred);
    t.prisma.child.findUnique.mockResolvedValue(cred ? { id: 'child-1', credential: cred } : null);
    return t;
  }

  it('answers 404 NO_CREDENTIAL for a child that was paired by family code (no login given)', async () => {
    const t = setup();
    t.prisma.child.findUnique.mockResolvedValue({ id: 'child-1', credential: null });

    const err = await caught(t.service.changePassword(user, { currentPassword: PASSWORD, newPassword: 'Yangi-parol7' }));

    expect(status(err)).toBe(404);
    expect(body(err)).toMatchObject({ code: 'NO_CREDENTIAL' });
  });

  it('counts a wrong current password toward the lock and answers 400 WRONG_PASSWORD', async () => {
    const t = withChild();

    const err = await caught(t.service.changePassword(user, { currentPassword: 'Xato-parol1', newPassword: 'Yangi-parol7' }));

    expect(status(err)).toBe(400);
    expect(body(err)).toMatchObject({ code: 'WRONG_PASSWORD' });
    expect(t.attempts.recordFailure).toHaveBeenCalledWith('child-1', T0);
  });

  it('answers 429 LOCKED once the wrong current passwords lock the account', async () => {
    const t = withChild();
    let last: unknown;
    for (let i = 0; i < MAX_FAILED_LOGINS; i++) {
      t.prisma.child.findUnique.mockResolvedValue({ id: 'child-1', credential: t.state.cred });
      last = await caught(t.service.changePassword(user, { currentPassword: 'Xato-parol1', newPassword: 'Yangi-parol7' }));
    }

    expect(status(last)).toBe(429);
    expect(body(last)).toMatchObject({ code: 'LOCKED' });
  });

  it('rejects a weak or unchanged new password after verifying the current one', async () => {
    const t = withChild();

    const weak = await caught(t.service.changePassword(user, { currentPassword: PASSWORD, newPassword: 'abc' }));
    const same = await caught(t.service.changePassword(user, { currentPassword: PASSWORD, newPassword: PASSWORD }));

    expect(body(weak)).toMatchObject({ code: 'WEAK_PASSWORD', reason: 'TOO_SHORT' });
    expect(body(same)).toMatchObject({ code: 'WEAK_PASSWORD', reason: 'SAME_AS_CURRENT' });
    expect(t.prisma.childCredential.updateMany).not.toHaveBeenCalled();
  });
});
