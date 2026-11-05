import { hasStaffCorrection, kioskTimesByDate, summarize, toChildDay, unknownDay } from './attendance-child-view';
import { SYSTEM_STAFF_ID } from './attendance-view';

const record = (over: Partial<Parameters<typeof toChildDay>[0]> = {}) => ({
  date: '2026-10-20',
  status: 'PRESENT' as const,
  inAt: '08:05',
  outAt: null,
  source: 'QR' as const,
  corrections: [],
  ...over,
});

describe('toChildDay', () => {
  it('maps a system-written ABSENT row to UNKNOWN (an unscanned day is not "absent")', () => {
    const day = toChildDay(record({ status: 'ABSENT', source: 'SYSTEM', inAt: null }), null);

    expect(day).toMatchObject({ status: 'UNKNOWN', confirmed: false, source: 'SYSTEM' });
  });

  it('keeps ABSENT when staff corrected the row, and marks it confirmed', () => {
    const day = toChildDay(record({ status: 'ABSENT', source: 'SYSTEM', corrections: [{ byStaffId: 'staff-1' }] }), null);

    expect(day).toMatchObject({ status: 'ABSENT', confirmed: true });
  });

  it('treats a manual mark as confirmed ABSENT', () => {
    expect(toChildDay(record({ status: 'ABSENT', source: 'MANUAL' }), null)).toMatchObject({ status: 'ABSENT', confirmed: true });
  });

  it('does not count the QR system correction as staff confirmation', () => {
    const day = toChildDay(record({ source: 'QR', corrections: [{ byStaffId: SYSTEM_STAFF_ID }] }), null);

    expect(day).toMatchObject({ status: 'PRESENT', confirmed: false });
  });

  it('passes kiosk times through', () => {
    expect(toChildDay(record(), { inAt: '08:01', outAt: null }).kiosk).toEqual({ inAt: '08:01', outAt: null });
  });
});

describe('hasStaffCorrection', () => {
  it('ignores system corrections only', () => {
    expect(hasStaffCorrection([])).toBe(false);
    expect(hasStaffCorrection([{ byStaffId: SYSTEM_STAFF_ID }])).toBe(false);
    expect(hasStaffCorrection([{ byStaffId: SYSTEM_STAFF_ID }, { byStaffId: 'abc' }])).toBe(true);
  });
});

describe('kioskTimesByDate', () => {
  const ev = (at: string, kind: 'IN' | 'OUT', date = '2026-10-20') => ({ at: new Date(at), date, kind });

  it('uses the first IN and the last OUT in Tashkent time, per day', () => {
    const times = kioskTimesByDate([
      ev('2026-10-20T03:10:00Z', 'IN'),
      ev('2026-10-20T03:05:00Z', 'IN'),
      ev('2026-10-20T08:00:00Z', 'OUT'),
      ev('2026-10-20T09:30:00Z', 'OUT'),
      ev('2026-10-21T03:00:00Z', 'IN', '2026-10-21'),
    ]);

    expect(times.get('2026-10-20')).toEqual({ inAt: '08:05', outAt: '14:30' });
    expect(times.get('2026-10-21')).toEqual({ inAt: '08:00', outAt: null });
    expect(times.get('2026-10-22')).toBeUndefined();
  });
});

describe('summarize', () => {
  it('counts UNKNOWN separately and leaves it out of the attendance rate', () => {
    const days = [
      toChildDay(record({ date: '2026-10-19' }), null),
      toChildDay(record({ date: '2026-10-20', status: 'LATE' }), null),
      toChildDay(record({ date: '2026-10-21', status: 'ABSENT', source: 'MANUAL' }), null),
      unknownDay('2026-10-22'),
    ];

    expect(summarize(days)).toEqual({ present: 1, late: 1, absent: 1, leftEarly: 0, excused: 0, unknown: 1, total: 4, rate: 67 });
  });

  it('is empty-safe', () => {
    expect(summarize([])).toEqual({ present: 0, late: 0, absent: 0, leftEarly: 0, excused: 0, unknown: 0, total: 0, rate: 0 });
  });
});
