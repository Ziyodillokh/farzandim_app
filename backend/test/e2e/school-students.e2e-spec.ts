// O'quvchilar: CRUD, sinf doirasi, psixolog uchun qisqartirish, tenant,
// sinf almashganda ochiq yozuvlar ko'chishi, arxiv, CSV import, 360° karta.

import { tashkentDay } from '../../src/common/time/tashkent';
import { resetDb } from './db';
import { createSchool, createStaff, login, LoggedIn } from './school-fixtures';
import { createClass, createGuardian, createStudent } from './school-students-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School students', () => {
  let t: TestApp;
  let schoolId: string;
  let directorId: string;
  let classA: string;
  let classB: string;
  let director: LoggedIn;

  const call = (who: LoggedIn, method: 'GET' | 'POST' | 'PUT' | 'DELETE', url: string, payload?: unknown) =>
    t.app.inject({
      method,
      url: `/api/school/students${url}`,
      payload: payload as object,
      headers: { authorization: `Bearer ${who.token}` },
    });

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    const created = await createSchool(t.prisma);
    schoolId = created.school.id;
    directorId = created.director.id;
    classA = (await createClass(t.prisma, schoolId, 7, 'A')).id;
    classB = (await createClass(t.prisma, schoolId, 7, 'B')).id;
    director = await login(t.app, 'direktor');
  });

  afterAll(() => t.close());

  it('yaratish (ota-ona bilan), ro\'yxat qatori va audit', async () => {
    const res = await call(director, 'POST', '', {
      lastName: 'Karimov', firstName: 'Aziz', middleName: 'Akmal o\'g\'li', gender: 'MALE',
      birthDate: '2013-05-14', classId: classA, device: 'NONE',
      guardian: { fullName: 'Karimova Malika', phone: '+998901234567', relation: 'MOTHER' },
    });
    expect(res.statusCode).toBe(201);
    const student = res.json();
    expect(student).toMatchObject({ classId: classA, archived: false, enrolledAt: tashkentDay() });
    expect(student.studentCode).toMatch(/^P-\d{4}$/);
    expect(student.guardianIds).toHaveLength(1);

    const list = (await call(director, 'GET', '?search=karimova')).json();
    expect(list.pagination.total).toBe(1);
    expect(list.items[0]).toMatchObject({
      fullName: 'Karimov Aziz Akmal o\'g\'li', className: '7-A', grade: 7, linkStatus: 'NOT_INVITED',
      guardianNames: ['Karimova Malika'], deviceStatus: 'NO_PHONE', todayStatus: null,
    });
    const guardian = await t.prisma.schoolGuardian.findFirstOrThrow();
    expect(guardian.phone).toBe('+998 90 123 45 67');
    expect(await t.prisma.schoolAuditLog.count({ where: { action: 'student.create' } })).toBe(1);
  });

  it('validatsiya xabarlari panel formatida; boshqa maktab sinfi — xato', async () => {
    const base = { lastName: 'A', firstName: 'B', gender: 'MALE', birthDate: '2013-01-01', classId: classA, device: 'NONE' };
    const cases: Array<[object, string]> = [
      [{ ...base, lastName: ' ' }, 'lastName: errors.form.required'],
      [{ ...base, birthDate: '13.01.2013' }, 'birthDate: errors.form.invalidDate'],
      [{ ...base, guardian: { fullName: 'X', phone: '123', relation: 'MOTHER' } }, 'guardian.phone: errors.form.invalidPhone'],
    ];
    for (const [payload, message] of cases) {
      const res = await call(director, 'POST', '', payload);
      expect(res.statusCode).toBe(400);
      expect(res.json()).toMatchObject({ code: 'VALIDATION', message });
    }
    const other = await createSchool(t.prisma, 'other-school');
    const foreignClass = await createClass(t.prisma, other.school.id, 5, 'A');
    expect((await call(director, 'POST', '', { ...base, classId: foreignClass.id })).statusCode).toBe(400);
  });

  it('sinf rahbari faqat o\'z sinfini ko\'radi, boshqarolmaydi; tenant izolyatsiyasi', async () => {
    const a = await createStudent(t.prisma, schoolId, classA);
    const b = await createStudent(t.prisma, schoolId, classB, { firstName: 'Bobur' });
    await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar', [classA]);
    const homeroom = await login(t.app, 'rahbar');

    const list = (await call(homeroom, 'GET', '')).json();
    expect(list.items.map((r: { id: string }) => r.id)).toEqual([a.id]);
    expect((await call(homeroom, 'GET', `/${b.id}`)).statusCode).toBe(403);
    expect((await call(homeroom, 'GET', `?classId=${classB}`)).statusCode).toBe(403);
    expect((await call(homeroom, 'GET', '/class-options')).json()).toEqual([{ id: classA, name: '7-A' }]);
    expect((await call(homeroom, 'PUT', `/${a.id}/archived`, { archived: true })).statusCode).toBe(403);

    const other = await createSchool(t.prisma, 'other-school');
    const foreign = await createStudent(t.prisma, other.school.id, (await createClass(t.prisma, other.school.id, 7, 'A')).id);
    expect((await call(director, 'GET', `/${foreign.id}`)).statusCode).toBe(404);
    expect((await call(director, 'PUT', `/${foreign.id}/archived`, { archived: true })).statusCode).toBe(404);
  });

  it('psixolog: faqat ism va sinf (ota-ona, qurilma, davomat yo\'q)', async () => {
    const s = await createStudent(t.prisma, schoolId, classA);
    await createGuardian(t.prisma, schoolId, [s.id], { linkStatus: 'LINKED' });
    await createStaff(t.prisma, schoolId, 'PSYCHOLOGIST', 'psixolog');
    const psych = await login(t.app, 'psixolog');
    const row = (await call(psych, 'GET', '')).json().items[0];
    expect(row).toMatchObject({ fullName: 'Karimov Aziz', birthDate: '', guardianNames: [], linkStatus: 'NOT_INVITED', device: 'NONE' });
    expect((await call(psych, 'GET', '?linkStatus=LINKED')).json().items).toHaveLength(0);
    const detail = (await call(psych, 'GET', `/${s.id}`)).json();
    expect(detail).toMatchObject({ guardians: [], today: null, exceptions: [], deviceState: null, className: '7-A' });
    expect((await call(psych, 'GET', `/${s.id}/notes`)).statusCode).toBe(403);
  });

  it('sinf almashganda bugungi / ochiq yozuvlar ko\'chadi, o\'tgan tarix qoladi', async () => {
    const s = await createStudent(t.prisma, schoolId, classA);
    const today = tashkentDay();
    await t.prisma.schoolAttendance.createMany({
      data: [
        { schoolId, studentId: s.id, classId: classA, date: today, status: 'PRESENT', source: 'MANUAL' },
        { schoolId, studentId: s.id, classId: classA, date: '2026-09-15', status: 'LATE', source: 'MANUAL' },
      ],
    });
    await t.prisma.schoolEarlyExit.create({
      data: { schoolId, studentId: s.id, classId: classA, date: '2026-09-15', time: '11:00', reason: 'Shifokor', pickupBy: 'Onasi' },
    });
    const res = await call(director, 'PUT', `/${s.id}`, {
      lastName: 'Karimov', firstName: 'Aziz', gender: 'MALE', birthDate: '2013-05-14', classId: classB, device: 'IOS',
    });
    expect(res.statusCode).toBe(200);
    const rows = await t.prisma.schoolAttendance.findMany({ orderBy: { date: 'asc' } });
    expect(rows.map((r) => r.classId)).toEqual([classA, classB]);
    expect((await t.prisma.schoolEarlyExit.findFirstOrThrow()).classId).toBe(classB);
    const audit = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'student.update' } });
    expect(audit.before).toMatchObject({ classId: classA });
    expect(audit.after).toMatchObject({ classId: classB, device: 'IOS' });
  });

  it('arxiv: ro\'yxatdan yashiriladi, includeArchived bilan ko\'rinadi, tiklanadi', async () => {
    const s = await createStudent(t.prisma, schoolId, classA);
    expect((await call(director, 'PUT', `/${s.id}/archived`, { archived: true })).json().archived).toBe(true);
    expect((await call(director, 'GET', '')).json().pagination.total).toBe(0);
    expect((await call(director, 'GET', '?includeArchived=true')).json().pagination.total).toBe(1);
    expect((await call(director, 'PUT', `/${s.id}/archived`, { archived: 'yes' })).statusCode).toBe(400);
    await call(director, 'PUT', `/${s.id}/archived`, { archived: false });
    expect((await call(director, 'GET', '')).json().pagination.total).toBe(1);
    expect(await t.prisma.schoolAuditLog.count({ where: { action: { in: ['student.archive', 'student.restore'] } } })).toBe(2);
  });

  it('CSV import: yaroqli qatorlar, sabablari bilan o\'tkazilganlar, takrorlar', async () => {
    await createStudent(t.prisma, schoolId, classA, { lastName: 'Bor', firstName: 'Oldin', birthDate: '2013-01-01' });
    const rows = [
      ['Karimov', 'Aziz', 'Akmal o\'g\'li', '7-a', 'M', '2013-05-14', 'Karimova Malika', '+998 90 123 45 67'],
      ['Rasulova', 'Madina', '', '7B', 'Q', '02.09.2013', '', ''],
      ['Rasulova', 'Madina', '', '7-B', 'F', '2013-09-02', '', ''],
      ['Bor', 'Oldin', '', '7-A', 'M', '2013-01-01', '', ''],
      ['Yo\'q', 'Sinf', '', '9-V', 'M', '2013-01-01', '', ''],
      ['Sana', 'Xato', '', '7-A', 'M', '2013-02-30', '', ''],
      ['Tel', 'Xato', '', '7-A', 'M', '2013-02-03', 'Ota', '123'],
      ['', '', ''],
    ];
    const res = await call(director, 'POST', '/import', { rows });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({
      created: 2,
      skipped: [
        { row: 3, reason: 'duplicate' },
        { row: 4, reason: 'duplicate' },
        { row: 5, reason: 'class:9-V' },
        { row: 6, reason: 'birthDate' },
        { row: 7, reason: 'guardian.phone: errors.form.invalidPhone' },
      ],
    });
    const madina = await t.prisma.schoolStudent.findFirstOrThrow({ where: { firstName: 'Madina' } });
    expect(madina).toMatchObject({ gender: 'FEMALE', birthDate: '2013-09-02', classId: classB });
    expect(await t.prisma.schoolGuardian.count()).toBe(1);
    const audit = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'student.import' } });
    expect(audit.params).toEqual({ created: 2, skipped: 5 });
    expect((await call(director, 'POST', '/import', { rows: [] })).statusCode).toBe(400);
  });

  it('eslatmalar: matn auditga yozilmaydi; o\'chirish — muallif yoki direktor', async () => {
    const s = await createStudent(t.prisma, schoolId, classA);
    await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar', [classA]);
    await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar2', [classA]);
    const homeroom = await login(t.app, 'rahbar');
    const note = (await call(homeroom, 'POST', `/${s.id}/notes`, { text: 'Maxfiy kuzatuv matni' })).json();
    expect(note).toMatchObject({ studentId: s.id, classId: classA, text: 'Maxfiy kuzatuv matni' });
    const audit = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'student.note.add' } });
    expect(JSON.stringify(audit)).not.toContain('Maxfiy');
    expect(audit.params).toEqual({ name: 'Karimov Aziz', chars: 20 });

    const other = await login(t.app, 'rahbar2');
    const notes = (await call(other, 'GET', `/${s.id}/notes`)).json();
    expect(notes[0]).toMatchObject({ byName: 'HOMEROOM xodim', canDelete: false });
    expect((await call(other, 'DELETE', `/notes/${note.id}`)).statusCode).toBe(403);
    expect((await call(director, 'DELETE', `/notes/${note.id}`)).statusCode).toBe(204);
    expect((await call(director, 'POST', `/${s.id}/notes`, { text: 'x'.repeat(1001) })).statusCode).toBe(400);
  });

  it('360° tarix: barcha manbalar bitta lentada; to\'lov faqat payments.manage bilan', async () => {
    const s = await createStudent(t.prisma, schoolId, classA);
    const g = await createGuardian(t.prisma, schoolId, [s.id]);
    const att = await t.prisma.schoolAttendance.create({
      data: { schoolId, studentId: s.id, classId: classA, date: '2026-10-01', status: 'PRESENT', source: 'MANUAL' },
    });
    await t.prisma.schoolAttendanceCorrection.create({
      data: { attendanceId: att.id, byStaffId: directorId, from: 'ABSENT', to: 'PRESENT', reason: 'Kech belgilandi', at: new Date('2026-10-01T05:00:00Z') },
    });
    await t.prisma.schoolParentNotice.create({
      data: { schoolId, studentId: s.id, guardianId: g.id, date: '2026-10-02', kind: 'ARRIVED', delivered: true, at: new Date('2026-10-02T03:00:00Z') },
    });
    await t.prisma.schoolPaymentReminder.create({
      data: {
        schoolId, guardianId: g.id, studentIds: [s.id], nextDate: '2026-11-05',
        history: [{ at: '2026-10-03T05:00:00.000Z', byStaffId: directorId, action: 'CREATED', note: 'Oylik' }],
      },
    });
    const history = (await call(director, 'GET', `/${s.id}/history`)).json();
    expect(history.items.map((i: { kind: string }) => i.kind)).toEqual(['PAYMENT', 'NOTIFICATION', 'CORRECTION']);
    expect(history.items[2]).toMatchObject({ date: '2026-10-01', byName: 'Karimov Akmal', from: 'ABSENT' });
    expect(history.items[1]).toMatchObject({ guardianName: 'Karimova Malika', delivered: true });
    expect(history.payment).toEqual({ nextDate: '2026-11-05', paused: false, prepaidMonths: 0 });

    await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar', [classA]);
    const homeroom = await login(t.app, 'rahbar');
    const limited = (await call(homeroom, 'GET', `/${s.id}/history`)).json();
    expect(limited.payment).toBeNull();
    expect(limited.items.map((i: { kind: string }) => i.kind)).toEqual(['NOTIFICATION', 'CORRECTION']);
  });
});
