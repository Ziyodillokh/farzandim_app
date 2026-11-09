import { attendanceCounts, averageArrival, classAverage, onTimeStreak, OverviewDay, pickPeriod, weeklyRates } from './overview-math';

const day = (date: string, status: OverviewDay['status'], inAt: string | null = null, schoolDay = true): OverviewDay => ({
  date,
  schoolDay,
  status,
  inAt,
});

describe('pickPeriod', () => {
  it('uses the configured quarter that contains today', () => {
    const quarters = [
      { no: 1, start: '2026-09-02', end: '2026-11-01' },
      { no: 2, start: '2026-11-09', end: '2026-12-27' },
    ];
    expect(pickPeriod(quarters, '2026-11-20')).toEqual({ kind: 'QUARTER', no: 2, from: '2026-11-09', to: '2026-11-20' });
  });

  it('falls back to the academic year (from 1 September) between quarters or without settings', () => {
    expect(pickPeriod([{ no: 1, start: '2026-09-02', end: '2026-11-01' }], '2026-11-05')).toEqual({
      kind: 'YEAR',
      no: null,
      from: '2026-09-01',
      to: '2026-11-05',
    });
    expect(pickPeriod(null, '2027-02-10').from).toBe('2026-09-01');
    expect(pickPeriod([{ start: 'bad' }], '2026-10-01').kind).toBe('YEAR');
  });
});

describe('attendance maths', () => {
  const days = [
    day('2026-11-02', 'PRESENT', '08:05'),
    day('2026-11-03', 'LATE', '08:41'),
    day('2026-11-04', 'ABSENT'),
    day('2026-11-05', 'PRESENT', '08:10'),
    day('2026-11-06', 'PRESENT', '08:00'),
    day('2026-11-07', null, null, false),
    day('2026-11-09', null),
  ];

  it('counts only school days; an unmarked day is pending', () => {
    expect(attendanceCounts(days)).toMatchObject({ present: 3, late: 1, absent: 1, pending: 1, total: 6 });
  });

  it('averages the arrival time of attended days', () => {
    expect(averageArrival(days)).toBe('08:14');
    expect(averageArrival([day('2026-11-04', 'ABSENT')])).toBeNull();
  });

  it('counts the on-time streak back from the latest school day, skipping a still-unmarked today', () => {
    expect(onTimeStreak(days)).toBe(2);
    expect(onTimeStreak([day('2026-11-05', 'PRESENT'), day('2026-11-06', 'LATE')])).toBe(0);
  });

  it('gives weekly rates with null for weeks without marked days', () => {
    const weeks = weeklyRates(days, '2026-11-09', 3);
    expect(weeks.map((w) => w.weekStart)).toEqual(['2026-10-26', '2026-11-02', '2026-11-09']);
    expect(weeks.map((w) => w.rate)).toEqual([null, 80, null]);
  });
});

describe('classAverage', () => {
  it('hides the class average below 5 students (privacy)', () => {
    expect(classAverage(4, 30, 40)).toBeNull();
    expect(classAverage(25, 470, 500)).toBe(94);
    expect(classAverage(25, 0, 0)).toBeNull();
  });
});
