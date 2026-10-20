// Parvoz Parents ilovasi (S4): maktab e'lonlari (o'qildi), to'lov eslatmalari,
// tekshiruv so'rovlari — faqat o'z vasiy yozuvlariga yuborilganlar (boshqasi 404).

import { resetDb } from './db';
import { createChild, createParent, TestParent } from './factories';
import {
  addFamily,
  addGuardian,
  addPayment,
  classesAudience,
  createClass,
  draft,
  Family,
  parentCall,
  SCHOOL,
  schoolCall,
} from './school-comms-fixtures';
import { createSchool, createStaff, login, LoggedIn } from './school-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School comms: ota-ona ilovasi (S4)', () => {
  let t: TestApp;
  let schoolId: string;
  let cls7a: string;
  let cls8b: string;
  let admin: LoggedIn;
  let mother: TestParent;
  let other: TestParent;
  let fam: Family;
  let call: ReturnType<typeof schoolCall>;
  let parentApi: ReturnType<typeof parentCall>;

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
    cls8b = (await createClass(t.prisma, schoolId, 8, 'B')).id;
    await createStaff(t.prisma, schoolId, 'ADMIN', 'admin');
    admin = await login(t.app, 'admin');
    mother = await createParent(t.prisma);
    other = await createParent(t.prisma);
    fam = await addFamily(t.prisma, schoolId, cls7a, { userId: mother.userId });
    await addFamily(t.prisma, schoolId, cls8b, { userId: other.userId });
  });

  afterAll(() => t.close());

  const send = async (audience: object, title: string) =>
    (await call(admin, 'POST', '/comms/announcements/send', draft(audience, title))).json() as { id: string };

  it('faqat menga yuborilgan e\'lonlar (yangisi oldin), sahifalash va o\'qilmaganlar soni', async () => {
    const first = await send(SCHOOL, 'Birinchi');
    const own = await send(classesAudience(cls7a), 'Sinfga');
    const foreign = await send(classesAudience(cls8b), 'Begona');
    await call(admin, 'POST', '/comms/announcements/drafts', draft(SCHOOL, 'Qoralama'));
    await t.prisma.schoolAnnouncement.update({ where: { id: first.id }, data: { sentAt: new Date(Date.now() - 60_000) } });

    const page = (await parentApi(mother.token, 'GET', '/announcements')).json();
    expect(page.items.map((a: { id: string }) => a.id)).toEqual([own.id, first.id]);
    expect(page).toMatchObject({ unread: 2, pagination: { page: 1, limit: 20, total: 2, totalPages: 1 } });
    expect(page.items[0]).toMatchObject({ schoolName: 'Test maktab', title: 'Sinfga', priority: 'NORMAL', readAt: null });
    const paged = (await parentApi(mother.token, 'GET', '/announcements?page=2&limit=1')).json();
    expect(paged.items.map((a: { id: string }) => a.id)).toEqual([first.id]);
    expect((await parentApi(mother.token, 'GET', '/announcements?limit=500')).statusCode).toBe(400);

    expect((await parentApi(mother.token, 'POST', `/announcements/${foreign.id}/read`)).statusCode).toBe(404);
    expect((await parentApi(mother.token, 'POST', '/announcements/no-such-id/read')).statusCode).toBe(404);
  });

  it('o\'qildi: belgilanadi (takror — vaqt o\'zgarmaydi), xodim statistikasida ko\'rinadi', async () => {
    const original = t.fcm.sendPushToUser.bind(t.fcm);
    const spy = jest.spyOn(t.fcm, 'sendPushToUser').mockResolvedValue({ sent: 0, failed: 0, invalidTokens: [] });
    const a = await send(SCHOOL, 'Yig\'ilish');
    spy.mockImplementation(original);
    expect((await call(admin, 'GET', `/comms/announcements/${a.id}`)).json().stats).toEqual({ recipients: 2, delivered: 0, read: 0 });

    const read = await parentApi(mother.token, 'POST', `/announcements/${a.id}/read`);
    expect(read.statusCode).toBe(200);
    const readAt = read.json().readAt;
    expect(Date.parse(readAt)).not.toBeNaN();
    expect((await parentApi(mother.token, 'POST', `/announcements/${a.id}/read`)).json().readAt).toBe(readAt);
    expect((await parentApi(mother.token, 'GET', '/announcements')).json()).toMatchObject({ unread: 0, items: [{ id: a.id, readAt }] });

    const stats = (await call(admin, 'GET', `/comms/announcements/${a.id}`)).json().stats;
    expect(stats).toEqual({ recipients: 2, delivered: 1, read: 1 });
    expect((await call(admin, 'GET', '/comms/announcements')).json().items[0].stats).toEqual(stats);
    spy.mockRestore();
  });

  it('bir nechta vasiy yozuvi (ikki maktab); maktab to\'xtatilsa yoki vasiy uzilsa — ko\'rinmaydi', async () => {
    const second = await createSchool(t.prisma, 'second-school');
    await t.prisma.school.update({ where: { id: second.school.id }, data: { name: 'Ikkinchi maktab', shortName: '2-maktab' } });
    const secondClass = await createClass(t.prisma, second.school.id, 5, 'A');
    const secondFam = await addFamily(t.prisma, second.school.id, secondClass.id, { userId: mother.userId });
    await createStaff(t.prisma, second.school.id, 'ADMIN', 'admin2');
    const admin2 = await login(t.app, 'admin2', 'second-school');
    await send(SCHOOL, 'Birinchi maktab');
    await call(admin2, 'POST', '/comms/announcements/send', draft(SCHOOL, 'Ikkinchi'));

    const list = (await parentApi(mother.token, 'GET', '/announcements')).json();
    expect(list.items.map((a: { schoolName: string }) => a.schoolName).sort()).toEqual(['Ikkinchi maktab', 'Test maktab']);
    expect(t.fcm.pushesTo(mother.userId).map((p) => p.title).sort()).toEqual(["2-maktab: yangi e'lon", "Test maktab: yangi e'lon"]);

    await t.prisma.school.update({ where: { id: second.school.id }, data: { status: 'SUSPENDED' } });
    expect((await parentApi(mother.token, 'GET', '/announcements')).json().items).toHaveLength(1);
    await t.prisma.school.update({ where: { id: second.school.id }, data: { status: 'ACTIVE' } });
    await t.prisma.schoolGuardian.update({ where: { id: secondFam.guardianId }, data: { userId: null, linkStatus: 'NOT_INVITED' } });
    expect((await parentApi(mother.token, 'GET', '/announcements')).json().items).toHaveLength(1);
  });

  it('to\'lov eslatmalarim: farzandlar, maktab, ochiq so\'rov; begonasi ko\'rinmaydi', async () => {
    const father = await createParent(t.prisma);
    await addGuardian(t.prisma, schoolId, fam.studentId, father.userId);
    const payment = await addPayment(t.prisma, schoolId, fam, '2099-04-05', { prepaidMonths: 2 });
    await parentApi(mother.token, 'POST', '/verifications', { paymentReminderId: payment.id, message: "To'laganman" });

    expect((await parentApi(mother.token, 'GET', '/payments')).json()).toEqual([
      {
        id: payment.id, schoolId, schoolName: 'Test maktab', nextDate: '2099-04-05', prepaidMonths: 2, paused: false,
        children: [{ id: fam.studentId, name: 'Aliyev Vali', className: '7-A' }], openVerification: true,
      },
    ]);
    expect((await parentApi(father.token, 'GET', '/payments')).json()).toEqual([]);
    expect((await parentApi(other.token, 'GET', '/payments')).json()).toEqual([]);
    expect((await parentApi(other.token, 'GET', '/verifications')).json()).toEqual([]);
    expect((await parentApi(father.token, 'POST', '/verifications', { paymentReminderId: payment.id, message: 'x' })).statusCode).toBe(404);
  });

  it('faqat PARENT tokeni: bola — 403, tokensiz — 401', async () => {
    const child = await createChild(t.prisma, mother);
    expect((await parentApi(child.token, 'GET', '/announcements')).statusCode).toBe(403);
    expect((await parentApi(child.token, 'GET', '/payments')).statusCode).toBe(403);
    const anon = await t.app.inject({ method: 'GET', url: '/api/parent/school/verifications' });
    expect(anon.statusCode).toBe(401);
  });
});
