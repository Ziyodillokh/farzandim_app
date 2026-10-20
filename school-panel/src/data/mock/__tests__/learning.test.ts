import { beforeEach, describe, expect, it } from 'vitest';

import { getTables } from '../db';
import { learningService } from '../services/learning';
import { freshDb, loginAs } from './helpers';

const DUE = '2026-10-20';

describe('Growth Learning — tayinlash doirasi', () => {
  beforeEach(freshDb);

  it('sinf rahbari faqat o\'z sinfiga tayinlaydi', async () => {
    loginAs('HOMEROOM');
    const created = await learningService.createAssignment({ materialId: 'mat-2', classIds: ['cls-7a'], dueDate: DUE, note: '' });
    expect(created.classIds).toEqual(['cls-7a']);
    expect(getTables().audit.at(-1)?.action).toBe('learning.assign');
    await expect(
      learningService.createAssignment({ materialId: 'mat-2', classIds: ['cls-7a', 'cls-8b'], dueDate: DUE, note: '' }),
    ).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('direktor faqat ko\'radi, tayinlay olmaydi; psixolog umuman kira olmaydi', async () => {
    loginAs('DIRECTOR');
    await expect(
      learningService.createAssignment({ materialId: 'mat-2', classIds: ['cls-7a'], dueDate: DUE, note: '' }),
    ).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('PSYCHOLOGIST');
    await expect(learningService.activity()).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('o\'tgan muddat va noma\'lum material rad etiladi', async () => {
    loginAs('ADMIN');
    await expect(
      learningService.createAssignment({ materialId: 'mat-2', classIds: ['cls-7a'], dueDate: '2026-10-01', note: '' }),
    ).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(
      learningService.createAssignment({ materialId: 'mat-x', classIds: ['cls-7a'], dueDate: DUE, note: '' }),
    ).rejects.toMatchObject({ code: 'VALIDATION' });
  });

  it('sinf rahbari boshqa sinflarga ham tegishli topshiriqni o\'chira olmaydi', async () => {
    loginAs('HOMEROOM');
    const rows = await learningService.assignments();
    const shared = rows.find((r) => r.classIds.length > 1);
    expect(shared?.canDelete).toBe(false);
    await expect(learningService.deleteAssignment(shared!.id)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    const own = rows.find((r) => r.classIds.length === 1 && r.classIds[0] === 'cls-7a');
    await learningService.deleteAssignment(own!.id);
    expect(getTables().assignments.some((a) => a.id === own!.id)).toBe(false);
  });
});

describe('Growth Learning — faollik doirasi', () => {
  beforeEach(freshDb);

  it('sinf rahbari faqat o\'z sinfi faolligini ko\'radi', async () => {
    loginAs('HOMEROOM');
    const activity = await learningService.activity();
    expect(activity.classes.map((c) => c.classId)).toEqual(['cls-7a']);
    expect(activity.weeks.length).toBeGreaterThan(1);
    await expect(learningService.activity({ classId: 'cls-8b' })).rejects.toMatchObject({ code: 'FORBIDDEN' });
    const assignments = await learningService.assignments();
    for (const a of assignments) expect(a.classIds).toContain('cls-7a');
    for (const a of assignments) expect(a.classNames).toEqual(['7-A']);
  });

  it('direktor butun maktab faolligini ko\'radi', async () => {
    loginAs('DIRECTOR');
    const activity = await learningService.activity();
    expect(activity.classes.length).toBe(getTables().classes.length);
    const last = activity.weeks.at(-1);
    expect(last?.activeStudents).toBe(activity.classes.reduce((s, c) => s + c.activeStudents, 0));
  });

  it('qiziqishlar taqsimoti deterministik va har sinf darajasida 100%', async () => {
    loginAs('ADMIN');
    const first = await learningService.interests();
    const second = await learningService.interests();
    expect(first).toEqual(second);
    expect(first.length).toBe(11);
    for (const row of first) expect(row.shares.reduce((s, x) => s + x.percent, 0)).toBe(100);
  });

  it('materiallar filtri ishlaydi', async () => {
    loginAs('ADMIN');
    const tests = await learningService.materials({ kind: 'TEST' });
    expect(tests.length).toBeGreaterThan(0);
    expect(tests.every((m) => m.kind === 'TEST')).toBe(true);
    const grade1 = await learningService.materials({ grade: 1 });
    expect(grade1.every((m) => m.grades.includes(1))).toBe(true);
  });
});
