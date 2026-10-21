import { tashkentDay } from '../../../common/time/tashkent';
import { ageGroupOf, childAge, fullYears, isKelajakAgeGroup, resolveKelajakAge } from './age';

describe('kelajak age', () => {
  it('to\'liq yosh: tug\'ilgan kun hali kelmagan bo\'lsa bir kam', () => {
    expect(fullYears('2015-10-21', '2026-10-21')).toBe(11);
    expect(fullYears('2015-10-22', '2026-10-21')).toBe(10);
    expect(fullYears('2015-11-01', '2026-10-21')).toBe(10);
    expect(fullYears('2015-09-30', '2026-10-21')).toBe(11);
    expect(fullYears('bad', '2026-10-21')).toBeNull();
  });

  it('29-fevral: kabisa bo\'lmagan yilda 1-martdan oshadi', () => {
    expect(fullYears('2016-02-29', '2027-02-28')).toBe(10);
    expect(fullYears('2016-02-29', '2027-03-01')).toBe(11);
  });

  it('birthDate (Date, @db.Date) ustun — age ustuni e\'tiborsiz', () => {
    const birthDate = new Date('2016-10-22T00:00:00.000Z');
    expect(childAge({ birthDate, age: 15 }, '2026-10-21')).toBe(9);
    expect(childAge({ birthDate, age: 15 }, '2026-10-22')).toBe(10);
  });

  it('Toshkent kuni: UTC 19:30 da Toshkentda ertangi kun boshlangan', () => {
    // 2026-10-21T19:30Z = Toshkentda 22-oktabr 00:30 — tug'ilgan kun keldi.
    const child = { birthDate: '2016-10-22', age: null };
    const at = new Date('2026-10-21T19:30:00.000Z');
    expect(childAge(child, tashkentDay(at))).toBe(10);
    expect(childAge(child, tashkentDay(new Date('2026-10-21T18:59:00.000Z')))).toBe(9);
  });

  it('birthDate yo\'q — age (1..25), aks holda null; fallback YO\'Q', () => {
    expect(childAge({ birthDate: null, age: 14 }, '2026-10-21')).toBe(14);
    expect(childAge({ birthDate: null, age: null }, '2026-10-21')).toBeNull();
    expect(childAge({ birthDate: null, age: 0 }, '2026-10-21')).toBeNull();
    expect(childAge({ birthDate: null, age: 26 }, '2026-10-21')).toBeNull();
    // Kelajakdagi sana yaroqsiz — age ustuniga tushadi.
    expect(childAge({ birthDate: '2030-01-01', age: 12 }, '2026-10-21')).toBe(12);
  });

  it.each([
    [6, null],
    [7, '7-9'],
    [9, '7-9'],
    [10, '10-12'],
    [12, '10-12'],
    [13, '13-15'],
    [15, '13-15'],
    [16, '16-18'],
    [18, '16-18'],
    [19, null],
  ])('yosh %i → guruh %s', (age, group) => {
    expect(ageGroupOf(age)).toBe(group);
  });

  it('holat: OK | AGE_REQUIRED | AGE_OUT_OF_RANGE', () => {
    expect(resolveKelajakAge({ birthDate: null, age: 8 }, '2026-10-21')).toEqual({
      status: 'OK',
      age: 8,
      ageGroup: '7-9',
    });
    expect(resolveKelajakAge({ birthDate: null, age: null }, '2026-10-21')).toEqual({
      status: 'AGE_REQUIRED',
      age: null,
      ageGroup: null,
    });
    expect(resolveKelajakAge({ birthDate: '2021-01-01', age: null }, '2026-10-21')).toEqual({
      status: 'AGE_OUT_OF_RANGE',
      age: 5,
      ageGroup: null,
    });
  });

  it('guruh tekshiruvi', () => {
    expect(isKelajakAgeGroup('13-15')).toBe(true);
    expect(isKelajakAgeGroup('13_15')).toBe(false);
    expect(isKelajakAgeGroup(13)).toBe(false);
  });
});
