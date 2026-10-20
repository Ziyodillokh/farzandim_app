// Maktab paneli S4: e'lonlar — ruxsat va sinf doirasi, haqiqiy yetkazish
// (push / ilovasiz / xato), rejalashtirish, qoralama, nusxa, validatsiya, audit.

import { resetDb } from './db';
import { createParent, TestParent } from './factories';
import {
  addFamily,
  classesAudience,
  createClass,
  draft,
  Family,
  guardiansAudience,
  localInFuture,
  SCHOOL,
  schoolCall,
} from './school-comms-fixtures';
import { createSchool, createStaff, login, LoggedIn } from './school-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School comms: e\'lonlar (S4)', () => {
  let t: TestApp;
  let schoolId: string;
  let cls7a: string;
  let cls8b: string;
  let admin: LoggedIn;
  let homeroom: LoggedIn;
  let parentUz: TestParent;
  let parentRu: TestParent;
  let linked7a: Family;
  let unlinked7a: Family;
  let linked8b: Family;
  let call: ReturnType<typeof schoolCall>;

  beforeAll(async () => {
    t = await createTestApp();
    call = schoolCall(t.app);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    schoolId = (await createSchool(t.prisma)).school.id;
    cls7a = (await createClass(t.prisma, schoolId, 7, 'A')).id;
    cls8b = (await createClass(t.prisma, schoolId, 8, 'B')).id;
    await createStaff(t.prisma, schoolId, 'ADMIN', 'admin');
    await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar', [cls7a]);
    admin = await login(t.app, 'admin');
    homeroom = await login(t.app, 'rahbar');
    parentUz = await createParent(t.prisma);
    parentRu = await createParent(t.prisma, { language: 'ru' });
    linked7a = await addFamily(t.prisma, schoolId, cls7a, { userId: parentUz.userId, guardianName: 'Karimova Dilnoza' });
    unlinked7a = await addFamily(t.prisma, schoolId, cls7a, { guardianName: 'Toshmatova Gulnora' });
    linked8b = await addFamily(t.prisma, schoolId, cls8b, { userId: parentRu.userId, guardianName: 'Petrova Anna' });
  });

  afterAll(() => t.close());

  it('darhol yuborish: yetkazish yozuvlari, haqiqiy push (tilida), statistika va audit', async () => {
    const res = await call(admin, 'POST', '/comms/announcements/send', draft(SCHOOL));
    expect(res.statusCode).toBe(200);
    const sent = res.json();
    expect(sent).toMatchObject({ status: 'SENT', scheduledAt: null, stats: { recipients: 3, delivered: 2, read: 0 } });
    expect(Date.parse(sent.sentAt)).not.toBeNaN();

    const uz = t.fcm.pushesTo(parentUz.userId);
    expect(uz).toHaveLength(1);
    expect(uz[0]).toMatchObject({ title: "Test maktab: yangi e'lon", data: { type: 'SCHOOL_ANNOUNCEMENT', announcementId: sent.id } });
    expect(uz[0]!.body).toContain('Sinov xabari');
    expect(t.fcm.pushesTo(parentRu.userId)[0]?.title).toBe('Test maktab: новое объявление');

    const rows = await t.prisma.schoolAnnouncementDelivery.findMany({ where: { announcementId: sent.id } });
    expect(rows).toHaveLength(3);
    expect(rows.find((r) => r.guardianId === unlinked7a.guardianId)).toMatchObject({ userId: null, deliveredAt: null });

    const detail = (await call(admin, 'GET', `/comms/announcements/${sent.id}`)).json();
    expect(detail.delivery).toEqual({ delivered: 2, noApp: 1, failed: 0 });
    expect(detail.reach).toEqual({ students: 3, guardians: 3, linked: 2, sms: 1 });
    expect(detail).toMatchObject({ authorName: 'ADMIN xodim', canManage: false });

    const audit = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'announcement.send' } });
    expect(audit).toMatchObject({ module: 'MESSAGES', entityId: sent.id, params: { title: 'Sinov xabari', recipients: 3 } });
  });

  it('push o\'tmasa — yetkazilmagan (xato), muhim e\'lon sarlavhasi', async () => {
    const original = t.fcm.sendPushToUser.bind(t.fcm);
    const spy = jest
      .spyOn(t.fcm, 'sendPushToUser')
      .mockImplementation(async (userId, payload) =>
        userId === parentRu.userId ? { sent: 0, failed: 1, invalidTokens: [] } : original(userId, payload),
      );
    try {
      const sent = (await call(admin, 'POST', '/comms/announcements/send', { ...draft(SCHOOL), priority: 'IMPORTANT' })).json();
      expect(sent.stats).toEqual({ recipients: 3, delivered: 1, read: 0 });
      const detail = (await call(admin, 'GET', `/comms/announcements/${sent.id}`)).json();
      expect(detail.delivery).toEqual({ delivered: 1, noApp: 1, failed: 1 });
      expect(t.fcm.pushesTo(parentUz.userId)[0]?.title).toBe("Test maktab: muhim e'lon");
    } finally {
      spy.mockRestore();
    }
  });

  it('sinf rahbari: maktabga / boshqa sinfga / begona ota-onaga yubora olmaydi, o\'z sinfiga — ha', async () => {
    expect((await call(homeroom, 'POST', '/comms/announcements/send', draft(SCHOOL))).statusCode).toBe(403);
    expect((await call(homeroom, 'POST', '/comms/announcements/send', draft(classesAudience(cls8b)))).statusCode).toBe(403);
    expect((await call(homeroom, 'POST', '/comms/announcements/drafts', draft(classesAudience(cls7a, cls8b)))).statusCode).toBe(403);
    expect((await call(homeroom, 'POST', '/comms/announcements/send', draft(guardiansAudience(linked8b.guardianId)))).statusCode).toBe(403);

    const own = await call(homeroom, 'POST', '/comms/announcements/send', draft(classesAudience(cls7a)));
    expect(own.json()).toMatchObject({ status: 'SENT', byStaffId: homeroom.me.staff.id, stats: { recipients: 2, delivered: 1 } });
    expect(t.fcm.pushesTo(parentRu.userId)).toHaveLength(0);
  });

  it('ro\'yxat doirasi: sinf rahbari begona qoralama va boshqa sinf xabarini ko\'rmaydi; psixolog — 403', async () => {
    const school = (await call(admin, 'POST', '/comms/announcements/send', draft(SCHOOL, 'Maktab'))).json();
    const own = (await call(admin, 'POST', '/comms/announcements/send', draft(classesAudience(cls7a), '7-A'))).json();
    const hidden = (await call(admin, 'POST', '/comms/announcements/drafts', draft(SCHOOL, 'Qoralama'))).json();
    const other = (await call(admin, 'POST', '/comms/announcements/send', {
      ...draft(classesAudience(cls8b), '8-B'),
      scheduledAt: localInFuture(60),
    })).json();

    const list = (await call(homeroom, 'GET', '/comms/announcements?limit=100')).json();
    const ids = list.items.map((a: { id: string }) => a.id);
    expect(ids).toEqual(expect.arrayContaining([school.id, own.id]));
    expect(ids).not.toContain(hidden.id);
    expect(ids).not.toContain(other.id);
    expect(list.items.find((a: { id: string }) => a.id === school.id)).toMatchObject({ canManage: false, stats: { delivered: 2 } });
    expect(list.counts).toEqual({ ALL: 2, SENT: 2, SCHEDULED: 0, DRAFT: 0 });
    expect((await call(homeroom, 'GET', `/comms/announcements/${hidden.id}`)).statusCode).toBe(403);

    const adminList = (await call(admin, 'GET', '/comms/announcements?status=SCHEDULED')).json();
    expect(adminList.items.map((a: { id: string }) => a.id)).toEqual([other.id]);
    expect(adminList.counts).toEqual({ ALL: 4, SENT: 2, SCHEDULED: 1, DRAFT: 1 });
    expect(adminList.pagination).toMatchObject({ page: 1, limit: 12, total: 1 });

    await createStaff(t.prisma, schoolId, 'PSYCHOLOGIST', 'psix');
    const psych = await login(t.app, 'psix');
    expect((await call(psych, 'GET', '/comms/announcements')).statusCode).toBe(403);
    expect((await call(psych, 'POST', '/comms/audience-size', SCHOOL)).statusCode).toBe(403);
  });

  it('rejalashtirish: o\'tgan / noto\'g\'ri vaqt rad etiladi, kelajakdagi — SCHEDULED (Toshkent vaqti), sendNow', async () => {
    const past = await call(admin, 'POST', '/comms/announcements/send', { ...draft(SCHOOL), scheduledAt: '2020-01-01T08:00' });
    expect(past.json()).toMatchObject({ code: 'VALIDATION', message: 'scheduledAt: errors.form.invalidDate' });
    const bad = await call(admin, 'POST', '/comms/announcements/send', { ...draft(SCHOOL), scheduledAt: '2099-02-30T08:00' });
    expect(bad.json()).toMatchObject({ code: 'VALIDATION', message: 'scheduledAt: errors.form.invalidDate' });

    const scheduled = (await call(admin, 'POST', '/comms/announcements/send', { ...draft(SCHOOL), scheduledAt: '2099-01-01T08:00' })).json();
    expect(scheduled).toMatchObject({ status: 'SCHEDULED', scheduledAt: '2099-01-01T08:00:00', sentAt: null, stats: { recipients: 3 } });
    const stored = await t.prisma.schoolAnnouncement.findUniqueOrThrow({ where: { id: scheduled.id } });
    expect(stored.scheduledAt?.toISOString()).toBe('2099-01-01T03:00:00.000Z');
    expect(t.fcm.sent).toHaveLength(0);
    const audit = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'announcement.schedule' } });
    expect(audit.params).toEqual({ title: 'Sinov xabari', at: '2099-01-01 08:00' });

    const now = (await call(admin, 'POST', `/comms/announcements/${scheduled.id}/send-now`)).json();
    expect(now).toMatchObject({ status: 'SENT', scheduledAt: null, stats: { recipients: 3, delivered: 2 } });
    expect(t.fcm.sent).toHaveLength(2);
    expect((await call(admin, 'DELETE', `/comms/announcements/${now.id}`)).statusCode).toBe(409);
    expect((await call(admin, 'POST', `/comms/announcements/${now.id}/send-now`)).statusCode).toBe(409);
    expect((await call(admin, 'PUT', `/comms/announcements/${now.id}/draft`, draft(SCHOOL))).statusCode).toBe(409);
  });

  it('parallel "hozir yuborish" (ikki marta bosish): bitta 200, bitta 409, push har ota-onaga bir marta', async () => {
    const saved = (await call(admin, 'POST', '/comms/announcements/drafts', draft(SCHOOL))).json();
    const [a, b] = await Promise.all([
      call(admin, 'POST', `/comms/announcements/${saved.id}/send-now`),
      call(admin, 'POST', `/comms/announcements/${saved.id}/send-now`),
    ]);
    expect([a.statusCode, b.statusCode].sort()).toEqual([200, 409]);
    expect(t.fcm.pushesTo(parentUz.userId)).toHaveLength(1);
    expect(t.fcm.pushesTo(parentRu.userId)).toHaveLength(1);
    expect(await t.prisma.schoolAnnouncementDelivery.count({ where: { announcementId: saved.id } })).toBe(3);
    expect(await t.prisma.schoolAuditLog.count({ where: { action: 'announcement.send' } })).toBe(1);
  });

  it('qoralama → tahrir → nusxa → o\'chirish audit jurnaliga; sinf rahbari nusxasi o\'z sinfiga o\'tadi', async () => {
    const saved = (await call(admin, 'POST', '/comms/announcements/drafts', draft(SCHOOL))).json();
    expect(saved).toMatchObject({ status: 'DRAFT', stats: { recipients: 3, delivered: 0, read: 0 } });
    const edited = (await call(admin, 'PUT', `/comms/announcements/${saved.id}/draft`, draft(classesAudience(cls7a), 'Yangi'))).json();
    expect(edited).toMatchObject({ id: saved.id, title: 'Yangi', stats: { recipients: 2 } });
    const copy = (await call(admin, 'POST', `/comms/announcements/${saved.id}/duplicate`)).json();
    expect(copy).toMatchObject({ status: 'DRAFT', title: 'Yangi' });
    expect((await call(admin, 'DELETE', `/comms/announcements/${copy.id}`)).statusCode).toBe(204);
    const actions = (await t.prisma.schoolAuditLog.findMany({ where: { module: 'MESSAGES' }, orderBy: { at: 'asc' } })).map((a) => a.action);
    expect(actions).toEqual(['announcement.draft', 'announcement.update', 'announcement.duplicate', 'announcement.delete']);

    const school = (await call(admin, 'POST', '/comms/announcements/send', draft(SCHOOL))).json();
    const homeroomCopy = (await call(homeroom, 'POST', `/comms/announcements/${school.id}/duplicate`)).json();
    expect(homeroomCopy.audience).toEqual(classesAudience(cls7a));
    expect(homeroomCopy.byStaffId).toBe(homeroom.me.staff.id);

    const sendDraft = (await call(admin, 'POST', `/comms/announcements/${saved.id}/send`, draft(classesAudience(cls8b), 'Yakuniy'))).json();
    expect(sendDraft).toMatchObject({ id: saved.id, status: 'SENT', title: 'Yakuniy', stats: { recipients: 1, delivered: 1 } });
  });

  it('validatsiya xabarlari panel formatida; boshqa maktab id\'lari — 404 / VALIDATION', async () => {
    const noTitle = await call(admin, 'POST', '/comms/announcements/send', { ...draft(SCHOOL), title: '  ' });
    expect(noTitle.json()).toMatchObject({ code: 'VALIDATION', message: 'title: errors.form.required' });
    const empty = await call(admin, 'POST', '/comms/announcements/send', draft(classesAudience()));
    expect(empty.json()).toMatchObject({ code: 'VALIDATION', message: 'audience.classIds: errors.form.selectAtLeastOne' });
    const ghost = await call(admin, 'POST', '/comms/announcements/send', draft(classesAudience('no-such-class')));
    expect(ghost.json()).toMatchObject({ code: 'VALIDATION', message: 'audience.classIds' });

    const other = await createSchool(t.prisma, 'other-school');
    const foreignClass = await createClass(t.prisma, other.school.id, 7, 'A');
    const foreign = await t.prisma.schoolAnnouncement.create({
      data: { schoolId: other.school.id, title: 'Begona', body: 'x', audience: SCHOOL, byStaffId: other.director.id },
    });
    expect((await call(admin, 'POST', '/comms/announcements/send', draft(classesAudience(foreignClass.id)))).statusCode).toBe(400);
    expect((await call(admin, 'GET', `/comms/announcements/${foreign.id}`)).statusCode).toBe(404);
    expect((await call(admin, 'POST', `/comms/announcements/${foreign.id}/send-now`)).statusCode).toBe(404);
    expect((await call(admin, 'POST', `/comms/announcements/${foreign.id}/duplicate`)).statusCode).toBe(404);
    expect((await call(admin, 'DELETE', `/comms/announcements/${foreign.id}`)).statusCode).toBe(404);
    expect(t.fcm.sent).toHaveLength(0);
  });

  it('auditoriya hajmi, shablonlar va bosh sahifa xulosasi (rolga qarab)', async () => {
    expect((await call(admin, 'POST', '/comms/audience-size', SCHOOL)).json()).toEqual({ students: 3, guardians: 3, linked: 2, sms: 1 });
    expect((await call(admin, 'POST', '/comms/audience-size', classesAudience())).json()).toEqual({ students: 0, guardians: 0, linked: 0, sms: 0 });
    expect((await call(homeroom, 'POST', '/comms/audience-size', classesAudience(cls8b))).statusCode).toBe(403);
    const templates = (await call(homeroom, 'GET', '/comms/templates')).json();
    expect(templates.map((x: { id: string }) => x.id)).toEqual(['meeting', 'exam', 'event', 'holiday', 'payment', 'schedule', 'health']);

    await call(admin, 'POST', '/comms/announcements/send', draft(SCHOOL));
    await call(admin, 'POST', '/comms/announcements/send', { ...draft(SCHOOL), scheduledAt: localInFuture(90) });
    const adminView = (await call(admin, 'GET', '/comms/overview')).json();
    expect(adminView).toMatchObject({ scheduled: 1, sentLast7Days: 1, openVerifications: 0, upcomingReminders: [] });
    expect(adminView.lastSent.stats).toEqual({ recipients: 3, delivered: 2, read: 0 });
    expect(adminView.payments).toMatchObject({ families: 0, dueSoonDays: 30 });
    const own = (await call(homeroom, 'GET', '/comms/overview')).json();
    expect(own).toMatchObject({ upcomingReminders: null, openVerifications: null, payments: null, scheduled: 1 });
  });
});
