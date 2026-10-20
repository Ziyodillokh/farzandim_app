// Maktab paneli S3 — kiosk QR tokeni, xodim kioski, Parvoz Growth QR kirishi /
// chiqishi va "kelmadi" cron'i (ota-onaga push — tur bo'yicha bir marta).

import { AttendanceAbsenceCron } from '../../src/school/attendance/attendance-absence.cron';
import { resetDb } from './db';
import { consumerCall, at, DAY, seedWorld, setNow, staffCall, World } from './school-attendance-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School attendance (S3): kiosk, QR va cron', () => {
  let t: TestApp;
  let w: World;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    w = await seedWorld(t);
    setNow(t, at(DAY, '07:55'));
  });

  afterAll(() => t.close());

  const kioskToken = async () => (await staffCall(t, w.duty, 'GET', '/kiosk/token')).json().token as string;
  const scan = (token: string, userToken = w.child.token) =>
    consumerCall(t, userToken, 'POST', '/child/school/check-in', { token });
  const pushKinds = () => t.fcm.pushesTo(w.parent.userId).map((p) => p.data?.kind ?? p.data?.status);

  it('QR token: 30 soniyada almashadi, faqat kiosk ruxsati bilan, sir oshkor qilinmaydi', async () => {
    const res = await staffCall(t, w.duty, 'GET', '/kiosk/token');
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.token).toMatch(/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);
    expect(body).toMatchObject({ expiresAt: '2026-10-20T02:55:30.000Z', rotatesInSeconds: 30 });
    expect(JSON.stringify(body)).not.toContain((await t.prisma.school.findFirstOrThrow()).kioskSecret);
    setNow(t, new Date(at(DAY, '07:55').getTime() + 10_000));
    expect((await staffCall(t, w.duty, 'GET', '/kiosk/token')).json()).toMatchObject({ token: body.token, rotatesInSeconds: 20 });
    setNow(t, new Date(at(DAY, '07:55').getTime() + 30_000));
    expect(await kioskToken()).not.toBe(body.token);
    expect((await staffCall(t, w.director, 'GET', '/kiosk/token')).statusCode).toBe(403);
    expect((await staffCall(t, w.homeroom, 'GET', '/kiosk/token')).statusCode).toBe(403);
  });

  it('xodim kioski: kod bo\'yicha kirish, ikkinchisi "allaqachon", audit, push, hisoblagichlar', async () => {
    const code = (await t.prisma.schoolStudent.findUniqueOrThrow({ where: { id: w.vali } })).studentCode;
    const first = (await staffCall(t, w.duty, 'POST', '/kiosk/check-in', { code: code.toLowerCase() })).json();
    expect(first).toMatchObject({ className: '7-A', status: 'PRESENT', alreadyIn: false });
    expect(first.student).toMatchObject({ id: w.vali, guardianIds: [w.guardianId], classId: w.classA });
    const again = (await staffCall(t, w.duty, 'POST', '/kiosk/check-in', { code })).json();
    expect(again).toMatchObject({ alreadyIn: true, status: 'PRESENT' });
    expect(pushKinds()).toEqual(['ARRIVED']);
    const log = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'attendance.kiosk' } });
    expect(log.params).toEqual({ name: 'Aliyev Vali', className: '7-A', status: 'PRESENT' });

    setNow(t, at(DAY, '08:11'));
    const late = (await staffCall(t, w.duty, 'POST', '/kiosk/check-in', { code: w.bek })).json();
    expect(late).toMatchObject({ status: 'LATE', alreadyIn: false });
    const stats = (await staffCall(t, w.duty, 'GET', '/kiosk/stats')).json();
    expect(stats).toMatchObject({ date: DAY, expected: 3, arrived: 2, late: 1 });
    expect(stats.recent.map((e: { studentId: string }) => e.studentId)).toEqual([w.bek, w.vali]);
    expect(stats.recent[0]).toMatchObject({ source: 'KIOSK', late: true, className: '8-B' });

    expect((await staffCall(t, w.duty, 'POST', '/kiosk/check-in', { code: 'P-0000' })).json()).toMatchObject({ code: 'NOT_FOUND' });
    expect((await staffCall(t, w.director, 'POST', '/kiosk/check-in', { code })).statusCode).toBe(403);
    expect((await staffCall(t, w.director, 'GET', '/kiosk/stats')).statusCode).toBe(403);
  });

  it('kiosk qidiruvi: kamida 2 belgi, ism yoki kod, bugun kirganmi', async () => {
    expect((await staffCall(t, w.duty, 'GET', '/kiosk/search?q=a')).json()).toEqual([]);
    await staffCall(t, w.duty, 'POST', '/kiosk/check-in', { code: w.vali });
    const found = (await staffCall(t, w.duty, 'GET', '/kiosk/search?q=aliyev')).json();
    expect(found).toEqual([expect.objectContaining({ id: w.vali, name: 'Aliyev Vali', className: '7-A', inToday: true })]);
    const byCode = (await staffCall(t, w.duty, 'GET', '/kiosk/search?q=p-')).json();
    expect(byCode).toHaveLength(3);
    expect(byCode.find((s: { id: string }) => s.id === w.malika).inToday).toBe(false);
  });

  it('Parvoz Growth QR: kirish, takror skanerlash, kechikish va bugungi holat', async () => {
    expect((await consumerCall(t, w.child.token, 'GET', '/child/school/today')).json().today).toMatchObject({
      date: DAY, schoolName: 'Test maktab', className: '7-A', schoolDay: true, record: null,
    });
    const first = await scan(await kioskToken());
    expect(first.statusCode).toBe(200);
    expect(first.json()).toMatchObject({ action: 'IN', today: { record: { status: 'PRESENT', inAt: '07:55', source: 'QR' } } });
    const second = (await scan(await kioskToken())).json();
    expect(second).toMatchObject({ action: 'NONE', today: { record: { status: 'PRESENT' } } });
    expect(pushKinds()).toEqual(['ARRIVED']);
    expect(t.fcm.pushesTo(w.parent.userId)[0]).toMatchObject({ title: 'Maktabga keldi' });
    const events = await t.prisma.schoolAttendanceEvent.findMany({ where: { studentId: w.vali } });
    expect(events).toEqual([expect.objectContaining({ kind: 'IN', source: 'QR', late: false })]);
  });

  it('QR tokeni: oldingi oyna qabul qilinadi; eskirgan, buzilgan, boshqa maktab — barqaror kodlar', async () => {
    const token = await kioskToken();
    const [payload, signature] = token.split('.');
    const forged = Buffer.from(JSON.stringify({ s: w.schoolId, t: 99_999_999 })).toString('base64url');
    expect((await scan(`${forged}.${signature}`)).json()).toMatchObject({ statusCode: 400, code: 'KIOSK_TOKEN_INVALID' });
    expect((await scan(`${payload}.${signature?.slice(0, -2)}xx`)).json()).toMatchObject({ code: 'KIOSK_TOKEN_INVALID' });
    expect((await scan('garbage')).json()).toMatchObject({ code: 'KIOSK_TOKEN_INVALID' });
    expect((await scan('')).json()).toMatchObject({ code: 'VALIDATION' });

    setNow(t, new Date(at(DAY, '07:55').getTime() + 61_000));
    expect((await scan(token)).json()).toMatchObject({ statusCode: 400, code: 'KIOSK_TOKEN_EXPIRED' });
    setNow(t, new Date(at(DAY, '07:55').getTime() + 45_000));
    expect((await scan(token)).json()).toMatchObject({ action: 'IN' });

    const other = await seedWorld(t, 'other-school');
    const otherToken = (await staffCall(t, other.duty, 'GET', '/kiosk/token')).json().token;
    const wrong = await scan(otherToken);
    expect(wrong.statusCode).toBe(403);
    expect(wrong.json()).toMatchObject({ code: 'NOT_ENROLLED' });
    expect((await scan(token, w.parent.token)).statusCode).toBe(403);
  });

  it('QR: kechikish, smena tugagach chiqish (bir marta "chiqdi"), keyingi skanerlash — o\'zgarishsiz', async () => {
    setNow(t, at(DAY, '08:20'));
    expect((await scan(await kioskToken())).json()).toMatchObject({ action: 'IN', today: { record: { status: 'LATE' } } });
    expect(t.fcm.pushesTo(w.parent.userId)[0]).toMatchObject({ title: 'Kechikib keldi' });
    setNow(t, at(DAY, '13:30'));
    const out = (await scan(await kioskToken())).json();
    expect(out).toMatchObject({ action: 'OUT', today: { record: { status: 'LATE', outAt: '13:30' } } });
    expect((await scan(await kioskToken())).json()).toMatchObject({ action: 'NONE' });
    expect(pushKinds()).toEqual(['ARRIVED', 'LEFT']);
    const feed = (await staffCall(t, w.admin, 'GET', '/feed?kind=OUT')).json();
    expect(feed).toEqual([expect.objectContaining({ studentId: w.vali, kind: 'OUT', source: 'QR' })]);
  });

  it('maktabga bog\'lanmagan bola: today — null, kirish — NOT_ENROLLED', async () => {
    await t.prisma.schoolStudent.update({ where: { id: w.vali }, data: { childId: null } });
    expect((await consumerCall(t, w.child.token, 'GET', '/child/school/today')).json()).toEqual({ today: null });
    const res = await scan(await kioskToken());
    expect(res.statusCode).toBe(403);
    expect(res.json()).toMatchObject({ code: 'NOT_ENROLLED' });
  });

  it('"kelmadi" cron: vaqtidan oldin yo\'q, keyin ABSENT + bir marta push, idempotent, qo\'lda yozuv saqlanadi', async () => {
    const cron = t.app.get(AttendanceAbsenceCron);
    await staffCall(t, w.admin, 'POST', '/mark', { studentId: w.malika, status: 'EXCUSED' });
    expect(await cron.sweep(at(DAY, '08:39'))).toEqual({ marked: 0, notified: 0 });
    // Faqat davomati olinayotgan sinf (A — Malika belgilangan); B sinf o'tkazib yuboriladi.
    expect(await cron.sweep(at(DAY, '08:40'))).toEqual({ marked: 1, notified: 1 });
    expect(await cron.sweep(at(DAY, '08:45'))).toEqual({ marked: 0, notified: 0 });
    const vali = await t.prisma.schoolAttendance.findFirstOrThrow({ where: { studentId: w.vali } });
    expect(vali).toMatchObject({ status: 'ABSENT', source: 'SYSTEM', parentNotified: true, date: DAY });
    expect((await t.prisma.schoolAttendance.findFirstOrThrow({ where: { studentId: w.malika } })).status).toBe('EXCUSED');
    expect(pushKinds()).toEqual(['ABSENT']);
    expect(t.fcm.pushesTo(w.parent.userId)[0]).toMatchObject({ title: 'Maktabga kelmadi' });

    // Keyin kelsa — QR kirishi ABSENT ni LATE ga tuzatadi (tizim tuzatishi) va "kechikib keldi".
    setNow(t, at(DAY, '09:00'));
    const res = (await scan(await kioskToken())).json();
    expect(res).toMatchObject({ action: 'IN', today: { record: { status: 'LATE', inAt: '09:00' } } });
    const fixed = await t.prisma.schoolAttendanceCorrection.findFirstOrThrow({ where: { attendanceId: vali.id } });
    expect(fixed).toMatchObject({ from: 'ABSENT', to: 'LATE', byStaffId: 'system' });
    expect(pushKinds()).toEqual(['ABSENT', 'ARRIVED']);
  });

  it('cron: bugun davomati olinmagan sinf o\'tkazib yuboriladi (noto\'g\'ri "kelmadi" yo\'q)', async () => {
    const cron = t.app.get(AttendanceAbsenceCron);
    expect(await cron.sweep(at(DAY, '09:00'))).toEqual({ marked: 0, notified: 0 });
    expect(await t.prisma.schoolAttendance.count()).toBe(0);
    expect(pushKinds()).toEqual([]);
  });

  it('cron: dam olish kuni va bayramda ishlamaydi', async () => {
    const cron = t.app.get(AttendanceAbsenceCron);
    expect(await cron.sweep(at('2026-10-18', '12:00'))).toEqual({ marked: 0, notified: 0 });
    await t.prisma.schoolHoliday.create({ data: { schoolId: w.schoolId, date: DAY, name: 'Bayram' } });
    expect(await cron.sweep(at(DAY, '12:00'))).toEqual({ marked: 0, notified: 0 });
    expect(await t.prisma.schoolAttendance.count()).toBe(0);
  });
});
