import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { REFRESH_WAIT_MS, settleWithin } from '../settle';

describe('settleWithin', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('tez tugasa — darhol (chegarani kutmaydi)', async () => {
    const done = vi.fn();
    void settleWithin(Promise.resolve('ok'), REFRESH_WAIT_MS).then(done);
    await vi.advanceTimersByTimeAsync(0);
    expect(done).toHaveBeenCalledTimes(1);
  });

  it('xato bilan tugasa ham yutiladi (bir martalik parol yo\'qolmasin)', async () => {
    await expect(settleWithin(Promise.reject(new Error('network')), REFRESH_WAIT_MS)).resolves.toBeUndefined();
  });

  it('osilib qolsa — aynan chegarada qaytadi', async () => {
    const done = vi.fn();
    void settleWithin(new Promise(() => undefined), REFRESH_WAIT_MS).then(done);
    await vi.advanceTimersByTimeAsync(REFRESH_WAIT_MS - 1);
    expect(done).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1);
    expect(done).toHaveBeenCalledTimes(1);
  });

  it('chegara 2 soniya', () => {
    expect(REFRESH_WAIT_MS).toBe(2000);
  });
});
