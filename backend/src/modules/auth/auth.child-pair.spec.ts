import { ConflictException } from '@nestjs/common';
import { AuthService } from './auth.service';

// `jose` faqat ESM — social-auth importi zanjirida keladi, test uchun kerak emas.
jest.mock('jose', () => ({ createRemoteJWKSet: jest.fn(), jwtVerify: jest.fn() }));

/**
 * F7: har do'konning demo (reviewer) kodi alohida va ikkinchi qurilma
 * birinchisini UZMAYDI; oddiy kodlar uchun "bir bola = bir qurilma" saqlanadi.
 */
describe('AuthService.childPair review codes', () => {
  const ENV_KEYS = ['PLAY_REVIEW_FAMILY_CODE', 'APP_REVIEW_FAMILY_CODES'] as const;
  const saved: Record<string, string | undefined> = {};

  const CHILD = {
    id: 'child-1',
    parentId: 'parent-1',
    name: 'Demo',
    age: 9,
    birthDate: null,
    familyCode: '22222',
    childUserId: 'child-user-1',
  };
  const CHILD_USER = {
    id: 'child-user-1',
    name: 'Demo',
    role: 'CHILD',
    tokenVersion: 0,
    avatarUrl: null,
    telegramId: null,
    language: 'uz',
    isActive: true,
  };

  let prisma: {
    child: { findUnique: jest.Mock; update: jest.Mock };
    user: { findUnique: jest.Mock; create: jest.Mock; update: jest.Mock };
    userSession: { updateMany: jest.Mock };
    fcmToken: { deleteMany: jest.Mock };
  };
  let service: AuthService;

  beforeAll(() => {
    for (const k of ENV_KEYS) saved[k] = process.env[k];
  });
  afterAll(() => {
    for (const k of ENV_KEYS) {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    }
  });

  beforeEach(() => {
    process.env.PLAY_REVIEW_FAMILY_CODE = '11111';
    process.env.APP_REVIEW_FAMILY_CODES = '22222';
    prisma = {
      child: {
        findUnique: jest.fn().mockResolvedValue(CHILD),
        update: jest.fn().mockImplementation(({ data }) => ({ ...CHILD, ...data })),
      },
      user: {
        findUnique: jest.fn().mockResolvedValue(CHILD_USER),
        create: jest.fn().mockResolvedValue({ ...CHILD_USER, id: 'new-user' }),
        update: jest.fn().mockReturnValue({ catch: () => undefined }),
      },
      userSession: { updateMany: jest.fn().mockResolvedValue({}) },
      fcmToken: { deleteMany: jest.fn().mockReturnValue({ catch: () => undefined }) },
    };
    const jwt = { sign: jest.fn().mockReturnValue('token') };
    const config = { get: jest.fn().mockReturnValue('x'.repeat(32)) };
    const audit = { log: jest.fn().mockResolvedValue(undefined) };
    const deps = [prisma, jwt, config, audit, {}, {}, {}, {}, {}, {}, {}];
    service = new (AuthService as unknown as new (...a: unknown[]) => AuthService)(
      ...deps,
    );
  });

  it('pairs an extra device to the review profile without logging out the first', async () => {
    // Act
    const res = await service.childPair({ familyCode: '22222' });

    // Assert
    expect(res.user.id).toBe('child-user-1');
    expect(res.accessToken).toBe('token');
    expect(prisma.user.create).not.toHaveBeenCalled();
    expect(prisma.userSession.updateMany).not.toHaveBeenCalled();
    expect(prisma.fcmToken.deleteMany).not.toHaveBeenCalled();
  });

  it('treats the legacy PLAY_REVIEW_FAMILY_CODE the same way', async () => {
    prisma.child.findUnique.mockResolvedValue({ ...CHILD, familyCode: '11111' });

    const res = await service.childPair({ familyCode: '11111' });

    expect(res.user.id).toBe('child-user-1');
  });

  it('re-pairs from scratch when the previous review user is inactive', async () => {
    prisma.user.findUnique.mockResolvedValue({ ...CHILD_USER, isActive: false });

    const res = await service.childPair({ familyCode: '22222' });

    expect(prisma.userSession.updateMany).toHaveBeenCalled();
    expect(prisma.user.create).toHaveBeenCalled();
    expect(res.user.id).toBe('new-user');
  });

  it('keeps one-device-per-child for normal family codes', async () => {
    prisma.child.findUnique.mockResolvedValue({ ...CHILD, familyCode: '33333' });

    await expect(service.childPair({ familyCode: '33333' })).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(prisma.user.create).not.toHaveBeenCalled();
  });

  it('pairs a fresh device to an unpaired profile', async () => {
    prisma.child.findUnique.mockResolvedValue({
      ...CHILD,
      familyCode: '33333',
      childUserId: null,
    });

    const res = await service.childPair({ familyCode: '33333' });

    expect(res.user.id).toBe('new-user');
    expect(res.child.id).toBe('child-1');
  });
});
