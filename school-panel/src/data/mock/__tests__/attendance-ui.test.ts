import { beforeEach, describe, expect, it } from 'vitest';

import { getTables, transact } from '../db';
import { attendanceService } from '../services/attendance';
import { simulate } from '../simulator';
import { freshDb, loginAs } from './helpers';

const TODAY = '2026-10-12';

/** 10:00 gacha simulyatsiya (1-smena kelgan, 2-smena hali yo'q). */
function morning(): void {
  transact((t) => simulate(t, TODAY, 10 * 60));
}

function secondShiftStudent() {
  const student = getTables().students.find((s) => s.classId === 'cls-3a' && !s.archived);
  if (!student) throw new Error('seed: cls-3a');
  return student;
}

describe('davomat UI: taxta va sinf', () => {
  beforeEach(freshDb);

  it('taxta qatorlarida smena ID bor, sinf variantlari doiraga mos', async () => {
    loginAs('ADMIN');
    morning();
    const board = await attendanceService.board();
    expect(board.rows.length).toBeGreaterThan(10);
    expect(board.rows.every((r) => r.shiftId.length > 0)).toBe(true);
    const all = await attendanceService.classOptions();
    expect(all).toHaveLength(board.rows.length);

    loginAs('HOMEROOM');
    const own = await attendanceService.classOptions();
    expect(own.map((c) => c.id)).toEqual(['cls-7a']);
  });

  it('navbatchi o\'tgan kunni ko\'ra olmaydi', async () => {
    loginAs('DUTY');
    await expect(attendanceService.board('2026-10-09')).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(attendanceService.board()).resolves.toMatchObject({ date: TODAY });
  });

  it('sinf kuni: dars kuni belgisi va smena nomi qaytadi', async () => {
    loginAs('ADMIN');
    const day = await attendanceService.classDay('cls-7a');
    expect(day.schoolDay).toBe(true);
    expect(day.shiftName).not.toBe('');
    const sunday = await attendanceService.classDay('cls-7a', '2026-10-11');
    expect(sunday.schoolDay).toBe(false);
    expect(sunday.rows.every((r) => r.record === null)).toBe(true);
  });

  it('qo\'lda belgilash: yangi — sababsiz, o\'zgartirish — faqat sabab bilan', async () => {
    loginAs('ADMIN');
    const student = secondShiftStudent();
    const created = await attendanceService.mark(student.id, 'PRESENT');
    expect(created.source).toBe('MANUAL');
    await expect(attendanceService.mark(student.id, 'ABSENT')).rejects.toMatchObject({ code: 'VALIDATION' });
    const changed = await attendanceService.mark(student.id, 'EXCUSED', 'Ota-onasi qo\'ng\'iroq qildi');
    expect(changed.status).toBe('EXCUSED');
    expect(changed.corrections).toHaveLength(1);
    const corrections = await attendanceService.corrections();
    expect(corrections[0]?.correction.reason).toBe('Ota-onasi qo\'ng\'iroq qildi');
  });
});

describe('davomat UI: jonli oqim', () => {
  beforeEach(freshDb);

  it('kiosk kirishi oqimda birinchi (vaqt bo\'yicha saralash)', async () => {
    morning();
    loginAs('DUTY');
    const student = secondShiftStudent();
    await attendanceService.checkIn(student.studentCode);
    const feed = await attendanceService.feed({ limit: 5 });
    expect(feed[0]?.studentId).toBe(student.id);
    expect(feed[0]?.source).toBe('KIOSK');
  });

  it('oqim IN/OUT bo\'yicha filtrlanadi', async () => {
    loginAs('ADMIN');
    morning();
    transact((t) => simulate(t, TODAY, 18 * 60));
    const outs = await attendanceService.feed({ kind: 'OUT', limit: 500 });
    expect(outs.length).toBeGreaterThan(0);
    expect(outs.every((e) => e.kind === 'OUT')).toBe(true);
    const ins = await attendanceService.feed({ kind: 'IN', classId: 'cls-7a', limit: 500 });
    expect(ins.every((e) => e.kind === 'IN' && e.classId === 'cls-7a')).toBe(true);
  });

  it('ota-onaga xabarlar eng yangisi birinchi', async () => {
    morning();
    loginAs('ADMIN');
    const list = await attendanceService.notifications(50);
    const times = list.map((n) => Date.parse(n.at));
    expect(times).toEqual([...times].sort((a, b) => b - a));
  });
});

