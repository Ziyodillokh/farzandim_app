import { describe, expect, test, beforeAll } from 'vitest';

// JWT testlari uchun env'ni sozlash (config/env.ts strict — ishga tushganda fail bo'lmasligi uchun)
beforeAll(() => {
  process.env.NODE_ENV = 'development';
  process.env.DATABASE_URL = process.env.DATABASE_URL ?? 'postgresql://localhost:5432/test';
  process.env.TELEGRAM_BOT_TOKEN =
    process.env.TELEGRAM_BOT_TOKEN ?? '1234567890:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
  process.env.TELEGRAM_BOT_USERNAME = process.env.TELEGRAM_BOT_USERNAME ?? 'testbot';
  process.env.JWT_ACCESS_SECRET =
    process.env.JWT_ACCESS_SECRET ?? 'test-access-secret-at-least-32-characters-long';
  process.env.JWT_REFRESH_SECRET =
    process.env.JWT_REFRESH_SECRET ?? 'test-refresh-secret-at-least-32-characters-long';
  process.env.MINIO_ENDPOINT = process.env.MINIO_ENDPOINT ?? 'http://localhost:9000';
  process.env.MINIO_ACCESS_KEY = process.env.MINIO_ACCESS_KEY ?? 'minio';
  process.env.MINIO_SECRET_KEY = process.env.MINIO_SECRET_KEY ?? 'minio123';
  process.env.MINIO_PUBLIC_URL = process.env.MINIO_PUBLIC_URL ?? 'http://localhost:9000';
});

describe('JWT sign/verify roundtrip', () => {
  test('access token roundtrip preserves payload', async () => {
    const { signAccessToken, verifyAccessToken } = await import('../../src/modules/auth/jwt');
    const token = signAccessToken({ userId: 'u-1', role: 'PARENT' });
    expect(typeof token).toBe('string');

    const decoded = verifyAccessToken(token);
    expect(decoded.userId).toBe('u-1');
    expect(decoded.role).toBe('PARENT');
  });

  test('refresh token roundtrip preserves payload', async () => {
    const { signRefreshToken, verifyRefreshToken } = await import('../../src/modules/auth/jwt');
    const token = signRefreshToken({ userId: 'u-2', role: 'CHILD' });
    const decoded = verifyRefreshToken(token);
    expect(decoded.userId).toBe('u-2');
    expect(decoded.role).toBe('CHILD');
  });

  test('access secret does not verify refresh token', async () => {
    const { signRefreshToken, verifyAccessToken } = await import('../../src/modules/auth/jwt');
    const refresh = signRefreshToken({ userId: 'u-3', role: 'PARENT' });
    expect(() => verifyAccessToken(refresh)).toThrow();
  });

  test('verify throws on tampered token', async () => {
    const { signAccessToken, verifyAccessToken } = await import('../../src/modules/auth/jwt');
    const token = signAccessToken({ userId: 'u-4', role: 'PARENT' });
    const tampered = token.slice(0, -3) + 'XXX';
    expect(() => verifyAccessToken(tampered)).toThrow();
  });
});
