// To'lov eslatmalari sinflar kesimida: sinf filtri (ro'yxat, ko'rsatkichlar, eksport), sinf rahbarining
// faqat-ko'rish doirasi (o'z sinfi, boshqa sinfdagi aka-uka ko'rinmaydi) va sinf bo'yicha ommaviy yaratish.

import { resetDb } from './db';
import { createParent } from './factories';
import { addFamily, addGuardian, addPayment, createClass, Family, schoolCall } from './school-comms-fixtures';
import { createSchool, createStaff, login, LoggedIn } from './school-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School payments by class', () => {
  let t: TestApp;
  let call: ReturnType<typeof schoolCall>;
  let schoolId: string;
  let classA: string;
  let classB: string;
  let admin: LoggedIn;
  let homeroomA: LoggedIn;
  let teacher: LoggedIn;
  let a1: Family;
  let a2: Family;
  let b1: Family;

  beforeAll(async () => {
    t = await createTestApp();
    call = schoolCall(t.app);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    schoolId = (await createSchool(t.prisma)).school.id;
    classA = (await createClass(t.prisma, schoolId, 5, 'A')).id;
    classB = (await createClass(t.prisma, schoolId, 2, 'B')).id;
    await createStaff(t.prisma, schoolId, 'ADMIN', 'admin');
    await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar-a', [classA]);
    await createStaff(t.prisma, schoolId, 'TEACHER', 'oqituvchi', [classA]);
    admin = await login(t.app, 'admin');
    homeroomA = await login(t.app, 'rahbar-a');
    teacher = await login(t.app, 'oqituvchi');
    a1 = await addFamily(t.prisma, schoolId, classA, { lastName: 'Karimov', guardianName: 'Karimova Dilnoza' });
    a2 = await addFamily(t.prisma, schoolId, classA, { lastName: 'Rahimov', guardianName: 'Rahimova Malika' });
    b1 = await addFamily(t.prisma, schoolId, classB, { lastName: 'Yusupov', guardianName: 'Yusupova Zarina' });
  });

  afterAll(() => t.close());

  const names = (res: { json: () => { items: Array<{ guardianName: string }> } }) => res.json().items.map((r) => r.guardianName).sort();

  it('filters the list, the stats and the export by class', async () => {
    await addPayment(t.prisma, schoolId, a1, '2099-01-05', { prepaidMonths: 2 });
    await addPayment(t.prisma, schoolId, b1, '2099-01-05', { paused: true });

    expect(names(await call(admin, 'GET', `/comms/payments?classId=${classA}`))).toEqual(['Karimova Dilnoza']);
    expect(names(await call(admin, 'GET', `/comms/payments?classId=${classB}`))).toEqual(['Yusupova Zarina']);
    expect((await call(admin, 'GET', `/comms/payments/stats?classId=${classA}`)).json()).toMatchObject({ families: 1, prepaid: 1, paused: 0 });
    expect((await call(admin, 'GET', '/comms/payments/stats')).json()).toMatchObject({ families: 2, prepaid: 1, paused: 1 });
    const exported = (await call(admin, 'GET', `/comms/payments/export?classId=${classB}`)).json();
    expect(exported.map((r: { guardianName: string }) => r.guardianName)).toEqual(['Yusupova Zarina']);
  });

  it('gives the class teacher a read-only view of their own class, hiding siblings from other classes', async () => {
    // Bir oila: farzandlari 5-A va 2-B da.
    const sibling = await t.prisma.schoolStudent.create({
      data: { schoolId, classId: classB, lastName: 'Karimov', firstName: 'Ali', gender: 'MALE', birthDate: '2018-01-01', studentCode: 'P-SIB001', enrolledAt: '2026-09-02' },
    });
    await t.prisma.schoolStudentGuardian.create({ data: { studentId: sibling.id, guardianId: a1.guardianId } });
    const family = await t.prisma.schoolPaymentReminder.create({
      data: { schoolId, guardianId: a1.guardianId, studentIds: [a1.studentId, sibling.id], nextDate: '2099-01-05', history: [] },
    });
    const other = await addPayment(t.prisma, schoolId, b1, '2099-01-05');

    const list = (await call(homeroomA, 'GET', '/comms/payments')).json();
    expect(list.items).toHaveLength(1);
    expect(list.items[0].children.map((c: { classId: string }) => c.classId)).toEqual([classA]);
    expect((await call(homeroomA, 'GET', '/comms/payments/stats')).json()).toMatchObject({ families: 1 });
    expect((await call(homeroomA, 'GET', `/comms/payments/${family.id}/history`)).statusCode).toBe(200);

    expect((await call(homeroomA, 'GET', `/comms/payments?classId=${classB}`)).statusCode).toBe(403);
    expect((await call(homeroomA, 'GET', `/comms/payments/${other.id}/history`)).statusCode).toBe(403);
    expect((await call(homeroomA, 'POST', `/comms/payments/${family.id}/pause`, { note: 'Sinov' })).statusCode).toBe(403);
    expect((await call(homeroomA, 'POST', '/comms/payments/bulk-create', { classId: classA, nextDate: '2099-02-01', note: 'Sinov' })).statusCode).toBe(403);
    expect((await call(teacher, 'GET', '/comms/payments')).statusCode).toBe(403);
  });

  it('creates one family reminder per uncovered student of a class, preferring the Parvoz-linked guardian', async () => {
    const parent = await createParent(t.prisma);
    const father = await addGuardian(t.prisma, schoolId, a2.studentId, parent.userId); // a2: onasi (ulanmagan) + otasi (ulangan)
    await addPayment(t.prisma, schoolId, a1, '2099-01-05'); // a1 allaqachon bor
    const noGuardian = await t.prisma.schoolStudent.create({
      data: { schoolId, classId: classA, lastName: 'Toshev', firstName: 'Bek', gender: 'MALE', birthDate: '2015-01-01', studentCode: 'P-NOG001', enrolledAt: '2026-09-02' },
    });

    const res = await call(admin, 'POST', '/comms/payments/bulk-create', { classId: classA, nextDate: '2099-02-05', note: 'Noyabr to\'lovi' });
    expect(res.statusCode).toBe(201);
    expect(res.json()).toEqual({ created: 1, skipped: 1, noGuardian: 1 });

    const created = await t.prisma.schoolPaymentReminder.findFirstOrThrow({ where: { guardianId: father.id } });
    expect(created).toMatchObject({ studentIds: [a2.studentId], nextDate: '2099-02-05', paused: false });
    expect(await t.prisma.schoolPaymentReminder.count({ where: { studentIds: { has: noGuardian.id } } })).toBe(0);
    expect(await t.prisma.schoolPaymentReminder.count({ where: { studentIds: { has: b1.studentId } } })).toBe(0);
    const audit = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'payment.bulkCreate' } });
    expect(audit.params).toMatchObject({ className: '5-A', count: 1, date: '2099-02-05' });

    // Takror — hamma qamrab olingan.
    expect((await call(admin, 'POST', '/comms/payments/bulk-create', { classId: classA, nextDate: '2099-02-05', note: 'Takror' })).json()).toEqual({
      created: 0,
      skipped: 2,
      noGuardian: 1,
    });
    expect((await call(admin, 'POST', '/comms/payments/bulk-create', { classId: 'yoq', nextDate: '2099-02-05', note: 'x' })).statusCode).toBe(400);
  });
});