describe('davomat UI: kiosk hisoblagichlari', () => {
  beforeEach(freshDb);

  it('keldi / kechikdi soni va oxirgi kirishlar', async () => {
    morning();
    loginAs('DUTY');
    const before = await attendanceService.kioskStats();
    expect(before.expected).toBeGreaterThan(before.arrived);
    expect(before.arrived).toBeGreaterThan(200);
    expect(before.late).toBeGreaterThan(0);
    const student = secondShiftStudent();
    await attendanceService.checkIn(student.studentCode);
    const after = await attendanceService.kioskStats();
    expect(after.arrived).toBe(before.arrived + 1);
    expect(after.recent[0]?.studentId).toBe(student.id);
  });

  it('kiosk ruxsati bo\'lmasa rad etiladi', async () => {
    loginAs('DIRECTOR');
    await expect(attendanceService.kioskStats()).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(attendanceService.checkIn('P-0000')).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('noma\'lum kod — NOT_FOUND', async () => {
    loginAs('DUTY');
    await expect(attendanceService.checkIn('P-0000')).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });
});

describe('davomat UI: erta ketish va hisobot', () => {
  beforeEach(freshDb);

  it('erta ketish tasdiqlansa o\'quvchi "erta ketdi" bo\'ladi', async () => {
    morning();
    loginAs('HOMEROOM');
    const student = getTables().students.find((s) => s.classId === 'cls-7a' && getTables().attendance.some((r) => r.studentId === s.id && r.inAt));
    expect(student).toBeDefined();
    const request = await attendanceService.createEarlyExit({ studentId: student!.id, time: '11:30', reason: 'Shifokor qabuli', pickupBy: 'Onasi' });
    expect(request.status).toBe('PENDING');
    await attendanceService.decideEarlyExit(request.id, true);
    const day = await attendanceService.classDay('cls-7a');
    expect(day.rows.find((r) => r.studentId === student!.id)?.record?.status).toBe('LEFT_EARLY');
    await expect(attendanceService.decideEarlyExit(request.id, false)).rejects.toMatchObject({ code: 'CONFLICT' });
  });

  it('oylik hisobot: sinf rahbari faqat o\'z sinfi', async () => {
    loginAs('HOMEROOM');
    const report = await attendanceService.monthReport('2026-10', 'cls-7a');
    expect(report.days.length).toBeGreaterThan(5);
    expect(report.rows[0]?.cells).toHaveLength(report.days.length);
    await expect(attendanceService.monthReport('2026-10', 'cls-8b')).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});

/** Mahalliy vaqt satri (seed/simulyator formati, "Z"siz). */
function localStamp(date: string, hhmm: string): string {
  return `${date}T${hhmm}:00`;
}

/** UTC satri (kiosk/xodim yozuvlari formati). */
function utcStamp(date: string, hhmm: string): string {
  const [y, m, d] = date.split('-').map(Number);
  const [h, min] = hhmm.split(':').map(Number);
  return new Date(y ?? 2026, (m ?? 1) - 1, d ?? 1, h ?? 0, min ?? 0).toISOString();
}

function addEarlyExit(id: string, date: string, requestedAt: string): void {
  const student = getTables().students.find((s) => s.classId === 'cls-7a');
  if (!student) throw new Error('seed: cls-7a');
  transact((t) => {
    t.earlyExits.push({
      id,
      studentId: student.id,
      classId: student.classId,
      date,
      time: '12:00',
      reason: 'Test',
      pickupBy: 'Onasi',
      status: 'APPROVED',
      requestedAt,
      decidedByStaffId: null,
      decidedAt: null,
    });
  });
}

describe('ruxsatlar: navbatchi (review #1, #2)', () => {
  beforeEach(freshDb);

  it('navbatchi kutilayotganni belgilaydi, lekin mavjud holatni o\'zgartira olmaydi', async () => {
    loginAs('DUTY');
    const student = secondShiftStudent();
    await expect(attendanceService.mark(student.id, 'PRESENT')).resolves.toMatchObject({ status: 'PRESENT' });
    await expect(attendanceService.mark(student.id, 'ABSENT', 'Xato belgilandi')).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(attendanceService.mark(student.id, 'PRESENT')).resolves.toMatchObject({ status: 'PRESENT' });
  });

  it('navbatchi tarixni o\'qiy olmaydi: studentMonth va trend', async () => {
    loginAs('DUTY');
    const student = secondShiftStudent();
    await expect(attendanceService.studentMonth(student.id, '2026-09')).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(attendanceService.trend(60)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('ADMIN');
    await expect(attendanceService.studentMonth(student.id, '2026-09')).resolves.toBeInstanceOf(Array);
    await expect(attendanceService.trend(14)).resolves.toBeInstanceOf(Array);
  });

  it('navbatchi erta ketishlarning faqat bugungisini ko\'radi', async () => {
    addEarlyExit('exit-old', '2026-10-09', localStamp('2026-10-09', '08:00'));
    addEarlyExit('exit-today', TODAY, localStamp(TODAY, '08:00'));
    loginAs('DUTY');
    const duty = await attendanceService.earlyExits();
    expect(duty.some((e) => e.id === 'exit-today')).toBe(true);
    expect(duty.every((e) => e.date === TODAY)).toBe(true);
    loginAs('ADMIN');
    const admin = await attendanceService.earlyExits();
    expect(admin.some((e) => e.id === 'exit-old')).toBe(true);
  });

  it('navbatchi ota-onaga xabarlarning faqat bugungisini ko\'radi', async () => {
    const student = secondShiftStudent();
    transact((t) => {
      t.parentNotifications.push(
        { id: 'ntf-old', at: localStamp('2026-10-09', '08:00'), studentId: student.id, guardianId: student.guardianIds[0] ?? 'g', kind: 'ARRIVED', delivered: true },
        { id: 'ntf-today', at: utcStamp(TODAY, '08:00'), studentId: student.id, guardianId: student.guardianIds[0] ?? 'g', kind: 'ARRIVED', delivered: true },
      );
    });
    loginAs('DUTY');
    const duty = await attendanceService.notifications(500);
    expect(duty.map((n) => n.id)).toContain('ntf-today');
    expect(duty.map((n) => n.id)).not.toContain('ntf-old');
    loginAs('ADMIN');
    expect((await attendanceService.notifications(500)).map((n) => n.id)).toContain('ntf-old');
  });
});

describe('vaqt belgilari: aralash format (review #3)', () => {
  beforeEach(freshDb);

  it('erta ketishlar mahalliy va UTC vaqt bo\'yicha to\'g\'ri tartiblanadi', async () => {
    addEarlyExit('exit-local-0900', TODAY, localStamp(TODAY, '09:00'));
    addEarlyExit('exit-utc-1030', TODAY, utcStamp(TODAY, '10:30'));
    loginAs('ADMIN');
    const list = (await attendanceService.earlyExits()).filter((e) => e.id.startsWith('exit-local') || e.id.startsWith('exit-utc'));
    expect(list.map((e) => e.id)).toEqual(['exit-utc-1030', 'exit-local-0900']);
  });

  it('tuzatishlar mahalliy va UTC vaqt bo\'yicha to\'g\'ri tartiblanadi', async () => {
    loginAs('ADMIN');
    const [a, b] = getTables().students.filter((s) => s.classId === 'cls-7a');
    if (!a || !b) throw new Error('seed');
    transact((t) => {
      const base = { date: '2026-10-09', classId: 'cls-7a', status: 'EXCUSED' as const, inAt: null, outAt: null, source: 'MANUAL' as const, parentNotified: false };
      t.attendance.push(
        { ...base, id: `2026-10-09:${a.id}`, studentId: a.id, corrections: [{ at: localStamp(TODAY, '09:00'), byStaffId: 'x', from: 'ABSENT', to: 'EXCUSED', reason: 'local' }] },
        { ...base, id: `2026-10-09:${b.id}`, studentId: b.id, corrections: [{ at: utcStamp(TODAY, '10:30'), byStaffId: 'x', from: 'ABSENT', to: 'EXCUSED', reason: 'utc' }] },
      );
    });
    const list = (await attendanceService.corrections()).filter((c) => c.correction.reason === 'local' || c.correction.reason === 'utc');
    expect(list.map((c) => c.correction.reason)).toEqual(['utc', 'local']);
  });
});
