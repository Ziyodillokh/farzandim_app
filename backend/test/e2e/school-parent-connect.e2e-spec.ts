// Ota-ona ↔ maktab aloqasi: kontaktlar, maxfiy yozishma (faqat qabul qiluvchi
// xodim ko'radi), push, chegaralar, farzand statistikasi; e'lon muallifi va
// auditoriyasi, to'lov tarixi (ota-ona ilovasi).

import { resetDb } from './db';
import { createParent, TestParent } from './factories';
import { addFamily, addPayment, classesAudience, createClass, draft, Family, parentCall, schoolCall } from './school-comms-fixtures';
import { createSchool, createStaff, login, LoggedIn } from './school-fixtures';
import { createTestApp, TestApp } from './test-app';

type Contact = { staffId: string; group: string; role: string; threadId: string | null; unread: number };

describe('School parent connect', () => {
  let t: TestApp;
  let call: ReturnType<typeof schoolCall>;
  let parentApi: ReturnType<typeof parentCall>;
  let schoolId: string;
  let cls6b: string;
  let cls7a: string;
  let directorId: string;
  let homeroomId: string;
  let teacherId: string;
  let otherTeacherId: string;
  let psychologistId: string;
  let director: LoggedIn;
  let homeroom: LoggedIn;
  let mother: TestParent;
  let stranger: TestParent;
  let fam: Family;

  beforeAll(async () => {
    t = await createTestApp();
    call = schoolCall(t.app);
    parentApi = parentCall(t.app);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    const created = await createSchool(t.prisma);
    schoolId = created.school.id;
    directorId = created.director.id;
    cls6b = (await createClass(t.prisma, schoolId, 6, 'B')).id;
    cls7a = (await createClass(t.prisma, schoolId, 7, 'A')).id;
    homeroomId = (await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar', [cls6b])).id;
    await t.prisma.schoolClass.update({ where: { id: cls6b }, data: { homeroomStaffId: homeroomId } });
    teacherId = (await createStaff(t.prisma, schoolId, 'TEACHER', 'matem', [cls6b])).id;
    await t.prisma.schoolStaff.update({ where: { id: teacherId }, data: { position: 'Matematika o\'qituvchisi' } });
    otherTeacherId = (await createStaff(t.prisma, schoolId, 'TEACHER', 'fizik', [cls7a])).id;
    psychologistId = (await createStaff(t.prisma, schoolId, 'PSYCHOLOGIST', 'psixolog')).id;
    await createStaff(t.prisma, schoolId, 'DUTY', 'navbatchi');
    // Panel hisobi yo'q xodim — ro'yxatda ko'rinmaydi.
    await t.prisma.schoolStaff.create({ data: { schoolId, fullName: 'Hisobsiz Admin', role: 'ADMIN' } });
    director = await login(t.app, 'direktor');
    homeroom = await login(t.app, 'rahbar');
    mother = await createParent(t.prisma);
    stranger = await createParent(t.prisma);
    fam = await addFamily(t.prisma, schoolId, cls6b, { userId: mother.userId, lastName: 'Karimova' });
    await addFamily(t.prisma, schoolId, cls7a, { userId: stranger.userId });
  });

  afterAll(() => t.close());

  const contacts = async (token: string, studentId = fam.studentId) =>
    parentApi(token, 'GET', `/contacts?studentId=${studentId}`);

  const start = (staffId: string, body = 'Assalomu alaykum, ertaga farzandim kelmaydi.', extra: object = {}) =>
    parentApi(mother.token, 'POST', '/threads', { staffId, studentId: fam.studentId, topic: 'ABSENCE', body, ...extra });

  it('lists the student contacts: homeroom, leadership, psychologist, own-class teachers only', async () => {
    const res = await contacts(mother.token);
    expect(res.statusCode).toBe(200);
    const list = res.json().contacts as Contact[];
    expect(list.map((c) => [c.staffId, c.group])).toEqual([
      [homeroomId, 'CLASS'],
      [directorId, 'LEADERSHIP'],
      [psychologistId, 'SUPPORT'],
      [teacherId, 'SUBJECT'],
    ]);
    expect(list.some((c) => c.staffId === otherTeacherId)).toBe(false);
    expect(res.json().student).toMatchObject({ id: fam.studentId, className: '6-B', schoolName: expect.any(String) });
    expect((await contacts(stranger.token)).statusCode).toBe(404);
  });

  it('delivers a parent message only to the chosen staff member, encrypted at rest', async () => {
    const res = await start(homeroomId);
    expect(res.statusCode).toBe(201);
    const thread = res.json();
    expect(thread).toMatchObject({ status: 'OPEN', unread: 0, available: true, staff: { id: homeroomId, role: 'HOMEROOM' } });
    expect(thread.messages).toEqual([expect.objectContaining({ author: 'PARENT', topic: 'ABSENCE', seen: false })]);

    const stored = await t.prisma.schoolParentMessage.findFirstOrThrow({ where: { threadId: thread.id } });
    expect(stored.bodyEnc).not.toContain('farzandim');

    const inbox = (await call(homeroom, 'GET', '/parent-threads')).json();
    expect(inbox.items).toEqual([expect.objectContaining({ id: thread.id, unread: 1, student: expect.objectContaining({ className: '6-B' }) })]);
    expect(inbox.items[0].preview.text).toContain('ertaga farzandim kelmaydi');
    expect(inbox.counts).toEqual({ unread: 1, open: 1 });

    // Direktor (butun maktab doirasi) ham boshqaning yozishmasini ko'rmaydi.
    expect((await call(director, 'GET', '/parent-threads')).json().items).toEqual([]);
    expect((await call(director, 'GET', `/parent-threads/${thread.id}`)).statusCode).toBe(404);

    const feed = (await call(homeroom, 'GET', '/notifications/feed')).json() as { kind: string; href: string }[];
    expect(feed).toContainEqual(expect.objectContaining({ kind: 'PARENT_MESSAGE', href: `/inbox?thread=${thread.id}` }));
    const directorFeed = (await call(director, 'GET', '/notifications/feed')).json() as { kind: string }[];
    expect(directorFeed.some((n) => n.kind === 'PARENT_MESSAGE')).toBe(false);
  });

  it('round-trips a reply with a push, unread counters and read receipts', async () => {
    const thread = (await start(homeroomId)).json();
    await call(homeroom, 'POST', `/parent-threads/${thread.id}/read`);
    const replied = await call(homeroom, 'POST', `/parent-threads/${thread.id}/messages`, { body: 'Rahmat, qabul qildim. Sog\'ayib keting!' });
    expect(replied.statusCode).toBe(201);
    expect(replied.json().messages.map((m: { author: string; seen: boolean }) => [m.author, m.seen])).toEqual([
      ['PARENT', true],
      ['STAFF', false],
    ]);

    const pushes = t.fcm.pushesTo(mother.userId);
    expect(pushes).toHaveLength(1);
    expect(pushes[0]).toMatchObject({ data: { type: 'SCHOOL_PARENT_MESSAGE', threadId: thread.id } });
    expect(pushes[0]!.body).toContain('Rahmat');

    const mine = (await parentApi(mother.token, 'GET', '/threads')).json();
    expect(mine).toMatchObject({ unread: 1, items: [expect.objectContaining({ id: thread.id, lastAuthor: 'STAFF', unread: 1 })] });
    await parentApi(mother.token, 'POST', `/threads/${thread.id}/read`);
    expect((await parentApi(mother.token, 'GET', '/threads')).json().unread).toBe(0);
    const staffView = (await call(homeroom, 'GET', `/parent-threads/${thread.id}`)).json();
    expect(staffView.messages[1]).toMatchObject({ author: 'STAFF', seen: true });
  });

  it('keeps psychologist replies out of the push banner', async () => {
    const thread = (await start(psychologistId, 'Farzandim so\'nggi paytda xafa yuribdi.', { topic: 'WELLBEING' })).json();
    const psych = await login(t.app, 'psixolog');
    await call(psych, 'POST', `/parent-threads/${thread.id}/messages`, { body: 'Ertaga 14:00 da suhbatlashamiz.' });
    const [push] = t.fcm.pushesTo(mother.userId);
    expect(push!.body).not.toContain('14:00');
  });

  it('rejects other-class teachers, foreign threads and bad input', async () => {
    expect((await start(otherTeacherId)).statusCode).toBe(404);
    expect((await start(homeroomId, '   ')).statusCode).toBe(400);
    expect((await start(homeroomId, 'x'.repeat(1001))).statusCode).toBe(400);
    expect((await start(homeroomId, 'Salom', { topic: 'NOPE' })).statusCode).toBe(400);
    const thread = (await start(homeroomId)).json();
    expect((await parentApi(stranger.token, 'GET', `/threads/${thread.id}`)).statusCode).toBe(404);
    expect((await parentApi(stranger.token, 'POST', `/threads/${thread.id}/messages`, { body: 'Salom' })).statusCode).toBe(404);
  });

  it('is idempotent per client message id and reopens a resolved thread', async () => {
    const first = (await start(homeroomId, 'Salom', { clientMessageId: 'msg-00000001' })).json();
    const again = (await start(homeroomId, 'Salom', { clientMessageId: 'msg-00000001' })).json();
    expect(again.id).toBe(first.id);
    expect(again.messages).toHaveLength(1);

    const resolved = await call(homeroom, 'POST', `/parent-threads/${first.id}/status`, { status: 'RESOLVED' });
    expect(resolved.json().status).toBe('RESOLVED');
    const reopened = (await parentApi(mother.token, 'POST', `/threads/${first.id}/messages`, { body: 'Yana bir savol', topic: 'HOMEWORK' })).json();
    expect(reopened.status).toBe('OPEN');
    expect(reopened.messages.at(-1)).toMatchObject({ topic: 'HOMEWORK' });
  });

  it('refuses to write to a staff member who is no longer a contact', async () => {
    const thread = (await start(teacherId)).json();
    await t.prisma.schoolStaffClass.deleteMany({ where: { staffId: teacherId } });
    const res = await parentApi(mother.token, 'POST', `/threads/${thread.id}/messages`, { body: 'Salom' });
    expect(res.statusCode).toBe(409);
    expect((await parentApi(mother.token, 'GET', `/threads/${thread.id}`)).json().available).toBe(false);
  });

  it('rate-limits messages per day', async () => {
    const thread = (await start(homeroomId)).json();
    const old = new Date(Date.now() - 2 * 24 * 3_600_000);
    await t.prisma.schoolParentMessage.createMany({
      data: Array.from({ length: 29 }, () => ({ threadId: thread.id, author: 'PARENT', bodyEnc: 'v1.x.y', createdAt: new Date() })),
    });
    await t.prisma.schoolParentMessage.create({ data: { threadId: thread.id, author: 'PARENT', bodyEnc: 'v1.x.y', createdAt: old } });
    const res = await parentApi(mother.token, 'POST', `/threads/${thread.id}/messages`, { body: 'Yana' });
    expect(res.statusCode).toBe(429);
    expect(res.json()).toMatchObject({ code: 'RATE_LIMITED' });
  });

  it('builds the student overview: attendance, arrival, class average (K=5) and written tasks', async () => {
    const today = new Date(Date.now() + 5 * 3_600_000).toISOString().slice(0, 10);
    await t.prisma.schoolAttendance.create({
      data: { schoolId, studentId: fam.studentId, classId: cls6b, date: today, status: 'PRESENT', inAt: '08:05', source: 'KIOSK' },
    });
    await t.prisma.schoolLearningAssignment.create({
      data: { schoolId, materialKind: 'WRITTEN', materialId: 'written', title: 'Mening Vatanim', classIds: [cls6b], dueDate: today, byStaffId: homeroomId },
    });
    const res = await parentApi(mother.token, 'GET', `/students/${fam.studentId}/overview`);
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.student).toMatchObject({ id: fam.studentId, className: '6-B' });
    expect(body.period).toMatchObject({ kind: expect.stringMatching(/QUARTER|YEAR/), to: today });
    expect(body.attendance).toMatchObject({ classRate: null, weeks: expect.any(Array) });
    expect(body.attendance.weeks).toHaveLength(8);
    expect(body.tasks).toMatchObject({ total: 1, submitted: 0, items: [expect.objectContaining({ title: 'Mening Vatanim', state: 'TODO' })] });
    expect((await parentApi(stranger.token, 'GET', `/students/${fam.studentId}/overview`)).statusCode).toBe(404);
  });

  it('adds the sender and audience to announcements, and the action history to payments', async () => {
    const admin = await createStaff(t.prisma, schoolId, 'ADMIN', 'admin');
    await t.prisma.schoolStaff.update({ where: { id: admin.id }, data: { position: 'Direktor o\'rinbosari' } });
    const adminSession = await login(t.app, 'admin');
    await call(adminSession, 'POST', '/comms/announcements/send', draft(classesAudience(cls6b), 'Sport kiyimi'));
    const page = (await parentApi(mother.token, 'GET', '/announcements')).json();
    expect(page.items[0]).toMatchObject({
      title: 'Sport kiyimi',
      from: { role: 'ADMIN', position: 'Direktor o\'rinbosari' },
      audience: { kind: 'CLASSES', classNames: ['6-B'] },
    });

    await addPayment(t.prisma, schoolId, fam, '2026-12-15');
    const [payment] = (await parentApi(mother.token, 'GET', '/payments')).json();
    expect(payment.history).toEqual([{ at: '2026-09-01T05:00:00.000Z', action: 'CREATED' }]);
  });
});
