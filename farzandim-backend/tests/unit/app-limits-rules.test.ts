import { describe, expect, test } from 'vitest';

// AppLimit business rules — sof funksiyalar (DB'siz).
// Backend module ichidan import qila olmaymiz (Prisma init kerak), shuning uchun
// validation logic'ni shu yerda ham yozamiz (Day 1 unit test, e2e alohida).

const MAX_DAY_MS = 24 * 60 * 60 * 1000; // 86_400_000
const MAX_WEEK_MS = 7 * MAX_DAY_MS;

function validateLimits(dailyMs: bigint, weeklyMs?: bigint | null): string | null {
  if (dailyMs < 0n || dailyMs > BigInt(MAX_DAY_MS)) {
    return `dailyLimitMs must be 0..${MAX_DAY_MS} (1 kun)`;
  }
  if (weeklyMs !== undefined && weeklyMs !== null) {
    if (weeklyMs < 0n || weeklyMs > BigInt(MAX_WEEK_MS)) {
      return `weeklyLimitMs must be 0..${MAX_WEEK_MS} (1 hafta)`;
    }
    if (weeklyMs < dailyMs) {
      return 'weeklyLimitMs cannot be less than dailyLimitMs';
    }
  }
  return null;
}

describe('AppLimit validation', () => {
  test('accepts zero daily (no limit)', () => {
    expect(validateLimits(0n)).toBeNull();
  });

  test('accepts 15 min daily (typical YouTube limit)', () => {
    expect(validateLimits(BigInt(15 * 60 * 1000))).toBeNull();
  });

  test('accepts daily at exact 24h boundary', () => {
    expect(validateLimits(BigInt(MAX_DAY_MS))).toBeNull();
  });

  test('rejects negative daily', () => {
    expect(validateLimits(-1n)).toContain('dailyLimitMs');
  });

  test('rejects daily above 24h', () => {
    expect(validateLimits(BigInt(MAX_DAY_MS + 1))).toContain('dailyLimitMs');
  });

  test('accepts weekly null (no weekly cap)', () => {
    expect(validateLimits(BigInt(60 * 1000), null)).toBeNull();
  });

  test('accepts weekly >= daily', () => {
    const daily = BigInt(15 * 60 * 1000);
    const weekly = BigInt(2 * 60 * 60 * 1000); // 2 soat
    expect(validateLimits(daily, weekly)).toBeNull();
  });

  test('rejects weekly < daily (logical contradiction)', () => {
    const daily = BigInt(60 * 60 * 1000); // 1 soat
    const weekly = BigInt(30 * 60 * 1000); // 30 min
    expect(validateLimits(daily, weekly)).toContain('weeklyLimitMs cannot be less');
  });

  test('rejects weekly above 7 days', () => {
    expect(validateLimits(0n, BigInt(MAX_WEEK_MS + 1))).toContain('weeklyLimitMs');
  });

  test('BigInt safe for max safe integer range', () => {
    // 1 hafta = ~6×10^8 ms — Number.MAX_SAFE_INTEGER (9×10^15) ichida xavfsiz
    const weekMs = MAX_WEEK_MS;
    expect(Number(BigInt(weekMs))).toBe(weekMs);
    expect(weekMs).toBeLessThan(Number.MAX_SAFE_INTEGER);
  });
});

describe('AppLimit serialization (BigInt → Number)', () => {
  function serialize(limit: { dailyLimitMs: bigint; weeklyLimitMs: bigint | null }) {
    return {
      ...limit,
      dailyLimitMs: Number(limit.dailyLimitMs),
      weeklyLimitMs: limit.weeklyLimitMs === null ? null : Number(limit.weeklyLimitMs),
    };
  }

  test('converts BigInt to Number for daily', () => {
    const result = serialize({ dailyLimitMs: BigInt(900_000), weeklyLimitMs: null });
    expect(result.dailyLimitMs).toBe(900_000);
    expect(typeof result.dailyLimitMs).toBe('number');
  });

  test('preserves null weekly', () => {
    const result = serialize({ dailyLimitMs: 0n, weeklyLimitMs: null });
    expect(result.weeklyLimitMs).toBeNull();
  });

  test('converts BigInt weekly to Number', () => {
    const result = serialize({ dailyLimitMs: 0n, weeklyLimitMs: BigInt(7_200_000) });
    expect(result.weeklyLimitMs).toBe(7_200_000);
  });
});
