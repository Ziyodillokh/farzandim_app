import { describe, expect, it } from 'vitest';

import { toCareSettingsBody, toCareSettingsView } from '../services/care-adapters';

/** Kontrakt C: `GET /school/care/settings` — sozlama maydonlari + `staffOptions` (tekis obyekt). */
const WIRE = {
  psychologistStaffId: 'stf-1',
  psychologistDisplayName: 'Dilnoza opa',
  deputyStaffId: 'stf-2',
  deputyDisplayName: null,
  workDays: [1, 2, 3, 4, 5],
  workStart: '09:00',
  workEnd: '17:00',
  urgentSlaMinutes: 60,
  normalSlaHours: 24,
  updatedAt: '2026-11-06T04:00:00.000Z',
  updatedByStaffId: 'stf-1',
  staffOptions: [
    { id: 'stf-1', fullName: 'Sobirova Lola' },
    { id: 'stf-2', fullName: 'Karimova Kamola' },
  ],
};

describe('toCareSettingsView', () => {
  it('kontrakt shaklini (tekis obyekt) panel turiga keltiradi; ortiqcha maydonlar tashlanadi', () => {
    const view = toCareSettingsView(WIRE);
    expect(view).toEqual({
      psychologistStaffId: 'stf-1',
      psychologistDisplayName: 'Dilnoza opa',
      deputyStaffId: 'stf-2',
      deputyDisplayName: null,
      workDays: [1, 2, 3, 4, 5],
      workStart: '09:00',
      workEnd: '17:00',
      urgentSlaMinutes: 60,
      normalSlaHours: 24,
      updatedAt: '2026-11-06T04:00:00.000Z',
      staffOptions: WIRE.staffOptions,
    });
    expect('updatedByStaffId' in view).toBe(false);
  });

  it('`{ settings, staffOptions }` ichma-ich shaklini ham qabul qiladi', () => {
    const { staffOptions, ...settings } = WIRE;
    expect(toCareSettingsView({ settings, staffOptions })).toEqual(toCareSettingsView(WIRE));
  });

  it('saqlangan yozuv yo\'q: updatedAt null/yo\'q, ismlar null — "sozlanmagan"', () => {
    const view = toCareSettingsView({ ...WIRE, psychologistStaffId: null, deputyStaffId: null, psychologistDisplayName: null, updatedAt: null });
    expect(view).toMatchObject({ psychologistStaffId: null, deputyStaffId: null, updatedAt: null });
    const { updatedAt: _omit, ...withoutUpdatedAt } = WIRE;
    void _omit;
    expect(toCareSettingsView(withoutUpdatedAt).updatedAt).toBeNull();
  });

  it('bo\'sh qator ismlari null ga aylanadi; kunlar tartiblanadi va takrorlanmaydi; "HH:MM:SS" → "HH:MM"', () => {
    const view = toCareSettingsView({ ...WIRE, psychologistDisplayName: '', workDays: [5, 1, 1, 3], workStart: '09:00:00', workEnd: '17:30:00' });
    expect(view).toMatchObject({ psychologistDisplayName: null, workDays: [1, 3, 5], workStart: '09:00', workEnd: '17:30' });
  });

  it('staffOptions yo\'q bo\'lsa — bo\'sh ro\'yxat (tahrirlash tanlovi bo\'sh)', () => {
    const { staffOptions: _omit, ...rest } = WIRE;
    void _omit;
    expect(toCareSettingsView(rest).staffOptions).toEqual([]);
  });

  const broken: Array<[string, unknown]> = [
    ['javob obyekt emas', 'ok'],
    ['workDays massiv emas', { ...WIRE, workDays: '1,2' }],
    ['workDays 8', { ...WIRE, workDays: [1, 8] }],
    ['workStart noto\'g\'ri', { ...WIRE, workStart: '9am' }],
    ['SLA son emas', { ...WIRE, urgentSlaMinutes: '60' }],
    ['SLA kasr', { ...WIRE, normalSlaHours: 1.5 }],
    ['staffOptions elementida fullName yo\'q', { ...WIRE, staffOptions: [{ id: 'stf-1', name: 'x' }] }],
    ['psychologistStaffId son', { ...WIRE, psychologistStaffId: 5 }],
  ];
  it.each(broken)('kutilmagan shakl aniq xato beradi (standart qiymat o\'rniga): %s', (_name, wire) => {
    expect(() => toCareSettingsView(wire)).toThrowError(/kutilmagan javob shakli/);
  });
});

describe('toCareSettingsBody', () => {
  it('PUT tanasi: aynan 9 maydon, to\'liq almashtirish; bo\'sh ism va tanlanmagan xodim — null', () => {
    const body = toCareSettingsBody({
      psychologistStaffId: 'stf-1',
      psychologistDisplayName: '  ',
      deputyStaffId: null,
      deputyDisplayName: ' Kamola opa ',
      workDays: [3, 1],
      workStart: '09:00',
      workEnd: '17:00',
      urgentSlaMinutes: 45,
      normalSlaHours: 12,
    });
    expect(body).toEqual({
      psychologistStaffId: 'stf-1',
      psychologistDisplayName: null,
      deputyStaffId: null,
      deputyDisplayName: 'Kamola opa',
      workDays: [1, 3],
      workStart: '09:00',
      workEnd: '17:00',
      urgentSlaMinutes: 45,
      normalSlaHours: 12,
    });
  });
});
