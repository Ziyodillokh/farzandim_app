import { calculateNewStreak, levelForXp, statusForXp } from './gamification-rules';

describe('calculateNewStreak (Toshkent kunlari)', () => {
  const now = new Date('2026-10-19T10:00:00Z'); // Toshkent: 19-okt 15:00

  it('birinchi faollik — 1', () => {
    expect(calculateNewStreak(null, 0, now)).toEqual({ newStreak: 1, isNewDay: true });
  });

  it('bugun allaqachon faol — o\'zgarmaydi', () => {
    // UTC 18-okt 20:00 = Toshkent 19-okt 01:00 — o'sha kun.
    const last = new Date('2026-10-18T20:00:00Z');
    expect(calculateNewStreak(last, 4, now)).toEqual({ newStreak: 4, isNewDay: false });
  });

  it('kecha faol — +1', () => {
    const last = new Date('2026-10-18T12:00:00Z');
    expect(calculateNewStreak(last, 4, now)).toEqual({ newStreak: 5, isNewDay: true });
  });

  it('bir kun o\'tkazib yuborilgan — 1 dan', () => {
    const last = new Date('2026-10-17T12:00:00Z');
    expect(calculateNewStreak(last, 9, now)).toEqual({ newStreak: 1, isNewDay: true });
  });

  it('bugun faol, lekin streak 0 bo\'lib qolgan — kamida 1', () => {
    expect(calculateNewStreak(new Date('2026-10-19T09:00:00Z'), 0, now).newStreak).toBe(1);
  });
});

describe('level / status', () => {
  it('XP chegaralari', () => {
    expect(levelForXp(-5)).toBe(1);
    expect(levelForXp(0)).toBe(1);
    expect(levelForXp(100)).toBe(3);
    expect(statusForXp(299)).toBe('Boshlovchi');
    expect(statusForXp(300)).toBe('Izlanuvchi');
    expect(statusForXp(5000)).toBe('Mentor');
  });
});
