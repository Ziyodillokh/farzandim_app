import { SlidingFailureCounter } from './sliding-failure-counter';

const MIN = 60_000;
const T0 = 1_800_000_000_000;

describe('SlidingFailureCounter', () => {
  const make = (max = 3, windowMs = 10 * MIN, maxKeys = 100) => new SlidingFailureCounter(max, windowMs, maxKeys);

  it('blocks a key once `max` failures are inside the window', () => {
    const c = make();
    c.fail('ip', T0);
    c.fail('ip', T0 + 1);
    expect(c.blocked('ip', T0 + 2)).toBe(false);

    c.fail('ip', T0 + 2);

    expect(c.blocked('ip', T0 + 3)).toBe(true);
  });

  it('counts failures per key', () => {
    const c = make();
    for (let i = 0; i < 3; i++) c.fail('a', T0 + i);

    expect(c.blocked('a', T0 + 10)).toBe(true);
    expect(c.blocked('b', T0 + 10)).toBe(false);
  });

  it('lets old failures age out of the window', () => {
    const c = make();
    for (let i = 0; i < 3; i++) c.fail('ip', T0 + i * 1_000);

    expect(c.blocked('ip', T0 + 10 * MIN - 1)).toBe(true);
    expect(c.blocked('ip', T0 + 10 * MIN + 2_100)).toBe(false);
  });

  it('keeps only recent failures: a slow trickle (2 per window) never blocks', () => {
    const c = make(3);
    for (let i = 0; i < 20; i++) c.fail('ip', T0 + i * 6 * MIN);

    expect(c.blocked('ip', T0 + 19 * 6 * MIN + 1)).toBe(false);
  });

  it('reports when the block will be lifted (the oldest of the newest `max` failures leaves the window)', () => {
    const c = make(3);
    c.fail('ip', T0);
    c.fail('ip', T0 + 2 * MIN);
    c.fail('ip', T0 + 4 * MIN);

    // 3 ta xato: eng eskisi T0 da -> T0 + 10 daqiqada chiqadi.
    expect(c.retryAfterSeconds('ip', T0 + 5 * MIN)).toBe(5 * 60);
    expect(c.retryAfterSeconds('other', T0)).toBe(0);
    c.fail('ip', T0 + 6 * MIN); // 4 ta: oxirgi 3 tasidan eng eskisi T0+2 daq
    expect(c.retryAfterSeconds('ip', T0 + 6 * MIN)).toBe(6 * 60);
  });

  it('never reports less than one second while blocked', () => {
    const c = make(1);
    c.fail('ip', T0);

    expect(c.retryAfterSeconds('ip', T0 + 10 * MIN - 1)).toBe(1);
  });

  it('is bounded: expired keys are dropped first, then the oldest', () => {
    const c = make(3, 10 * MIN, 3);
    c.fail('old', T0);
    c.fail('b', T0 + 11 * MIN);
    c.fail('c', T0 + 11 * MIN);
    c.fail('d', T0 + 12 * MIN); // 4-kalit: 'old' (oynasi tugagan) tushadi
    expect(c.size).toBe(3);

    for (let i = 0; i < 20; i++) c.fail(`k${i}`, T0 + 12 * MIN);
    expect(c.size).toBe(3);
  });
});
