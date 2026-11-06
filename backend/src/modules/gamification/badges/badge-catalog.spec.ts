import {
  applyUnlocks,
  BADGE_IDS,
  readAchievements,
  readDates,
  streakBadgesFor,
  toBadgeItems,
} from './badge-catalog';

describe('badge catalog', () => {
  it('katalog tartibi va barqaror id\'lar', () => {
    expect(BADGE_IDS).toEqual(['streak_7', 'streak_30', 'first_book', 'olympian', 'topic_master', 'thinker']);
  });

  it.each([
    [0, []],
    [6, []],
    [7, ['streak_7']],
    [29, ['streak_7']],
    [30, ['streak_7', 'streak_30']],
    [400, ['streak_7', 'streak_30']],
  ])('streak %i → %j', (days, ids) => {
    expect(streakBadgesFor(days)).toEqual(ids);
  });
});

describe('applyUnlocks', () => {
  const at = new Date('2026-11-05T09:12:00.000Z');
  const empty = { achievements: [], achievementDates: {} };

  it('yangi yutuq qo\'shiladi, vaqt yoziladi; kiruvchi holat o\'zgarmaydi', () => {
    const state = { achievements: ['first_book'], achievementDates: {} };
    const next = applyUnlocks(state, ['streak_7'], at);
    expect(next).toEqual({
      achievements: ['first_book', 'streak_7'],
      dates: { streak_7: '2026-11-05T09:12:00.000Z' },
    });
    expect(state).toEqual({ achievements: ['first_book'], achievementDates: {} });
  });

  it('idempotent: allaqachon bor bo\'lsa null (vaqt qayta yozilmaydi)', () => {
    const state = { achievements: ['streak_7'], achievementDates: { streak_7: '2026-01-01T00:00:00.000Z' } };
    expect(applyUnlocks(state, ['streak_7'], at)).toBeNull();
    expect(applyUnlocks(state, [], at)).toBeNull();
  });

  it('takroriy id\'lar bir marta; mavjudlari o\'tkaziladi', () => {
    const next = applyUnlocks({ achievements: ['a'], achievementDates: {} }, ['b', 'a', 'b'], at);
    expect(next?.achievements).toEqual(['a', 'b']);
  });

  it('backfill (at = null): yutuq ochiladi, vaqt yozilmaydi; eski vaqtlar saqlanadi', () => {
    const next = applyUnlocks(
      { achievements: ['olympian'], achievementDates: { olympian: '2026-02-02T00:00:00.000Z' } },
      ['thinker'],
      null,
    );
    expect(next).toEqual({
      achievements: ['olympian', 'thinker'],
      dates: { olympian: '2026-02-02T00:00:00.000Z' },
    });
  });

  it('buzuq JSON qiymatlari bardoshli', () => {
    expect(readAchievements(null)).toEqual([]);
    expect(readAchievements({ a: 1 })).toEqual([]);
    expect(readAchievements(['a', 5, null, 'b'])).toEqual(['a', 'b']);
    expect(readDates(['x'])).toEqual({});
    expect(readDates({ a: 'x', b: 3 })).toEqual({ a: 'x' });
    expect(applyUnlocks({ achievements: undefined, achievementDates: 'oops' }, ['streak_7'], at)?.achievements).toEqual([
      'streak_7',
    ]);
    expect(applyUnlocks(empty, ['streak_7'], at)).not.toBeNull();
  });
});

describe('toBadgeItems', () => {
  it('katalog tartibida; ochilmaganlar earned=false, earnedAt=null', () => {
    const items = toBadgeItems(['thinker', 'streak_7', 'custom_legacy'], { streak_7: '2026-11-05T09:12:00.000Z' });
    expect(items.map((i) => i.id)).toEqual([...BADGE_IDS]);
    expect(items.find((i) => i.id === 'streak_7')).toEqual({
      id: 'streak_7',
      earned: true,
      earnedAt: '2026-11-05T09:12:00.000Z',
    });
    // Ochilgan, lekin vaqti noma'lum (backfill)
    expect(items.find((i) => i.id === 'thinker')).toEqual({ id: 'thinker', earned: true, earnedAt: null });
    expect(items.find((i) => i.id === 'olympian')).toEqual({ id: 'olympian', earned: false, earnedAt: null });
    expect(items).toHaveLength(BADGE_IDS.length); // katalogda yo'q "custom_legacy" chiqmaydi
  });

  it('ochilmagan yutuqning eski vaqti (nomuvofiq) ko\'rsatilmaydi', () => {
    const items = toBadgeItems([], { olympian: '2026-01-01T00:00:00.000Z' });
    expect(items.find((i) => i.id === 'olympian')?.earnedAt).toBeNull();
  });
});
