import { describe, expect, it } from 'vitest';

import { DIFFICULTY_COLORS, DIFFICULTY_LEVELS, hasDifficulty } from './difficulty';

describe('hasDifficulty', () => {
  it("o'zlashtirish yo'q (servis nollar qaytaradi) — ma'lumot yo'q", () => {
    expect(hasDifficulty({ level1: 0, level2: 0, level3: 0 })).toBe(false);
  });

  it("hech bo'lmasa bitta daraja ulushi bor — ma'lumot bor", () => {
    expect(hasDifficulty({ level1: 0, level2: 0, level3: 5 })).toBe(true);
    expect(hasDifficulty({ level1: 24, level2: 48.9, level3: 27.1 })).toBe(true);
  });
});

describe('qiyinlik darajalari', () => {
  it('tartib: oson → murakkab; har daraja uchun alohida rang', () => {
    expect(DIFFICULTY_LEVELS).toEqual(['level1', 'level2', 'level3']);
    expect(new Set(DIFFICULTY_LEVELS.map((k) => DIFFICULTY_COLORS[k])).size).toBe(DIFFICULTY_LEVELS.length);
  });
});
