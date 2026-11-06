import { HttpException } from '@nestjs/common';
import { CHILD_FAILURES, IP_FAILURES, LINK_WINDOW_MS, LinkAttemptLimiter } from './link-attempt-limiter';
import { CodeInvalidException } from './link-errors';

describe('LinkAttemptLimiter', () => {
  const T0 = 5_000_000;
  let limiter: LinkAttemptLimiter;

  beforeEach(() => {
    limiter = new LinkAttemptLimiter();
  });

  it('uses 5 wrong codes per child and 60 per IP (school NAT) within 15 minutes', () => {
    expect([CHILD_FAILURES, IP_FAILURES, LINK_WINDOW_MS]).toEqual([5, 60, 15 * 60_000]);
  });

  it('locks a child after 5 failures with the remaining time rounded up to seconds', () => {
    for (let i = 0; i < 4; i += 1) limiter.fail('child-1', '1.1.1.1', T0 + i);
    expect(limiter.retryAfterSeconds('child-1', '1.1.1.1', T0 + 10)).toBe(0);
    limiter.fail('child-1', '1.1.1.1', T0 + 4);

    expect(limiter.retryAfterSeconds('child-1', '1.1.1.1', T0 + 1_000)).toBe(899);
    expect(limiter.retryAfterSeconds('child-1', '1.1.1.1', T0 + 61_000)).toBe(839);
    expect(limiter.retryAfterSeconds('child-1', '1.1.1.1', T0 + LINK_WINDOW_MS - 400)).toBe(1);
    expect(limiter.retryAfterSeconds('child-1', '1.1.1.1', T0 + LINK_WINDOW_MS)).toBe(0);
  });

  it('locks other children behind the same IP after 20 failures, but not other IPs', () => {
    for (let i = 0; i < IP_FAILURES; i += 1) limiter.fail(`child-${i % 5}`, '2.2.2.2', T0 + i);

    expect(limiter.retryAfterSeconds('fresh-child', '2.2.2.2', T0 + 100)).toBeGreaterThan(0);
    expect(limiter.retryAfterSeconds('fresh-child', '3.3.3.3', T0 + 100)).toBe(0);
  });

  it('a child lock does not affect other children on other IPs', () => {
    for (let i = 0; i < CHILD_FAILURES; i += 1) limiter.fail('child-a', '4.4.4.4', T0 + i);

    expect(limiter.retryAfterSeconds('child-a', '9.9.9.9', T0 + 50)).toBeGreaterThan(0);
    expect(limiter.retryAfterSeconds('child-b', '9.9.9.9', T0 + 50)).toBe(0);
  });

  it('reset() clears both counters', () => {
    for (let i = 0; i < CHILD_FAILURES; i += 1) limiter.fail('child-a', '5.5.5.5', T0);

    limiter.reset();

    expect(limiter.retryAfterSeconds('child-a', '5.5.5.5', T0)).toBe(0);
  });

  describe('guarded', () => {
    const tick = () => new Promise<void>((resolve) => setImmediate(resolve));
    const invalid = async () => {
      await tick();
      throw new CodeInvalidException();
    };

    it('returns the result of a successful attempt and does not count it', async () => {
      for (let i = 0; i < 20; i += 1) await expect(limiter.guarded('c', 'ip', async () => 'ok')).resolves.toBe('ok');

      expect(limiter.retryAfterSeconds('c', 'ip')).toBe(0);
    });

    it('counts only CODE_INVALID failures and then answers 429 LOCKED without running the attempt', async () => {
      const run = jest.fn(invalid);
      for (let i = 0; i < CHILD_FAILURES; i += 1) await expect(limiter.guarded('c', 'ip', run)).rejects.toBeInstanceOf(CodeInvalidException);

      const blocked = await limiter.guarded('c', 'ip', run).catch((e) => e);

      expect(run).toHaveBeenCalledTimes(CHILD_FAILURES);
      expect(blocked).toBeInstanceOf(HttpException);
      expect((blocked as HttpException).getStatus()).toBe(429);
      expect((blocked as HttpException).getResponse()).toMatchObject({ code: 'LOCKED', retryAfterSeconds: expect.any(Number) });
    });

    it('does not count other errors', async () => {
      for (let i = 0; i < 10; i += 1) await expect(limiter.guarded('c', 'ip', async () => Promise.reject(new Error('db down')))).rejects.toThrow('db down');

      expect(limiter.retryAfterSeconds('c', 'ip')).toBe(0);
    });

    it('serializes parallel attempts: a burst cannot slip past the limit', async () => {
      const run = jest.fn(invalid);

      const results = await Promise.allSettled(Array.from({ length: 40 }, () => limiter.guarded('c', 'ip', run)));

      expect(run).toHaveBeenCalledTimes(CHILD_FAILURES);
      expect(results.filter((r) => r.status === 'rejected' && r.reason instanceof CodeInvalidException)).toHaveLength(CHILD_FAILURES);
      expect(results.filter((r) => r.status === 'rejected' && r.reason instanceof HttpException && r.reason.getStatus() === 429)).toHaveLength(40 - CHILD_FAILURES);
    });

    it('serializes a burst from one IP across children', async () => {
      const run = jest.fn(invalid);

      await Promise.allSettled(Array.from({ length: IP_FAILURES + 20 }, (_, i) => limiter.guarded(`child-${i}`, 'shared-ip', run)));

      expect(run).toHaveBeenCalledTimes(IP_FAILURES);
    });
  });
});
