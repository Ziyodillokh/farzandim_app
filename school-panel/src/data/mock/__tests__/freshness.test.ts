import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import type { PsychTest } from '@/data/contracts';
import { __setClockForTests } from '../clock';
import { getDb, getTables, transact } from '../db';
import { daysBetween, ensureDemoFresh, needsRegeneration } from '../freshness';
import { PSYCH_TEMPLATES } from '../seed/psych-templates';
import { freshDb } from './helpers';

const PHOTO = 'data:image/png;base64,AAAA';

function setClockDate(scenarioDate: string): void {
  __setClockForTests({ mode: 'SCENARIO', scenarioDate, scenarioStartMinute: 9 * 60, realStartedAt: Date.now(), speed: 1 });
}

function customTest(base: PsychTest): PsychTest {
  return { ...base, id: 'pt-custom-1', source: 'CUSTOM', basedOn: base.id, title: { uz: 'Maktab testi', ru: 'Тест школы' } };
}

describe('demo ma\'lumotlari yangiligi', () => {
  beforeEach(freshDb);
  afterEach(() => __setClockForTests(null));

  it('sana farqi va o\'quv yili', () => {
    expect(daysBetween('2026-10-12', '2026-10-12')).toBe(0);
    expect(daysBetween('2026-10-12', '2026-10-09')).toBe(3);
    expect(needsRegeneration({ baseDate: '2026-10-12' }, new Date(2026, 9, 12, 18))).toBe(false);
    expect(needsRegeneration({ baseDate: '2026-10-12' }, new Date(2026, 9, 13, 8))).toBe(true);
  });

  it('bir xil kun — OK, baza o\'zgarmaydi', () => {
    const before = getDb();
    expect(ensureDemoFresh()).toBe('OK');
    expect(getDb()).toBe(before);
  });

  it('kun o\'zgarsa — qayta yaratiladi; brend, rasmlar va maktab testlari saqlanadi', () => {
    transact((t) => {
      t.school = { ...t.school, name: 'Toshkent 25-maktab', shortName: '25M', city: 'Toshkent', logo: PHOTO, phone: '+998 90 000 00 00', address: 'Chilonzor', lateAfterMinutes: 15 };
      t.staff = t.staff.map((s) => (s.id === 'stf-director' ? { ...s, photo: PHOTO } : s));
      t.earlyExits = [];
      t.psychTests = [customTest(PSYCH_TEMPLATES['tpl-logic'])];
      t.psychTemplateState = { ...t.psychTemplateState, 'tpl-logic': { status: 'ARCHIVED', norms: null } };
    });
    const portrait = getTables().staff.find((s) => s.id === 'stf-psychologist')?.portrait;

    setClockDate('2026-10-15');
    expect(ensureDemoFresh()).toBe('REGENERATED');

    const db = getDb();
    const t = db.tables;
    expect(db.baseDate).toBe('2026-10-15');
    expect(t.school).toMatchObject({ name: 'Toshkent 25-maktab', shortName: '25M', city: 'Toshkent', logo: PHOTO, phone: '+998 90 000 00 00', address: 'Chilonzor', lateAfterMinutes: 15 });
    expect(t.staff.find((s) => s.id === 'stf-director')?.photo).toBe(PHOTO);
    expect(t.staff.find((s) => s.id === 'stf-psychologist')?.portrait).toBe(portrait);
    // Bugungi so'rovlar yangi kunga qayta yaratildi.
    expect(t.earlyExits.length).toBeGreaterThan(0);
    expect(t.earlyExits.some((e) => e.date === '2026-10-15')).toBe(true);
    expect(t.psychTests.map((x) => x.id)).toEqual(['pt-custom-1']);
    expect(t.psychTemplateState['tpl-logic']).toEqual({ status: 'ARCHIVED', norms: null });
    expect(t.audit.at(-1)?.action).toBe('demo.regenerated');

    // Takroriy chaqiruv — endi OK.
    expect(ensureDemoFresh()).toBe('OK');
  });

  it('yangi o\'quv yili — maktab yili yangilanadi, nom saqlanadi', () => {
    transact((t) => {
      t.school = { ...t.school, name: 'Brend maktab' };
    });
    setClockDate('2027-09-07');
    expect(ensureDemoFresh()).toBe('REGENERATED');
    expect(getTables().school.academicYear).toBe('2027–2028');
    expect(getTables().school.name).toBe('Brend maktab');
  });
});
