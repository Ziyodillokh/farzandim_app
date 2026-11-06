import { ExecutionContext, HttpException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ThrottlerStorageService } from '@nestjs/throttler';
import { StructuredThrottlerGuard } from '../../common/throttle/structured-throttler.guard';
import {
  buildThrottlers,
  CHILD_LOGIN_IP_LIMIT,
  CHILD_RECOVERY_IP_LIMIT,
  CHILD_RECOVERY_LOGIN_LIMIT,
  isThrottlerDeclared,
  loginTracker,
  THROTTLER_NAMES,
} from '../../common/throttle/throttle.config';
import { ChildLoginController } from './child-login.controller';
import { ChildRecoveryController } from './child-recovery.controller';

// `jose` faqat ESM — AuthService importi zanjirida keladi, test uchun kerak emas.
jest.mock('jose', () => ({ createRemoteJWKSet: jest.fn(), jwtVerify: jest.fn() }));

type Req = { ip: string; body: { login?: unknown }; headers: object };
type Ctor = new (...args: never[]) => unknown;

const contextFor = (controller: Ctor, handler: string, req: Req): ExecutionContext => {
  const res = { header: jest.fn() };
  return {
    getHandler: () => (controller.prototype as Record<string, unknown>)[handler],
    getClass: () => controller,
    switchToHttp: () => ({ getRequest: () => req, getResponse: () => res }),
  } as unknown as ExecutionContext;
};

