// Ota-onalar: doira, statistika, taklif kodi (bitta / ommaviy), ulanish
// ko'rsatkichlari va Parvoz Parents oqimi (kod → bog'lanish → farzand bilan
// moslash → qurilma holati → aloqani uzish).

import { createChild, createParent } from './factories';
import { resetDb } from './db';
import { createSchool, createStaff, login, LoggedIn } from './school-fixtures';
import { createClass, createGuardian, createStudent } from './school-students-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School guardians and parent links', () => {
  let t: TestApp;
  let schoolId: string;
  let classA: string;
  let classB: string;
  let director: LoggedIn;

  const staff = (who: LoggedIn, method: 'GET' | 'POST' | 'PUT', url: string, payload?: unknown) =>
    t.app.inject({ method, url: `/api/school${url}`, payload: payload as object, headers: { authorization: `Bearer ${who.token}` } });
  const parent = (token: string, method: 'GET' | 'POST' | 'PUT' | 'DELETE', url: string, payload?: unknown) =>
    t.app.inject({ method, url: `/api/parent/school${url}`, payload: payload as object, headers: { authorization: `Bearer ${token}` } });

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

  it('sinf rahbari faqat o\'z sinfidagi ota-onalarni va farzandlarini ko\'radi', async () => {
    const a = await createStudent(t.prisma, schoolId, classA, { firstName: 'Aziz' });
    const b = await createStudent(t.prisma, schoolId, classB, { firstName: 'Bobur' });
    await createGuardian(t.prisma, schoolId, [a.id, b.id], { fullName: 'Ikki farzandli' });
    await createGuardian(t.prisma, schoolId, [b.id], { fullName: 'Faqat B' });
    await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar', [classA]);
    const homeroom = await login(t.app, 'rahbar');

    const list = (await staff(homeroom, 'GET', '/guardians')).json();
    expect(list.items).toHaveLength(1);
    expect(list.items[0]).toMatchObject({ fullName: 'Ikki farzandli', children: [{ id: a.id, name: 'Karimov Aziz', className: '7-A' }] });
    expect((await staff(director, 'GET', '/guardians?classId=' + classB)).json().pagination.total).toBe(2);
    expect((await staff(director, 'GET', '/guardians?search=faqat')).json().items[0].fullName).toBe('Faqat B');
    expect((await staff(homeroom, 'GET', '/guardians/stats')).json()).toEqual({ LINKED: 0, INVITED: 0, NOT_INVITED: 1, total: 1 });

    const onlyB = await t.prisma.schoolGuardian.findFirstOrThrow({ where: { fullName: 'Faqat B' } });
    expect((await staff(homeroom, 'POST', `/guardians/${onlyB.id}/invite`)).statusCode).toBe(403);
    expect((await staff(homeroom, 'PUT', `/guardians/${onlyB.id}`, { fullName: 'X', phone: '+998901112233', relation: 'FATHER' })).statusCode).toBe(403);
  });

  it('taklif kodi: 8 belgi, 7 kun; ulangan ota-onaga — 409; ommaviy taklif filtr bo\'yicha', async () => {
    const a = await createStudent(t.prisma, schoolId, classA);
    const b = await createStudent(t.prisma, schoolId, classB, { firstName: 'Bobur' });
    const g1 = await createGuardian(t.prisma, schoolId, [a.id]);
    await createGuardian(t.prisma, schoolId, [a.id], { fullName: 'Karimov Akmal' });
    await createGuardian(t.prisma, schoolId, [b.id], { fullName: 'B ota-ona' });
    const linked = await createGuardian(t.prisma, schoolId, [b.id], { fullName: 'Ulangan', linkStatus: 'LINKED' });

    const invited = (await staff(director, 'POST', `/guardians/${g1.id}/invite`)).json();
    expect(invited.linkStatus).toBe('INVITED');
    expect(invited.inviteCode).toMatch(/^[A-HJ-NP-Z2-9]{8}$/);
    const days = (Date.parse(invited.inviteExpiresAt) - Date.now()) / 86_400_000;
    expect(days).toBeGreaterThan(6.9);
    expect((await staff(director, 'POST', `/guardians/${linked.id}/invite`)).statusCode).toBe(409);

    const bulk = await staff(director, 'POST', '/guardians/invite-bulk', { classId: classA });
    expect(bulk.json()).toEqual({ invited: 1 });
    expect((await staff(director, 'POST', '/guardians/invite-bulk', {})).json()).toEqual({ invited: 1 });
    expect((await staff(director, 'POST', '/guardians/invite-bulk', {})).json()).toEqual({ invited: 0 });
    const codes = (await t.prisma.schoolGuardian.findMany({ where: { linkStatus: 'INVITED' } })).map((g) => g.inviteCode);
    expect(new Set(codes).size).toBe(3);
    const audit = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'guardian.inviteBulk' }, orderBy: { at: 'asc' } });
    expect(audit.params).toEqual({ variant: 'codeClass', className: '7-A', count: 1 });

    const summary = (await staff(director, 'GET', '/guardians/link-summary')).json();
    expect(summary).toEqual({
      students: { linked: 1, total: 2, rate: 50 },
      guardians: { linked: 1, invited: 3, total: 4, rate: 25 },
    });
  });

  it('ota-ona qo\'shish va tahrirlash (telefon normallashadi, audit)', async () => {
    const a = await createStudent(t.prisma, schoolId, classA);
    const added = await staff(director, 'POST', `/students/${a.id}/guardians`, { fullName: 'Karimov Akmal', phone: '+998 93 765 43 21', relation: 'FATHER' });
    expect(added.statusCode).toBe(201);
    const g = added.json();
    expect(g).toMatchObject({ phone: '+998 93 765 43 21', linkStatus: 'NOT_INVITED' });
    const updated = (await staff(director, 'PUT', `/guardians/${g.id}`, { fullName: 'Karimov Akmal B.', phone: '+998937654321', relation: 'FATHER' })).json();
    expect(updated).toMatchObject({ fullName: 'Karimov Akmal B.' });
    expect((await staff(director, 'PUT', `/guardians/${g.id}`, { fullName: 'X', phone: '+1 555', relation: 'FATHER' })).json().message).toBe('phone: errors.form.invalidPhone');
    expect(await t.prisma.schoolAuditLog.count({ where: { module: 'GUARDIANS' } })).toBe(2);
  });

  it('Parvoz Parents: kod → bog\'lanish → farzand bilan moslash → qurilma holati → uzish', async () => {
    const student = await createStudent(t.prisma, schoolId, classA);
    const guardian = await createGuardian(t.prisma, schoolId, [student.id]);
    const code = (await staff(director, 'POST', `/guardians/${guardian.id}/invite`)).json().inviteCode as string;
    const mom = await createParent(t.prisma, { name: 'Malika' });
    const kid = await createChild(t.prisma, mom, { name: 'Aziz' });

    expect((await parent(mom.token, 'POST', '/link', { code: 'AB' })).statusCode).toBe(400);
    const redeemed = await parent(mom.token, 'POST', '/link', { code: code.toLowerCase() });
    expect(redeemed.statusCode).toBe(200);
    expect(redeemed.json()).toMatchObject({
      links: [{ guardianId: guardian.id, school: { name: 'Test maktab' }, students: [{ id: student.id, className: '7-A', childId: null, linkedBy: 'NONE' }] }],
      children: [{ id: kid.childId, name: 'Aziz' }],
    });
    const row = await t.prisma.schoolGuardian.findUniqueOrThrow({ where: { id: guardian.id } });
    expect(row).toMatchObject({ linkStatus: 'LINKED', userId: mom.userId, inviteCode: null });
    const audit = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'guardian.linked' } });
    expect(audit).toMatchObject({ actorId: null, actorName: 'Ota-ona: Karimova Malika' });
    expect((await parent(mom.token, 'POST', '/link', { code })).json().code).toBe('INVITE_INVALID');

    // Moslash: faqat o'z farzandi; boshqa ota-ona bu o'quvchini ko'rmaydi.
    const stranger = await createParent(t.prisma);
    const strangerKid = await createChild(t.prisma, stranger);
    expect((await parent(mom.token, 'PUT', `/students/${student.id}/child`, { childId: strangerKid.childId })).json().code).toBe('CHILD_NOT_FOUND');
    expect((await parent(stranger.token, 'PUT', `/students/${student.id}/child`, { childId: strangerKid.childId })).statusCode).toBe(404);
    const linked = (await parent(mom.token, 'PUT', `/students/${student.id}/child`, { childId: kid.childId })).json();
    expect(linked.links[0].students[0]).toMatchObject({ childId: kid.childId, linkedBy: 'ME' });

    // Xodim qurilma holatini ko'radi (foydalanish statistikasi emas).
    const detail = () => staff(director, 'GET', `/students/${student.id}`).then((r) => r.json());
    expect((await detail()).deviceState.status).toBe('OFFLINE');
    await t.prisma.child.update({ where: { id: kid.childId }, data: { lastSeenAt: new Date(), accessibilityEnabled: false } });
    expect((await detail()).deviceState.status).toBe('NO_PERMISSION');
    await t.prisma.child.update({ where: { id: kid.childId }, data: { accessibilityEnabled: true } });
    expect((await detail()).deviceState.status).toBe('APPLIED');
    await t.prisma.child.update({ where: { id: kid.childId }, data: { lastSeenAt: new Date(Date.now() - 3_600_000) } });
    expect((await detail()).deviceState.status).toBe('OFFLINE');
    expect((await staff(director, 'GET', '/students')).json().items[0]).toMatchObject({ linkStatus: 'LINKED', deviceStatus: 'OFFLINE' });

    // Aloqani uzish: vasiy bo'shaydi, farzand o'quvchidan uziladi.
    expect((await parent(stranger.token, 'DELETE', `/links/${guardian.id}`)).statusCode).toBe(404);
    expect((await parent(mom.token, 'DELETE', `/links/${guardian.id}`)).statusCode).toBe(204);
    expect(await t.prisma.schoolStudent.findUniqueOrThrow({ where: { id: student.id } })).toMatchObject({ childId: null });
    expect(await t.prisma.schoolGuardian.findUniqueOrThrow({ where: { id: guardian.id } })).toMatchObject({ linkStatus: 'NOT_INVITED', userId: null });
    expect((await parent(mom.token, 'GET', '/links')).json().links).toEqual([]);
  });

  it('muddati o\'tgan kod qabul qilinmaydi; bola tokeni bilan — 403', async () => {
    const student = await createStudent(t.prisma, schoolId, classA);
    await createGuardian(t.prisma, schoolId, [student.id], {
      linkStatus: 'INVITED', inviteCode: 'ABCD2345', inviteExpiresAt: new Date(Date.now() - 1000),
    });
    const mom = await createParent(t.prisma);
    const res = await parent(mom.token, 'POST', '/link', { code: 'abcd-2345' });
    expect(res.statusCode).toBe(404);
    expect(res.json().code).toBe('INVITE_INVALID');
    const kid = await createChild(t.prisma, mom);
    expect((await parent(kid.token, 'GET', '/links')).statusCode).toBe(403);
  });

  it('noto\'g\'ri kod: 5 ta xatodan keyin foydalanuvchi bloklanadi (to\'g\'ri kod ham)', async () => {
    const student = await createStudent(t.prisma, schoolId, classA);
    const guardian = await createGuardian(t.prisma, schoolId, [student.id]);
    const code = (await staff(director, 'POST', `/guardians/${guardian.id}/invite`)).json().inviteCode as string;
    const guesser = await createParent(t.prisma);
    for (let i = 0; i < 5; i++) {
      expect((await parent(guesser.token, 'POST', '/link', { code: `ZZZZZZ${i + 2}2` })).json().code).toBe('INVITE_INVALID');
    }
    const blocked = await parent(guesser.token, 'POST', '/link', { code });
    expect(blocked.statusCode).toBe(429);
    expect(blocked.json().code).toBe('TOO_MANY_ATTEMPTS');
    expect(await t.prisma.schoolGuardian.findUniqueOrThrow({ where: { id: guardian.id } })).toMatchObject({ linkStatus: 'INVITED' });
  });

  it('maktab tomonidan aloqani uzish: doira, farzand moslashi tozalanadi, audit', async () => {
    const a = await createStudent(t.prisma, schoolId, classA);
    const mom = await createParent(t.prisma);
    const kid = await createChild(t.prisma, mom);
    await t.prisma.schoolStudent.update({ where: { id: a.id }, data: { childId: kid.childId } });
    const guardian = await createGuardian(t.prisma, schoolId, [a.id], { linkStatus: 'LINKED', userId: mom.userId });
    await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar', [classB]);
    expect((await staff(await login(t.app, 'rahbar'), 'POST', `/guardians/${guardian.id}/unlink`)).statusCode).toBe(403);

    const res = await staff(director, 'POST', `/guardians/${guardian.id}/unlink`);
    expect(res.json()).toMatchObject({ linkStatus: 'NOT_INVITED', linkedAt: null });
    expect(await t.prisma.schoolStudent.findUniqueOrThrow({ where: { id: a.id } })).toMatchObject({ childId: null });
    expect((await staff(director, 'POST', `/guardians/${guardian.id}/unlink`)).statusCode).toBe(409);
    const audit = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'guardian.unlinked' } });
    expect(audit).toMatchObject({ actorName: 'Karimov Akmal', params: { name: 'Karimova Malika', variant: 'staff' } });
    expect((await parent(mom.token, 'GET', '/links')).json().links).toEqual([]);
  });
});
