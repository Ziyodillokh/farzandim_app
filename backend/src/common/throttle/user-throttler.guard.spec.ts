import { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ThrottlerException, ThrottlerStorageService } from '@nestjs/throttler';
import { AuthController } from '../../modules/auth/auth.controller';
import { DataDeletionController } from '../../modules/data-deletion/data-deletion.controller';
import {
  buildThrottlers,
  DATA_DELETION_LIMIT,
  isThrottlerDeclared,
  THROTTLER_NAMES,
} from './throttle.config';
import { UserThrottlerGuard } from './user-throttler.guard';

// `jose` faqat ESM — auth.controller importi zanjirida keladi, test uchun kerak emas.
jest.mock('jose', () => ({ createRemoteJWKSet: jest.fn(), jwtVerify: jest.fn() }));

describe('data deletion request rate limit', () => {
  type Req = { ip: string; user?: { userId: string }; body: object; headers: object };

  const contextFor = (controller: new (...args: never[]) => unknown, handler: string, req: Req): ExecutionContext => {
    const res = { header: jest.fn() };
    return {
      getHandler: () => (controller.prototype as Record<string, unknown>)[handler],
      getClass: () => controller,
      switchToHttp: () => ({ getRequest: () => req, getResponse: () => res }),
    } as unknown as ExecutionContext;
  };

  let storage: ThrottlerStorageService;
  let guard: UserThrottlerGuard;

  beforeEach(async () => {
    storage = new ThrottlerStorageService();
    guard = new UserThrottlerGuard(buildThrottlers(), storage, new Reflector());
    await guard.onModuleInit();
  });
  afterEach(() => storage.onApplicationShutdown());

  async function passes(userId: string, count: number, ip = '10.0.0.1'): Promise<number> {
    let passed = 0;
    for (let i = 0; i < count; i++) {
      try {
        await guard.canActivate(contextFor(DataDeletionController, 'create', { ip, user: { userId }, body: {}, headers: {} }));
        passed++;
      } catch (err) {
        if (!(err instanceof ThrottlerException)) throw err;
      }
    }
    return passed;
  }

  it('declares the limit only on the POST route', () => {
    const post = contextFor(DataDeletionController, 'create', { ip: '1.1.1.1', body: {}, headers: {} });
    const latest = contextFor(DataDeletionController, 'latest', { ip: '1.1.1.1', body: {}, headers: {} });
    const pair = contextFor(AuthController, 'childPair', { ip: '1.1.1.1', body: {}, headers: {} });

    expect(isThrottlerDeclared(post, THROTTLER_NAMES.dataDeletion)).toBe(true);
    expect(isThrottlerDeclared(latest, THROTTLER_NAMES.dataDeletion)).toBe(false);
    expect(isThrottlerDeclared(pair, THROTTLER_NAMES.dataDeletion)).toBe(false);
    expect(isThrottlerDeclared(post, THROTTLER_NAMES.childPair)).toBe(false);
  });

  it('allows 3 requests per user per day and blocks the 4th', async () => {
    expect(DATA_DELETION_LIMIT).toEqual({ limit: 3, ttl: 86_400_000 });

    expect(await passes('user-a', 5)).toBe(3);
  });

  it('counts per user, not per IP (shared mobile IP)', async () => {
    expect(await passes('user-a', 3, '10.9.9.9')).toBe(3);
    expect(await passes('user-b', 3, '10.9.9.9')).toBe(3);
  });

  it('does not rate limit unrelated routes with this limit', async () => {
    const latest = contextFor(DataDeletionController, 'latest', { ip: '1.1.1.1', user: { userId: 'u' }, body: {}, headers: {} });

    for (let i = 0; i < 10; i++) expect(await guard.canActivate(latest)).toBe(true);
  });
});
