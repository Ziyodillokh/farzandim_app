import { beforeEach, describe, expect, it } from 'vitest';

import type { SchoolModeException } from '@/data/contracts';
import { smMsg } from '@/data/schemas/school-mode';
import { getTables, transact } from '../db';
import { classModeState } from '../school-mode-state';
import { schoolModeService as sm } from '../services/school-mode';
import { exceptionStatus } from '../services/school-mode-model';
import { freshDb, loginAs } from './helpers';

/** Demo vaqti (helpers): 2026-10-12, dushanba, 10:00 — 1-smena, 3-dars. */
const TODAY = '2026-10-12';
const MINUTE = 10 * 60;
const LESSON = { kind: 'LESSON' as const };
const BREAK = { kind: 'BREAK' as const };

function studentOf(classId: string, index = 0): string {
  const student = getTables().students.filter((s) => s.classId === classId && !s.archived)[index];
  if (!student) throw new Error(classId);
  return student.id;
}

function stateOf(classId: string) {
  const t = getTables();
  const cls = t.classes.find((c) => c.id === classId);
  if (!cls) throw new Error(classId);
  return classModeState(t, cls, TODAY, MINUTE);
}

const lastAudit = () => getTables().audit.at(-1);

describe('School Mode: ruxsatlar', () => {
  beforeEach(freshDb);

  it('sinf rahbari siyosat, jadval va favqulodda holatni boshqara olmaydi', async () => {
    loginAs('HOMEROOM');
    await expect(sm.updatePolicy({ enabled: false })).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(sm.addAllowedApp({ name: 'X', category: 'EDU' })).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(sm.updateShift('shf-1', { weekdays: [1], periods: [{ start: '08:00', end: '08:45', ...LESSON }] })).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(sm.activateEmergency({ scope: 'SCHOOL', reason: 'Test' })).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('sinf rahbari istisnoni faqat o\'z sinfi uchun beradi', async () => {
    loginAs('HOMEROOM');
    const own = await sm.createException({ studentId: studentOf('cls-7a', 10), until: '12:00', reason: 'Shifokor qabuli' });
    expect(own.classId).toBe('cls-7a');
    await expect(sm.createException({ studentId: studentOf('cls-8b'), until: '12:00', reason: 'Sabab' })).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('sinf rahbari faqat o\'z sinfini ko\'radi; psixolog va navbatchi School Mode\'ni ko\'rmaydi', async () => {
    loginAs('HOMEROOM');
    const overview = await sm.overview();
    expect(overview.classes.map((c) => c.classId)).toEqual(['cls-7a']);
    const devices = await sm.devices({ limit: 500 });
    expect(new Set(devices.items.map((d) => d.classId))).toEqual(new Set(['cls-7a']));
    await expect(sm.devices({ classId: 'cls-8b' })).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('PSYCHOLOGIST');
    await expect(sm.overview()).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('DUTY');
    await expect(sm.policy()).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('ota-onaga eslatma faqat NO_PERMISSION qurilmalarga va faqat doira ichida', async () => {
    loginAs('ADMIN');
    const noPermission = (await sm.devices({ status: 'NO_PERMISSION', limit: 500 })).items.map((d) => d.studentId);
    const applied = (await sm.devices({ status: 'APPLIED', limit: 2 })).items.map((d) => d.studentId);
    expect(noPermission.length).toBeGreaterThan(0);
    const result = await sm.remindParents([...noPermission, ...applied]);
    expect(result).toEqual({ sent: noPermission.length, skipped: applied.length });
    expect(lastAudit()?.action).toBe('device.remind');
    loginAs('HOMEROOM');
    await expect(sm.remindParents([studentOf('cls-8b')])).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});

describe('School Mode: validatsiya', () => {
  beforeEach(() => {
    freshDb();
    loginAs('ADMIN');
  });

  it('ustma-ust tushgan davrlar rad etiladi', async () => {
    const periods = [
      { start: '08:00', end: '08:45', ...LESSON },
      { start: '08:40', end: '08:50', ...BREAK },
      { start: '08:50', end: '09:35', ...LESSON },
    ];
    await expect(sm.updateShift('shf-1', { weekdays: [1, 2], periods })).rejects.toMatchObject({ code: 'VALIDATION', message: expect.stringContaining(smMsg.overlap) });
  });

  it('tugash boshlanishdan oldin, noto\'g\'ri vaqt va tanaffus bilan boshlanish rad etiladi', async () => {
    await expect(sm.updateShift('shf-1', { weekdays: [1], periods: [{ start: '09:00', end: '08:45', ...LESSON }] })).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(sm.updateShift('shf-1', { weekdays: [1], periods: [{ start: '9:00', end: '09:45', ...LESSON }] })).rejects.toMatchObject({ code: 'VALIDATION' });
    const startsWithBreak = [{ start: '07:50', end: '08:00', ...BREAK }, { start: '08:00', end: '08:45', ...LESSON }];
    await expect(sm.updateShift('shf-1', { weekdays: [1], periods: startsWithBreak })).rejects.toMatchObject({ message: expect.stringContaining(smMsg.edgeLesson) });
    await expect(sm.updateShift('shf-1', { weekdays: [], periods: [{ start: '08:00', end: '08:45', ...LESSON }] })).rejects.toMatchObject({ code: 'VALIDATION' });
  });

  it('to\'g\'ri jadval saqlanadi: raqamlar, boshi va oxiri qayta hisoblanadi', async () => {
    const periods = [
      { start: '08:30', end: '09:15', ...LESSON },
      { start: '09:15', end: '09:25', ...BREAK },
      { start: '09:25', end: '10:10', ...LESSON },
    ];
    const shift = await sm.updateShift('shf-1', { weekdays: [5, 1, 3], periods });
    expect(shift).toMatchObject({ start: '08:30', end: '10:10', weekdays: [1, 3, 5] });
    expect(shift.periods.map((p) => p.no)).toEqual([1, 1, 2]);
    expect(lastAudit()?.action).toBe('shift.update');
  });

  it('istisno: sabab majburiy, muddat kelajakda va shu kun ichida', async () => {
    const studentId = studentOf('cls-9a');
    await expect(sm.createException({ studentId, until: '12:00', reason: '   ' })).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(sm.createException({ studentId, until: '09:00', reason: 'Sabab' })).rejects.toMatchObject({ message: expect.stringContaining(smMsg.untilPast) });
    await expect(sm.createException({ studentId, until: '2026-10-13T09:00:00', reason: 'Sabab' })).rejects.toMatchObject({ message: expect.stringContaining(smMsg.untilTooFar) });
  });

  it('bitta o\'quvchiga ikkita faol istisno berilmaydi; bekor qilish ishlaydi', async () => {
    const studentId = studentOf('cls-9a', 2);
    const created = await sm.createException({ studentId, until: '11:30', reason: 'Olimpiada' });
    await expect(sm.createException({ studentId, until: '12:00', reason: 'Yana' })).rejects.toMatchObject({ code: 'CONFLICT' });
    const revoked = await sm.revokeException(created.id);
    expect(revoked.revokedAt).not.toBeNull();
    expect(lastAudit()?.action).toBe('exception.revoke');
    await expect(sm.revokeException(created.id)).rejects.toMatchObject({ code: 'CONFLICT' });
    const list = await sm.exceptions({ status: 'REVOKED' });
    expect(list.items.some((e) => e.id === created.id)).toBe(true);
    expect(list.counts.REVOKED).toBeGreaterThanOrEqual(1);
  });

  it('siyosat: kamida bitta toifa cheklanadi; ilova nomi takrorlanmaydi', async () => {
    await expect(sm.updatePolicy({ blockedCategories: [] })).rejects.toMatchObject({ code: 'VALIDATION' });
    await sm.addAllowedApp({ name: 'Wikipedia', category: 'EDU' });
    await expect(sm.addAllowedApp({ name: 'wikipedia', category: 'EDU' })).rejects.toMatchObject({ code: 'CONFLICT' });
  });

  it('favqulodda o\'chirish uchun sabab majburiy', async () => {
    await expect(sm.activateEmergency({ scope: 'SCHOOL', reason: '' })).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(sm.activateEmergency({ scope: 'CLASS', classIds: [], reason: 'Sabab' })).rejects.toMatchObject({ code: 'VALIDATION' });
  });
});

describe('School Mode: holat va audit', () => {
  beforeEach(() => {
    freshDb();
    loginAs('DIRECTOR');
  });

  it('demo vaqtida 1-smena dars, 2-smena hali boshlanmagan', async () => {
    expect(stateOf('cls-9a')).toMatchObject({ kind: 'LESSON', periodNo: 3, restricted: true });
    expect(stateOf('cls-2a')).toMatchObject({ kind: 'BEFORE' });
    const overview = await sm.overview();
    expect(overview.totals.restrictedClasses).toBe(overview.classes.filter((c) => c.grade >= 5).length);
    expect(overview.shifts.find((s) => s.id === 'shf-1')?.phase).toMatchObject({ kind: 'LESSON', periodNo: 3 });
  });

  it('butun maktab bo\'yicha favqulodda o\'chirish → EMERGENCY_OFF, qayta yoqish → LESSON', async () => {
    await sm.activateEmergency({ scope: 'SCHOOL', reason: 'Yong\'in mashqi' });
    expect(lastAudit()?.action).toBe('emergency.on');
    expect(stateOf('cls-9a').kind).toBe('EMERGENCY_OFF');
    expect(stateOf('cls-2a').kind).toBe('EMERGENCY_OFF');
    expect((await sm.overview()).totals.restrictedClasses).toBe(0);
    await sm.deactivateEmergency();
    expect(lastAudit()?.action).toBe('emergency.off');
    expect(stateOf('cls-9a').kind).toBe('LESSON');
    await expect(sm.deactivateEmergency()).rejects.toMatchObject({ code: 'CONFLICT' });
  });

  it('sinf bo\'yicha favqulodda o\'chirish faqat tanlangan sinflarga ta\'sir qiladi va qo\'shiladi', async () => {
    await sm.activateEmergency({ scope: 'CLASS', classIds: ['cls-9a'], reason: 'Ekskursiya' });
    await sm.activateEmergency({ scope: 'CLASS', classIds: ['cls-10a'], reason: 'Ekskursiya' });
    expect(stateOf('cls-9a').kind).toBe('EMERGENCY_OFF');
    expect(stateOf('cls-10a').kind).toBe('EMERGENCY_OFF');
    expect(stateOf('cls-9b').kind).toBe('LESSON');
  });

  it('siyosat o\'chirilsa sinflar DISABLED; har o\'zgarish auditga yoziladi', async () => {
    const before = getTables().audit.length;
    await sm.updatePolicy({ enabled: false });
    expect(stateOf('cls-9a').kind).toBe('DISABLED');
    await sm.updatePolicy({ enabled: true, relaxDuringBreaks: true });
    const app = await sm.addAllowedApp({ name: 'GeoGebra', category: 'EDU' });
    const added = app.allowedApps.find((a) => a.name === 'GeoGebra');
    await sm.removeAllowedApp(added?.id ?? '');
    const actions = getTables().audit.slice(before).map((a) => a.action);
    expect(actions).toEqual(['policy.update', 'policy.update', 'policy.appAdd', 'policy.appRemove']);
    expect(getTables().audit.slice(before).every((a) => a.module === 'SCHOOL_MODE')).toBe(true);
  });
});

describe('School Mode: regressiyalar (kod tekshiruvi)', () => {
  beforeEach(() => {
    freshDb();
    loginAs('ADMIN');
  });

  const base = { studentId: 's', classId: 'c', reason: 'Sabab', byStaffId: 'stf-admin', revokedAt: null };
  const local = (h: number, m: number) => new Date(2026, 9, 12, h, m);

  function seedException(extra: Pick<SchoolModeException, 'id' | 'studentId' | 'classId' | 'from' | 'until'>): void {
    transact((t) => {
      t.exceptions = [...t.exceptions, { ...base, ...extra }];
    });
  }

  it('butun maktab bo\'yicha favqulodda o\'chirishni sinf so\'rovi toraytira olmaydi', async () => {
    await sm.activateEmergency({ scope: 'SCHOOL', reason: 'Evakuatsiya' });
    const audits = getTables().audit.length;
    await expect(sm.activateEmergency({ scope: 'CLASS', classIds: ['cls-9a'], reason: 'Ekskursiya' })).rejects.toMatchObject({
      code: 'CONFLICT',
      message: expect.stringContaining(smMsg.emergencySchoolActive),
    });
    expect(getTables().emergency).toMatchObject({ active: true, scope: 'SCHOOL', reason: 'Evakuatsiya' });
    expect(stateOf('cls-9b').kind).toBe('EMERGENCY_OFF');
    expect(getTables().audit.length).toBe(audits);
  });

  it('exceptionStatus `from`ni hisobga oladi va mahalliy/UTC vaqtni Date.parse bilan solishtiradi', () => {
    const now = local(10, 0).getTime();
    expect(exceptionStatus({ ...base, id: 'a', from: '2026-10-12T11:40:00', until: '2026-10-12T12:25:00' }, now)).toBe('SCHEDULED');
    expect(exceptionStatus({ ...base, id: 'b', from: local(9, 0).toISOString(), until: local(10, 30).toISOString() }, now)).toBe('ACTIVE');
    expect(exceptionStatus({ ...base, id: 'c', from: '2026-10-12T07:30:00', until: local(9, 59).toISOString() }, now)).toBe('EXPIRED');
    expect(exceptionStatus({ ...base, id: 'd', from: '2026-10-12T11:40:00', until: '2026-10-12T12:25:00', revokedAt: local(9, 0).toISOString() }, now)).toBe('REVOKED');
  });

  it('kelajakdagi istisno hozir faol emas: ro\'yxat, sinf soni va qurilma belgisi', async () => {
    const studentId = studentOf('cls-9a', 4);
    seedException({ id: 'exc-future', studentId, classId: 'cls-9a', from: '2026-10-12T11:40:00', until: '2026-10-12T12:25:00' });
    expect((await sm.exceptions({ status: 'ACTIVE' })).items.some((e) => e.id === 'exc-future')).toBe(false);
    const scheduled = await sm.exceptions({ status: 'SCHEDULED' });
    expect(scheduled.items.map((e) => e.id)).toContain('exc-future');
    expect(scheduled.counts.SCHEDULED).toBeGreaterThanOrEqual(1);
    expect((await sm.overview()).classes.find((c) => c.classId === 'cls-9a')?.activeExceptions).toBe(0);
    const device = (await sm.devices({ classId: 'cls-9a', limit: 500 })).items.find((d) => d.studentId === studentId);
    expect(device?.hasException).toBe(false);
  });

  it('rejalashtirilgan istisno bilan ustma-ust tushgan yangisi rad etiladi; oldingisi beriladi; bekor qilish mumkin', async () => {
    const studentId = studentOf('cls-9a', 5);
    seedException({ id: 'exc-later', studentId, classId: 'cls-9a', from: '2026-10-12T11:40:00', until: '2026-10-12T12:25:00' });
    await expect(sm.createException({ studentId, until: '12:00', reason: 'Ustma-ust' })).rejects.toMatchObject({ code: 'CONFLICT' });
    const before = await sm.createException({ studentId, until: '11:00', reason: 'Oldin' });
    expect(exceptionStatus(before, local(10, 0).getTime())).toBe('ACTIVE');
    const revoked = await sm.revokeException('exc-later');
    expect(revoked.revokedAt).not.toBeNull();
  });
});
