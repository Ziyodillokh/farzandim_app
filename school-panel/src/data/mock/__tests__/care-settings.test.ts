import { beforeEach, describe, expect, it } from 'vitest';

import type { CareSettingsInput } from '@/data/schemas/care';
import { createFreshSnapshot, getTables, migrate, transact } from '../db';
import { FIXED_STAFF } from '../seed/people';
import { careService } from '../services/care';
import { freshDb, loginAs } from './helpers';

const VALID: CareSettingsInput = {
  psychologistStaffId: FIXED_STAFF.psychologist,
  psychologistDisplayName: 'Dilnoza opa',
  deputyStaffId: FIXED_STAFF.psychologistDeputy,
  deputyDisplayName: '',
  workDays: [1, 2, 3, 4, 5],
  workStart: '09:00',
  workEnd: '17:00',
  urgentSlaMinutes: 45,
  normalSlaHours: 12,
};

describe('Bola ovozi sozlamalari — ruxsatlar', () => {
  beforeEach(freshDb);

  it('o\'qish: direktor, admin va psixolog; sinf rahbari va navbatchi — yo\'q', async () => {
    for (const role of ['DIRECTOR', 'ADMIN', 'PSYCHOLOGIST'] as const) {
      loginAs(role);
      await expect(careService.getSettings()).resolves.toMatchObject({ workDays: [1, 2, 3, 4, 5] });
    }
    for (const role of ['HOMEROOM', 'DUTY'] as const) {
      loginAs(role);
      await expect(careService.getSettings()).rejects.toMatchObject({ code: 'FORBIDDEN' });
    }
  });

  it('yozish: care.settings — psixolog, direktor va admin; sinf rahbari va navbatchi — yo\'q', async () => {
    for (const role of ['PSYCHOLOGIST', 'DIRECTOR', 'ADMIN'] as const) {
      loginAs(role);
      await expect(careService.updateSettings(VALID)).resolves.toMatchObject({ urgentSlaMinutes: 45 });
    }
    for (const role of ['HOMEROOM', 'DUTY'] as const) {
      loginAs(role);
      await expect(careService.updateSettings(VALID)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    }
  });
});

describe('Bola ovozi sozlamalari — o\'qish va saqlash', () => {
  beforeEach(() => {
    freshDb();
    loginAs('PSYCHOLOGIST');
  });

  it('staffOptions — faqat faol PSIXOLOG xodimlar', async () => {
    transact((t) => {
      t.staff = t.staff.map((s) => (s.id === FIXED_STAFF.psychologistDeputy ? { ...s, active: false } : s));
    });
    const view = await careService.getSettings();
    expect(view.staffOptions).toEqual([{ id: FIXED_STAFF.psychologist, fullName: 'Sobirova Lola Baxromovna' }]);
  });

  it('saqlangan yozuv yo\'q — standart qiymatlar, updatedAt: null', async () => {
    transact((t) => {
      t.careSettings = null;
    });
    const view = await careService.getSettings();
    expect(view).toMatchObject({
      psychologistStaffId: null,
      deputyStaffId: null,
      workDays: [1, 2, 3, 4, 5],
      workStart: '09:00',
      workEnd: '17:00',
      urgentSlaMinutes: 60,
      normalSlaHours: 24,
      updatedAt: null,
    });
  });

  it('saqlaydi: bo\'sh ism → null, kunlar tartiblanadi, updatedAt qo\'yiladi, keyingi o\'qishda qaytadi', async () => {
    await careService.updateSettings({ ...VALID, workDays: [5, 1, 3] });
    const view = await careService.getSettings();
    expect(view).toMatchObject({ psychologistDisplayName: 'Dilnoza opa', deputyDisplayName: null, workDays: [1, 3, 5], urgentSlaMinutes: 45, normalSlaHours: 12 });
    expect(view.updatedAt).toMatch(/^\d{4}-\d{2}-\d{2}T/);
  });

  it('auditga tafsilotsiz yoziladi (xodim ismi, ID yo\'q)', async () => {
    await careService.updateSettings(VALID);
    const entry = getTables().audit.at(-1);
    expect(entry).toMatchObject({ module: 'CARE', action: 'care.settings.update', entityId: null, before: null, after: null });
    const json = JSON.stringify(entry);
    for (const secret of [FIXED_STAFF.psychologistDeputy, 'Karimova', 'Dilnoza']) expect(json.includes(secret)).toBe(false);
  });

  const bad: Array<[string, Partial<CareSettingsInput>, string]> = [
    ['o\'rinbosar = mas\'ul psixolog', { deputyStaffId: FIXED_STAFF.psychologist }, 'deputyStaffId: errors.form.deputySame'],
    ['ish vaqti teskari', { workStart: '17:00', workEnd: '09:00' }, 'workEnd: errors.form.endBeforeStart'],
    ['tugash = boshlanish', { workStart: '09:00', workEnd: '09:00' }, 'workEnd: errors.form.endBeforeStart'],
    ['kunlar bo\'sh', { workDays: [] }, 'workDays: errors.form.selectAtLeastOne'],
    ['kun 8', { workDays: [1, 8] }, 'workDays.1:'],
    ['kunlar takrorlangan', { workDays: [1, 1] }, 'workDays: errors.form.duplicateDay'],
    ['shoshilinch muddat 14', { urgentSlaMinutes: 14 }, 'urgentSlaMinutes: errors.form.slaMinutesRange'],
    ['shoshilinch muddat 1441', { urgentSlaMinutes: 1441 }, 'urgentSlaMinutes: errors.form.slaMinutesRange'],
    ['oddiy muddat 0', { normalSlaHours: 0 }, 'normalSlaHours: errors.form.slaHoursRange'],
    ['oddiy muddat 169', { normalSlaHours: 169 }, 'normalSlaHours: errors.form.slaHoursRange'],
    ['ism 41 belgi', { psychologistDisplayName: 'x'.repeat(41) }, 'psychologistDisplayName: errors.form.tooLong'],
    ['vaqt formati', { workStart: '9:00' }, 'workStart: errors.form.invalidTime'],
  ];
  it.each(bad)('rad etadi: %s', async (_name, patch, message) => {
    const rejection = await careService.updateSettings({ ...VALID, ...patch }).catch((e: unknown) => e);
    expect(rejection).toMatchObject({ code: 'VALIDATION' });
    expect((rejection as Error).message.startsWith(message)).toBe(true);
  });

  it('psixolog bo\'lmagan, nofaol yoki noma\'lum xodimni rad etadi', async () => {
    await expect(careService.updateSettings({ ...VALID, psychologistStaffId: FIXED_STAFF.director })).rejects.toMatchObject({
      code: 'VALIDATION',
      message: 'psychologistStaffId: errors.form.staffInvalid',
    });
    await expect(careService.updateSettings({ ...VALID, deputyStaffId: 'stf-yoq' })).rejects.toMatchObject({
      message: 'deputyStaffId: errors.form.staffInvalid',
    });
    transact((t) => {
      t.staff = t.staff.map((s) => (s.id === FIXED_STAFF.psychologistDeputy ? { ...s, active: false } : s));
    });
    await expect(careService.updateSettings(VALID)).rejects.toMatchObject({ message: 'deputyStaffId: errors.form.staffInvalid' });
  });

  it('mas\'ul va o\'rinbosarni tozalash mumkin (null)', async () => {
    await careService.updateSettings({ ...VALID, psychologistStaffId: null, deputyStaffId: null });
    expect(await careService.getSettings()).toMatchObject({ psychologistStaffId: null, deputyStaffId: null });
  });
});

describe('demo bazasi migratsiyasi — Bola ovozi sozlamalari', () => {
  it('eski bazaga demo sozlamalar va ikkinchi psixolog qo\'shiladi; takror qo\'shilmaydi', () => {
    const fresh = createFreshSnapshot(new Date(2026, 9, 14, 10));
    const withoutDeputy = fresh.tables.staff.filter((s) => s.id !== FIXED_STAFF.psychologistDeputy);
    const { careSettings: _drop, ...rest } = fresh.tables;
    void _drop;
    const legacy = { ...fresh, tables: { ...rest, staff: withoutDeputy } } as unknown as typeof fresh;
    const migrated = migrate(legacy);
    expect(migrated.tables.careSettings).toMatchObject({ psychologistStaffId: FIXED_STAFF.psychologist, deputyStaffId: FIXED_STAFF.psychologistDeputy });
    expect(migrated.tables.staff.filter((s) => s.id === FIXED_STAFF.psychologistDeputy)).toHaveLength(1);
    expect(migrate(migrated)).toBe(migrated);
  });
});
