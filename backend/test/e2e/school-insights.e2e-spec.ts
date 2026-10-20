// Bosh sahifa, bildirishnomalar markazi, oylik hisobot va global qidiruv —
// rol va sinf doirasi, maxfiylik (xavfsizlik signalida tafsilot yo'q).

import { addDays, tashkentDay } from '../../src/common/time/tashkent';
import { resetDb } from './db';
import { createSchool, createStaff, login, LoggedIn } from './school-fixtures';
import { createClass, createGuardian, createStudent } from './school-students-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School insights', () => {
  let t: TestApp;
  let schoolId: string;
  let classA: string;
  let classB: string;
  let director: LoggedIn;

  const get = (who: LoggedIn, url: string) =>
    t.app.inject({ method: 'GET', url: `/api/school${url}`, headers: { authorization: `Bearer ${who.token}` } });

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    schoolId = (await createSchool(t.prisma)).school.id;
    classA = (await createClass(t.prisma, schoolId, 7, 'A')).id;
    classB = (await createClass(t.prisma, schoolId, 7, 'B')).id;
    director = await login(t.app, 'direktor');
  });

  afterAll(() => t.close());

  it('qidiruv: apostrof farqsiz, rol doirasida', async () => {
    await createStudent(t.prisma, schoolId, classA, { lastName: 'To‘xtayev', firstName: 'Ali' });
    await createStudent(t.prisma, schoolId, classB, { lastName: 'Toxirov', firstName: 'Vali' });
    await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar', [classA]);
    const homeroom = await login(t.app, 'rahbar');

    const all = (await get(director, `/search?q=${encodeURIComponent("to'xta")}`)).json();
    expect(all.students.map((s: { name: string }) => s.name)).toEqual(['To‘xtayev Ali']);
    expect((await get(director, '/search?q=7-')).json().classes.map((c: { name: string }) => c.name)).toEqual(['7-A', '7-B']);
    expect((await get(director, '/search?q=karimov')).json().staff[0]).toMatchObject({ name: 'Karimov Akmal' });
    expect((await get(director, '/search?q=t')).json()).toEqual({ students: [], classes: [], staff: [] });

    const scoped = (await get(homeroom, '/search?q=to')).json();
    expect(scoped.students.map((s: { name: string }) => s.name)).toEqual(['To‘xtayev Ali']);
    expect(scoped.staff).toEqual([]);
  });

  it('bildirishnomalar: rolga mos; xavfsizlik signalida tafsilot yo\'q', async () => {
    const a = await createStudent(t.prisma, schoolId, classA);
    const b = await createStudent(t.prisma, schoolId, classB, { firstName: 'Bobur' });
    await t.prisma.schoolEarlyExit.createMany({
      data: [
        { schoolId, studentId: a.id, classId: classA, date: tashkentDay(), time: '11:00', reason: 'Shifokor', pickupBy: 'Onasi' },
        { schoolId, studentId: b.id, classId: classB, date: tashkentDay(), time: '12:00', reason: 'Oilaviy', pickupBy: 'Otasi' },
      ],
    });
    await t.prisma.schoolStaffNotification.create({ data: { schoolId, kind: 'SAFETY_SIGNAL', roles: ['DIRECTOR', 'DUTY'], classIds: [], params: {} } });
    await t.prisma.schoolCareRequest.create({ data: { schoolId, studentId: a.id, classId: classA, topic: 'BULLYING', messageEnc: 'v1.x.y', urgency: 'URGENT' } });
    await t.prisma.schoolEmergency.create({ data: { schoolId, active: true, scope: 'CLASS', classIds: [classB], reason: 'Mashq', at: new Date() } });
    await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar', [classA]);
    await createStaff(t.prisma, schoolId, 'PSYCHOLOGIST', 'psixolog');
    const homeroom = await login(t.app, 'rahbar');
    const psych = await login(t.app, 'psixolog');

    const kinds = async (who: LoggedIn) => (await get(who, '/notifications/feed')).json().map((n: { kind: string }) => n.kind).sort();
    expect(await kinds(director)).toEqual(['EARLY_EXIT_PENDING', 'EARLY_EXIT_PENDING', 'EMERGENCY', 'SAFETY_SIGNAL']);
    expect(await kinds(homeroom)).toEqual(['EARLY_EXIT_PENDING']);
    expect(await kinds(psych)).toEqual(['CARE_URGENT']);

    const feed = (await get(director, '/notifications/feed')).json();
    expect(feed.find((n: { kind: string }) => n.kind === 'SAFETY_SIGNAL')).toMatchObject({ params: {}, subject: null, tone: 'destructive' });
    const care = (await get(psych, '/notifications/feed')).json()[0];
    expect(care).toMatchObject({ params: { className: '7-A' }, subject: { uz: 'Masxara / tazyiq' } });
    expect(JSON.stringify(care)).not.toContain('Karimov');
  });

  it('bosh sahifa: rolga mos bo\'limlar va ogohlantirishlar', async () => {
    const a = await createStudent(t.prisma, schoolId, classA);
    const a2 = await createStudent(t.prisma, schoolId, classA, { firstName: 'Sardor' });
    await createGuardian(t.prisma, schoolId, [a.id], { linkStatus: 'LINKED' });
    await t.prisma.schoolShift.updateMany({ where: { schoolId }, data: { weekdays: [1, 2, 3, 4, 5, 6, 7] } });
    await t.prisma.schoolAttendance.createMany({
      data: [
        { schoolId, studentId: a.id, classId: classA, date: tashkentDay(), status: 'PRESENT', source: 'MANUAL' },
        { schoolId, studentId: a2.id, classId: classA, date: tashkentDay(), status: 'ABSENT', source: 'SYSTEM' },
      ],
    });
    await t.prisma.schoolEarlyExit.create({
      data: { schoolId, studentId: a.id, classId: classA, date: tashkentDay(), time: '11:00', reason: 'X', pickupBy: 'Onasi' },
    });

    const overview = (await get(director, '/dashboard/overview')).json();
    expect(overview).toMatchObject({
      role: 'DIRECTOR',
      schoolDay: true,
      attendance: { counts: { present: 1, absent: 1, total: 2 }, rate: 50, arrived: 1, decided: 2 },
      parents: { students: { linked: 1, total: 2 } },
      openRequests: { earlyExits: 1, verifications: 0, total: 1 },
      careInbox: null,
      development: null,
    });
    expect(overview.classes.map((c: { className: string }) => c.className)).toEqual(['7-A', '7-B']);
    expect(overview.schoolMode).toMatchObject({ emergency: false, devices: { NO_PERMISSION: 2 } });
    expect(overview.alerts.map((x: { kind: string }) => x.kind)).toEqual(['ABSENT', 'NO_PERMISSION']);

    await createStaff(t.prisma, schoolId, 'PSYCHOLOGIST', 'psixolog');
    const psych = await login(t.app, 'psixolog');
    const p = (await get(psych, '/dashboard/overview')).json();
    expect(p).toMatchObject({ attendance: null, schoolMode: null, parents: null, careInbox: { newCount: 0 } });
  });

  it('oylik hisobot: faqat butun maktab doirasi, validatsiya, haqiqiy yozuvlar', async () => {
    const a = await createStudent(t.prisma, schoolId, classA);
    const yesterday = addDays(tashkentDay(), -1);
    const month = yesterday.slice(0, 7);
    await t.prisma.schoolAttendance.create({ data: { schoolId, studentId: a.id, classId: classA, date: yesterday, status: 'LATE', source: 'QR' } });

    expect((await get(director, '/reports/monthly?month=2026-13')).statusCode).toBe(400);
    const report = (await get(director, `/reports/monthly?month=${month}`)).json();
    expect(report).toMatchObject({ month, until: yesterday, generatedBy: 'Karimov Akmal', learning: { completedTasks: 0, assignments: 0 } });
    expect(report.attendance).toMatchObject({ rate: 100, late: 1, absent: 0 });
    expect(report.attendance.byClass[0]).toMatchObject({ className: '7-A', students: 1, rate: 100, late: 1 });
    expect(report.parents).toMatchObject({ linkedStudents: 0, totalStudents: 1 });
    expect(report.messages).toMatchObject({ announcements: 0, deliveryRate: 0 });
    expect(report.care).toMatchObject({ surveys: 0, requests: '0', groups: [] });

    await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar', [classA]);
    expect((await get(await login(t.app, 'rahbar'), `/reports/monthly?month=${month}`)).statusCode).toBe(403);
  });
});
