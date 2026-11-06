// Men (I07): rejalashtirilgan va hodisaviy push'lar — kunlik eslatma (bola belgilagan vaqt), ertangi topshiriq
// eslatmasi (17:00) va maktab e'loni -> bolalar. Hammasi bir marta (qayta ishga tushirish dublikat bermaydi),
// push xatosi asosiy amalni yiqitmaydi.

import { DailyReminderService } from '../../src/modules/nudges/daily-reminder.service';
import { NudgeService } from '../../src/modules/nudges/nudge.service';
import { AnnouncementChildPushService } from '../../src/school/comms/announcement-child-push.service';
import { AnnouncementDeliveryService } from '../../src/school/comms/announcement-delivery.service';
import { CommsDispatcherService } from '../../src/school/comms/comms-dispatcher.service';
import { HomeworkReminderService } from '../../src/school/learning/homework-reminder.service';
import { resetDb } from './db';
import { createChild, TestChild } from './factories';
import { seedWorld, World } from './school-attendance-fixtures';
import { appReq, linkNewChild, schoolReq, unlinkedChild } from './school-child-fixtures';
import { createTestApp, TestApp } from './test-app';

// 2026-11-06, juma. 13:00 UTC = 18:00 Toshkent; 12:00 UTC = 17:00 Toshkent.
const AT_1800 = new Date('2026-11-06T13:00:00Z');
const AT_1700 = new Date('2026-11-06T12:00:00Z');

