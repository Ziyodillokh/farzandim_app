import { beforeEach, describe, expect, it } from 'vitest';

import type { AuditLog } from '@/data/contracts';
import { auditActionKey, auditText } from '@/features/audit/audit-text';
import { type TKey, translate } from '@/i18n/translate';
import { audit as ruAudit } from '@/i18n/ru/audit';
import { audit as uzAudit } from '@/i18n/uz/audit';
import type { Vars } from '@/i18n/types';
import { getTables } from '../db';
import { attendanceService } from '../services/attendance';
import { studentsService } from '../services/students';
import { freshDb, loginAs } from './helpers';

const ru = (key: TKey, vars?: Vars) => translate('ru', key, vars);
const uz = (key: TKey, vars?: Vars) => translate('uz', key, vars);

const entry = (action: string, summary: string, params?: AuditLog['params']) => ({ action, summary, params });

describe('auditText: tarjima va zaxira', () => {
  it('kalit yo\'q (care/demo) — saqlangan tavsif', () => {
    expect(auditText(ru, entry('care.request.status', 'Murojaat holati o\'zgardi', { name: 'x' }))).toBe('Murojaat holati o\'zgardi');
    expect(auditText(ru, entry('demo.trigger', 'Demo hodisa: LATE'))).toBe('Demo hodisa: LATE');
  });

  it('parametr yetishmasa (eski yozuv) — tavsif, `{name}` ko\'rinmaydi', () => {
    expect(auditText(ru, entry('student.create', 'Aliyev Vali qo\'shildi'))).toBe('Aliyev Vali qo\'shildi');
    expect(auditText(ru, entry('student.create', 'Aliyev Vali qo\'shildi', { other: 1 }))).toBe('Aliyev Vali qo\'shildi');
  });

  it('ruscha UI: parametrlar bilan ruscha matn', () => {
    expect(auditText(ru, entry('student.create', 'Aliyev Vali qo\'shildi', { name: 'Aliyev Vali' }))).toBe('Добавлен ученик: Aliyev Vali');
    expect(auditText(uz, entry('student.create', 'x', { name: 'Aliyev Vali' }))).toBe('Aliyev Vali qo\'shildi');
  });

  it('holat kodlari tarjima qilinadi; variant alohida kalitni tanlaydi', () => {
    expect(auditText(ru, entry('attendance.mark', 'Aliyev Vali — LATE', { name: 'Aliyev Vali', status: 'LATE' }))).toBe('Aliyev Vali — Опоздал');
    expect(auditText(uz, entry('attendance.mark', 'x', { name: 'Aliyev Vali', status: 'LATE' }))).toBe('Aliyev Vali — Kechikdi');
    const bulk = entry('payment.bulkShift', 'x', { variant: 'months', count: 18, months: 1, note: 'oldindan' });
    expect(auditActionKey(bulk)).toBe('audit.actions.payment_bulkShift_months');
    expect(auditText(ru, bulk)).toBe('Дата напоминания перенесена на 1 мес., семей: 18 — oldindan');
  });

  it('parametrsiz shablon (kirish) — eski yozuvlar ham tarjima qilinadi', () => {
    expect(auditText(ru, entry('auth.login', 'Panelga kirdi'))).toBe('Вход в панель');
  });

  it('uz va ru shablonlarida bir xil parametrlar', () => {
    const placeholders = (s: string) => [...s.matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort();
    for (const [key, template] of Object.entries(uzAudit.actions)) {
      expect(placeholders(ruAudit.actions[key as keyof typeof ruAudit.actions]), key).toEqual(placeholders(template));
    }
  });
});

describe('auditText: servis yozuvlari va seed', () => {
  beforeEach(freshDb);

  it('seed yozuvlari ruscha ko\'rsatiladi (tavsifga qaytmaydi)', () => {
    const seeded = getTables().audit.filter((a) => a.id.startsWith('aud-seed-'));
    expect(seeded.length).toBeGreaterThan(5);
    for (const a of seeded) expect(auditText(ru, a), a.action).not.toBe(a.summary);
    expect(auditText(uz, seeded.find((a) => a.action === 'school.update') ?? seeded[0]!)).toBe('Kechikish chegarasi 10 daqiqa etib belgilandi');
  });

  it('servis parametr yozadi: o\'quvchi yaratish va davomat ruscha', async () => {
    loginAs('ADMIN');
    const student = await studentsService.create({ lastName: 'Karimov', firstName: 'Aziz', middleName: '', gender: 'MALE', birthDate: '2014-03-01', classId: 'cls-7a', device: 'NONE' });
    expect(auditText(ru, getTables().audit.at(-1)!)).toBe('Добавлен ученик: Karimov Aziz');
    await attendanceService.mark(student.id, 'ABSENT');
    expect(auditText(ru, getTables().audit.at(-1)!)).toBe('Karimov Aziz — Отсутствует');
  });
});
