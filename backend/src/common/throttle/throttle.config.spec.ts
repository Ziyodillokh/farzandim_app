import { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import {
  ThrottlerException,
  ThrottlerGuard,
  ThrottlerStorageService,
} from '@nestjs/throttler';
import { AuthController } from '../../modules/auth/auth.controller';
import { AdminAuthController } from '../../admin/admin-auth/admin-auth.controller';
import {
  CHILD_PAIR_CODE_LIMIT,
  CHILD_PAIR_IP_LIMIT,
  buildThrottlers,
  familyCodeTracker,
  isThrottlerDeclared,
} from './throttle.config';

// `jose` faqat ESM — auth.controller importi zanjirida keladi, test uchun kerak emas.
jest.mock('jose', () => ({ createRemoteJWKSet: jest.fn(), jwtVerify: jest.fn() }));

/**
 * F8/F41 regressiya: `child-pair` faqat O'Z limitlari bilan cheklanadi —
 * admin login (5/10daq) yoki checkout (5/10daq) limiti unga tushmaydi.
 */
describe('throttle.config', () => {
  type Req = { ip: string; body: { familyCode?: string }; headers: object };

  function contextFor(
    controller: new (...args: never[]) => unknown,
    handler: string,
    req: Req,
  ): ExecutionContext {
    const res = { header: jest.fn() };
    return {
      getHandler: () =>
        (controller.prototype as Record<string, unknown>)[handler],
      getClass: () => controller,
      switchToHttp: () => ({ getRequest: () => req, getResponse: () => res }),
    } as unknown as ExecutionContext;
  }

  async function makeGuard(): Promise<{
    guard: ThrottlerGuard;
    storage: ThrottlerStorageService;
  }> {
    const storage = new ThrottlerStorageService();
    const guard = new ThrottlerGuard(buildThrottlers(), storage, new Reflector());
    await guard.onModuleInit();
    return { guard, storage };
  }

  async function attempts(
    guard: ThrottlerGuard,
    count: number,
    req: (i: number) => Req,
  ): Promise<number> {
    let passed = 0;
    for (let i = 0; i < count; i++) {
      try {
        await guard.canActivate(contextFor(AuthController, 'childPair', req(i)));
        passed++;
      } catch (err) {
        if (!(err instanceof ThrottlerException)) throw err;
      }
    }
    return passed;
  }

  let storage: ThrottlerStorageService | undefined;
  afterEach(() => storage?.onApplicationShutdown());

  it('applies only the throttlers a route declares', () => {
    const pair = contextFor(AuthController, 'childPair', {
      ip: '1.1.1.1',
      body: {},
      headers: {},
    });
    const login = contextFor(AdminAuthController, 'login', {
      ip: '1.1.1.1',
      body: {},
      headers: {},
    });

    expect(isThrottlerDeclared(pair, 'childPair')).toBe(true);
    expect(isThrottlerDeclared(pair, 'childPairCode')).toBe(true);
    expect(isThrottlerDeclared(pair, 'adminLogin')).toBe(false);
    expect(isThrottlerDeclared(pair, 'checkout')).toBe(false);
    expect(isThrottlerDeclared(login, 'adminLogin')).toBe(true);
    expect(isThrottlerDeclared(login, 'childPair')).toBe(false);
  });

  it('allows more than 5 child-pair attempts per IP (adminLogin no longer leaks)', async () => {
    // Arrange
    const made = await makeGuard();
    storage = made.storage;

    // Act — har urinish boshqa kod bilan, bitta IP'dan
    const passed = await attempts(made.guard, CHILD_PAIR_IP_LIMIT.limit + 1, (i) => ({
      ip: '10.0.0.1',
      body: { familyCode: String(10000 + i) },
      headers: {},
    }));

    // Assert — aynan IP limiti, undan keyin 429
    expect(passed).toBe(CHILD_PAIR_IP_LIMIT.limit);
  });

  it('limits attempts per family code even when the IP changes', async () => {
    const made = await makeGuard();
    storage = made.storage;

    const passed = await attempts(made.guard, CHILD_PAIR_CODE_LIMIT.limit + 3, (i) => ({
      ip: `10.0.1.${i}`,
      body: { familyCode: '55555' },
      headers: {},
    }));

    expect(passed).toBe(CHILD_PAIR_CODE_LIMIT.limit);
  });

  it('does not let anyone lock a store-review code with the per-code limit', async () => {
    const previous = process.env.APP_REVIEW_FAMILY_CODES;
    process.env.APP_REVIEW_FAMILY_CODES = '77777';
    try {
      const made = await makeGuard();
      storage = made.storage;

      const passed = await attempts(made.guard, CHILD_PAIR_CODE_LIMIT.limit + 3, (i) => ({
        ip: `10.0.2.${i}`,
        body: { familyCode: '77777' },
        headers: {},
      }));

      expect(passed).toBe(CHILD_PAIR_CODE_LIMIT.limit + 3);
    } finally {
      if (previous === undefined) delete process.env.APP_REVIEW_FAMILY_CODES;
      else process.env.APP_REVIEW_FAMILY_CODES = previous;
    }
  });

  it('tracks by family code, falling back to the IP', () => {
    expect(familyCodeTracker({ ip: '1.2.3.4', body: { familyCode: ' 12345 ' } })).toBe(
      'family:12345',
    );
    expect(familyCodeTracker({ ip: '1.2.3.4', body: {} })).toBe('ip:1.2.3.4');
  });
});