describe('Men notify: kunlik eslatma', () => {
  let t: TestApp;
  let w: World;
  let daily: DailyReminderService;

  beforeAll(async () => {
    t = await createTestApp();
    daily = t.app.get(DailyReminderService);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    w = await seedWorld(t);
  });

  afterAll(() => t.close());

  const setPrefs = (body: object, token = w.child.token) =>
    appReq(t, token, 'PUT', `/children/${w.child.childId}/notification-preferences`, body);
  const studyPushes = () => t.fcm.pushesTo(w.child.userId).filter((p) => p.data?.type === 'study_nudge');
  const completedAttempt = (completedAt: Date) =>
    t.prisma.learningAttempt.create({
      data: { childId: w.child.childId, subject: 'MATH', day: '2026-11-06', isDaily: true, status: 'COMPLETED', questionIds: [], total: 5, correct: 3, completedAt },
    });

  it('sends the study nudge at 18:00 by default (children without settings) exactly once', async () => {
    expect(await daily.run(new Date('2026-11-06T12:59:00Z'))).toBe(0);

    expect(await daily.run(AT_1800)).toBe(1);
    expect(await daily.run(new Date('2026-11-06T13:01:00Z'))).toBe(0);

    expect(studyPushes()).toHaveLength(1);
    expect(studyPushes()[0]).toMatchObject({ title: 'Parvoz', data: { type: 'study_nudge', childId: w.child.childId } });
    expect(await t.prisma.notification.count({ where: { childId: w.child.childId, type: 'STUDY_NUDGE' } })).toBe(1);
    expect(await t.prisma.childPushDedupe.findMany({ where: { childId: w.child.childId }, select: { kind: true, refKey: true } })).toEqual([
      { kind: 'STUDY_NUDGE', refKey: '2026-11-06' },
    ]);
    expect((await t.prisma.notificationPreference.findUniqueOrThrow({ where: { childId: w.child.childId } })).lastStudyNudgeAt).toEqual(AT_1800);
  });

  it('is atomic: parallel runs (several server instances) and repeated ticks inside the window send exactly one push', async () => {
    const runs = await Promise.all([daily.run(AT_1800), daily.run(AT_1800), daily.run(new Date('2026-11-06T13:01:00Z'))]);
    await daily.run(new Date('2026-11-06T13:04:00Z'));

    expect(runs.reduce((n, r) => n + r, 0)).toBe(1);
    expect(studyPushes()).toHaveLength(1);
  });

  it('sends again the next day (the once-a-day claim is per Tashkent day)', async () => {
    await daily.run(AT_1800);
    await daily.run(new Date('2026-11-07T13:00:00Z'));

    expect(studyPushes()).toHaveLength(2);
  });

  it('reaches many children in one run (bounded concurrency) and each exactly once', async () => {
    for (let i = 0; i < 12; i++) await createChild(t.prisma, w.parent, { name: `Bola ${i}` });

    const sent = await daily.run(AT_1800);
    await daily.run(new Date('2026-11-06T13:02:00Z'));

    expect(sent).toBe(13);
    expect(t.fcm.sent.filter((p) => p.payload.data?.type === 'study_nudge')).toHaveLength(13);
  });

  it('sends at the time the child chose instead of the fixed time', async () => {
    expect((await setPrefs({ dailyReminderTime: '19:30' })).statusCode).toBe(200);

    expect(await daily.run(AT_1800)).toBe(0);
    expect(await daily.run(new Date('2026-11-06T14:29:00Z'))).toBe(0);
    expect(await daily.run(new Date('2026-11-06T14:30:00Z'))).toBe(1);

    expect(studyPushes()).toHaveLength(1);
  });

  it('is not sent when the child turned the daily reminder off', async () => {
    await setPrefs({ dailyReminder: false });

    expect(await daily.run(AT_1800)).toBe(0);
    expect(studyPushes()).toHaveLength(0);
  });

  it('is not sent when the parent turned the study nudge off', async () => {
    await setPrefs({ studyNudge: false }, w.parent.token);

    expect(await daily.run(AT_1800)).toBe(0);
  });

  it('is not sent to a child who already completed a daily test today (Tashkent day), and is not re-checked afterwards', async () => {
    await completedAttempt(new Date('2026-11-06T04:00:00Z')); // 09:00 Toshkent, bugun

    expect(await daily.run(AT_1800)).toBe(0);
    expect(await daily.run(new Date('2026-11-06T13:01:00Z'))).toBe(0);

    expect(studyPushes()).toHaveLength(0);
    expect(await t.prisma.childPushDedupe.count({ where: { childId: w.child.childId, kind: 'STUDY_NUDGE' } })).toBe(1);
  });

  it('is not sent to a child who started an olympiad attempt today', async () => {
    const olympiad = await t.prisma.olympiad.create({
      data: { title: 'Sinov', subject: 'Matematika', ageFrom: 6, ageTo: 16, startTime: new Date('2026-11-01T00:00:00Z'), endTime: new Date('2026-11-30T00:00:00Z') },
    });
    await t.prisma.olympiadAttempt.create({ data: { childId: w.child.childId, olympiadId: olympiad.id, startedAt: new Date('2026-11-06T05:00:00Z') } });

    expect(await daily.run(AT_1800)).toBe(0);
  });

  it('still sends when the only completed test was yesterday in Tashkent', async () => {
    await completedAttempt(new Date('2026-11-05T18:00:00Z')); // 23:00 Toshkent, kecha

    expect(await daily.run(AT_1800)).toBe(1);
  });

  it('respects the child quiet hours (and does not use up the day)', async () => {
    await setPrefs({ quietFrom: '17:30', quietTo: '19:00' });

    expect(await daily.run(AT_1800)).toBe(0);
    expect(await t.prisma.childPushDedupe.count({ where: { kind: 'STUDY_NUDGE' } })).toBe(0);
  });

  it('no longer sends anything from the hourly tick at the old fixed 16:00', async () => {
    const res = await t.app.get(NudgeService).tick(new Date('2026-11-06T11:00:00Z'));

    expect(res).toEqual({ kind: null, sent: 0 });
    expect(studyPushes()).toHaveLength(0);
  });
});

