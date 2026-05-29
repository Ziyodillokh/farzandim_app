import { describe, expect, test } from 'vitest';
import {
  statusForXp,
  levelForXp,
  calculateNewStreak,
} from '../../src/lib/gamification-rules';

describe('statusForXp', () => {
  test('returns Boshlovchi for xp < 300', () => {
    expect(statusForXp(0)).toBe('Boshlovchi');
    expect(statusForXp(299)).toBe('Boshlovchi');
  });

  test('returns Izlanuvchi for 300 ≤ xp < 900', () => {
    expect(statusForXp(300)).toBe('Izlanuvchi');
    expect(statusForXp(899)).toBe('Izlanuvchi');
  });

  test('returns Bilimdon for 900 ≤ xp < 2000', () => {
    expect(statusForXp(900)).toBe('Bilimdon');
    expect(statusForXp(1999)).toBe('Bilimdon');
  });

  test('returns Lider for 2000 ≤ xp < 5000', () => {
    expect(statusForXp(2000)).toBe('Lider');
    expect(statusForXp(4999)).toBe('Lider');
  });

  test('returns Mentor for xp ≥ 5000', () => {
    expect(statusForXp(5000)).toBe('Mentor');
    expect(statusForXp(99999)).toBe('Mentor');
  });
});

describe('levelForXp', () => {
  test('returns 1 for xp 0 (sqrt(0)/5 + 1)', () => {
    expect(levelForXp(0)).toBe(1);
  });

  test('returns 1 for negative xp', () => {
    expect(levelForXp(-100)).toBe(1);
  });

  test('matches floor(sqrt(xp) / 5) + 1', () => {
    // sqrt(25) / 5 = 1 → level 2
    expect(levelForXp(25)).toBe(2);
    // sqrt(100) / 5 = 2 → level 3
    expect(levelForXp(100)).toBe(3);
    // sqrt(2500) / 5 = 10 → level 11
    expect(levelForXp(2500)).toBe(11);
  });
});

describe('calculateNewStreak', () => {
  const now = new Date(2026, 4, 15, 10, 0, 0); // May 15, 2026, 10:00 local

  test('starts at 1 when no previous activity', () => {
    expect(calculateNewStreak(null, 0, now)).toEqual({ newStreak: 1, isNewDay: true });
  });

  test('keeps streak if last activity was today', () => {
    const earlierToday = new Date(2026, 4, 15, 7, 0, 0);
    expect(calculateNewStreak(earlierToday, 5, now)).toEqual({
      newStreak: 5,
      isNewDay: false,
    });
  });

  test('increments streak if last activity was yesterday', () => {
    const yesterday = new Date(2026, 4, 14, 22, 0, 0);
    expect(calculateNewStreak(yesterday, 5, now)).toEqual({ newStreak: 6, isNewDay: true });
  });

  test('resets to 1 if gap > 1 day', () => {
    const fourDaysAgo = new Date(2026, 4, 11, 9, 0, 0);
    expect(calculateNewStreak(fourDaysAgo, 12, now)).toEqual({ newStreak: 1, isNewDay: true });
  });
});
