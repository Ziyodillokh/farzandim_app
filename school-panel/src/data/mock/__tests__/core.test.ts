import { beforeEach, describe, expect, it } from 'vitest';

import { ROLES, PERMISSIONS } from '@/auth/permissions';
import { ROUTES } from '@/auth/route-manifest';
import { ServiceError } from '@/data/contracts';
import { applyKAnonymity, maskSmallCount } from '@/lib/k-anon';
import { escapeCsvCell, parseCsv, toCsv } from '@/lib/csv';
import { normalizeSearch } from '@/lib/normalize-search';
import { simulate } from '../simulator';
import { getTables, transact } from '../db';
import { attendanceService } from '../services/attendance';
import { studentsService } from '../services/students';
import { freshDb, loginAs } from './helpers';

describe('ruxsatlar va marshrutlar', () => {
  it('har marshrut ma\'lum ruxsatga bog\'langan', () => {
    for (const r of ROUTES) expect(PERMISSIONS).toContain(r.perm);
  });
  it('psixolog yagona shaxsiy Bola ovozi huquqiga ega', () => {
    const withIndividual = Object.values(ROLES).filter((r) => r.permissions.includes('care.individual'));
    expect(withIndividual.map((r) => r.key)).toEqual(['PSYCHOLOGIST']);
  });
  it('testlarni faqat psixolog boshqaradi; shaxsiy rivojlanish — psixolog va sinf rahbari', () => {
    const keysWith = (p: (typeof PERMISSIONS)[number]) => Object.values(ROLES).filter((r) => r.permissions.includes(p)).map((r) => r.key).sort();
    expect(keysWith('assessments.manage')).toEqual(['PSYCHOLOGIST']);
    expect(keysWith('development.individual')).toEqual(['HOMEROOM', 'PSYCHOLOGIST']);
    expect(ROLES.DUTY.permissions.some((p) => p.startsWith('development.') || p.startsWith('assessments.'))).toBe(false);
  });
});

describe('xizmatlar: doira va audit', () => {
  beforeEach(freshDb);

  it('sinf rahbari faqat o\'z sinfini ko\'radi', async () => {
    loginAs('HOMEROOM');
    const page = await studentsService.list({ limit: 500 });
    expect(page.items.length).toBeGreaterThan(20);
    expect(new Set(page.items.map((s) => s.classId))).toEqual(new Set(['cls-7a']));
    await expect(studentsService.list({ classId: 'cls-8b' })).rejects.toBeInstanceOf(ServiceError);
  });

  it('navbatchi o\'quvchi qo\'sha olmaydi', async () => {
    loginAs('DUTY');
    await expect(
      studentsService.create({ lastName: 'A', firstName: 'B', gender: 'MALE', birthDate: '2014-01-01', classId: 'cls-7a', device: 'NONE' }),
    ).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('har o\'zgarish audit jurnaliga yoziladi', async () => {
    loginAs('ADMIN');
    const before = getTables().audit.length;
    await studentsService.create({ lastName: 'Test', firstName: 'Bola', gender: 'MALE', birthDate: '2014-01-01', classId: 'cls-7a', device: 'NONE' });
    expect(getTables().audit.length).toBe(before + 1);
    expect(getTables().audit.at(-1)?.action).toBe('student.create');
  });

  it('zod validatsiyasi — noto\'g\'ri telefon rad etiladi', async () => {
    loginAs('ADMIN');
    await expect(
      studentsService.create({ lastName: 'A', firstName: 'B', gender: 'MALE', birthDate: '2014-01-01', classId: 'cls-7a', device: 'NONE', guardian: { fullName: 'X', phone: '123', relation: 'MOTHER' } }),
    ).rejects.toMatchObject({ code: 'VALIDATION' });
  });
});

describe('simulyator va davomat', () => {
  beforeEach(freshDb);

  it('10:00 gacha 1-smena o\'quvchilari kelgan, 2-smena hali yo\'q', () => {
    const events = transact((t) => simulate(t, '2026-10-12', 10 * 60));
    expect(events.length).toBeGreaterThan(200);
    const t = getTables();
    const firstShift = new Set(t.classes.filter((c) => c.grade >= 5).map((c) => c.id));
    expect(t.attendance.every((r) => firstShift.has(r.classId))).toBe(true);
  });

  it('qayta chaqiruv yangi hodisa bermaydi (idempotent)', () => {
    transact((t) => simulate(t, '2026-10-12', 10 * 60));
    const again = transact((t) => simulate(t, '2026-10-12', 10 * 60));
    expect(again).toHaveLength(0);
  });

  it('kiosk orqali kirish ikkinchi marta "allaqachon" deb qaytadi', async () => {
    loginAs('DUTY');
    const student = getTables().students.find((s) => s.classId === 'cls-3a');
    expect(student).toBeDefined();
    const first = await attendanceService.checkIn(student!.studentCode);
    expect(first.alreadyIn).toBe(false);
    const second = await attendanceService.checkIn(student!.studentCode);
    expect(second.alreadyIn).toBe(true);
  });

  it('o\'tgan kunni tuzatish sababsiz bo\'lmaydi va tarixda saqlanadi', async () => {
    loginAs('ADMIN');
    const student = getTables().students[0]!;
    await expect(attendanceService.correct({ studentId: student.id, date: '2026-10-09', status: 'EXCUSED', reason: '' })).rejects.toMatchObject({ code: 'VALIDATION' });
    const record = await attendanceService.correct({ studentId: student.id, date: '2026-10-09', status: 'EXCUSED', reason: 'Shifokor ma\'lumotnomasi' });
    expect(record.status).toBe('EXCUSED');
    expect(record.corrections).toHaveLength(1);
  });

  it('kiosk kodi joriy va oldingi oynada qabul qilinadi', () => {
    const token = attendanceService.currentToken();
    expect(attendanceService.verifyToken(token.code)).toBe(true);
    expect(attendanceService.verifyToken('000000x')).toBe(false);
  });
});

describe('yordamchilar', () => {
  it('k-anonimlik: kichik guruh va ikkilamchi yashirish', () => {
    const groups = applyKAnonymity([
      { key: 'a', label: 'A', respondents: 3, value: 1 },
      { key: 'b', label: 'B', respondents: 6, value: 1 },
      { key: 'c', label: 'C', respondents: 20, value: 1 },
    ]);
    expect(groups.map((g) => g.hidden)).toEqual([true, true, false]);
    expect(maskSmallCount(3)).toBe('<5');
    expect(maskSmallCount(0)).toBe('0');
  });

  it('CSV: BOM, ; ajratuvchi, formula-injection himoyasi', () => {
    const csv = toCsv([{ a: '=1+2', b: 'x;y' }], [
      { header: 'A', value: (r) => r.a },
      { header: 'B', value: (r) => r.b },
    ]);
    expect(csv.startsWith('﻿')).toBe(true);
    expect(csv).toContain("'=1+2");
    expect(csv).toContain('"x;y"');
    expect(escapeCsvCell(null)).toBe('');
    expect(parseCsv('a;b\n"c;d";e')).toEqual([['a', 'b'], ['c;d', 'e']]);
  });

  it('qidiruv apostroflarni bir xil ko\'radi', () => {
    expect(normalizeSearch('Gʻulomov')).toBe(normalizeSearch("G'ulomov"));
  });
});