describe('Men notify: ertangi topshiriq eslatmasi', () => {
  let t: TestApp;
  let w: World;
  let reminder: HomeworkReminderService;

  beforeAll(async () => {
    t = await createTestApp();
    reminder = t.app.get(HomeworkReminderService);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    w = await seedWorld(t);
  });

  afterAll(() => t.close());

  const assign = (over: Record<string, unknown> = {}) =>
    t.prisma.schoolLearningAssignment.create({
      data: {
        schoolId: w.schoolId,
        materialKind: 'TEST',
        materialId: 'test:MATH',
        classIds: [w.classA],
        dueDate: '2026-11-07',
        byStaffId: w.admin.staffId,
        createdAt: new Date('2026-11-04T08:00:00Z'),
        ...over,
      },
    });
  const homeworkPushes = (userId = w.child.userId) => t.fcm.pushesTo(userId).filter((p) => p.data?.type === 'HOMEWORK_DUE');
  const complete = (childId: string, completedAt: Date, subject: 'MATH' | 'ENGLISH' = 'MATH') =>
    t.prisma.learningAttempt.create({
      data: { childId, subject, day: '2026-11-05', isDaily: true, status: 'COMPLETED', questionIds: [], total: 5, completedAt },
    });
  const submission = (assignmentId: string, status: 'SUBMITTED' | 'ACCEPTED' | 'RETURNED') =>
    t.prisma.schoolHomeworkSubmission.create({ data: { assignmentId, studentId: w.vali, status } });

  it('sends one neutral HOMEWORK_DUE push for an assignment due tomorrow', async () => {
    await assign();

    expect(await reminder.remindDue(AT_1700)).toBe(1);

    expect(homeworkPushes()).toEqual([{ title: 'Parvoz', body: 'Ertaga topshiriq muddati', data: { type: 'HOMEWORK_DUE' } }]);
  });

  it('speaks Russian to a Russian-speaking child', async () => {
    await t.prisma.user.update({ where: { id: w.child.userId }, data: { language: 'ru' } });
    await assign();

    await reminder.remindDue(AT_1700);

    expect(homeworkPushes()[0]).toMatchObject({ body: 'Завтра срок задания' });
  });

  it('is idempotent: repeated and parallel runs on the same day send exactly one push per child', async () => {
    await assign();
    await assign({ materialId: 'test:ENGLISH' });

    const runs = await Promise.all([reminder.remindDue(AT_1700), reminder.remindDue(AT_1700), reminder.remindDue(new Date('2026-11-06T12:30:00Z'))]);
    await reminder.remindDue(new Date('2026-11-06T13:30:00Z'));

    expect(runs.reduce((n, r) => n + r, 0)).toBe(1);
    expect(homeworkPushes()).toHaveLength(1);
    expect(await t.prisma.childPushDedupe.count({ where: { childId: w.child.childId, kind: 'HOMEWORK_DUE' } })).toBe(1);
  });

  it('reminds again the next day for a new tomorrow', async () => {
    await assign();
    await assign({ dueDate: '2026-11-08' });

    await reminder.remindDue(AT_1700);
    await reminder.remindDue(new Date('2026-11-07T12:00:00Z'));

    expect(homeworkPushes()).toHaveLength(2);
  });

  it('ignores assignments that are not due tomorrow', async () => {
    await assign({ dueDate: '2026-11-06' });
    await assign({ dueDate: '2026-11-08' });
    await assign({ dueDate: '2026-11-05' });

    expect(await reminder.remindDue(AT_1700)).toBe(0);
  });

  it('only reminds students of the assigned class (other class and unlinked children get nothing)', async () => {
    const bek = await linkNewChild(t, w.bek);
    const alone = await unlinkedChild(t);
    await assign();

    await reminder.remindDue(AT_1700);

    expect(homeworkPushes()).toHaveLength(1);
    expect(homeworkPushes(bek.userId)).toHaveLength(0);
    expect(homeworkPushes(alone.userId)).toHaveLength(0);
  });

  it('skips archived students and inactive schools', async () => {
    await assign();
    await t.prisma.schoolStudent.update({ where: { id: w.vali }, data: { archived: true } });
    expect(await reminder.remindDue(AT_1700)).toBe(0);

    await t.prisma.schoolStudent.update({ where: { id: w.vali }, data: { archived: false } });
    await t.prisma.school.update({ where: { id: w.schoolId }, data: { status: 'SUSPENDED' } });
    expect(await reminder.remindDue(AT_1700)).toBe(0);
  });

  describe('done / submitted exclusions', () => {
    it('excludes a child who completed that subject test after the assignment was given', async () => {
      await assign();
      await complete(w.child.childId, new Date('2026-11-05T10:00:00Z'));

      expect(await reminder.remindDue(AT_1700)).toBe(0);
    });

    it('still reminds when the completed test is for another subject or older than the assignment', async () => {
      await assign();
      await complete(w.child.childId, new Date('2026-11-05T10:00:00Z'), 'ENGLISH');
      await complete(w.child.childId, new Date('2026-11-03T10:00:00Z'));

      expect(await reminder.remindDue(AT_1700)).toBe(1);
    });

    it('excludes written homework that was submitted or accepted, but not a returned one', async () => {
      const written = await assign({ materialKind: 'WRITTEN', materialId: 'written', title: 'Masala 5' });

      const sub = await submission(written.id, 'SUBMITTED');
      expect(await reminder.remindDue(AT_1700)).toBe(0);

      await t.prisma.schoolHomeworkSubmission.update({ where: { id: sub.id }, data: { status: 'ACCEPTED' } });
      expect(await reminder.remindDue(AT_1700)).toBe(0);

      await t.prisma.schoolHomeworkSubmission.update({ where: { id: sub.id }, data: { status: 'RETURNED' } });
      expect(await reminder.remindDue(AT_1700)).toBe(1);
    });

    it('reminds when one of two assignments is still open', async () => {
      await assign();
      await assign({ materialId: 'test:ENGLISH' });
      await complete(w.child.childId, new Date('2026-11-05T10:00:00Z'));

      expect(await reminder.remindDue(AT_1700)).toBe(1);
    });
  });

  describe('preferences', () => {
    it('skips a child who switched homework reminders off', async () => {
      await assign();
      await appReq(t, w.child.token, 'PUT', `/children/${w.child.childId}/notification-preferences`, { homeworkReminder: false });

      expect(await reminder.remindDue(AT_1700)).toBe(0);
    });

    it('skips a child in quiet hours', async () => {
      await assign();
      await appReq(t, w.child.token, 'PUT', `/children/${w.child.childId}/notification-preferences`, { quietFrom: '16:00', quietTo: '18:00' });

      expect(await reminder.remindDue(AT_1700)).toBe(0);
      // Tinch soatda kun "sarflanmaydi": tinch soat tugagach (17:30 dagi zaxira urinish) yuboriladi.
      expect(await t.prisma.childPushDedupe.count({ where: { kind: 'HOMEWORK_DUE' } })).toBe(0);
      await appReq(t, w.child.token, 'PUT', `/children/${w.child.childId}/notification-preferences`, { quietFrom: '16:00', quietTo: '17:10' });
      expect(await reminder.remindDue(new Date('2026-11-06T12:30:00Z'))).toBe(1);
    });
  });

  it('a failing push does not break the run and the next child still gets theirs', async () => {
    const bek = await linkNewChild(t, w.bek);
    await assign({ classIds: [w.classA, w.classB] });
    const original = t.fcm.sendPushToUser.bind(t.fcm);
    const spy = jest.spyOn(t.fcm, 'sendPushToUser').mockImplementation(async (userId, payload) => {
      if (userId === w.child.userId) throw new Error('fcm down');
      return original(userId, payload);
    });

    try {
      await expect(reminder.remindDue(AT_1700)).resolves.toBe(1);
    } finally {
      spy.mockRestore();
    }

    expect(homeworkPushes(bek.userId)).toHaveLength(1);
  });

  it('does not log or push any assignment content', async () => {
    await assign({ materialKind: 'WRITTEN', materialId: 'written', title: 'Maxfiy sarlavha', note: 'Maxfiy izoh' });

    await reminder.remindDue(AT_1700);

    expect(JSON.stringify(t.fcm.sent)).not.toContain('Maxfiy');
  });
});

