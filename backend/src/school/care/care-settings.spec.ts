import { buildContact, DEFAULT_CARE_SETTINGS, slaMinutes } from './care-settings';
import { careSettingsInputSchema } from './care-settings.schemas';
import { parseOrThrow } from '../common/school-zod';

// 2026-11-06 — juma, 07 — shanba, 09 — dushanba (Toshkent UTC+5).
const tk = (iso: string) => new Date(`${iso}+05:00`);
const settings = { ...DEFAULT_CARE_SETTINGS, workDays: [1, 2, 3, 4, 5] };
const people = { psychologist: { name: 'Dilnoza opa' }, deputy: { name: 'Kamola opa' } };

describe('buildContact', () => {
  it('reports open now with no next opening', () => {
    const c = buildContact({ configured: true, settings, ...people, holidays: new Set(), now: tk('2026-11-06T10:00:00') });
    expect(c).toEqual({ ...people, hours: { days: [1, 2, 3, 4, 5], start: '09:00', end: '17:00' }, openNow: true, nextOpenAt: null });
  });

  it('points at Monday opening on a Saturday', () => {
    const c = buildContact({ configured: true, settings, ...people, holidays: new Set(), now: tk('2026-11-07T10:00:00') });
    expect(c.openNow).toBe(false);
    expect(c.nextOpenAt).toBe('2026-11-09T04:00:00.000Z');
  });

  it('treats a holiday as closed and skips it', () => {
    const c = buildContact({ configured: true, settings, ...people, holidays: new Set(['2026-11-06', '2026-11-09']), now: tk('2026-11-06T10:00:00') });
    expect(c.openNow).toBe(false);
    expect(c.nextOpenAt).toBe('2026-11-10T04:00:00.000Z');
  });

  it('has no hours, is closed and has no next opening when nothing is configured', () => {
    const c = buildContact({ configured: false, settings, psychologist: people.psychologist, deputy: null, holidays: new Set(), now: tk('2026-11-06T10:00:00') });
    expect(c).toEqual({ psychologist: people.psychologist, deputy: null, hours: null, openNow: false, nextOpenAt: null });
  });
});

describe('slaMinutes', () => {
  it('uses minutes for URGENT and hours for NORMAL', () => {
    expect(slaMinutes({ urgentSlaMinutes: 45, normalSlaHours: 24 }, 'URGENT')).toBe(45);
    expect(slaMinutes({ urgentSlaMinutes: 45, normalSlaHours: 24 }, 'NORMAL')).toBe(1440);
  });
});

describe('careSettingsInputSchema', () => {
  const valid = {
    psychologistStaffId: 'p1',
    psychologistDisplayName: ' Dilnoza opa ',
    deputyStaffId: 'p2',
    deputyDisplayName: null,
    workDays: [1, 2, 3],
    workStart: '09:00',
    workEnd: '17:30',
    urgentSlaMinutes: 30,
    normalSlaHours: 48,
  };
  const messageOf = (input: unknown) => {
    try {
      parseOrThrow(careSettingsInputSchema, input);
      return 'ok';
    } catch (err) {
      return (err as { response: { message: string } }).response.message;
    }
  };

  it('accepts a valid body and trims display names', () => {
    expect(parseOrThrow(careSettingsInputSchema, valid)).toMatchObject({ psychologistDisplayName: 'Dilnoza opa', deputyDisplayName: null });
  });

  it('fills defaults for omitted schedule fields and nulls for omitted people', () => {
    expect(parseOrThrow(careSettingsInputSchema, {})).toEqual({
      psychologistStaffId: null,
      psychologistDisplayName: null,
      deputyStaffId: null,
      deputyDisplayName: null,
      workDays: [1, 2, 3, 4, 5],
      workStart: '09:00',
      workEnd: '17:00',
      urgentSlaMinutes: 60,
      normalSlaHours: 24,
    });
  });

  it.each([
    [{ ...valid, deputyStaffId: 'p1' }, 'deputyStaffId: errors.form.duplicate'],
    [{ ...valid, psychologistDisplayName: 'x'.repeat(41) }, 'psychologistDisplayName: errors.form.tooLong'],
    [{ ...valid, workStart: '17:00', workEnd: '09:00' }, 'workEnd: errors.form.endBeforeStart'],
    [{ ...valid, workStart: '09:00', workEnd: '09:00' }, 'workEnd: errors.form.endBeforeStart'],
    [{ ...valid, workStart: '9:00' }, 'workStart: errors.form.invalidTime'],
    [{ ...valid, workDays: [1, 1, 2] }, 'workDays: errors.form.duplicate'],
    [{ ...valid, workDays: [0, 1] }, 'workDays.0: errors.form.outOfRange'],
    [{ ...valid, workDays: [8] }, 'workDays.0: errors.form.outOfRange'],
    [{ ...valid, workDays: [] }, 'workDays: errors.form.selectAtLeastOne'],
    [{ ...valid, urgentSlaMinutes: 14 }, 'urgentSlaMinutes: errors.form.outOfRange'],
    [{ ...valid, urgentSlaMinutes: 1441 }, 'urgentSlaMinutes: errors.form.outOfRange'],
    [{ ...valid, normalSlaHours: 0 }, 'normalSlaHours: errors.form.outOfRange'],
    [{ ...valid, normalSlaHours: 169 }, 'normalSlaHours: errors.form.outOfRange'],
  ])('rejects %j with %s', (input, message) => {
    expect(messageOf(input)).toBe(message);
  });

  it('accepts the boundary values', () => {
    expect(messageOf({ ...valid, urgentSlaMinutes: 15, normalSlaHours: 1, workDays: [7] })).toBe('ok');
    expect(messageOf({ ...valid, urgentSlaMinutes: 1440, normalSlaHours: 168 })).toBe('ok');
  });
});
