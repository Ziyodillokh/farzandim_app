// Maktab paneli S4: har daqiqalik yuborish (cron) — rejali e'lonlar, Smart
// Reminder (bir martalik / haftalik / oylik) va to'lov eslatmalari. Har biri
// AYNAN BIR MARTA (takroriy va parallel ishga tushirishda ham).

import { CommsDispatcherService } from '../../src/school/comms/comms-dispatcher.service';
import { latestOccurrence, nextOccurrence, occurrenceAt, toLocalDateTime } from '../../src/school/comms/comms-time';
import { resetDb } from './db';
import { createParent, TestParent } from './factories';
import { addFamily, addPayment, classesAudience, createClass, draft, Family, SCHOOL, schoolCall } from './school-comms-fixtures';
import { createSchool, createStaff, login, LoggedIn } from './school-fixtures';
import { createTestApp, TestApp } from './test-app';

/** Toshkent devor soati → lahza. */
const tk = (local: string) => new Date(`${local}:00+05:00`);

describe('School comms: yuborish rejasi (S4 cron)', () => {
  let t: TestApp;
  let dispatcher: CommsDispatcherService;
  let schoolId: string;
  let cls7a: string;
  let admin: LoggedIn;
  let parentUz: TestParent;
  let parentRu: TestParent;
  let fam7a: Family;
  let fam8b: Family;
  let call: ReturnType<typeof schoolCall>;

  beforeAll(async () => {
    t = await createTestApp();
    dispatcher = t.app.get(CommsDispatcherService);
    call = schoolCall(t.app);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    schoolId = (await createSchool(t.prisma)).school.id;
    cls7a = (await createClass(t.prisma, schoolId, 7, 'A')).id;
    const cls8b = (await createClass(t.prisma, schoolId, 8, 'B')).id;
    await createStaff(t.prisma, schoolId, 'ADMIN', 'admin');
    admin = await login(t.app, 'admin');
    parentUz = await createParent(t.prisma);
    parentRu = await createParent(t.prisma, { language: 'ru' });
    fam7a = await addFamily(t.prisma, schoolId, cls7a, { userId: parentUz.userId });
    fam8b = await addFamily(t.prisma, schoolId, cls8b, { userId: parentRu.userId });
    await addFamily(t.prisma, schoolId, cls7a);
  });

  afterAll(() => t.close());

  it('rejali e\'lon: vaqti kelguncha yo\'q, keyin AYNAN BIR MARTA (parallel ishga tushirishda ham)', async () => {
    const scheduled = (await call(admin, 'POST', '/comms/announcements/send', { ...draft(SCHOOL), scheduledAt: '2099-03-01T08:00' })).json();
    expect((await dispatcher.dispatchDue(tk('2099-03-01T07:59'))).announcements).toBe(0);

    const due = tk('2099-03-01T08:00');
    const runs = await Promise.all([dispatcher.dispatchDue(due), dispatcher.dispatchDue(due), dispatcher.dispatchDue(due)]);
    expect(runs.reduce((n, r) => n + r.announcements, 0)).toBe(1);
    expect(t.fcm.sent).toHaveLength(2);
    expect((await dispatcher.dispatchDue(tk('2099-03-01T08:05'))).announcements).toBe(0);
    expect(t.fcm.sent).toHaveLength(2);

    const detail = (await call(admin, 'GET', `/comms/announcements/${scheduled.id}`)).json();
    expect(detail).toMatchObject({ status: 'SENT', scheduledAt: '2099-03-01T08:00:00', sentAt: due.toISOString() });
    expect(detail.stats).toEqual({ recipients: 3, delivered: 2, read: 0 });
    expect(await t.prisma.schoolAnnouncementDelivery.count({ where: { announcementId: scheduled.id } })).toBe(3);
  });

  it('qoralamaga qaytarilgan yoki to\'xtatilgan maktab xabari yuborilmaydi', async () => {
    const back = (await call(admin, 'POST', '/comms/announcements/send', { ...draft(SCHOOL), scheduledAt: '2099-03-01T08:00' })).json();
    await call(admin, 'PUT', `/comms/announcements/${back.id}/draft`, draft(SCHOOL));
    expect((await dispatcher.dispatchDue(tk('2099-03-02T08:00'))).announcements).toBe(0);
    expect((await t.prisma.schoolAnnouncement.findUniqueOrThrow({ where: { id: back.id } })).status).toBe('DRAFT');

    await call(admin, 'POST', '/comms/announcements/send', { ...draft(SCHOOL, 'Suspended'), scheduledAt: '2099-03-01T08:00' });
    await t.prisma.school.update({ where: { id: schoolId }, data: { status: 'SUSPENDED' } });
    expect((await dispatcher.dispatchDue(tk('2099-03-02T08:00'))).announcements).toBe(0);
    expect(t.fcm.sent).toHaveLength(0);
  });

  it('bir martalik eslatma: vaqtida bir marta (tilida), eskirgani yuborilmaydi', async () => {
    const created = await call(admin, 'POST', '/comms/reminders', {
      kind: 'EXAM',
      title: 'Chorak imtihoni',
      body: 'Jadval ilovada.',
      audience: classesAudience(cls7a),
      sendAt: '2099-05-01T09:00',
      repeat: 'NONE',
    });
    expect(created.json()).toMatchObject({ sendAt: '2099-05-01T09:00:00', active: true });
    expect((await dispatcher.dispatchDue(tk('2099-05-01T08:59'))).reminders).toBe(0);
    expect((await dispatcher.dispatchDue(tk('2099-05-01T09:01'))).reminders).toBe(1);
    expect((await dispatcher.dispatchDue(tk('2099-05-01T09:02'))).reminders).toBe(0);
    expect(t.fcm.pushesTo(parentUz.userId)).toEqual([
      expect.objectContaining({ title: 'Test maktab: Nazorat ishi', data: { type: 'SCHOOL_REMINDER', reminderId: created.json().id } }),
    ]);
    expect(t.fcm.pushesTo(parentRu.userId)).toHaveLength(0);

    await call(admin, 'POST', '/comms/reminders', {
      kind: 'MEETING', title: 'Kech qolgan', body: 'x', audience: SCHOOL, sendAt: '2099-06-01T09:00', repeat: 'NONE',
    });
    expect((await dispatcher.dispatchDue(tk('2099-06-01T11:00'))).reminders).toBe(0);
  });

  it('haftalik: har navbat bir marta; to\'xtatilgani yuborilmaydi', async () => {
    const weekly = (await call(admin, 'POST', '/comms/reminders', {
      kind: 'MEETING', title: 'Haftalik', body: 'Har dushanba', audience: SCHOOL, sendAt: '2099-01-05T08:30', repeat: 'WEEKLY',
    })).json();
    expect((await dispatcher.dispatchDue(tk('2099-01-05T08:31'))).reminders).toBe(1);
    expect((await dispatcher.dispatchDue(tk('2099-01-05T08:40'))).reminders).toBe(0);
    expect((await dispatcher.dispatchDue(tk('2099-01-12T08:30'))).reminders).toBe(1);
    expect(t.fcm.pushesTo(parentRu.userId).map((p) => p.title)).toEqual([
      'Test maktab: Родительское собрание',
      'Test maktab: Родительское собрание',
    ]);
    await call(admin, 'PATCH', `/comms/reminders/${weekly.id}/active`, { active: false });
    expect((await dispatcher.dispatchDue(tk('2099-01-19T08:31'))).reminders).toBe(0);
  });

  it('oylik: 31-yanvar → 28-fevral (oy qisqa) — vaqt Toshkent kalendari bo\'yicha', async () => {
    await call(admin, 'POST', '/comms/reminders', {
      kind: 'EVENT', title: 'Oylik', body: 'x', audience: SCHOOL, sendAt: '2099-01-31T09:00', repeat: 'MONTHLY',
    });
    expect((await dispatcher.dispatchDue(tk('2099-02-27T09:00'))).reminders).toBe(0);
    expect((await dispatcher.dispatchDue(tk('2099-02-28T09:00'))).reminders).toBe(1);
    expect((await dispatcher.dispatchDue(tk('2099-03-31T09:10'))).reminders).toBe(1);
  });

  it('to\'lov eslatmasi: sanadan 3 kun oldin, 09:00 dan keyin, davr uchun bir marta; ilovasiz / to\'xtatilgan — yo\'q', async () => {
    const payment = await addPayment(t.prisma, schoolId, fam7a, '2099-04-10');
    await addPayment(t.prisma, schoolId, fam8b, '2099-04-10', { paused: true });
    const unlinked = await addFamily(t.prisma, schoolId, cls7a, { guardianName: 'Ilovasiz' });
    await addPayment(t.prisma, schoolId, unlinked, '2099-04-09');

    expect((await dispatcher.dispatchDue(tk('2099-04-06T10:00'))).payments).toBe(0);
    expect((await dispatcher.dispatchDue(tk('2099-04-07T08:59'))).payments).toBe(0);
    const runs = await Promise.all([dispatcher.dispatchDue(tk('2099-04-07T09:00')), dispatcher.dispatchDue(tk('2099-04-07T09:00'))]);
    expect(runs.reduce((n, r) => n + r.payments, 0)).toBe(1);
    expect((await dispatcher.dispatchDue(tk('2099-04-09T12:00'))).payments).toBe(0);
    const pushes = t.fcm.pushesTo(parentUz.userId);
    expect(pushes).toHaveLength(1);
    expect(pushes[0]).toMatchObject({ title: "Test maktab: to'lov eslatmasi", data: { type: 'SCHOOL_PAYMENT_REMINDER', paymentReminderId: payment.id } });
    expect(pushes[0]!.body).toContain('2099-04-10');
    expect(pushes[0]!.body).not.toMatch(/qarz/i);
    expect(t.fcm.pushesTo(parentRu.userId)).toHaveLength(0);

    await call(admin, 'POST', `/comms/payments/${payment.id}/shift`, { nextDate: '2099-05-10', note: 'Keyingi oy' });
    expect((await dispatcher.dispatchDue(tk('2099-05-07T09:30'))).payments).toBe(1);
  });

  it('vaqt hisobi: oylik qadam siljimaydi, haftalik — 7 kun, o\'tgan bir martalik — null', () => {
    const anchor = tk('2027-01-31T09:00');
    expect(toLocalDateTime(occurrenceAt(anchor, 'MONTHLY', 1))).toBe('2027-02-28T09:00:00');
    expect(toLocalDateTime(occurrenceAt(anchor, 'MONTHLY', 2))).toBe('2027-03-31T09:00:00');
    expect(toLocalDateTime(occurrenceAt(anchor, 'MONTHLY', 3))).toBe('2027-04-30T09:00:00');
    expect(toLocalDateTime(occurrenceAt(tk('2028-01-31T09:00'), 'MONTHLY', 1))).toBe('2028-02-29T09:00:00');
    expect(toLocalDateTime(nextOccurrence(anchor, 'MONTHLY', tk('2027-02-05T00:00'))!)).toBe('2027-02-28T09:00:00');
    expect(toLocalDateTime(nextOccurrence(tk('2027-01-04T08:30'), 'WEEKLY', tk('2027-01-12T00:00'))!)).toBe('2027-01-18T08:30:00');
    expect(nextOccurrence(tk('2027-01-04T08:30'), 'NONE', tk('2027-01-12T00:00'))).toBeNull();
    expect(toLocalDateTime(latestOccurrence(tk('2027-01-04T08:30'), 'WEEKLY', tk('2027-01-12T00:00'))!)).toBe('2027-01-11T08:30:00');
    expect(toLocalDateTime(tk('2027-01-04T23:30'))).toBe('2027-01-04T23:30:00');
  });
});
