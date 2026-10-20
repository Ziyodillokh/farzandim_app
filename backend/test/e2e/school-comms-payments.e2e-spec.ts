// Maktab paneli S4: to'lov eslatmalari (qarz hisoblanmaydi — faqat keyingi
// sana) va tekshiruv so'rovlari: ota-ona ilovada yaratadi, maktab javob beradi.

import { addDays, tashkentDay } from '../../src/common/time/tashkent';
import { resetDb } from './db';
import { createParent, TestParent } from './factories';
import { addFamily, addPayment, createClass, Family, parentCall, schoolCall } from './school-comms-fixtures';
import { createSchool, createStaff, login, LoggedIn } from './school-fixtures';
import { createTestApp, TestApp } from './test-app';

const CONTRACT_KEYS = ['guardianId', 'history', 'id', 'nextDate', 'paused', 'prepaidMonths', 'studentIds'];

describe('School comms: to\'lov eslatmalari va tekshiruv so\'rovlari (S4)', () => {
  let t: TestApp;
  let schoolId: string;
  let cls7a: string;
  let admin: LoggedIn;
  let parent: TestParent;
  let fam: Family;
  let paymentId: string;
  let call: ReturnType<typeof schoolCall>;
  let parentApi: ReturnType<typeof parentCall>;
  const today = () => tashkentDay();

  beforeAll(async () => {
    t = await createTestApp();
    call = schoolCall(t.app);
    parentApi = parentCall(t.app);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    schoolId = (await createSchool(t.prisma)).school.id;
    cls7a = (await createClass(t.prisma, schoolId, 7, 'A')).id;
    await createStaff(t.prisma, schoolId, 'ADMIN', 'admin');
    admin = await login(t.app, 'admin');
    parent = await createParent(t.prisma);
    fam = await addFamily(t.prisma, schoolId, cls7a, { userId: parent.userId, guardianName: 'Karimova Dilnoza', lastName: 'Karimov' });
    paymentId = (await addPayment(t.prisma, schoolId, fam, addDays(today(), 10))).id;
  });

  afterAll(() => t.close());

  it('faqat payments.manage: sinf rahbari / o\'qituvchi — 403', async () => {
    await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar', [cls7a]);
    const homeroom = await login(t.app, 'rahbar');
    const denied = [
      ['GET', '/comms/payments'], ['GET', '/comms/payments/stats'], ['GET', '/comms/payments/export'],
      ['GET', `/comms/payments/${paymentId}/history`], ['GET', '/comms/verifications'],
    ] as const;
    for (const [method, url] of denied) expect((await call(homeroom, method, url)).statusCode).toBe(403);
    expect((await call(homeroom, 'POST', `/comms/payments/${paymentId}/shift`, { nextDate: '2099-01-01', note: 'x' })).statusCode).toBe(403);
    expect((await call(homeroom, 'POST', '/comms/payments/bulk-shift', { ids: [paymentId], months: 1, note: 'x' })).statusCode).toBe(403);
    expect((await call(homeroom, 'GET', '/comms/reminders')).statusCode).toBe(403);
    await createStaff(t.prisma, schoolId, 'TEACHER', 'oqituvchi', [cls7a]);
    const teacher = await login(t.app, 'oqituvchi');
    expect((await call(teacher, 'GET', '/comms/payments')).statusCode).toBe(403);
    expect((await call(teacher, 'GET', '/comms/announcements')).statusCode).toBe(403);
    expect((await call(teacher, 'POST', '/comms/announcements/send', { title: 'x', body: 'y', priority: 'NORMAL', audience: { kind: 'CLASSES', classIds: [cls7a] } })).statusCode).toBe(403);
  });

  it('ro\'yxat: oila, farzandlar, yaqinlik, filtr, qidiruv, saralash; ko\'rsatkichlar va eksport', async () => {
    const far = await addFamily(t.prisma, schoolId, cls7a, { guardianName: 'Aliyeva Malika', lastName: 'Aliyev' });
    await addPayment(t.prisma, schoolId, far, addDays(today(), 40), { prepaidMonths: 3 });
    const paused = await addFamily(t.prisma, schoolId, null, { guardianName: 'Bakirova Zuhra' });
    await addPayment(t.prisma, schoolId, paused, addDays(today(), 5), { paused: true });

    const list = (await call(admin, 'GET', '/comms/payments')).json();
    expect(list.pagination).toMatchObject({ total: 3, limit: 20 });
    expect(list.items.map((r: { guardianName: string }) => r.guardianName)).toEqual(['Bakirova Zuhra', 'Karimova Dilnoza', 'Aliyeva Malika']);
    expect(list.items[1]).toMatchObject({
      phone: '+998 90 123 45 67', linkStatus: 'LINKED', dueSoon: true, openVerifications: 0,
      children: [{ id: fam.studentId, name: 'Karimov Vali', className: '7-A', classId: cls7a }],
      lastEntry: { action: 'CREATED' },
    });
    expect(list.items[0].dueSoon).toBe(false);
    const ids = (q: string) => call(admin, 'GET', `/comms/payments?${q}`).then((r) => r.json().items.map((x: { guardianName: string }) => x.guardianName));
    expect(await ids('filter=DUE_SOON')).toEqual(['Karimova Dilnoza']);
    expect(await ids('filter=PREPAID')).toEqual(['Aliyeva Malika']);
    expect(await ids('filter=PAUSED')).toEqual(['Bakirova Zuhra']);
    expect(await ids('search=karimov%20vali')).toEqual(['Karimova Dilnoza']);
    expect(await ids('search=vali%207-a')).toEqual(['Karimova Dilnoza', 'Aliyeva Malika']);
    expect(await ids('sortBy=name&sortDir=desc')).toEqual(['Karimova Dilnoza', 'Bakirova Zuhra', 'Aliyeva Malika']);

    const stats = (await call(admin, 'GET', '/comms/payments/stats')).json();
    expect(stats).toEqual({ families: 3, dueSoon: 1, prepaid: 1, paused: 1, nearestDate: addDays(today(), 10), dueSoonDays: 30 });
    for (let i = 0; i < 22; i++) await addPayment(t.prisma, schoolId, await addFamily(t.prisma, schoolId, cls7a), addDays(today(), 60));
    expect((await call(admin, 'GET', '/comms/payments')).json().items).toHaveLength(20);
    expect((await call(admin, 'GET', '/comms/payments/export')).json()).toHaveLength(25);
    expect((await call(admin, 'GET', '/comms/payments/export?filter=PAUSED')).json()).toHaveLength(1);
  });

  it('surish, to\'xtatish / yoqish, tarix — audit bilan, qarz maydonisiz', async () => {
    const shifted = (await call(admin, 'POST', `/comms/payments/${paymentId}/shift`, { nextDate: '2099-12-10', note: 'Maosh 10-sanada' })).json();
    expect(Object.keys(shifted).sort()).toEqual(CONTRACT_KEYS);
    expect(JSON.stringify(shifted)).not.toMatch(/debt|qarz|balance|amount|owed/i);
    expect(shifted).toMatchObject({ nextDate: '2099-12-10' });
    expect((await call(admin, 'POST', `/comms/payments/${paymentId}/shift`, { nextDate: '2099-13-01', note: 'x' })).json())
      .toMatchObject({ code: 'VALIDATION', message: 'nextDate: errors.form.invalidDate' });
    expect((await call(admin, 'POST', `/comms/payments/${paymentId}/pause`, { note: '' })).json())
      .toMatchObject({ code: 'VALIDATION', message: 'note: errors.form.required' });

    expect((await call(admin, 'POST', `/comms/payments/${paymentId}/pause`, { note: 'Oila iltimosi' })).json()).toMatchObject({ paused: true });
    expect((await call(admin, 'POST', `/comms/payments/${paymentId}/pause`, { note: 'Yana' })).statusCode).toBe(409);
    expect((await call(admin, 'POST', `/comms/payments/${paymentId}/resume`, { note: 'Qayta' })).json()).toMatchObject({ paused: false });

    const history = (await call(admin, 'GET', `/comms/payments/${paymentId}/history`)).json();
    expect(history.map((h: { action: string }) => h.action)).toEqual(['RESUMED', 'PAUSED', 'SHIFTED', 'CREATED']);
    expect(history[0]).toMatchObject({ byStaffId: admin.me.staff.id, byName: 'ADMIN xodim', note: 'Qayta' });
    const audits = await t.prisma.schoolAuditLog.findMany({ where: { module: 'PAYMENTS' }, orderBy: { at: 'asc' } });
    expect(audits.map((a) => a.action)).toEqual(['payment.shift', 'payment.pause', 'payment.resume']);
    expect(audits[0]!.params).toEqual({ name: 'Karimova Dilnoza', fromDate: addDays(today(), 10), toDate: '2099-12-10' });
  });

  it('parallel o\'zgarishlar tarixni yo\'qotmaydi; parallel so\'rovlardan faqat bittasi ochiq qoladi', async () => {
    const results = await Promise.all([
      call(admin, 'POST', `/comms/payments/${paymentId}/shift`, { nextDate: '2099-03-03', note: 'A' }),
      call(admin, 'POST', `/comms/payments/${paymentId}/pause`, { note: 'B' }),
      call(admin, 'POST', '/comms/payments/bulk-shift', { ids: [paymentId], months: 1, note: 'C' }),
    ]);
    expect(results.map((r) => r.statusCode)).toEqual([200, 200, 200]);
    const history = (await call(admin, 'GET', `/comms/payments/${paymentId}/history`)).json();
    expect(history.map((h: { note: string }) => h.note).sort()).toEqual(['A', 'B', "Boshlang'ich", 'C']);

    const asks = await Promise.all(
      [1, 2, 3].map((i) => parentApi(parent.token, 'POST', '/verifications', { paymentReminderId: paymentId, message: `So'rov ${i}` })),
    );
    expect(asks.map((r) => r.statusCode).sort()).toEqual([201, 409, 409]);
    expect(await t.prisma.schoolVerificationRequest.count({ where: { paymentReminderId: paymentId, status: 'OPEN' } })).toBe(1);
  });

  it('ommaviy surish: oylar (+ oldindan to\'langan, oy oxiri qisqaradi) yoki sana; validatsiya va begona id', async () => {
    const second = (await addPayment(t.prisma, schoolId, await addFamily(t.prisma, schoolId, cls7a), '2099-01-31', { prepaidMonths: 1 })).id;
    const res = await call(admin, 'POST', '/comms/payments/bulk-shift', { ids: [paymentId, second, second], months: 1, note: 'Buxgalteriya', markPrepaid: true });
    expect(res.json()).toEqual({ updated: 2 });
    const after = await t.prisma.schoolPaymentReminder.findUniqueOrThrow({ where: { id: second } });
    expect(after).toMatchObject({ nextDate: '2099-02-28', prepaidMonths: 2 });
    const audit = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'payment.bulkShift' } });
    expect(audit.params).toEqual({ variant: 'months', count: 2, months: 1, note: 'Buxgalteriya' });

    expect((await call(admin, 'POST', '/comms/payments/bulk-shift', { ids: [second], date: '2099-06-01', note: 'Sana' })).json()).toEqual({ updated: 1 });
    expect((await t.prisma.schoolPaymentReminder.findUniqueOrThrow({ where: { id: second } })).nextDate).toBe('2099-06-01');
    expect((await call(admin, 'POST', '/comms/payments/bulk-shift', { ids: [second], note: 'x' })).json())
      .toMatchObject({ code: 'VALIDATION', message: 'months: errors.form.required' });
    expect((await call(admin, 'POST', '/comms/payments/bulk-shift', { ids: [], months: 1, note: 'x' })).json())
      .toMatchObject({ message: 'ids: errors.form.selectAtLeastOne' });

    const other = await createSchool(t.prisma, 'other-school');
    const foreign = await addPayment(t.prisma, other.school.id, await addFamily(t.prisma, other.school.id, null), '2099-01-01');
    expect((await call(admin, 'POST', '/comms/payments/bulk-shift', { ids: [paymentId, foreign.id], months: 1, note: 'x' })).statusCode).toBe(404);
    expect((await call(admin, 'POST', `/comms/payments/${foreign.id}/shift`, { nextDate: '2099-02-01', note: 'x' })).statusCode).toBe(404);
    expect((await call(admin, 'GET', `/comms/payments/${foreign.id}/history`)).statusCode).toBe(404);
    expect((await t.prisma.schoolPaymentReminder.findUniqueOrThrow({ where: { id: foreign.id } })).nextDate).toBe('2099-01-01');
  });

  it('yangi oila eslatmasi: vasiy va farzandlar shu maktabdan, bittadan (409), audit', async () => {
    const family = await addFamily(t.prisma, schoolId, cls7a, { guardianName: 'Yangi Oila' });
    const created = await call(admin, 'POST', '/comms/payments', { guardianId: family.guardianId, nextDate: '2099-09-05', note: 'Yil boshida' });
    expect(created.statusCode).toBe(201);
    expect(created.json()).toMatchObject({ guardianId: family.guardianId, studentIds: [family.studentId], prepaidMonths: 0, paused: false });
    expect(created.json().history).toEqual([expect.objectContaining({ action: 'CREATED', note: 'Yil boshida' })]);
    expect((await call(admin, 'POST', '/comms/payments', { guardianId: family.guardianId, nextDate: '2099-09-05', note: 'x' })).statusCode).toBe(409);
    expect((await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'payment.create' } })).params)
      .toEqual({ name: 'Yangi Oila', date: '2099-09-05' });

    const other = await createSchool(t.prisma, 'other-school');
    const foreign = await addFamily(t.prisma, other.school.id, null);
    expect((await call(admin, 'POST', '/comms/payments', { guardianId: foreign.guardianId, nextDate: '2099-09-05', note: 'x' })).json())
      .toMatchObject({ code: 'VALIDATION', message: 'guardianId' });
    const lone = await addFamily(t.prisma, schoolId, cls7a);
    expect((await call(admin, 'POST', '/comms/payments', { guardianId: lone.guardianId, studentIds: [family.studentId], nextDate: '2099-09-05', note: 'x' })).json())
      .toMatchObject({ code: 'VALIDATION', message: 'studentIds' });
  });

  it('tekshiruv so\'rovi: ota-ona yaratadi (bittadan ochiq), maktab javob beradi (yangi sana) → push, yopadi', async () => {
    const bad = await parentApi(parent.token, 'POST', '/verifications', { paymentReminderId: paymentId, message: ' ' });
    expect(bad.json()).toMatchObject({ code: 'VALIDATION', message: 'message: errors.form.required' });
    const long = await parentApi(parent.token, 'POST', '/verifications', { paymentReminderId: paymentId, message: 'x'.repeat(501) });
    expect(long.json()).toMatchObject({ message: 'message: errors.form.tooLong' });
    const created = await parentApi(parent.token, 'POST', '/verifications', { paymentReminderId: paymentId, message: "To'laganman, tekshiring" });
    expect(created.statusCode).toBe(201);
    const v = created.json();
    expect(v).toMatchObject({ status: 'OPEN', schoolName: 'Test maktab', answer: null, nextDate: addDays(today(), 10) });
    expect((await parentApi(parent.token, 'POST', '/verifications', { paymentReminderId: paymentId, message: 'Yana' })).statusCode).toBe(409);
    const stranger = await createParent(t.prisma);
    expect((await parentApi(stranger.token, 'POST', '/verifications', { paymentReminderId: paymentId, message: 'x' })).statusCode).toBe(404);

    const list = (await call(admin, 'GET', '/comms/verifications?status=OPEN')).json();
    expect(list.counts).toEqual({ ALL: 1, OPEN: 1, ANSWERED: 0, CLOSED: 0 });
    expect(list.items[0]).toMatchObject({
      id: v.id, guardianName: 'Karimova Dilnoza', message: "To'laganman, tekshiring", answeredByName: null,
      payment: { id: paymentId, paused: false, prepaidMonths: 0 }, children: [{ name: 'Karimov Vali' }],
    });
    expect((await call(admin, 'GET', '/comms/payments')).json().items[0].openVerifications).toBe(1);

    const answered = (await call(admin, 'POST', `/comms/verifications/${v.id}/answer`, { text: "Tekshirdik, sana to'g'rilandi.", newDate: '2099-02-05' })).json();
    expect(answered).toMatchObject({ status: 'ANSWERED', answeredByStaffId: admin.me.staff.id, answer: "Tekshirdik, sana to'g'rilandi." });
    const payment = await t.prisma.schoolPaymentReminder.findUniqueOrThrow({ where: { id: paymentId } });
    expect(payment.nextDate).toBe('2099-02-05');
    expect((payment.history as Array<{ action: string }>).at(-1)?.action).toBe('VERIFIED');
    expect(t.fcm.pushesTo(parent.userId)).toEqual([
      expect.objectContaining({
        title: "Test maktab: so'rovingizga javob berildi",
        body: "Tekshirdik, sana to'g'rilandi.",
        data: { type: 'SCHOOL_VERIFICATION_ANSWERED', verificationId: v.id, paymentReminderId: paymentId },
      }),
    ]);
    const mine = (await parentApi(parent.token, 'GET', '/verifications')).json();
    expect(mine[0]).toMatchObject({ id: v.id, status: 'ANSWERED', answer: "Tekshirdik, sana to'g'rilandi.", nextDate: '2099-02-05' });

    expect((await call(admin, 'POST', `/comms/verifications/${v.id}/close`)).json()).toMatchObject({ status: 'CLOSED' });
    expect((await call(admin, 'POST', `/comms/verifications/${v.id}/answer`, { text: 'x' })).statusCode).toBe(409);
    expect((await call(admin, 'POST', `/comms/verifications/${v.id}/close`)).statusCode).toBe(409);
    const actions = (await t.prisma.schoolAuditLog.findMany({ where: { module: 'PAYMENTS' }, orderBy: { at: 'asc' } })).map((a) => a.action);
    expect(actions).toEqual(['payment.shift', 'verification.answer', 'verification.close']);
    expect((await parentApi(parent.token, 'POST', '/verifications', { paymentReminderId: paymentId, message: 'Yangi savol' })).statusCode).toBe(201);

    const other = await createSchool(t.prisma, 'other-school');
    const foreignFam = await addFamily(t.prisma, other.school.id, null);
    const foreignPay = await addPayment(t.prisma, other.school.id, foreignFam, '2099-01-01');
    const foreign = await t.prisma.schoolVerificationRequest.create({
      data: { schoolId: other.school.id, guardianId: foreignFam.guardianId, paymentReminderId: foreignPay.id, message: 'x' },
    });
    expect((await call(admin, 'POST', `/comms/verifications/${foreign.id}/answer`, { text: 'x' })).statusCode).toBe(404);
    expect((await call(admin, 'POST', `/comms/verifications/${foreign.id}/close`)).statusCode).toBe(404);
  });
});
