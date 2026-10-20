// Maktab paneli S1: profil va bayramlar, sinflar, xodimlar (+ panel hisobi),
// audit, profil — ruxsatlar va sinf doirasi bilan.

import { resetDb } from './db';
import { createSchool, createStaff, login, LoggedIn } from './school-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School core (S1)', () => {
  let t: TestApp;
  let schoolId: string;
  let shiftId: string;
  let director: LoggedIn;

  const call = (
    s: LoggedIn,
    method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE',
    url: string,
    payload?: object,
  ) =>
    t.app.inject({
      method,
      url: `/api/school${url}`,
      headers: { authorization: `Bearer ${s.token}` },
      ...(payload && { payload }),
    });

  async function addStudent(classId: string, device: 'IOS' | 'NONE', linked: boolean) {
    const student = await t.prisma.schoolStudent.create({
      data: {
        schoolId,
        classId,
        lastName: 'Aliyev',
        firstName: 'Vali',
        gender: 'MALE',
        birthDate: '2014-03-01',
        device,
        studentCode: `P-${Math.floor(Math.random() * 1e6)}`,
        enrolledAt: '2026-09-02',
      },
    });
    await t.prisma.schoolGuardian.create({
      data: {
        schoolId,
        fullName: 'Aliyeva Nodira',
        phone: '+998 90 123 45 67',
        relation: 'MOTHER',
        linkStatus: linked ? 'LINKED' : 'NOT_INVITED',
        students: { create: { studentId: student.id } },
      },
    });
    return student;
  }

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    const created = await createSchool(t.prisma);
    schoolId = created.school.id;
    shiftId = (await t.prisma.schoolShift.findFirstOrThrow({ where: { schoolId } })).id;
    director = await login(t.app, 'direktor');
  });

  afterAll(() => t.close());

  describe('maktab profili', () => {
    it('ma\'lumot, tahrirlash (validatsiya xabari panel formatida), logo, bayramlar', async () => {
      const info = (await call(director, 'GET', '/info')).json();
      expect(info.school).toMatchObject({ name: 'Test maktab', lateAfterMinutes: 10 });
      expect(info.school).not.toHaveProperty('kioskSecret');
      expect(info.shifts[0].periods.length).toBeGreaterThan(0);

      const bad = await call(director, 'PUT', '/info', { name: '', shortName: 'T', city: 'X', academicYear: '2026', lateAfterMinutes: 5 });
      expect(bad.statusCode).toBe(400);
      expect(bad.json()).toMatchObject({ code: 'VALIDATION', message: 'name: errors.form.required' });
      const ok = await call(director, 'PUT', '/info', {
        name: '14-maktab', shortName: '14-M', city: 'Toshkent', academicYear: '2026–2027', lateAfterMinutes: 15,
      });
      expect(ok.json()).toMatchObject({ name: '14-maktab', lateAfterMinutes: 15 });

      expect((await call(director, 'PUT', '/logo', { logo: 'javascript:alert(1)' })).statusCode).toBe(400);
      expect((await call(director, 'PUT', '/logo', { logo: 'data:image/png;base64,iVBORw0KGgo=' })).json().logo).toContain('data:image/png');

      const holiday = (await call(director, 'POST', '/holidays', { date: '2026-12-31', name: 'Yangi yil' })).json();
      expect((await call(director, 'POST', '/holidays', { date: '2026-12-31', name: 'Takror' })).statusCode).toBe(409);
      expect((await call(director, 'DELETE', `/holidays/${holiday.id}`)).statusCode).toBe(204);

      const brand = await t.app.inject({ method: 'GET', url: '/api/school/public/brand?code=test-school' });
      expect(brand.json()).toEqual({
        name: '14-maktab',
        shortName: '14-M',
        logo: expect.stringContaining('data:image/png'),
        city: 'Toshkent',
        academicYear: '2026–2027',
      });
      const missing = await t.app.inject({ method: 'GET', url: '/api/school/public/brand?code=nope' });
      expect(missing.statusCode).toBe(404);
      expect(await t.prisma.schoolAuditLog.count({ where: { module: 'SETTINGS' } })).toBe(2);
    });

    it('navbatchi profilni tahrirlay olmaydi', async () => {
      await createStaff(t.prisma, schoolId, 'DUTY', 'navbatchi');
      const duty = await login(t.app, 'navbatchi');
      const res = await call(duty, 'PUT', '/info', {
        name: 'X', shortName: 'X', city: 'X', academicYear: 'X', lateAfterMinutes: 1,
      });
      expect(res.statusCode).toBe(403);
      expect(res.json().code).toBe('FORBIDDEN');
    });
  });

  describe('sinflar', () => {
    it('yaratish, qator statistikasi, takror nom, o\'quvchili sinfni o\'chirib bo\'lmaydi', async () => {
      const cls = (await call(director, 'POST', '/classes', { grade: 7, letter: 'a', shiftId })).json();
      expect(cls).toMatchObject({ name: '7-A', letter: 'A' });
      expect((await call(director, 'POST', '/classes', { grade: 7, letter: 'A', shiftId })).statusCode).toBe(409);
      expect((await call(director, 'POST', '/classes', { grade: 7, letter: 'B', shiftId: 'x' })).json().message).toBe('shiftId');

      await addStudent(cls.id, 'IOS', true);
      await addStudent(cls.id, 'NONE', false);
      const rows = (await call(director, 'GET', '/classes')).json();
      expect(rows[0]).toMatchObject({ name: '7-A', size: 2, linkedRate: 50, phoneRate: 50, shiftName: '1-smena' });
      expect((await call(director, 'GET', `/classes/${cls.id}/detail`)).json()).toMatchObject({
        notInvitedGuardians: 1,
        shift: { name: '1-smena' },
      });
      expect((await call(director, 'DELETE', `/classes/${cls.id}`)).statusCode).toBe(409);
    });

    it('sinf rahbari: biriktirish va doira (faqat o\'z sinfi)', async () => {
      const a = (await call(director, 'POST', '/classes', { grade: 5, letter: 'A', shiftId })).json();
      const b = (await call(director, 'POST', '/classes', { grade: 5, letter: 'B', shiftId })).json();
      const teacher = await createStaff(t.prisma, schoolId, 'HOMEROOM', 'sinf5a');
      const updated = await call(director, 'PUT', `/classes/${a.id}`, { grade: 5, letter: 'A', shiftId, homeroomStaffId: teacher.id });
      expect(updated.json().homeroomStaffId).toBe(teacher.id);

      const homeroom = await login(t.app, 'sinf5a');
      expect(homeroom.me.classIds).toEqual([a.id]);
      expect((await call(homeroom, 'GET', '/classes')).json().map((c: { id: string }) => c.id)).toEqual([a.id]);
      expect((await call(homeroom, 'GET', `/classes/${b.id}/detail`)).statusCode).toBe(403);
      expect((await call(homeroom, 'POST', '/classes', { grade: 6, letter: 'A', shiftId })).statusCode).toBe(403);
    });
  });

  describe('xodimlar', () => {
    it('yaratish (sinf rahbari sinfsiz bo\'lmaydi), ro\'yxat qidiruv / saralash, xulosa', async () => {
      const cls = (await call(director, 'POST', '/classes', { grade: 9, letter: 'V', shiftId })).json();
      const noClass = await call(director, 'POST', '/staff', {
        fullName: 'G‘ulomova Dilnoza', position: 'Sinf rahbari', role: 'HOMEROOM', phone: '+998901234567',
      });
      expect(noClass.json().message).toBe('classIds: errors.form.selectAtLeastOne');
      const created = (await call(director, 'POST', '/staff', {
        fullName: 'G‘ulomova Dilnoza', position: 'Sinf rahbari', role: 'HOMEROOM', phone: '+998 90 123 45 67', classIds: [cls.id],
      })).json();
      expect(created).toMatchObject({ phone: '+998 90 123 45 67', classIds: [cls.id], username: null });
      expect((await t.prisma.schoolClass.findUniqueOrThrow({ where: { id: cls.id } })).homeroomStaffId).toBe(created.id);

      const search = (await call(director, 'GET', "/staff?search=G'ulomova")).json();
      expect(search.items.map((s: { id: string }) => s.id)).toEqual([created.id]);
      expect(search.items[0].classNames).toEqual(['9-V']);
      const page = (await call(director, 'GET', '/staff?limit=1&sortBy=name&sortDir=desc')).json();
      expect(page.pagination).toMatchObject({ total: 2, totalPages: 2 });
      expect((await call(director, 'GET', '/staff/summary')).json()).toMatchObject({ total: 2, active: 2, demo: 1 });
    });

    it('o\'z rolini o\'zgartirib / o\'zini faolsizlantirib bo\'lmaydi', async () => {
      const self = director.me.staff.id;
      const res = await call(director, 'PUT', `/staff/${self}`, {
        fullName: 'Karimov Akmal', position: 'Direktor', role: 'ADMIN', phone: '+998901112233',
      });
      expect(res.statusCode).toBe(409);
      expect((await call(director, 'PATCH', `/staff/${self}/active`, { active: false })).statusCode).toBe(409);
    });

    it('panel hisobi: yaratish → kirish; faolsizlantirish sessiyani yopadi; hisobni o\'chirish', async () => {
      const staff = await createStaff(t.prisma, schoolId, 'DUTY', 'old');
      const account = await call(director, 'PUT', `/staff/${staff.id}/account`, { username: 'Navbatchi1', password: 'Temporary-2026' });
      expect(account.json().username).toBe('navbatchi1');
      const duty = await login(t.app, 'navbatchi1', 'test-school', 'Temporary-2026');
      expect((await t.prisma.schoolStaff.findUniqueOrThrow({ where: { id: staff.id } })).mustChangePassword).toBe(true);

      expect((await call(director, 'PATCH', `/staff/${staff.id}/active`, { active: false })).json().active).toBe(false);
      expect((await call(duty, 'GET', '/profile/me')).statusCode).toBe(401);

      await call(director, 'PATCH', `/staff/${staff.id}/active`, { active: true });
      expect((await call(director, 'DELETE', `/staff/${staff.id}/account`)).json().username).toBeNull();
      const relogin = await t.app.inject({
        method: 'POST', url: '/api/school/auth/login', payload: { school: 'test-school', username: 'navbatchi1', password: 'Temporary-2026' },
      });
      expect(relogin.statusCode).toBe(401);
      const taken = await call(director, 'PUT', `/staff/${staff.id}/account`, { username: 'direktor', password: 'Temporary-2026' });
      expect(taken.statusCode).toBe(409);
    });
  });

  describe('audit va profil', () => {
    it('jurnal: filtr, qidiruv; CARE yozuvlari direktorga ko\'rinmaydi', async () => {
      await call(director, 'POST', '/classes', { grade: 3, letter: 'A', shiftId });
      await t.prisma.schoolAuditLog.create({
        data: { schoolId, actorName: 'Psixolog', module: 'CARE', action: 'care.note', summary: 'maxfiy' },
      });
      const all = (await call(director, 'GET', '/audit')).json();
      expect(all.items.map((a: { module: string }) => a.module)).toEqual(['CLASSES', 'AUTH']);
      const byModule = (await call(director, 'GET', '/audit?module=CLASSES&search=3-a')).json();
      expect(byModule.items).toHaveLength(1);
      expect(byModule.items[0]).toMatchObject({ action: 'class.create', params: { name: '3-A' } });
      expect((await call(director, 'GET', '/audit/actors')).json()).toEqual([{ id: director.me.staff.id, name: 'Karimov Akmal' }]);

      await createStaff(t.prisma, schoolId, 'PSYCHOLOGIST', 'psixolog');
      const psych = await login(t.app, 'psixolog');
      expect((await call(psych, 'GET', '/audit')).statusCode).toBe(403);
    });

    it('profil: o\'z rasmi; boshqaniki — faqat staff.manage', async () => {
      const duty = await createStaff(t.prisma, schoolId, 'DUTY', 'navbatchi');
      const dutySession = await login(t.app, 'navbatchi');
      const photo = 'data:image/png;base64,iVBORw0KGgo=';
      expect((await call(dutySession, 'PUT', `/profile/photo/${duty.id}`, { photo })).json().photo).toBe(photo);
      expect((await call(dutySession, 'PUT', `/profile/photo/${director.me.staff.id}`, { photo })).statusCode).toBe(403);
      expect((await call(dutySession, 'PUT', `/profile/photo/${duty.id}`, { photo: 'data:image/svg+xml;base64,PHN2Zz4=' })).statusCode).toBe(400);
      const avatars = (await call(dutySession, 'GET', '/profile/avatars')).json();
      expect(Object.keys(avatars)).toHaveLength(2);
      expect((await call(dutySession, 'GET', '/profile/me')).json()).toMatchObject({ username: 'navbatchi', role: 'DUTY' });
    });
  });
});
