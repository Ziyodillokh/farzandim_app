import { addWorkingMinutes, hhmmToMinutes, isWorkingAt, nextWorkingStart, WorkingHours } from './care-working-time';

// 2026-11-06 — juma, 07 — shanba, 08 — yakshanba, 09 — dushanba, 10 — seshanba (Toshkent UTC+5).
const HOURS: WorkingHours = { days: [1, 2, 3, 4, 5], start: '09:00', end: '17:00' };
const NO_HOLIDAYS = new Set<string>();
/** Toshkent devor soati → lahza. */
const tk = (iso: string) => new Date(`${iso}+05:00`);
const iso = (d: Date | null) => d?.toISOString() ?? null;

describe('hhmmToMinutes', () => {
  it('parses valid clock times and rejects garbage', () => {
    expect(hhmmToMinutes('09:30')).toBe(570);
    expect(hhmmToMinutes('24:00')).toBeNaN();
    expect(hhmmToMinutes('9:00')).toBeNaN();
  });
});

describe('isWorkingAt', () => {
  it('is open inside the window and closed at the end boundary', () => {
    expect(isWorkingAt(tk('2026-11-06T09:00:00'), HOURS, NO_HOLIDAYS)).toBe(true);
    expect(isWorkingAt(tk('2026-11-06T16:59:59'), HOURS, NO_HOLIDAYS)).toBe(true);
    expect(isWorkingAt(tk('2026-11-06T17:00:00'), HOURS, NO_HOLIDAYS)).toBe(false);
    expect(isWorkingAt(tk('2026-11-06T08:59:59'), HOURS, NO_HOLIDAYS)).toBe(false);
  });

  it('is closed on weekends and holidays', () => {
    expect(isWorkingAt(tk('2026-11-07T10:00:00'), HOURS, NO_HOLIDAYS)).toBe(false);
    expect(isWorkingAt(tk('2026-11-09T10:00:00'), HOURS, new Set(['2026-11-09']))).toBe(false);
  });

  it('uses the Tashkent day, not the UTC day', () => {
    // 2026-11-08 20:30Z = 2026-11-09 01:30 Toshkent (dushanba, hali ochilmagan).
    expect(isWorkingAt(new Date('2026-11-08T20:30:00Z'), HOURS, NO_HOLIDAYS)).toBe(false);
    expect(isWorkingAt(new Date('2026-11-09T04:00:00Z'), HOURS, NO_HOLIDAYS)).toBe(true);
  });

  it('is never open when the configured window is empty or inverted', () => {
    expect(isWorkingAt(tk('2026-11-06T10:00:00'), { ...HOURS, start: '17:00', end: '09:00' }, NO_HOLIDAYS)).toBe(false);
    expect(isWorkingAt(tk('2026-11-06T10:00:00'), { ...HOURS, days: [] }, NO_HOLIDAYS)).toBe(false);
  });
});

describe('nextWorkingStart', () => {
  it('returns the same instant while open', () => {
    expect(iso(nextWorkingStart(tk('2026-11-06T10:15:00'), HOURS, NO_HOLIDAYS))).toBe(iso(tk('2026-11-06T10:15:00')));
  });

  it('jumps to today opening when called before hours', () => {
    expect(iso(nextWorkingStart(tk('2026-11-06T07:00:00'), HOURS, NO_HOLIDAYS))).toBe('2026-11-06T04:00:00.000Z');
  });

  it('skips the weekend after Friday closing', () => {
    expect(iso(nextWorkingStart(tk('2026-11-06T18:00:00'), HOURS, NO_HOLIDAYS))).toBe('2026-11-09T04:00:00.000Z');
  });

  it('skips holidays', () => {
    expect(iso(nextWorkingStart(tk('2026-11-06T18:00:00'), HOURS, new Set(['2026-11-09'])))).toBe('2026-11-10T04:00:00.000Z');
  });

  it('returns null when there is no working day at all', () => {
    expect(nextWorkingStart(tk('2026-11-06T10:00:00'), { ...HOURS, days: [] }, NO_HOLIDAYS)).toBeNull();
  });
});

describe('addWorkingMinutes', () => {
  it('adds within the same working day', () => {
    expect(iso(addWorkingMinutes(tk('2026-11-06T10:00:00'), 60, HOURS, NO_HOLIDAYS))).toBe(iso(tk('2026-11-06T11:00:00')));
  });

  it('rolls over to Monday across the weekend (Friday 16:30 + 60 min)', () => {
    expect(iso(addWorkingMinutes(tk('2026-11-06T16:30:00'), 60, HOURS, NO_HOLIDAYS))).toBe(iso(tk('2026-11-09T09:30:00')));
  });

  it('starts counting at opening when created outside hours (Saturday 12:00 + 60 min)', () => {
    expect(iso(addWorkingMinutes(tk('2026-11-07T12:00:00'), 60, HOURS, NO_HOLIDAYS))).toBe(iso(tk('2026-11-09T10:00:00')));
  });

  it('starts counting at opening when created before hours and after hours', () => {
    expect(iso(addWorkingMinutes(tk('2026-11-06T06:00:00'), 30, HOURS, NO_HOLIDAYS))).toBe(iso(tk('2026-11-06T09:30:00')));
    expect(iso(addWorkingMinutes(tk('2026-11-06T20:00:00'), 30, HOURS, NO_HOLIDAYS))).toBe(iso(tk('2026-11-09T09:30:00')));
  });

  it('skips a holiday Monday', () => {
    expect(iso(addWorkingMinutes(tk('2026-11-06T16:30:00'), 60, HOURS, new Set(['2026-11-09'])))).toBe(iso(tk('2026-11-10T09:30:00')));
  });

  it('lands exactly on closing time when the minutes fit exactly', () => {
    expect(iso(addWorkingMinutes(tk('2026-11-06T16:00:00'), 60, HOURS, NO_HOLIDAYS))).toBe(iso(tk('2026-11-06T17:00:00')));
  });

  it('counts 24 working hours as three 8-hour days (normal SLA)', () => {
    // Juma 10:00 → 7 soat juma + 8 dushanba + 8 seshanba + 1 soat chorshanba = 24 soat.
    expect(iso(addWorkingMinutes(tk('2026-11-06T10:00:00'), 24 * 60, HOURS, NO_HOLIDAYS))).toBe(iso(tk('2026-11-11T10:00:00')));
  });

  it('honours custom days and hours', () => {
    const shortWeek: WorkingHours = { days: [2, 4], start: '10:00', end: '12:00' };
    // Dushanba 11:00 → birinchi ish oynasi seshanba 10:00; 150 daqiqa = 120 (seshanba) + 30 (payshanba).
    expect(iso(addWorkingMinutes(tk('2026-11-09T11:00:00'), 150, shortWeek, NO_HOLIDAYS))).toBe(iso(tk('2026-11-12T10:30:00')));
  });

  it('returns the first working instant for zero minutes', () => {
    expect(iso(addWorkingMinutes(tk('2026-11-07T12:00:00'), 0, HOURS, NO_HOLIDAYS))).toBe(iso(tk('2026-11-09T09:00:00')));
  });

  it('returns null when no working time exists', () => {
    expect(addWorkingMinutes(tk('2026-11-06T10:00:00'), 60, { ...HOURS, days: [] }, NO_HOLIDAYS)).toBeNull();
  });
});
