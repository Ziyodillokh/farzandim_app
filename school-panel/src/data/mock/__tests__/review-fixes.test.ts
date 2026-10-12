import { beforeEach, describe, expect, it } from 'vitest';

import { decodeBrand, encodeBrand } from '@/lib/brand-link';
import { getTables, transact } from '../db';
import { simulate } from '../simulator';
import { dashboardService } from '../services/dashboard';
import { availableTriggers, demoService } from '../services/demo';
import { guardiansService, studentsService } from '../services/students';
import { freshDb, loginAs } from './helpers';

describe('ota-onalar: doira va statistika', () => {
  beforeEach(freshDb);

  it('sinf rahbari boshqa sinfdagi farzandlarni ko\'rmaydi', async () => {
    loginAs('HOMEROOM');
    const page = await guardiansService.list({ limit: 500 });
    expect(page.items.length).toBeGreaterThan(0);
    for (const g of page.items) for (const c of g.children) expect(c.className).toBe('7-A');
  });

  it('sinf rahbari boshqa sinf filtri bilan so\'rasa — FORBIDDEN', async () => {
    loginAs('HOMEROOM');
    await expect(guardiansService.list({ classId: 'cls-8b' })).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('psixolog ota-onalar ro\'yxatini ololmaydi', async () => {
    loginAs('PSYCHOLOGIST');
    await expect(guardiansService.list()).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('statistika 500 dan ko\'p ota-onada ham to\'liq hisoblanadi', async () => {
    loginAs('ADMIN');
    const stats = await guardiansService.stats();
    const t = getTables();
    const withChildren = new Set(t.students.filter((s) => !s.archived).flatMap((s) => s.guardianIds));
    expect(stats.total).toBe(withChildren.size);
    expect(stats.total).toBeGreaterThan(500);
    const linked = t.guardians.filter((g) => withChildren.has(g.id) && g.linkStatus === 'LINKED').length;
    expect(stats.LINKED).toBe(linked);
  });
});

describe('o\'quvchi: psixolog uchun redaksiya va sinf almashishi', () => {
  beforeEach(freshDb);

  it('psixolog ro\'yxatida tug\'ilgan sana, ota-ona va qurilma yo\'q', async () => {
    loginAs('PSYCHOLOGIST');
    const page = await studentsService.list({ limit: 5 });
    for (const s of page.items) {
      expect(s.birthDate).toBe('');
      expect(s.guardianNames).toEqual([]);
      expect(s.todayStatus).toBeNull();
    }
    expect((await studentsService.classOptions()).length).toBe(22);
  });

  it('sinf almashsa ochiq erta ketish so\'rovi yangi sinfga o\'tadi; noma\'lum sinf rad etiladi', async () => {
    loginAs('ADMIN');
    const student = getTables().students.find((s) => s.classId === 'cls-7a' && !s.archived);
    if (!student) throw new Error('no student');
    transact((t) => {
      t.earlyExits.push({ id: 'exit-test', studentId: student.id, classId: 'cls-7a', date: '2026-10-12', time: '11:00', reason: 'x', pickupBy: 'Onasi', status: 'PENDING', requestedAt: '2026-10-12T09:00:00', decidedByStaffId: null, decidedAt: null });
    });
    const { guardianIds: _g, studentCode: _c, enrolledAt: _e, archived: _a, id: _i, ...input } = student;
    void [_g, _c, _e, _a, _i];
    await studentsService.update(student.id, { ...input, classId: 'cls-8a' });
    expect(getTables().earlyExits.find((x) => x.id === 'exit-test')?.classId).toBe('cls-8a');
    await expect(studentsService.update(student.id, { ...input, classId: 'cls-yoq' })).rejects.toMatchObject({ code: 'VALIDATION' });
  });
});

describe('demo triggerlari', () => {
  beforeEach(freshDb);

  it('rolga mos turlar', () => {
    expect(availableTriggers('PSYCHOLOGIST')).toEqual(['CARE_URGENT', 'SURVEY_RESPONSES', 'TEST_COMPLETIONS']);
    expect(availableTriggers('DUTY')).toEqual(['LATE']);
    expect(availableTriggers('DIRECTOR')).toContain('VERIFICATION');
  });

  it('sinf rahbari faqat o\'z sinfida hodisa yaratadi va audit yoziladi', () => {
    loginAs('HOMEROOM');
    const before = getTables().audit.length;
    demoService.trigger('LATE');
    const t = getTables();
    const latest = t.attendanceEvents[t.attendanceEvents.length - 1];
    expect(latest?.classId).toBe('cls-7a');
    expect(t.audit.length).toBe(before + 1);
    expect(() => demoService.trigger('VERIFICATION')).toThrow();
  });
});

describe('simulyator: kun almashganda qo\'lda belgilanganlar saqlanadi', () => {
  beforeEach(freshDb);

  it('oldingi kunning MANUAL yozuvi yangi kun boshida o\'chmaydi', () => {
    const student = getTables().students.find((s) => s.classId === 'cls-7a');
    if (!student) throw new Error('no student');
    transact((t) => {
      simulate(t, '2026-10-12', 9 * 60, 0);
      t.attendance = t.attendance.filter((r) => !(r.date === '2026-10-12' && r.studentId === student.id));
      t.attendance.push({ id: `2026-10-12:${student.id}`, date: '2026-10-12', studentId: student.id, classId: 'cls-7a', status: 'ABSENT', inAt: null, outAt: null, source: 'MANUAL', corrections: [], parentNotified: true });
      simulate(t, '2026-10-13', 8 * 60, 0);
    });
    const kept = getTables().attendance.find((r) => r.id === `2026-10-12:${student.id}`);
    expect(kept?.status).toBe('ABSENT');
    // Avtomatik (tuzatilmagan QR/SYSTEM) yozuvlar tashlanadi — tarix rejadan hisoblanadi.
    const leftovers = getTables().attendance.filter((r) => r.date === '2026-10-12');
    expect(leftovers.every((r) => r.corrections.length > 0 || r.source === 'MANUAL' || r.source === 'KIOSK')).toBe(true);
  });
});

describe('bosh sahifa: eslatmalar doirasi', () => {
  beforeEach(freshDb);

  it('boshqa sinf ota-onasiga yo\'llangan eslatma sinf rahbariga ko\'rinmaydi', async () => {
    const guardianOf9a = getTables().students.find((s) => s.classId === 'cls-9a')?.guardianIds[0] ?? '';
    transact((t) => {
      t.reminders.push({ id: 'rem-test', kind: 'MEETING', title: 'Alohida suhbat: 9-A oilasi', body: '', audience: { kind: 'GUARDIANS', classIds: [], guardianIds: [guardianOf9a] }, sendAt: '2026-10-13T09:00:00', repeat: 'NONE', active: true, byStaffId: 'stf-admin' });
    });
    loginAs('HOMEROOM');
    const o = await dashboardService.overview();
    expect(o.upcoming?.some((r) => r.id === 'rem-test')).toBe(false);
    loginAs('ADMIN');
    expect((await dashboardService.overview()).upcoming?.some((r) => r.id === 'rem-test')).toBe(true);
  });
});

describe('maktab havolasi', () => {
  it('juda katta yoki noto\'g\'ri logo qabul qilinmaydi', () => {
    const big = `data:image/png;base64,${'A'.repeat(70_000)}`;
    const hash = `#b=${encodeBrand({ name: 'X maktab', shortName: 'XM', city: '', logo: null })}`;
    expect(decodeBrand(hash)?.name).toBe('X maktab');
    const raw = btoa(JSON.stringify({ n: 'Y', s: 'Y', c: '', l: big })).replace(/=+$/, '');
    expect(decodeBrand(`#b=${raw}`)?.logo ?? null).toBeNull();
  });
});
