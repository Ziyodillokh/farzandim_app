import { describe, expect, it } from 'vitest';

import type { CareSettingsView } from '@/data/contracts';
import { translate } from '@/i18n/translate';
import { childFacingName, formatWorkDays, formatWorkHours, isDraftDirty, isSettingsConfigured, NO_STAFF, parseFieldError, toDraft, toInput } from '../settings';

const t = ((key: string, vars?: Record<string, string | number>) => translate('uz', key, vars)) as Parameters<typeof formatWorkDays>[0];

const VIEW: CareSettingsView = {
  psychologistStaffId: 'a',
  psychologistDisplayName: null,
  deputyStaffId: null,
  deputyDisplayName: 'Kamola opa',
  workDays: [1, 2, 3, 4, 5],
  workStart: '08:30',
  workEnd: '16:30',
  urgentSlaMinutes: 60,
  normalSlaHours: 24,
  updatedAt: '2026-11-06T04:00:00',
  staffOptions: [{ id: 'a', fullName: 'Sobirova Lola' }],
};

describe('ish kunlarini yozish', () => {
  it('ketma-ket 3+ kun — oraliq; aks holda ro\'yxat; 7 kun — "Har kuni"', () => {
    expect(formatWorkDays(t, [1, 2, 3, 4, 5])).toBe('Du–Ju');
    expect(formatWorkDays(t, [1, 2, 3, 4, 5, 6])).toBe('Du–Sh');
    expect(formatWorkDays(t, [1, 3, 5])).toBe('Du, Ch, Ju');
    expect(formatWorkDays(t, [1, 2])).toBe('Du, Se');
    expect(formatWorkDays(t, [1, 2, 3, 5, 6])).toBe('Du–Ch, Ju, Sh');
    expect(formatWorkDays(t, [1, 2, 3, 4, 5, 6, 7])).toBe('Har kuni');
  });

  it('tartibsiz, takror va noto\'g\'ri kunlar tozalanadi; bo\'sh — "—"', () => {
    expect(formatWorkDays(t, [5, 3, 1, 1, 4, 2, 9, 0])).toBe('Du–Ju');
    expect(formatWorkDays(t, [])).toBe('—');
  });

  it('kunlar + soat', () => {
    expect(formatWorkHours(t, VIEW)).toBe('Du–Ju, 08:30–16:30');
  });
});

describe('sozlama holati', () => {
  it('saqlangan — updatedAt bor; standart (updatedAt: null) yoki yo\'q — sozlanmagan', () => {
    expect(isSettingsConfigured(VIEW)).toBe(true);
    expect(isSettingsConfigured({ updatedAt: null })).toBe(false);
    expect(isSettingsConfigured(undefined)).toBe(false);
  });

  it('bola ko\'radigan ism: ko\'rsatiladigan ism → to\'liq ism → null', () => {
    expect(childFacingName('Lola opa', 'a', VIEW.staffOptions)).toBe('Lola opa');
    expect(childFacingName('  ', 'a', VIEW.staffOptions)).toBe('Sobirova Lola');
    expect(childFacingName(null, 'zzz', VIEW.staffOptions)).toBeNull();
    expect(childFacingName(null, null, VIEW.staffOptions)).toBeNull();
  });
});

describe('forma qoralamasi', () => {
  it('toDraft → toInput aylanishi ma\'lumotni saqlaydi; tanlanmagan xodim NO_STAFF ↔ null', () => {
    const draft = toDraft(VIEW);
    expect(draft.deputyStaffId).toBe(NO_STAFF);
    expect(toInput(draft)).toMatchObject({ psychologistStaffId: 'a', deputyStaffId: null, deputyDisplayName: 'Kamola opa', urgentSlaMinutes: 60 });
  });

  it('bo\'sh yoki noto\'g\'ri son — NaN (sxema "to\'g\'ri son" xatosini beradi)', () => {
    const draft = { ...toDraft(VIEW), urgentSlaMinutes: '', normalSlaHours: 'abc' };
    const input = toInput(draft);
    expect(Number.isNaN(input.urgentSlaMinutes)).toBe(true);
    expect(Number.isNaN(input.normalSlaHours)).toBe(true);
  });

  it('o\'zgarish aniqlanadi (kunlar tartibiga bog\'liq emas)', () => {
    const base = toDraft(VIEW);
    expect(isDraftDirty(base, toDraft(VIEW))).toBe(false);
    expect(isDraftDirty({ ...base, workDays: [5, 4, 3, 2, 1] }, base)).toBe(false);
    expect(isDraftDirty({ ...base, workEnd: '17:00' }, base)).toBe(true);
  });
});

describe('servis xatosidan maydon', () => {
  it('`maydon: errors.form.kalit` ajratiladi; boshqa xabar — null', () => {
    expect(parseFieldError('workEnd: errors.form.endBeforeStart')).toEqual({ field: 'workEnd', key: 'errors.form.endBeforeStart' });
    expect(parseFieldError('HTTP 400')).toBeNull();
    expect(parseFieldError('urgency')).toBeNull();
  });
});
