import { describe, expect, test, beforeAll } from 'vitest';
import { createHash, createHmac } from 'crypto';

const BOT_TOKEN = '1234567890:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

beforeAll(() => {
  process.env.NODE_ENV = 'development';
  process.env.DATABASE_URL = process.env.DATABASE_URL ?? 'postgresql://localhost:5432/test';
  process.env.TELEGRAM_BOT_TOKEN = BOT_TOKEN;
  process.env.TELEGRAM_BOT_USERNAME = 'testbot';
  process.env.JWT_ACCESS_SECRET = 'test-access-secret-at-least-32-characters-long';
  process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-at-least-32-characters-long';
  process.env.MINIO_ENDPOINT = 'http://localhost:9000';
  process.env.MINIO_ACCESS_KEY = 'minio';
  process.env.MINIO_SECRET_KEY = 'minio123';
  process.env.MINIO_PUBLIC_URL = 'http://localhost:9000';
});

/** Test helper — Telegram'ning rasmiy formulasi bo'yicha valid hash hisoblash. */
function signTelegramPayload(
  fields: Record<string, string | number>,
  token = BOT_TOKEN,
): string {
  const dataCheckString = Object.keys(fields)
    .sort()
    .filter((k) => fields[k] !== undefined)
    .map((k) => `${k}=${fields[k]}`)
    .join('\n');
  const secret = createHash('sha256').update(token).digest();
  return createHmac('sha256', secret).update(dataCheckString).digest('hex');
}

describe('verifyTelegramAuth', () => {
  test('accepts a payload with a correct hash', async () => {
    const { verifyTelegramAuth } = await import('../../src/modules/auth/telegram');
    const fields = { id: 123, first_name: 'Ali', auth_date: 1715000000 };
    const hash = signTelegramPayload(fields);
    expect(verifyTelegramAuth({ ...fields, hash })).toBe(true);
  });

  test('rejects a tampered first_name', async () => {
    const { verifyTelegramAuth } = await import('../../src/modules/auth/telegram');
    const fields = { id: 123, first_name: 'Ali', auth_date: 1715000000 };
    const hash = signTelegramPayload(fields);
    expect(verifyTelegramAuth({ ...fields, first_name: 'Vali', hash })).toBe(false);
  });

  test('rejects a hash signed with a different token', async () => {
    const { verifyTelegramAuth } = await import('../../src/modules/auth/telegram');
    const fields = { id: 123, first_name: 'Ali', auth_date: 1715000000 };
    const hash = signTelegramPayload(fields, '9999999999:BBB');
    expect(verifyTelegramAuth({ ...fields, hash })).toBe(false);
  });
});

describe('isAuthDataFresh', () => {
  test('accepts auth_date within 24 hours', async () => {
    const { isAuthDataFresh } = await import('../../src/modules/auth/telegram');
    const now = Math.floor(Date.now() / 1000);
    expect(isAuthDataFresh(now - 60)).toBe(true);
  });

  test('rejects auth_date older than 24 hours', async () => {
    const { isAuthDataFresh } = await import('../../src/modules/auth/telegram');
    const now = Math.floor(Date.now() / 1000);
    expect(isAuthDataFresh(now - 86401)).toBe(false);
  });
});