describe('child auth rate limits', () => {
  let storage: ThrottlerStorageService;
  let guard: StructuredThrottlerGuard;

  beforeEach(async () => {
    storage = new ThrottlerStorageService();
    guard = new StructuredThrottlerGuard(buildThrottlers(), storage, new Reflector());
    await guard.onModuleInit();
  });
  afterEach(() => storage.onApplicationShutdown());

  async function outcomes(controller: Ctor, handler: string, count: number, req: (i: number) => Req) {
    const results: Array<'ok' | HttpException> = [];
    for (let i = 0; i < count; i++) {
      try {
        await guard.canActivate(contextFor(controller, handler, req(i)));
        results.push('ok');
      } catch (err) {
        if (!(err instanceof HttpException)) throw err;
        results.push(err);
      }
    }
    return results;
  }

  it('declares each limit only on the routes that use it', () => {
    const ctx = (c: Ctor, h: string) => contextFor(c, h, { ip: '1.1.1.1', body: {}, headers: {} });

    expect(isThrottlerDeclared(ctx(ChildLoginController, 'childLogin'), THROTTLER_NAMES.childLogin)).toBe(true);
    expect(isThrottlerDeclared(ctx(ChildLoginController, 'childSetup'), THROTTLER_NAMES.childLogin)).toBe(true);
    expect(isThrottlerDeclared(ctx(ChildLoginController, 'devices'), THROTTLER_NAMES.childLogin)).toBe(false);
    expect(isThrottlerDeclared(ctx(ChildLoginController, 'changePassword'), THROTTLER_NAMES.childLogin)).toBe(false);
    expect(isThrottlerDeclared(ctx(ChildRecoveryController, 'request'), THROTTLER_NAMES.childRecoveryLogin)).toBe(true);
    expect(isThrottlerDeclared(ctx(ChildRecoveryController, 'request'), THROTTLER_NAMES.childRecoveryIp)).toBe(true);
    expect(isThrottlerDeclared(ctx(ChildRecoveryController, 'request'), THROTTLER_NAMES.childLogin)).toBe(false);
    expect(isThrottlerDeclared(ctx(ChildRecoveryController, 'status'), THROTTLER_NAMES.childRecoveryIp)).toBe(false);
    expect(isThrottlerDeclared(ctx(ChildLoginController, 'childLogin'), THROTTLER_NAMES.childRecoveryIp)).toBe(false);
  });

  it('allows 30 child-login requests per IP in 10 minutes, then answers a structured 429', async () => {
    const results = await outcomes(ChildLoginController, 'childLogin', CHILD_LOGIN_IP_LIMIT.limit + 2, (i) => ({
      ip: '10.0.0.1',
      body: { login: `user.${i}` },
      headers: {},
    }));

    expect(CHILD_LOGIN_IP_LIMIT).toEqual({ limit: 30, ttl: 600_000 });
    expect(results.slice(0, 30).every((r) => r === 'ok')).toBe(true);
    const blocked = results[30] as HttpException;
    expect(blocked.getStatus()).toBe(429);
    expect(blocked.getResponse()).toMatchObject({ code: 'RATE_LIMITED', retryAfterSeconds: expect.any(Number) });
    expect((blocked.getResponse() as { retryAfterSeconds: number }).retryAfterSeconds).toBeGreaterThan(0);
  });

  it('does not let one IP exhaust another IP', async () => {
    await outcomes(ChildLoginController, 'childLogin', 40, () => ({ ip: '10.0.0.2', body: {}, headers: {} }));

    const other = await outcomes(ChildLoginController, 'childLogin', 1, () => ({ ip: '10.0.0.3', body: {}, headers: {} }));

    expect(other).toEqual(['ok']);
  });

  it('keeps child-login and child-setup counters apart', async () => {
    await outcomes(ChildLoginController, 'childLogin', 31, () => ({ ip: '10.0.0.4', body: {}, headers: {} }));

    const setup = await outcomes(ChildLoginController, 'childSetup', 1, () => ({ ip: '10.0.0.4', body: {}, headers: {} }));

    expect(setup).toEqual(['ok']);
  });

  it('limits recovery requests to 3 per day per login text, whatever the IP and whether the login exists', async () => {
    const results = await outcomes(ChildRecoveryController, 'request', 5, (i) => ({
      ip: `10.1.0.${i}`,
      body: { login: i % 2 ? '  AZIZA.K24 ' : 'aziza.k24' },
      headers: {},
    }));

    expect(CHILD_RECOVERY_LOGIN_LIMIT).toEqual({ limit: 3, ttl: 86_400_000 });
    expect(results.map((r) => (r === 'ok' ? 'ok' : r.getStatus()))).toEqual(['ok', 'ok', 'ok', 429, 429]);
    // Boshqa login shu IP'lardan hanuz o'tadi.
    const other = await outcomes(ChildRecoveryController, 'request', 1, () => ({
      ip: '10.1.0.9',
      body: { login: 'boshqa.b11' },
      headers: {},
    }));
    expect(other).toEqual(['ok']);
  });

  it('limits recovery requests to 10 per day per IP across different logins', async () => {
    const results = await outcomes(ChildRecoveryController, 'request', 12, (i) => ({
      ip: '10.2.0.1',
      body: { login: `kimdir.${i}` },
      headers: {},
    }));

    expect(CHILD_RECOVERY_IP_LIMIT).toEqual({ limit: 10, ttl: 86_400_000 });
    expect(results.map((r) => (r === 'ok' ? 'ok' : r.getStatus()))).toEqual([
      ...Array<string>(10).fill('ok'),
      429,
      429,
    ]);
  });

  it('answers the same 429 for existing and unknown logins (the key is the text, not the account)', async () => {
    const known = await outcomes(ChildRecoveryController, 'request', 4, (i) => ({ ip: `10.3.0.${i}`, body: { login: 'bor.b11' }, headers: {} }));
    const unknown = await outcomes(ChildRecoveryController, 'request', 4, (i) => ({ ip: `10.4.0.${i}`, body: { login: 'yoq.y00' }, headers: {} }));

    const shape = (r: 'ok' | HttpException) => (r === 'ok' ? 'ok' : JSON.stringify(r.getResponse()).replace(/\d+/g, 'N'));
    expect(known.map(shape)).toEqual(unknown.map(shape));
  });
});

describe('loginTracker', () => {
  it('tracks by the normalized login text, falling back to the IP', () => {
    expect(loginTracker({ ip: '1.2.3.4', body: { login: '  Aziza.K24 ' } })).toBe('login:aziza.k24');
    expect(loginTracker({ ip: '1.2.3.4', body: {} })).toBe('ip:1.2.3.4');
    expect(loginTracker({ ip: '1.2.3.4', body: { login: 42 } })).toBe('ip:1.2.3.4');
    expect(loginTracker({ ip: '1.2.3.4' })).toBe('ip:1.2.3.4');
    expect(loginTracker({ ip: '1.2.3.4', body: { login: 'x'.repeat(500) } })).toBe(`login:${'x'.repeat(64)}`);
  });
});
