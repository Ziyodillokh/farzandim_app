// Bola ilovasi: o'z davomat tarixi — UNKNOWN xaritasi, `confirmed`, kiosk vaqtlari, jami,
// oy tekshiruvi va izolyatsiya (boshqa o'quvchi, ota-ona tokeni, bog'lanmagan bola).

import type { AttendanceSource, AttendanceStatus } from '@prisma/client';
import { resetDb } from './db';
import { at, DAY, seedWorld, setNow, World } from './school-attendance-fixtures';
import { appReq, unlinkedChild } from './school-child-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School child app: davomat tarixi', () => {
  let t: TestApp;
  let w: World;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    w = await seedWorld(t);
    setNow(t, at(DAY, '09:00')); // seshanba 2026-10-20
  });

  afterAll(() => t.close());

  const history = (month?: string, token = w.child.token) => appReq(t, token, 'GET', `/child/school/attendance${month ? `?month=${month}` : ''}`);
  const day = (res: { json(): { days: { date: string }[] } }, date: string) => res.json().days.find((d) => d.date === date);

  async function row(
    date: string,
    status: AttendanceStatus,
    source: AttendanceSource,
    over: { studentId?: string; inAt?: string | null; outAt?: string | null; corrections?: string[] } = {},
  ) {
    const created = await t.prisma.schoolAttendance.create({
      data: {
        schoolId: w.schoolId,
        studentId: over.studentId ?? w.vali,
        classId: w.classA,
        date,
        status,
        source,
        inAt: over.inAt === undefined ? null : over.inAt,
        outAt: over.outAt ?? null,
      },
    });
    for (const byStaffId of over.corrections ?? []) {
      await t.prisma.schoolAttendanceCorrection.create({ data: { attendanceId: created.id, byStaffId, from: 'ABSENT', to: status, reason: 'sabab' } });
    }
    return created;
  }

  const event = (date: string, time: string, kind: 'IN' | 'OUT', source: AttendanceSource, studentId = w.vali) =>
    t.prisma.schoolAttendanceEvent.create({ data: { schoolId: w.schoolId, at: at(date, time), date, studentId, classId: w.classA, kind, source } });

  it('maps system ABSENT to UNKNOWN, keeps staff-confirmed rows and exposes kiosk times', async () => {
    await row('2026-10-19', 'PRESENT', 'QR', { inAt: '08:02', outAt: '13:30' }); // dushanba, QR
    await event('2026-10-19', '08:02', 'IN', 'QR');
    await event('2026-10-19', '08:00', 'IN', 'KIOSK'); // eng erta kirish
    await event('2026-10-19', '13:20', 'OUT', 'KIOSK');
    await event('2026-10-19', '13:30', 'OUT', 'QR'); // oxirgi chiqish
    await event('2026-10-19', '07:00', 'IN', 'MANUAL'); // qo'lda — kioskka kirmaydi
    await row('2026-10-16', 'ABSENT', 'SYSTEM'); // juma: tizim "kelmadi"
    await row('2026-10-15', 'ABSENT', 'SYSTEM', { corrections: [w.admin.staffId] }); // payshanba: xodim tasdiqlagan
    await row('2026-10-14', 'EXCUSED', 'SYSTEM', { corrections: [w.homeroom.staffId] }); // chorshanba: sababli
    await row('2026-10-13', 'ABSENT', 'MANUAL'); // seshanba: qo'lda kelmadi
    await row('2026-10-12', 'LATE', 'QR', { inAt: '08:20', corrections: ['system'] }); // tizim tuzatishi — xodim emas

    const res = await history('2026-10');
    expect(res.statusCode).toBe(200);
    expect(res.json().month).toBe('2026-10');

    expect(day(res, '2026-10-19')).toEqual({
      date: '2026-10-19',
      status: 'PRESENT',
      inAt: '08:02',
      outAt: '13:30',
      source: 'QR',
      confirmed: false,
      kiosk: { inAt: '08:00', outAt: '13:30' },
    });
    expect(day(res, '2026-10-16')).toMatchObject({ status: 'UNKNOWN', confirmed: false, source: 'SYSTEM', inAt: null, kiosk: null });
    expect(day(res, '2026-10-15')).toMatchObject({ status: 'ABSENT', confirmed: true });
    expect(day(res, '2026-10-14')).toMatchObject({ status: 'EXCUSED', confirmed: true });
    expect(day(res, '2026-10-13')).toMatchObject({ status: 'ABSENT', confirmed: true, source: 'MANUAL' });
    expect(day(res, '2026-10-12')).toMatchObject({ status: 'LATE', confirmed: false });
  });

  it('synthesizes UNKNOWN for past school days without a row; skips weekends, holidays, today, future and pre-enrolment', async () => {
    await t.prisma.schoolHoliday.create({ data: { schoolId: w.schoolId, date: '2026-10-07', name: 'Bayram' } });
    await row('2026-10-19', 'PRESENT', 'QR', { inAt: '08:00' });

    const res = await history('2026-10');
    const dates = res.json().days.map((d: { date: string }) => d.date);

    expect(day(res, '2026-10-17')).toMatchObject({ status: 'UNKNOWN' }); // shanba — o'quv kuni
    expect(dates).not.toContain('2026-10-18'); // yakshanba
    expect(dates).not.toContain('2026-10-07'); // bayram
    expect(dates).not.toContain('2026-10-20'); // bugun, yozuv yo'q
    expect(dates).not.toContain('2026-10-21'); // kelajak
    expect(dates).toContain('2026-10-01');
    expect(dates).toEqual([...dates].sort());

    expect((await history('2026-08')).json().days).toEqual([]); // qabuldan oldin (2026-09-02)
    expect((await history('2026-09')).json().days[0].date).toBe('2026-09-02');
  });

  it("counts school days up to today in the summary; UNKNOWN is separate and outside the rate", async () => {
    await row('2026-10-19', 'PRESENT', 'QR', { inAt: '08:00' });
    await row('2026-10-17', 'LATE', 'QR', { inAt: '08:30' });
    await row('2026-10-16', 'ABSENT', 'MANUAL');
    await row('2026-10-15', 'ABSENT', 'SYSTEM'); // UNKNOWN
    await row('2026-10-20', 'PRESENT', 'QR', { inAt: '08:00' }); // bugun
    // qolgan o'tgan o'quv kunlari yozuvsiz — UNKNOWN (1-14 oktyabr, yakshanbalarsiz)

    const { summary, days } = (await history('2026-10')).json();
    const unknown = days.filter((d: { status: string }) => d.status === 'UNKNOWN').length;

    expect(summary).toMatchObject({ present: 2, late: 1, absent: 1, leftEarly: 0, excused: 0, unknown });
    expect(summary.total).toBe(4 + unknown);
    expect(summary.rate).toBe(100 * 3 / 4);
    expect(unknown).toBeGreaterThan(1);
  });

  it('defaults to the current month and validates the month', async () => {
    await row('2026-10-19', 'PRESENT', 'QR', { inAt: '08:00' });
    expect((await history()).json().month).toBe('2026-10');
    expect((await history()).json().days.map((d: { date: string }) => d.date)).toContain('2026-10-19');

    for (const bad of ['2026-13', '2026-00', '26-10', 'abc', '2026-1']) {
      expect((await history(bad)).statusCode).toBe(400);
    }
    expect((await history('2026-11')).json()).toMatchObject({ month: '2026-11', days: [] });
  });

  it("only the child's own student: classmates' rows never appear", async () => {
    await row('2026-10-19', 'PRESENT', 'QR', { studentId: w.malika, inAt: '08:00' });
    await row('2026-10-16', 'ABSENT', 'MANUAL', { studentId: w.malika });
    await event('2026-10-19', '08:00', 'IN', 'QR', w.malika);

    const res = await history('2026-10');

    expect(day(res, '2026-10-19')).toMatchObject({ status: 'UNKNOWN', kiosk: null }); // Vali'da yozuv yo'q
    expect(day(res, '2026-10-16')).toMatchObject({ status: 'UNKNOWN', confirmed: false });
  });

  it('rejects parent tokens and anonymous callers; unlinked or archived children get 404', async () => {
    expect((await history('2026-10', w.parent.token)).statusCode).toBe(403);
    expect((await t.app.inject({ method: 'GET', url: '/api/child/school/attendance' })).statusCode).toBe(401);

    const lonely = await unlinkedChild(t);
    const res = await history('2026-10', lonely.token);
    expect(res.statusCode).toBe(404);
    expect(res.json()).toMatchObject({ code: 'NOT_ENROLLED' });

    await t.prisma.schoolStudent.update({ where: { id: w.vali }, data: { archived: true } });
    expect((await history('2026-10')).statusCode).toBe(404);
  });
});
