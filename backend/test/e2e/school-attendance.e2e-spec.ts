// Maktab paneli S3 — davomat: taxta, sinf kuni, jonli oqim, qo'lda belgilash,
// tuzatishlar; ruxsatlar, sinf doirasi, tenant izolyatsiyasi, audit, push.

import { resetDb } from './db';
import { at, DAY, seedWorld, setNow, staffCall, World } from './school-attendance-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School attendance (S3): taxta va belgilash', () => {
  let t: TestApp;
  let w: World;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    w = await seedWorld(t);
    setNow(t, at(DAY, '08:05'));
  });

  afterAll(() => t.close());

  const auditActions = async () =>
    (await t.prisma.schoolAuditLog.findMany({ where: { module: 'ATTENDANCE' }, orderBy: { at: 'asc' } })).map((a) => a.action);

  it('taxta: sinflar, hisoblagichlar va doira (sinf rahbari faqat o\'z sinfi)', async () => {
    const empty = (await staffCall(t, w.admin, 'GET', '/board')).json();
    expect(empty.date).toBe(DAY);
    expect(empty.rows.map((r: { className: string }) => r.className)).toEqual(['7-A', '8-B']);
    expect(empty.totals).toMatchObject({ pending: 3, total: 3 });
    expect(empty.rows[0]).toMatchObject({ shiftId: w.shiftId, schoolDay: true, rate: 0 });

    await staffCall(t, w.admin, 'POST', '/mark', { studentId: w.vali, status: 'PRESENT' });
    await staffCall(t, w.admin, 'POST', '/mark', { studentId: w.malika, status: 'ABSENT' });
    const board = (await staffCall(t, w.admin, 'GET', '/board')).json();
    expect(board.rows[0].counts).toMatchObject({ present: 1, absent: 1, pending: 0, total: 2 });
    expect(board.rows[0].rate).toBe(50);

    const own = (await staffCall(t, w.homeroom, 'GET', '/board')).json();
    expect(own.rows.map((r: { classId: string }) => r.classId)).toEqual([w.classA]);
    expect((await staffCall(t, w.psych, 'GET', '/board')).statusCode).toBe(403);
  });

  it('navbatchi o\'tgan kunni ko\'ra olmaydi; dam olish kuni — hisoblanmaydi', async () => {
    expect((await staffCall(t, w.duty, 'GET', '/board?date=2026-10-19')).json()).toMatchObject({ code: 'FORBIDDEN' });
    expect((await staffCall(t, w.duty, 'GET', '/board')).statusCode).toBe(200);
    const sunday = (await staffCall(t, w.admin, 'GET', '/board?date=2026-10-18')).json();
    expect(sunday.rows.every((r: { schoolDay: boolean }) => !r.schoolDay)).toBe(true);
    expect(sunday.totals.total).toBe(0);
    for (const date of ['2026-02-30', '2026-13-45', '20261020']) {
      const bad = await staffCall(t, w.admin, 'GET', `/board?date=${date}`);
      expect(bad.json()).toMatchObject({ code: 'VALIDATION', message: 'date: errors.form.invalidDate' });
    }
  });

  it('sinf kuni: ism tartibi, dam olish kuni, sinf kartochkasi (today), doira va 404', async () => {
    const day = (await staffCall(t, w.homeroom, 'GET', `/classes/${w.classA}`)).json();
    expect(day).toMatchObject({ date: DAY, className: '7-A', shiftName: '1-smena', schoolDay: true });
    expect(day.rows.map((r: { name: string }) => r.name)).toEqual(['Aliyev Vali', 'Karimova Malika']);
    expect(day.rows[0]).toMatchObject({ studentCode: expect.stringMatching(/^P-/), device: 'IOS', record: null });

    const today = (await staffCall(t, w.teacher, 'GET', `/classes/${w.classB}/today`)).json();
    expect(today.rows).toHaveLength(1);
    const sunday = (await staffCall(t, w.admin, 'GET', `/classes/${w.classA}?date=2026-10-18`)).json();
    expect(sunday.schoolDay).toBe(false);
    expect((await staffCall(t, w.homeroom, 'GET', `/classes/${w.classB}`)).statusCode).toBe(403);
    expect((await staffCall(t, w.admin, 'GET', '/classes/nope')).statusCode).toBe(404);
  });

  it('qo\'lda belgilash: yangi — sababsiz, o\'zgartirish — faqat sabab bilan; audit va oqim', async () => {
    const created = await staffCall(t, w.admin, 'POST', '/mark', { studentId: w.vali, status: 'PRESENT' });
    expect(created.statusCode).toBe(200);
    expect(created.json()).toMatchObject({ status: 'PRESENT', source: 'MANUAL', inAt: '08:05', date: DAY, corrections: [] });

    const noReason = await staffCall(t, w.admin, 'POST', '/mark', { studentId: w.vali, status: 'ABSENT' });
    expect(noReason.json()).toMatchObject({ code: 'VALIDATION', message: 'reason: errors.form.required' });

    const same = await staffCall(t, w.admin, 'POST', '/mark', { studentId: w.vali, status: 'PRESENT' });
    expect(same.json().id).toBe(created.json().id);

    const changed = (
      await staffCall(t, w.admin, 'POST', '/mark', { studentId: w.vali, status: 'EXCUSED', reason: 'Ota-onasi qo\'ng\'iroq qildi' })
    ).json();
    expect(changed.status).toBe('EXCUSED');
    expect(changed.corrections).toEqual([
      expect.objectContaining({ from: 'PRESENT', to: 'EXCUSED', reason: 'Ota-onasi qo\'ng\'iroq qildi' }),
    ]);
    expect(await auditActions()).toEqual(['attendance.mark', 'attendance.correct']);
    const log = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'attendance.correct' } });
    expect(log.params).toEqual({ name: 'Aliyev Vali', date: DAY, from: 'PRESENT', to: 'EXCUSED' });

    const feed = (await staffCall(t, w.admin, 'GET', '/feed?limit=5')).json();
    expect(feed).toEqual([expect.objectContaining({ studentId: w.vali, kind: 'IN', source: 'MANUAL', studentName: 'Aliyev Vali', className: '7-A' })]);
  });

  it('navbatchi kutilayotganni belgilaydi, lekin o\'zgartira olmaydi; o\'qituvchi belgilay olmaydi', async () => {
    await expect(staffCall(t, w.duty, 'POST', '/mark', { studentId: w.bek, status: 'PRESENT' })).resolves.toMatchObject({ statusCode: 200 });
    const change = await staffCall(t, w.duty, 'POST', '/mark', { studentId: w.bek, status: 'ABSENT', reason: 'Xato' });
    expect(change.json()).toMatchObject({ code: 'FORBIDDEN' });
    expect((await staffCall(t, w.teacher, 'POST', '/mark', { studentId: w.bek, status: 'PRESENT' })).statusCode).toBe(403);
    expect((await staffCall(t, w.homeroom, 'POST', '/mark', { studentId: w.bek, status: 'PRESENT' })).statusCode).toBe(403);
    const bad = await staffCall(t, w.admin, 'POST', '/mark', { studentId: w.bek, status: 'HERE' });
    expect(bad.json()).toMatchObject({ code: 'VALIDATION', message: 'status: errors.form.required' });
  });

  it('ota-onaga push: belgilash va bugungi tuzatish — tur bo\'yicha bir marta', async () => {
    await staffCall(t, w.admin, 'POST', '/mark', { studentId: w.vali, status: 'LATE' });
    await staffCall(t, w.admin, 'POST', '/mark', { studentId: w.vali, status: 'PRESENT', reason: 'Xato' });
    const pushes = t.fcm.pushesTo(w.parent.userId);
    expect(pushes).toHaveLength(1);
    expect(pushes[0]).toMatchObject({ title: 'Kechikib keldi', data: { type: 'school_attendance', kind: 'ARRIVED' } });
    expect(pushes[0]?.body).toContain('Vali');

    await staffCall(t, w.admin, 'POST', '/mark', { studentId: w.vali, status: 'ABSENT', reason: 'Xato belgilangan' });
    expect(t.fcm.pushesTo(w.parent.userId).map((p) => p.data?.kind)).toEqual(['ARRIVED', 'ABSENT']);
    const notices = await t.prisma.schoolParentNotice.findMany({ where: { studentId: w.vali } });
    expect(notices.map((n) => n.kind).sort()).toEqual(['ABSENT', 'ARRIVED']);
    expect(notices.every((n) => n.delivered && n.guardianId === w.guardianId)).toBe(true);
    // Ota-onasi ilovada yo'q o'quvchi — push ham, xabar yozuvi ham yo'q.
    const malika = (await staffCall(t, w.admin, 'POST', '/mark', { studentId: w.malika, status: 'PRESENT' })).json();
    expect(malika.parentNotified).toBe(false);
    expect(await t.prisma.schoolParentNotice.count({ where: { studentId: w.malika } })).toBe(0);
  });

  it('tuzatish: kelajak / sababsiz / dam olish kuni — VALIDATION; yozuvsiz o\'tgan kun tiklanadi', async () => {
    const future = await staffCall(t, w.admin, 'POST', '/corrections', { studentId: w.vali, date: '2026-10-21', status: 'EXCUSED', reason: 'x' });
    expect(future.json()).toMatchObject({ code: 'VALIDATION', message: 'date: errors.form.invalidDate' });
    const noReason = await staffCall(t, w.admin, 'POST', '/corrections', { studentId: w.vali, date: '2026-10-19', status: 'EXCUSED', reason: ' ' });
    expect(noReason.json()).toMatchObject({ code: 'VALIDATION', message: 'reason: errors.form.required' });
    const sunday = await staffCall(t, w.admin, 'POST', '/corrections', { studentId: w.vali, date: '2026-10-18', status: 'EXCUSED', reason: 'x' });
    expect(sunday.json()).toMatchObject({ code: 'VALIDATION', message: 'date: errors.form.invalidDate' });

    const res = await staffCall(t, w.admin, 'POST', '/corrections', {
      studentId: w.vali, date: '2026-10-19', status: 'EXCUSED', reason: 'Shifokor ma\'lumotnomasi',
    });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({ date: '2026-10-19', status: 'EXCUSED', source: 'SYSTEM' });
    expect(res.json().corrections).toEqual([expect.objectContaining({ from: 'ABSENT', to: 'EXCUSED' })]);
    expect(t.fcm.pushesTo(w.parent.userId)).toHaveLength(0);

    const list = (await staffCall(t, w.admin, 'GET', '/corrections')).json();
    expect(list[0]).toMatchObject({ studentName: 'Aliyev Vali', className: '7-A', byName: 'ADMIN xodim' });
    expect(list[0].correction.reason).toBe('Shifokor ma\'lumotnomasi');
    expect((await staffCall(t, w.duty, 'GET', '/corrections')).statusCode).toBe(403);
    expect((await staffCall(t, w.homeroom, 'POST', '/corrections', {
      studentId: w.bek, date: '2026-10-19', status: 'EXCUSED', reason: 'x',
    })).statusCode).toBe(403);
  });

  it('oqim filtrlari va sinf variantlari doiraga mos', async () => {
    await staffCall(t, w.admin, 'POST', '/mark', { studentId: w.vali, status: 'PRESENT' });
    setNow(t, at(DAY, '08:20'));
    await staffCall(t, w.admin, 'POST', '/mark', { studentId: w.bek, status: 'LATE' });
    const feed = (await staffCall(t, w.admin, 'GET', '/feed')).json();
    expect(feed.map((e: { studentId: string }) => e.studentId)).toEqual([w.bek, w.vali]);
    expect(feed[0].late).toBe(true);
    expect((await staffCall(t, w.admin, 'GET', '/feed?kind=OUT')).json()).toEqual([]);
    const own = (await staffCall(t, w.homeroom, 'GET', '/feed')).json();
    expect(own.map((e: { studentId: string }) => e.studentId)).toEqual([w.vali]);
    expect((await staffCall(t, w.homeroom, 'GET', `/feed?classId=${w.classB}`)).statusCode).toBe(403);

    const options = (await staffCall(t, w.admin, 'GET', '/class-options')).json();
    expect(options).toEqual([
      { id: w.classA, name: '7-A', grade: 7, shiftId: w.shiftId, shiftName: '1-smena' },
      { id: w.classB, name: '8-B', grade: 8, shiftId: w.shiftId, shiftName: '1-smena' },
    ]);
    expect((await staffCall(t, w.teacher, 'GET', '/class-options')).json()).toHaveLength(1);
  });

  it('tenant izolyatsiyasi: boshqa maktab o\'quvchisi va sinfi — 404', async () => {
    const other = await seedWorld(t, 'other-school');
    expect((await staffCall(t, w.admin, 'POST', '/mark', { studentId: other.vali, status: 'PRESENT' })).statusCode).toBe(404);
    expect((await staffCall(t, w.admin, 'GET', `/classes/${other.classA}`)).statusCode).toBe(404);
    expect((await staffCall(t, w.admin, 'POST', '/corrections', {
      studentId: other.vali, date: '2026-10-19', status: 'EXCUSED', reason: 'x',
    })).statusCode).toBe(404);
    await staffCall(t, other.admin, 'POST', '/mark', { studentId: other.vali, status: 'PRESENT' });
    expect((await staffCall(t, w.admin, 'GET', '/feed')).json()).toEqual([]);
    expect((await staffCall(t, w.admin, 'GET', '/board')).json().totals.present).toBe(0);
  });
});
