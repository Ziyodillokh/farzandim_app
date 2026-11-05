import { beforeEach, describe, expect, it } from 'vitest';

import type { TimetableLesson } from '@/data/contracts';
import { getTables } from '../db';
import { timetableService } from '../services/timetable';
import { freshDb, loginAs } from './helpers';

const lesson = (weekday: number, periodNo: number, subject = 'math'): TimetableLesson => ({ weekday: weekday as TimetableLesson['weekday'], periodNo, subject });

describe('dars jadvali: seed', () => {
  beforeEach(freshDb);

  it('har sinfda jadval bor; barcha darslar sinf smenasining DARS davrlariga to\'g\'ri keladi, takrorsiz', () => {
    const t = getTables();
    expect(t.timetables).toHaveLength(t.classes.length);
    for (const cls of t.classes) {
      const shift = t.shifts.find((s) => s.id === cls.shiftId)!;
      const lessonNos = new Set(shift.periods.filter((p) => p.kind === 'LESSON').map((p) => p.no));
      const lessons = t.timetables.find((r) => r.classId === cls.id)!.lessons;
      expect(lessons.length, cls.name).toBeGreaterThan(20);
      const keys = lessons.map((l) => `${l.weekday}:${l.periodNo}`);
      expect(new Set(keys).size, cls.name).toBe(keys.length);
      for (const l of lessons) {
        expect(lessonNos.has(l.periodNo), `${cls.name} ${keys}`).toBe(true);
        expect(l.weekday).toBeGreaterThanOrEqual(1);
        expect(l.weekday).toBeLessThanOrEqual(6);
        expect(l.subject.length).toBeGreaterThan(0);
        expect(l.subject.length).toBeLessThanOrEqual(60);
      }
    }
  });

  it('bir kunda ketma-ket bir xil fan chiqmaydi', () => {
    for (const record of getTables().timetables) {
      for (const l of record.lessons) {
        const previous = record.lessons.find((x) => x.weekday === l.weekday && x.periodNo === l.periodNo - 1);
        expect(previous?.subject, `${record.classId} ${l.weekday}:${l.periodNo}`).not.toBe(l.subject);
      }
    }
  });

  it('2-smena (1–4-sinf) shanba kuni dars yo\'q; 1-smenada shanba qisqa', async () => {
    loginAs('DIRECTOR');
    const second = await timetableService.get('cls-2a');
    expect(second.lessons.some((l) => l.weekday === 6)).toBe(false);
    const first = await timetableService.get('cls-7a');
    const saturday = first.lessons.filter((l) => l.weekday === 6);
    expect(saturday.length).toBeGreaterThan(0);
    expect(saturday.length).toBeLessThan(first.lessons.filter((l) => l.weekday === 1).length);
  });
});

describe('dars jadvali: ruxsat va doira', () => {
  beforeEach(freshDb);

  it('get sinfning smenasini (davrlar bilan) va darslarni qaytaradi', async () => {
    loginAs('ADMIN');
    const tt = await timetableService.get('cls-7a');
    expect(tt.classId).toBe('cls-7a');
    expect(tt.shift.id).toBe('shf-1');
    expect(tt.shift.periods.some((p) => p.kind === 'LESSON')).toBe(true);
    await expect(timetableService.get('cls-yoq')).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('sinf rahbari o\'z sinfini ko\'radi va tahrirlaydi, boshqasiga ruxsat yo\'q', async () => {
    loginAs('HOMEROOM');
    await expect(timetableService.get('cls-7a')).resolves.toBeTruthy();
    await expect(timetableService.save('cls-7a', { lessons: [lesson(1, 1)] })).resolves.toBeTruthy();
    await expect(timetableService.get('cls-8b')).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(timetableService.save('cls-8b', { lessons: [] })).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('timetable.manage yo\'q rol (psixolog, navbatchi) tahrirlay olmaydi; psixolog ko\'ra olmaydi ham', async () => {
    loginAs('DUTY');
    await expect(timetableService.save('cls-7a', { lessons: [] })).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('PSYCHOLOGIST');
    await expect(timetableService.get('cls-7a')).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});

describe('dars jadvali: saqlash', () => {
  beforeEach(freshDb);

  it('PUT haftani to\'liq almashtiradi (eski darslar qolmaydi) va audit yoziladi', async () => {
    loginAs('DIRECTOR');
    const saved = await timetableService.save('cls-7a', {
      lessons: [lesson(1, 1, 'math'), { ...lesson(2, 2, 'Texnologiya'), room: ' 205 ', teacherName: '' }],
    });
    expect(saved.lessons).toEqual([
      { weekday: 1, periodNo: 1, subject: 'math' },
      { weekday: 2, periodNo: 2, subject: 'Texnologiya', room: '205' },
    ]);
    expect((await timetableService.get('cls-7a')).lessons).toHaveLength(2);
    // Boshqa sinf jadvali tegilmaydi.
    expect((await timetableService.get('cls-7b')).lessons.length).toBeGreaterThan(20);
    const audit = getTables().audit.at(-1);
    expect(audit?.action).toBe('timetable.save');
    expect(audit?.params).toMatchObject({ class: '7-A', count: 2 });
  });

  it('bo\'sh ro\'yxat jadvalni tozalaydi', async () => {
    loginAs('ADMIN');
    expect((await timetableService.save('cls-7a', { lessons: [] })).lessons).toEqual([]);
  });

  it('noto\'g\'ri davr/kun/takror/uzun fan — VALIDATION va yo\'l xabarda (lessons.N)', async () => {
    loginAs('ADMIN');
    await expect(timetableService.save('cls-7a', { lessons: [lesson(1, 1), lesson(1, 99)] })).rejects.toMatchObject({ code: 'VALIDATION', message: expect.stringContaining('lessons.1') });
    await expect(timetableService.save('cls-7a', { lessons: [lesson(7, 1)] })).rejects.toMatchObject({ code: 'VALIDATION', message: expect.stringContaining('lessons.0.weekday') });
    await expect(timetableService.save('cls-7a', { lessons: [lesson(1, 1), lesson(1, 1, 'english')] })).rejects.toMatchObject({ code: 'VALIDATION', message: expect.stringContaining('lessons.1') });
    await expect(timetableService.save('cls-7a', { lessons: [lesson(1, 1, 'x'.repeat(61))] })).rejects.toMatchObject({ code: 'VALIDATION', message: expect.stringContaining('lessons.0.subject') });
    // 2-smenada 6-dars yo'q (1-smenada bor).
    await expect(timetableService.save('cls-2a', { lessons: [lesson(1, 6)] })).rejects.toMatchObject({ code: 'VALIDATION' });
  });

  it('muvaffaqiyatsiz saqlash eski jadvalni o\'zgartirmaydi', async () => {
    loginAs('ADMIN');
    const before = await timetableService.get('cls-7a');
    await expect(timetableService.save('cls-7a', { lessons: [lesson(1, 1), lesson(1, 99)] })).rejects.toBeTruthy();
    expect((await timetableService.get('cls-7a')).lessons).toEqual(before.lessons);
  });
});
