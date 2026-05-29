import { describe, expect, test } from 'vitest';
import { tashkentNow, isActiveNow } from '../../src/lib/routines-rules';

describe('tashkentNow', () => {
  test('converts UTC to Tashkent (UTC+5)', () => {
    // 2026-05-15 05:00 UTC → 10:00 Tashkent → Friday (ISO weekday 5)
    const utc = new Date(Date.UTC(2026, 4, 15, 5, 0, 0));
    const { isoWeekday, hour, minute, totalMinutes } = tashkentNow(utc);
    expect(isoWeekday).toBe(5);
    expect(hour).toBe(10);
    expect(minute).toBe(0);
    expect(totalMinutes).toBe(600);
  });

  test('Sunday UTC maps to ISO weekday 7 in Tashkent', () => {
    // 2026-05-17 (Sunday) 19:00 UTC → 00:00 Mon Tashkent → ISO 1
    // So instead: 17:00 UTC → 22:00 Sun Tashkent → ISO 7
    const utc = new Date(Date.UTC(2026, 4, 17, 17, 0, 0));
    const { isoWeekday } = tashkentNow(utc);
    expect(isoWeekday).toBe(7);
  });

  test('crosses midnight in Tashkent', () => {
    // 2026-05-15 20:00 UTC → 01:00 of 2026-05-16 Tashkent (ISO weekday 6, Saturday)
    const utc = new Date(Date.UTC(2026, 4, 15, 20, 0, 0));
    const { isoWeekday, hour, totalMinutes } = tashkentNow(utc);
    expect(isoWeekday).toBe(6);
    expect(hour).toBe(1);
    expect(totalMinutes).toBe(60);
  });
});

describe('isActiveNow', () => {
  test('inside same-day window', () => {
    // 09:00-12:00, now 10:30
    expect(
      isActiveNow({ startHour: 9, startMinute: 0, endHour: 12, endMinute: 0 }, 10 * 60 + 30),
    ).toBe(true);
  });

  test('before start', () => {
    expect(
      isActiveNow({ startHour: 9, startMinute: 0, endHour: 12, endMinute: 0 }, 8 * 60),
    ).toBe(false);
  });

  test('exclusive end boundary', () => {
    expect(
      isActiveNow({ startHour: 9, startMinute: 0, endHour: 12, endMinute: 0 }, 12 * 60),
    ).toBe(false);
  });

  test('wrap-around: 22:00 → 06:00, active at 23:00', () => {
    expect(
      isActiveNow({ startHour: 22, startMinute: 0, endHour: 6, endMinute: 0 }, 23 * 60),
    ).toBe(true);
  });

  test('wrap-around: 22:00 → 06:00, active at 02:00', () => {
    expect(
      isActiveNow({ startHour: 22, startMinute: 0, endHour: 6, endMinute: 0 }, 2 * 60),
    ).toBe(true);
  });

  test('wrap-around: 22:00 → 06:00, inactive at 12:00', () => {
    expect(
      isActiveNow({ startHour: 22, startMinute: 0, endHour: 6, endMinute: 0 }, 12 * 60),
    ).toBe(false);
  });
});
