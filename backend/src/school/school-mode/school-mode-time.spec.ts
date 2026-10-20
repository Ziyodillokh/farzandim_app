import {
  bellPhase,
  classModeState,
  dayWindowOf,
  exceptionStatus,
  numberPeriods,
  restrictedWindows,
  ShiftLike,
  subtractWindow,
  tashkentInstant,
  tashkentMinute,
} from './school-mode-time';

const shift: ShiftLike = {
  id: 'sh1',
  start: '08:00',
  end: '09:40',
  weekdays: [1, 2, 3, 4, 5, 6],
  periods: [
    { no: 1, start: '08:00', end: '08:45', kind: 'LESSON' },
    { no: 1, start: '08:45', end: '08:55', kind: 'BREAK' },
    { no: 2, start: '08:55', end: '09:40', kind: 'LESSON' },
  ],
};
const policy = { enabled: true, shiftIds: ['sh1'], relaxDuringBreaks: true };
const calm = { active: false, scope: 'SCHOOL', classIds: [] as string[] };
// 2026-10-19 — dushanba, 2026-10-25 — yakshanba.
const MONDAY = '2026-10-19';
const at = (hhmm: string) => Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3));

describe('school mode time', () => {
  it('Toshkent daqiqasi va mutlaq vaqt (UTC+5)', () => {
    expect(tashkentMinute(new Date('2026-10-19T03:30:00Z'))).toBe(at('08:30'));
    expect(tashkentInstant(MONDAY, at('08:00')).toISOString()).toBe('2026-10-19T03:00:00.000Z');
  });

  it('qo\'ng\'iroq bosqichi: oldin, dars, tanaffus, keyin, dam olish / bayram', () => {
    expect(bellPhase(shift, MONDAY, at('07:59'), [])).toEqual({ kind: 'BEFORE', startsAt: '08:00' });
    expect(bellPhase(shift, MONDAY, at('08:00'), [])).toMatchObject({ kind: 'LESSON', periodNo: 1, endsAt: '08:45' });
    expect(bellPhase(shift, MONDAY, at('08:50'), [])).toMatchObject({ kind: 'BREAK', periodNo: 1 });
    expect(bellPhase(shift, MONDAY, at('09:40'), [])).toEqual({ kind: 'AFTER' });
    expect(bellPhase(shift, '2026-10-25', at('08:30'), [])).toEqual({ kind: 'DAY_OFF' });
    expect(bellPhase(shift, MONDAY, at('08:30'), [{ date: MONDAY }])).toEqual({ kind: 'DAY_OFF' });
  });

  it('sinf holati: siyosat, favqulodda, tanaffusda yumshatish', () => {
    const base = { classId: 'c1', shift, policy, emergency: calm, holidays: [] };
    expect(classModeState(base, MONDAY, at('08:10'))).toMatchObject({ kind: 'LESSON', restricted: true });
    expect(classModeState(base, MONDAY, at('08:50'))).toMatchObject({ kind: 'BREAK', restricted: false });
    expect(classModeState({ ...base, policy: { ...policy, relaxDuringBreaks: false } }, MONDAY, at('08:50'))).toMatchObject({ restricted: true });
    expect(classModeState({ ...base, policy: { ...policy, enabled: false } }, MONDAY, at('08:10')).kind).toBe('DISABLED');
    expect(classModeState({ ...base, policy: { ...policy, shiftIds: [] } }, MONDAY, at('08:10')).kind).toBe('DISABLED');
    const classOnly = { active: true, scope: 'CLASS', classIds: ['c1'] };
    expect(classModeState({ ...base, emergency: classOnly }, MONDAY, at('08:10')).kind).toBe('EMERGENCY_OFF');
    expect(classModeState({ ...base, classId: 'c2', emergency: classOnly }, MONDAY, at('08:10')).kind).toBe('LESSON');
    expect(classModeState({ ...base, shift: null }, MONDAY, at('08:10')).kind).toBe('DAY_OFF');
  });

  it('istisno holati', () => {
    const now = new Date('2026-10-19T05:00:00Z');
    const e = (from: string, until: string, revokedAt: Date | null = null) => ({ from: new Date(from), until: new Date(until), revokedAt });
    expect(exceptionStatus(e('2026-10-19T04:00:00Z', '2026-10-19T06:00:00Z'), now)).toBe('ACTIVE');
    expect(exceptionStatus(e('2026-10-19T05:30:00Z', '2026-10-19T06:00:00Z'), now)).toBe('SCHEDULED');
    expect(exceptionStatus(e('2026-10-19T03:00:00Z', '2026-10-19T05:00:00Z'), now)).toBe('EXPIRED');
    expect(exceptionStatus(e('2026-10-19T04:00:00Z', '2026-10-19T06:00:00Z', now), now)).toBe('REVOKED');
  });

  it('davr raqamlari: tanaffus — oldingi dars raqami', () => {
    const numbered = numberPeriods([
      { start: '08:00', end: '08:45', kind: 'LESSON' },
      { start: '08:45', end: '08:55', kind: 'BREAK' },
      { start: '08:55', end: '09:40', kind: 'LESSON' },
    ]);
    expect(numbered.map((p) => p.no)).toEqual([1, 1, 2]);
  });

  it('cheklov oynalari va istisno oralig\'ini ayirish', () => {
    expect(restrictedWindows(shift, policy)).toEqual([
      { start: at('08:00'), end: at('08:45') },
      { start: at('08:55'), end: at('09:40') },
    ]);
    expect(restrictedWindows(shift, { ...policy, relaxDuringBreaks: false })).toEqual([{ start: at('08:00'), end: at('09:40') }]);
    const windows = restrictedWindows(shift, policy);
    expect(subtractWindow(windows, { start: at('08:30'), end: at('09:00') })).toEqual([
      { start: at('08:00'), end: at('08:30') },
      { start: at('09:00'), end: at('09:40') },
    ]);
    expect(subtractWindow(windows, { start: at('07:00'), end: at('10:00') })).toEqual([]);
  });

  it('istisno — kun daqiqalariga (kun chegarasida kesiladi)', () => {
    expect(dayWindowOf(MONDAY, new Date('2026-10-19T03:30:00Z'), new Date('2026-10-19T04:00:00Z'))).toEqual({ start: at('08:30'), end: at('09:00') });
    expect(dayWindowOf(MONDAY, new Date('2026-10-18T10:00:00Z'), new Date('2026-10-19T03:00:00Z'))).toEqual({ start: 0, end: at('08:00') });
    expect(dayWindowOf(MONDAY, new Date('2026-10-20T00:00:00Z'), new Date('2026-10-20T01:00:00Z'))).toBeNull();
  });
});
