import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { ChildAuthClock } from './child-auth-clock';
import { CHILD_LOGIN_IP_FAILURES } from './child-auth.constants';
import { invalidCredentials, lockedError, setupTokenInvalid, tempPasswordExpired, weakPassword } from './child-auth.errors';
import { ChildAuthIpLimits, errorCode } from './child-ip-limits';

const MIN = 60_000;
const T0 = new Date('2026-11-09T09:00:00.000Z');

function setup() {
  const clock = new ChildAuthClock();
  let now = T0;
  clock.now = () => now;
  return { limits: new ChildAuthIpLimits(clock), advance: (ms: number) => { now = new Date(now.getTime() + ms); } };
}

const ok = () => Promise.resolve('ok');
const failWith = (err: Error) => () => Promise.reject(err);
const caught = async (promise: Promise<unknown>) => promise.then(() => null, (e: unknown) => e);
const status = (err: unknown) => (err as { getStatus(): number }).getStatus();
const body = (err: unknown) => (err as { getResponse(): Record<string, unknown> }).getResponse();

describe('ChildAuthIpLimits', () => {
  it('never counts successful attempts: any number of OK logins from one IP is allowed (school Wi-Fi)', async () => {
    const { limits } = setup();

    for (let i = 0; i < 200; i++) expect(await limits.guard('login', '10.0.0.1', ok)).toBe('ok');
  });

  it('allows 30 failed logins per 10 minutes and blocks the 31st request BEFORE the work runs', async () => {
    const { limits } = setup();
    for (let i = 0; i < CHILD_LOGIN_IP_FAILURES; i++) {
      expect(status(await caught(limits.guard('login', '10.0.0.1', failWith(invalidCredentials()))))).toBe(401);
    }
    const work = jest.fn(ok);

    const err = await caught(limits.guard('login', '10.0.0.1', work));

    expect(CHILD_LOGIN_IP_FAILURES).toBe(30);
    expect(work).not.toHaveBeenCalled();
    expect(status(err)).toBe(429);
    expect(body(err)).toMatchObject({ code: 'RATE_LIMITED', message: 'Too many requests', retryAfterSeconds: 600 });
  });

  it('blocks even a would-be successful login while the IP has too many failures, and unblocks after the window', async () => {
    const { limits, advance } = setup();
    for (let i = 0; i < 30; i++) await caught(limits.guard('login', '10.0.0.1', failWith(invalidCredentials())));

    expect(status(await caught(limits.guard('login', '10.0.0.1', ok)))).toBe(429);
    advance(10 * MIN + 1_000);

    expect(await limits.guard('login', '10.0.0.1', ok)).toBe('ok');
  });

  it('counts both INVALID_CREDENTIALS and LOCKED responses as failures', async () => {
    const { limits } = setup();
    for (let i = 0; i < 15; i++) await caught(limits.guard('login', '10.0.0.1', failWith(invalidCredentials())));
    for (let i = 0; i < 15; i++) await caught(limits.guard('login', '10.0.0.1', failWith(lockedError(900))));

    expect(status(await caught(limits.guard('login', '10.0.0.1', ok)))).toBe(429);
  });

  it('does not count expired temporary passwords, validation errors or unexpected errors', async () => {
    const { limits } = setup();
    for (let i = 0; i < 40; i++) {
      await caught(limits.guard('login', '10.0.0.1', failWith(tempPasswordExpired())));
      await caught(limits.guard('login', '10.0.0.1', failWith(new BadRequestException('x'))));
      await caught(limits.guard('login', '10.0.0.1', failWith(new Error('boom'))));
      await caught(limits.guard('login', '10.0.0.1', failWith(new UnauthorizedException('plain'))));
    }

    expect(await limits.guard('login', '10.0.0.1', ok)).toBe('ok');
  });

  it('keeps IPs apart', async () => {
    const { limits } = setup();
    for (let i = 0; i < 30; i++) await caught(limits.guard('login', '10.0.0.1', failWith(invalidCredentials())));

    expect(await limits.guard('login', '10.0.0.2', ok)).toBe('ok');
    expect(status(await caught(limits.guard('login', '10.0.0.1', ok)))).toBe(429);
  });

  it('counts only SETUP_TOKEN_INVALID for child-setup (weak passwords and successes are free)', async () => {
    const { limits } = setup();
    for (let i = 0; i < 100; i++) {
      await caught(limits.guard('setup', '10.0.0.1', failWith(weakPassword('TOO_SHORT'))));
      await limits.guard('setup', '10.0.0.1', ok);
    }
    expect(await limits.guard('setup', '10.0.0.1', ok)).toBe('ok');

    for (let i = 0; i < 30; i++) await caught(limits.guard('setup', '10.0.0.1', failWith(setupTokenInvalid())));

    expect(status(await caught(limits.guard('setup', '10.0.0.1', ok)))).toBe(429);
  });

  it('keeps the login and the setup budgets apart', async () => {
    const { limits } = setup();
    for (let i = 0; i < 30; i++) await caught(limits.guard('login', '10.0.0.1', failWith(invalidCredentials())));
    for (let i = 0; i < 30; i++) await caught(limits.guard('setup', '10.0.0.2', failWith(setupTokenInvalid())));

    expect(await limits.guard('setup', '10.0.0.1', ok)).toBe('ok');
    expect(await limits.guard('login', '10.0.0.2', ok)).toBe('ok');
    // Login'dagi INVALID_CREDENTIALS setup'ga, SETUP_TOKEN_INVALID login'ga sanalmaydi.
    for (let i = 0; i < 40; i++) await caught(limits.guard('login', '10.0.0.3', failWith(setupTokenInvalid())));
    expect(await limits.guard('login', '10.0.0.3', ok)).toBe('ok');
  });

  it('treats a missing IP as one shared bucket instead of crashing', async () => {
    const { limits } = setup();
    for (let i = 0; i < 30; i++) await caught(limits.guard('login', undefined, failWith(invalidCredentials())));

    expect(status(await caught(limits.guard('login', undefined, ok)))).toBe(429);
    expect(status(await caught(limits.guard('login', '  ', ok)))).toBe(429);
  });

  it('rethrows the original error unchanged', async () => {
    const { limits } = setup();
    const original = invalidCredentials();

    expect(await caught(limits.guard('login', '10.0.0.1', failWith(original)))).toBe(original);
  });
});

describe('errorCode', () => {
  it('reads the code of an HttpException response', () => {
    expect(errorCode(invalidCredentials())).toBe('INVALID_CREDENTIALS');
    expect(errorCode(lockedError(5))).toBe('LOCKED');
    expect(errorCode(new BadRequestException('plain text'))).toBeUndefined();
    expect(errorCode(new Error('x'))).toBeUndefined();
    expect(errorCode('x')).toBeUndefined();
  });
});
