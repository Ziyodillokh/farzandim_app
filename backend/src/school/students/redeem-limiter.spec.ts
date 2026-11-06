import { FailureLimiter } from './redeem-limiter';

describe('FailureLimiter', () => {
  const WINDOW = 15 * 60_000;
  const T0 = 1_000_000;

  it('blocks only after `max` failures inside the window', () => {
    const limiter = new FailureLimiter(3, WINDOW);

    limiter.fail('k', T0);
    limiter.fail('k', T0 + 1);
    expect(limiter.blocked('k', T0 + 2)).toBe(false);
    limiter.fail('k', T0 + 2);

    expect(limiter.blocked('k', T0 + 3)).toBe(true);
    expect(limiter.blocked('other', T0 + 3)).toBe(false);
  });

  it('forgets failures after the window', () => {
    const limiter = new FailureLimiter(2, WINDOW);
    limiter.fail('k', T0);
    limiter.fail('k', T0 + 10);

    expect(limiter.blocked('k', T0 + WINDOW - 1)).toBe(true);
    expect(limiter.blocked('k', T0 + WINDOW)).toBe(false); // birinchi xato oynadan chiqdi: 1 < 2
    expect(limiter.blocked('k', T0 + WINDOW + 10)).toBe(false);
  });

  describe('retryAfterMs', () => {
    it('is 0 while not blocked', () => {
      const limiter = new FailureLimiter(2, WINDOW);
      limiter.fail('k', T0);

      expect(limiter.retryAfterMs('k', T0 + 5)).toBe(0);
      expect(limiter.retryAfterMs('unknown', T0)).toBe(0);
    });

    it('is the time until the oldest counted failure leaves the window', () => {
      const limiter = new FailureLimiter(2, WINDOW);
      limiter.fail('k', T0);
      limiter.fail('k', T0 + 60_000);

      expect(limiter.retryAfterMs('k', T0 + 120_000)).toBe(WINDOW - 120_000);
      expect(limiter.retryAfterMs('k', T0 + WINDOW - 1)).toBe(1);
      expect(limiter.retryAfterMs('k', T0 + WINDOW)).toBe(0); // birinchi xato chiqdi, bitta qoldi -> blok tugadi
    });

    it('accounts for failures beyond the maximum (parallel requests)', () => {
      const limiter = new FailureLimiter(2, WINDOW);
      limiter.fail('k', T0);
      limiter.fail('k', T0 + 1_000);
      limiter.fail('k', T0 + 2_000);

      // Hisob 2 dan pastga tushishi uchun ikkinchi xato (T0+1000) chiqishi kerak
      expect(limiter.retryAfterMs('k', T0 + 3_000)).toBe(WINDOW - 2_000);
    });
  });

  it('clear() forgets everything', () => {
    const limiter = new FailureLimiter(1, WINDOW);
    limiter.fail('k', T0);
    expect(limiter.blocked('k', T0)).toBe(true);

    limiter.clear();

    expect(limiter.blocked('k', T0)).toBe(false);
  });

  it('drops idle keys once per window so one-off failures from many sources do not pile up in memory', () => {
    const limiter = new FailureLimiter(5, WINDOW);
    for (let i = 0; i < 1_000; i += 1) limiter.fail(`source-${i}`, T0);
    expect(limiter.size).toBe(1_000);

    limiter.fail('late', T0 + WINDOW + 1);

    expect(limiter.size).toBe(1);
    expect(limiter.blocked('source-1', T0 + WINDOW + 1)).toBe(false);
  });
});
