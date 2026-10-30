import { describe, expect, it } from 'vitest';

import { hasShares, leader } from './leader';
import { openPath } from './radar-path';

describe('leader', () => {
  it("hamma ulush 0 — yetakchi yo'q (birinchi kalit yetakchi deb ko'rsatilmaydi)", () => {
    const items = [
      { key: 'IT', share: 0 },
      { key: 'MEDICINE', share: 0 },
    ];
    expect(leader(items)).toBeUndefined();
    expect(hasShares(items)).toBe(false);
    expect(leader([])).toBeUndefined();
  });

  it("eng katta ulush — ro'yxat tartibiga tayanmaydi; tenglikda — birinchisi", () => {
    expect(leader([{ key: 'a', share: 10 }, { key: 'b', share: 30 }, { key: 'c', share: 20 }])?.key).toBe('b');
    expect(leader([{ key: 'a', share: 30 }, { key: 'b', share: 30 }])?.key).toBe('a');
  });

  it("yashirilgan ulush (null) e'tiborsiz", () => {
    const items = [
      { key: 'a', share: null },
      { key: 'b', share: 5 },
    ];
    expect(leader(items)?.key).toBe('b');
    expect(hasShares(items)).toBe(true);
    expect(hasShares([{ share: null }])).toBe(false);
  });
});

describe('openPath (radar)', () => {
  it("hamma uch bor — yopiq kontur (har qo'shni juftlik)", () => {
    expect(openPath([[0, 0], [10, 0], [5, 5]])).toBe('M0,0L10,0M10,0L5,5M5,5L0,0');
  });

  it("qiymatsiz o'q markazga tortilmaydi — unga tutashgan kesmalar chizilmaydi", () => {
    expect(openPath([[0, 0], null, [5, 5], [0, 5]])).toBe('M5,5L0,5M0,5L0,0');
  });

  it("ikkitadan kam uch yoki hammasi yo'q — bo'sh", () => {
    expect(openPath([[1, 1]])).toBe('');
    expect(openPath([null, null, null])).toBe('');
  });
});
