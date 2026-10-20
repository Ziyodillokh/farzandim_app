import {
  addDays,
  daysBetween,
  isDayKey,
  isoWeekday,
  tashkentDay,
  tashkentDayRange,
  tashkentDayStart,
} from './tashkent';

describe('tashkent time', () => {
  it('UTC kechqurun Toshkentda ertangi kun', () => {
    expect(tashkentDay(new Date('2026-10-18T18:59:59Z'))).toBe('2026-10-18');
    expect(tashkentDay(new Date('2026-10-18T19:00:00Z'))).toBe('2026-10-19');
  });

  it('kun boshlanishi va oralig\'i', () => {
    expect(tashkentDayStart('2026-10-19').toISOString()).toBe(
      '2026-10-18T19:00:00.000Z',
    );
    const range = tashkentDayRange('2026-10-19');
    expect(range.lt.getTime() - range.gte.getTime()).toBe(86_400_000);
  });

  it('kun arifmetikasi oy va yil chegarasida', () => {
    expect(addDays('2026-12-31', 1)).toBe('2027-01-01');
    expect(addDays('2026-03-01', -1)).toBe('2026-02-28');
    expect(daysBetween('2026-10-12', '2026-10-19')).toBe(7);
    expect(daysBetween('2026-10-19', '2026-10-12')).toBe(-7);
  });

  it('kun kaliti validatsiyasi', () => {
    expect(isDayKey('2026-10-19')).toBe(true);
    expect(isDayKey('2026-02-30')).toBe(false);
    expect(isDayKey('2026-1-9')).toBe(false);
    expect(isDayKey('kecha')).toBe(false);
  });

  it('ISO hafta kuni', () => {
    expect(isoWeekday('2026-10-19')).toBe(1);
    expect(isoWeekday('2026-10-25')).toBe(7);
  });
});
