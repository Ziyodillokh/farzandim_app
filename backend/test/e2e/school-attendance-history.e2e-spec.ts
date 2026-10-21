// Maktab paneli S3 — erta ketish (xodim + Parvoz Parents), ota-onaga xabarlar
// jurnali, oylik hisobot, trend, o'quvchi oyi va ota-onaning davomat ko'rinishi.

import type { AttendanceStatus } from '@prisma/client';
import { resetDb } from './db';
import { at, consumerCall, DAY, seedWorld, setNow, staffCall, World } from './school-attendance-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School attendance (S3): erta ketish va hisobotlar', () => {
  let t: TestApp;
  let w: World;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    w = await seedWorld(t);
    setNow(t, at(DAY, '09:00'));
  });

  afterAll(() => t.close());

  const exitInput = (studentId: string) => ({ studentId, time: '11:30', reason: 'Shifokor qabuli', pickupBy: 'Onasi' });
  const put = (studentId: string, date: string, status: AttendanceStatus, classId = w.classA) =>
    t.prisma.schoolAttendance.create({ data: { schoolId: w.schoolId, studentId, classId, date, status, source: 'MANUAL' } });

  it('xodim: yaratish, tasdiqlash — "erta ketdi", ota-onaga push, takroriy qaror CONFLICT', async () => {
    await staffCall(t, w.homeroom, 'POST', '/mark', { studentId: w.vali, status: 'PRESENT' });
    t.fcm.reset();
    const created = await staffCall(t, w.homeroom, 'POST', '/early-exits', exitInput(w.vali));
    expect(created.statusCode).toBe(201);
    expect(created.json()).toMatchObject({ status: 'PENDING', date: DAY, time: '11:30', classId: w.classA, decidedAt: null });
    const id = created.json().id;
    const log = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'earlyExit.create' } });
    expect(log.params).toEqual({ name: 'Aliyev Vali', time: '11:30' });

    const approved = (await staffCall(t, w.homeroom, 'POST', `/early-exits/${id}/decision`, { approve: true })).json();
    expect(approved).toMatchObject({ status: 'APPROVED', decidedByStaffId: w.homeroom.staffId });
    const day = (await staffCall(t, w.homeroom, 'GET', `/classes/${w.classA}`)).json();
    const record = day.rows.find((r: { studentId: string }) => r.studentId === w.vali).record;
    expect(record).toMatchObject({ status: 'LEFT_EARLY', outAt: '11:30' });
    expect(record.corrections[0]).toMatchObject({ from: 'PRESENT', to: 'LEFT_EARLY', reason: 'Erta ketish tasdiqlandi: Shifokor qabuli' });
    expect(t.fcm.pushesTo(w.parent.userId)).toEqual([
      expect.objectContaining({ title: 'Erta ketish tasdiqlandi', data: expect.objectContaining({ type: 'school_early_exit', status: 'APPROVED' }) }),
    ]);
    expect(await t.prisma.schoolParentNotice.count({ where: { studentId: w.vali, kind: 'EARLY_EXIT' } })).toBe(1);
    const again = await staffCall(t, w.homeroom, 'POST', `/early-exits/${id}/decision`, { approve: false });
    expect(again.json()).toMatchObject({ code: 'CONFLICT', message: 'APPROVED' });

    const list = (await staffCall(t, w.admin, 'GET', '/early-exits?status=APPROVED')).json();
    expect(list).toEqual([expect.objectContaining({ id, studentName: 'Aliyev Vali', className: '7-A', decidedByName: 'HOMEROOM xodim' })]);
    expect((await staffCall(t, w.admin, 'GET', '/early-exits?status=PENDING')).json()).toEqual([]);
  });

  it('rad etish: yozuv o\'zgarmaydi, ota-onaga "rad etildi"; ruxsat va doira', async () => {
    const id = (await staffCall(t, w.admin, 'POST', '/early-exits', exitInput(w.vali))).json().id;
    const bekExit = (await staffCall(t, w.admin, 'POST', '/early-exits', exitInput(w.bek))).json().id;
    expect((await staffCall(t, w.homeroom, 'POST', `/early-exits/${bekExit}/decision`, { approve: true })).statusCode).toBe(403);
    expect((await staffCall(t, w.teacher, 'POST', '/early-exits', exitInput(w.bek))).statusCode).toBe(403);
    expect((await staffCall(t, w.homeroom, 'POST', '/early-exits', exitInput(w.bek))).statusCode).toBe(403);
    const bad = await staffCall(t, w.admin, 'POST', '/early-exits', { ...exitInput(w.vali), time: '25:00' });
    expect(bad.json()).toMatchObject({ code: 'VALIDATION', message: 'time: errors.form.invalidTime' });
    expect((await staffCall(t, w.admin, 'POST', `/early-exits/${id}/decision`, {})).json()).toMatchObject({ code: 'VALIDATION' });

    const rejected = (await staffCall(t, w.admin, 'POST', `/early-exits/${id}/decision`, { approve: false })).json();
    expect(rejected.status).toBe('REJECTED');
    expect(t.fcm.pushesTo(w.parent.userId)).toEqual([expect.objectContaining({ title: 'Erta ketish rad etildi' })]);
    expect(await t.prisma.schoolParentNotice.count()).toBe(0);
    expect(await t.prisma.schoolAuditLog.count({ where: { action: 'earlyExit.reject' } })).toBe(1);
    expect((await staffCall(t, w.admin, 'POST', '/early-exits/nope/decision', { approve: true })).statusCode).toBe(404);
  });

  it('navbatchi faqat bugungi erta ketishlarni ko\'radi; sinf rahbari — o\'z sinfi', async () => {
    await t.prisma.schoolEarlyExit.create({
      data: { schoolId: w.schoolId, studentId: w.vali, classId: w.classA, date: '2026-10-19', time: '12:00', reason: 'x', pickupBy: 'y', status: 'APPROVED' },
    });
    await staffCall(t, w.admin, 'POST', '/early-exits', exitInput(w.bek));
    const duty = (await staffCall(t, w.duty, 'GET', '/early-exits')).json();
    expect(duty.map((e: { date: string }) => e.date)).toEqual([DAY]);
    expect((await staffCall(t, w.admin, 'GET', '/early-exits')).json()).toHaveLength(2);
    const own = (await staffCall(t, w.homeroom, 'GET', '/early-exits')).json();
    expect(own.map((e: { studentId: string }) => e.studentId)).toEqual([w.vali]);
  });

  it('Parvoz Parents: faqat o\'z farzandi uchun so\'rov, takroriy kutilayotgan — CONFLICT, qaror push\'i', async () => {
    const res = await consumerCall(t, w.parent.token, 'POST', '/parent/school/early-exits', exitInput(w.vali));
    expect(res.statusCode).toBe(201);
    expect(res.json()).toMatchObject({ status: 'PENDING', studentName: 'Aliyev Vali', className: '7-A', requestedByMe: true });
    const dup = await consumerCall(t, w.parent.token, 'POST', '/parent/school/early-exits', exitInput(w.vali));
    expect(dup.json()).toMatchObject({ code: 'CONFLICT' });
    expect((await consumerCall(t, w.parent.token, 'POST', '/parent/school/early-exits', exitInput(w.malika))).statusCode).toBe(404);
    expect((await consumerCall(t, w.child.token, 'POST', '/parent/school/early-exits', exitInput(w.vali))).statusCode).toBe(403);
    const audit = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'earlyExit.create' } });
    expect(audit).toMatchObject({ actorId: null, actorName: 'Aliyeva Nodira', entityId: res.json().id });

    const staffList = (await staffCall(t, w.admin, 'GET', '/early-exits?status=PENDING')).json();
    expect(staffList[0].id).toBe(res.json().id);
    await staffCall(t, w.admin, 'POST', `/early-exits/${res.json().id}/decision`, { approve: true });
    expect(t.fcm.pushesTo(w.parent.userId).map((p) => p.data?.status)).toEqual(['APPROVED']);
    const mine = (await consumerCall(t, w.parent.token, 'GET', '/parent/school/early-exits')).json();
    expect(mine).toEqual([expect.objectContaining({ id: res.json().id, status: 'APPROVED', requestedByMe: true })]);
  });

  it('Parvoz Parents: farzandning oylik davomati; boshqa o\'quvchi — 404', async () => {
    await put(w.vali, '2026-10-19', 'PRESENT');
    await put(w.vali, '2026-10-16', 'ABSENT');
    const res = await consumerCall(t, w.parent.token, 'GET', `/parent/school/attendance?studentId=${w.vali}&month=2026-10`);
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.student).toEqual({ id: w.vali, name: 'Aliyev Vali', className: '7-A', schoolName: 'Test maktab' });
    expect(body.days).toHaveLength(31);
    expect(body.days.find((d: { date: string }) => d.date === '2026-10-18').schoolDay).toBe(false);
    expect(body.days.find((d: { date: string }) => d.date === '2026-10-19').record).toMatchObject({ status: 'PRESENT' });
    expect(body.summary).toMatchObject({ present: 1, absent: 1 });
    expect(body.rate).toBe(50);
    expect((await consumerCall(t, w.parent.token, 'GET', `/parent/school/attendance?studentId=${w.malika}`)).statusCode).toBe(404);
    const bad = await consumerCall(t, w.parent.token, 'GET', `/parent/school/attendance?studentId=${w.vali}&month=2026-13`);
    expect(bad.json()).toMatchObject({ code: 'VALIDATION', message: 'month: errors.form.invalidDate' });
  });

  it('ota-onaga xabarlar jurnali: eng yangisi birinchi, navbatchi — bugun, doira', async () => {
    await t.prisma.schoolParentNotice.create({
      data: { schoolId: w.schoolId, studentId: w.vali, guardianId: w.guardianId, date: '2026-10-19', kind: 'ARRIVED', at: at('2026-10-19', '08:00') },
    });
    await staffCall(t, w.admin, 'POST', '/mark', { studentId: w.vali, status: 'PRESENT' });
    const list = (await staffCall(t, w.admin, 'GET', '/notifications?limit=10')).json();
    // `at` — bazadagi haqiqiy vaqt (davomat soati emas): sanani qotirmay, tartibni tekshiramiz.
    expect(list).toHaveLength(2);
    expect(list[1].at.slice(0, 10)).toBe('2026-10-19');
    expect(Date.parse(list[0].at)).toBeGreaterThan(Date.parse(list[1].at));
    expect(list[0]).toMatchObject({ studentName: 'Aliyev Vali', className: '7-A', guardianName: 'Aliyeva Nodira', kind: 'ARRIVED', delivered: true });
    expect((await staffCall(t, w.duty, 'GET', '/notifications')).json()).toHaveLength(1);
    expect((await staffCall(t, w.teacher, 'GET', '/notifications')).json()).toEqual([]);
    expect((await staffCall(t, w.psych, 'GET', '/notifications')).statusCode).toBe(403);
  });

  it('oylik hisobot, trend va o\'quvchi oyi: faqat haqiqiy yozuvlar; ruxsat va doira', async () => {
    await put(w.vali, '2026-10-19', 'PRESENT');
    await put(w.malika, '2026-10-19', 'LATE');
    await put(w.vali, '2026-10-18', 'PRESENT');
    const report = (await staffCall(t, w.homeroom, 'GET', `/month-report?month=2026-10&classId=${w.classA}`)).json();
    expect(report.className).toBe('7-A');
    expect(report.days[0]).toBe('2026-10-01');
    expect(report.days).not.toContain('2026-10-18');
    expect(report.days.at(-1)).toBe(DAY);
    expect(report.rows.map((r: { name: string }) => r.name)).toEqual(['Aliyev Vali', 'Karimova Malika']);
    const vali = report.rows[0];
    expect(vali.cells).toHaveLength(report.days.length);
    expect(vali.cells[report.days.indexOf('2026-10-19')]).toBe('PRESENT');
    expect(vali.summary).toMatchObject({ present: 1, pending: report.days.length - 1 });
    expect(vali.rate).toBe(100);
    expect((await staffCall(t, w.homeroom, 'GET', `/month-report?month=2026-10&classId=${w.classB}`)).statusCode).toBe(403);
    expect((await staffCall(t, w.duty, 'GET', `/month-report?month=2026-10&classId=${w.classA}`)).statusCode).toBe(403);
    expect((await staffCall(t, w.admin, 'GET', '/month-report?month=2026-10')).json()).toMatchObject({ code: 'VALIDATION' });

    const trend = (await staffCall(t, w.admin, 'GET', '/trend?daysBack=3')).json();
    expect(trend).toEqual([
      { date: '2026-10-18', rate: 100, late: 0 },
      { date: '2026-10-19', rate: 100, late: 1 },
    ]);
    expect((await staffCall(t, w.duty, 'GET', '/trend')).statusCode).toBe(403);

    const month = (await staffCall(t, w.admin, 'GET', `/students/${w.vali}/month?month=2026-10`)).json();
    expect(month).toHaveLength(31);
    expect(month.find((d: { date: string }) => d.date === '2026-10-19').record).toMatchObject({ status: 'PRESENT' });
    expect(month.find((d: { date: string }) => d.date === '2026-10-18').record).toBeNull();
    expect((await staffCall(t, w.duty, 'GET', `/students/${w.vali}/month?month=2026-10`)).statusCode).toBe(403);
    expect((await staffCall(t, w.homeroom, 'GET', `/students/${w.bek}/month?month=2026-10`)).statusCode).toBe(403);
    const other = await seedWorld(t, 'other-school');
    expect((await staffCall(t, w.admin, 'GET', `/students/${other.vali}/month?month=2026-10`)).statusCode).toBe(404);
    expect((await staffCall(t, w.admin, 'POST', '/early-exits', exitInput(other.vali))).statusCode).toBe(404);
    const otherExit = (await staffCall(t, other.admin, 'POST', '/early-exits', exitInput(other.vali))).json().id;
    expect((await staffCall(t, w.admin, 'POST', `/early-exits/${otherExit}/decision`, { approve: true })).statusCode).toBe(404);
    expect((await staffCall(t, w.admin, 'GET', `/month-report?month=2026-10&classId=${other.classA}`)).statusCode).toBe(404);
  });
});