describe('Men notify: maktab e\'loni -> bolalar', () => {
  let t: TestApp;
  let w: World;
  let bek: TestChild;
  let alone: TestChild;
  let childPush: AnnouncementChildPushService;

  beforeAll(async () => {
    t = await createTestApp();
    childPush = t.app.get(AnnouncementChildPushService);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    w = await seedWorld(t);
    bek = await linkNewChild(t, w.bek);
    alone = await unlinkedChild(t);
  });

  afterAll(() => t.close());

  const audience = (kind: string, extra: Record<string, unknown> = {}) => ({ kind, classIds: [], guardianIds: [], ...extra });
  const send = async (aud: object, title = "Ertaga yig'ilish") => {
    const res = await schoolReq(t, w.admin, 'POST', '/comms/announcements/send', {
      title,
      body: "Batafsil: soat 09:00 da zalda.",
      priority: 'NORMAL',
      audience: aud,
    });
    expect(res.statusCode).toBe(200);
    return res.json() as { id: string };
  };
  const announcementPushes = (userId: string) => t.fcm.pushesTo(userId).filter((p) => p.data?.type === 'SCHOOL_ANNOUNCEMENT');
  const setPrefs = (child: TestChild, body: object) => appReq(t, child.token, 'PUT', `/children/${child.childId}/notification-preferences`, body);

  it('whole school + includeStudents: pushes a neutral message to every linked child (and nobody else)', async () => {
    const a = await send(audience('SCHOOL', { includeStudents: true }));

    for (const child of [w.child, bek]) {
      expect(announcementPushes(child.userId)).toEqual([
        { title: 'Parvoz', body: 'Maktabdan yangi eʼlon', data: { type: 'SCHOOL_ANNOUNCEMENT', id: a.id } },
      ]);
    }
    expect(announcementPushes(alone.userId)).toHaveLength(0);
    // Ota-ona push'i avvalgidek (alohida, o'z ilovasi uchun).
    expect(t.fcm.pushesTo(w.parent.userId)).toHaveLength(1);
  });

  it('classes audience: only children of those classes', async () => {
    await send(audience('CLASSES', { classIds: [w.classB], includeStudents: true }));

    expect(announcementPushes(bek.userId)).toHaveLength(1);
    expect(announcementPushes(w.child.userId)).toHaveLength(0);
  });

  it('no child pushes without includeStudents or for a guardians-only audience', async () => {
    await send(audience('SCHOOL'));
    await send(audience('CLASSES', { classIds: [w.classA] }));
    await send(audience('GUARDIANS', { guardianIds: [w.guardianId], includeStudents: true }));

    expect(announcementPushes(w.child.userId)).toHaveLength(0);
    expect(announcementPushes(bek.userId)).toHaveLength(0);
  });

  it('skips children who switched school announcements off', async () => {
    await setPrefs(w.child, { schoolAnnouncements: false });

    await send(audience('SCHOOL', { includeStudents: true }));

    expect(announcementPushes(w.child.userId)).toHaveLength(0);
    expect(announcementPushes(bek.userId)).toHaveLength(1);
  });

  it('is always neutral: title, body and school never reach the lock screen, whatever hideText says', async () => {
    await setPrefs(w.child, { hideText: false });
    await setPrefs(bek, { hideText: true });

    await send(audience('SCHOOL', { includeStudents: true }), 'Maxfiy sarlavha');

    for (const child of [w.child, bek]) {
      expect(announcementPushes(child.userId)[0]).toMatchObject({ title: 'Parvoz', body: 'Maktabdan yangi e\u02bclon' });
      expect(JSON.stringify(announcementPushes(child.userId))).not.toContain('Maxfiy');
      expect(JSON.stringify(announcementPushes(child.userId))).not.toContain('Test maktab');
    }
  });

  it('skips archived students and children whose device account was removed', async () => {
    await t.prisma.schoolStudent.update({ where: { id: w.bek }, data: { archived: true } });
    await t.prisma.child.update({ where: { id: w.child.childId }, data: { childUserId: null } });

    await send(audience('SCHOOL', { includeStudents: true }));

    expect(announcementPushes(bek.userId)).toHaveLength(0);
    expect(announcementPushes(w.child.userId)).toHaveLength(0);
  });

  it('never pushes twice for the same announcement (retry / re-delivery)', async () => {
    const a = await send(audience('SCHOOL', { includeStudents: true }));

    expect(await childPush.notify(a.id)).toBe(0);
    await t.app.get(AnnouncementDeliveryService).pushPending(a.id, new Date());

    expect(announcementPushes(w.child.userId)).toHaveLength(1);
    expect(announcementPushes(bek.userId)).toHaveLength(1);
    expect(await t.prisma.childPushDedupe.count({ where: { kind: 'SCHOOL_ANNOUNCEMENT', refKey: a.id } })).toBe(2);
  });

  it('parallel notify calls still push once per child', async () => {
    const a = await send(audience('SCHOOL', { includeStudents: true }));
    t.fcm.reset();
    await t.prisma.childPushDedupe.deleteMany({});

    const results = await Promise.all([childPush.notify(a.id), childPush.notify(a.id), childPush.notify(a.id)]);

    expect(results.reduce((n, r) => n + r, 0)).toBe(2);
    expect(announcementPushes(w.child.userId)).toHaveLength(1);
    expect(announcementPushes(bek.userId)).toHaveLength(1);
  });

  it('a different announcement is a new push', async () => {
    await send(audience('SCHOOL', { includeStudents: true }), 'Birinchi');
    await send(audience('SCHOOL', { includeStudents: true }), 'Ikkinchi');

    expect(announcementPushes(w.child.userId)).toHaveLength(2);
  });

  it('a scheduled announcement pushes to children exactly once when it becomes due', async () => {
    const dispatcher = t.app.get(CommsDispatcherService);
    const res = await schoolReq(t, w.admin, 'POST', '/comms/announcements/send', {
      title: 'Rejali',
      body: 'Matn',
      priority: 'NORMAL',
      audience: audience('SCHOOL', { includeStudents: true }),
      scheduledAt: '2099-03-01T08:00',
    });
    expect(res.statusCode).toBe(200);
    t.fcm.reset();
    const due = new Date('2099-03-01T08:00:00+05:00');

    await Promise.all([dispatcher.dispatchDue(due), dispatcher.dispatchDue(due)]);
    await dispatcher.dispatchDue(new Date('2099-03-01T08:05:00+05:00'));

    expect(announcementPushes(w.child.userId)).toHaveLength(1);
    expect(announcementPushes(bek.userId)).toHaveLength(1);
  });

  it('a push failure for a child never fails sending the announcement', async () => {
    const spy = jest.spyOn(t.fcm, 'sendPushToUser').mockRejectedValue(new Error('fcm down'));

    try {
      const a = await send(audience('SCHOOL', { includeStudents: true }));
      const stored = await t.prisma.schoolAnnouncement.findUniqueOrThrow({ where: { id: a.id } });
      expect(stored.status).toBe('SENT');
    } finally {
      spy.mockRestore();
    }
  });

  it('does not leak the announcement body into any child push', async () => {
    await send(audience('SCHOOL', { includeStudents: true }), 'Sarlavha');

    for (const child of [w.child, bek]) expect(JSON.stringify(announcementPushes(child.userId))).not.toContain('zalda');
  });
});
