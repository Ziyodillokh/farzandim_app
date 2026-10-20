// School Mode: siyosat, ilovalar, smena, istisno, favqulodda o'chirish,
// qurilmalar va ota-onaga eslatma; bola qurilmasiga virtual "Maktab"
// jadvallari (Android bola ilovasi shularni qo'llaydi).

import { tashkentDay, tashkentDayStart, addDays } from '../../src/common/time/tashkent';
import { minutesToHhmm, tashkentMinute } from '../../src/school/school-mode/school-mode-time';
import { createChild, createParent, TestChild } from './factories';
import { resetDb } from './db';
import { createSchool, createStaff, login, LoggedIn } from './school-fixtures';
import { createClass, createGuardian, createStudent } from './school-students-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School Mode', () => {
  let t: TestApp;
  let schoolId: string;
  let shiftId: string;
  let classA: string;
  let classB: string;
  let director: LoggedIn;

  const call = (who: LoggedIn, method: 'GET' | 'POST' | 'PUT' | 'DELETE', url: string, payload?: unknown) =>
    t.app.inject({ method, url: `/api/school/school-mode${url}`, payload: payload as object, headers: { authorization: `Bearer ${who.token}` } });
  const routines = (token: string, childId: string) =>
    t.app.inject({ method: 'GET', url: `/api/children/${childId}/routines`, headers: { authorization: `Bearer ${token}` } });
  const settle = () => new Promise((r) => setTimeout(r, 50));

  /** Hozirgi daqiqani o'z ichiga olgan bitta dars (har kuni) — natija soatga bog'liq bo'lmasin. */
  async function lessonAroundNow() {
    const m = tashkentMinute(new Date());
    const start = Math.max(0, m - 60);
    const end = Math.min(1439, m + 60);
    await t.prisma.schoolShift.update({
      where: { id: shiftId },
      data: {
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        start: minutesToHhmm(start),
        end: minutesToHhmm(end),
        periods: [{ no: 1, start: minutesToHhmm(start), end: minutesToHhmm(end), kind: 'LESSON' }],
      },
    });
  }

  async function linkedChild(classId: string): Promise<{ kid: TestChild; studentId: string; parentToken: string; parentUserId: string }> {
    const mom = await createParent(t.prisma);
    const kid = await createChild(t.prisma, mom);
    await t.prisma.child.update({ where: { id: kid.childId }, data: { lastSeenAt: new Date(), accessibilityEnabled: true } });
    const student = await createStudent(t.prisma, schoolId, classId, { childId: kid.childId });
    await createGuardian(t.prisma, schoolId, [student.id], { linkStatus: 'LINKED', userId: mom.userId });
    await t.prisma.installedApp.createMany({
      data: [
        { childId: kid.childId, packageName: 'com.supercell.clashofclans', appName: 'Clash of Clans', category: 'GAME' },
        { childId: kid.childId, packageName: 'org.telegram.messenger', appName: 'Telegram', category: 'SOCIAL' },
        { childId: kid.childId, packageName: 'com.google.android.youtube', appName: 'YouTube', category: 'VIDEO' },
        { childId: kid.childId, packageName: 'uz.kundalik.app', appName: 'Kundalik', category: 'EDU' },
        { childId: kid.childId, packageName: 'com.android.dialer', appName: 'Phone', category: 'OTHER', isSystem: true },
        { childId: kid.childId, packageName: 'com.farzandim.growth', appName: 'Parvoz Growth', category: 'GAME' },
      ],
    });
    return { kid, studentId: student.id, parentToken: mom.token, parentUserId: mom.userId };
  }

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    schoolId = (await createSchool(t.prisma)).school.id;
    shiftId = (await t.prisma.schoolShift.findFirstOrThrow({ where: { schoolId } })).id;
    classA = (await createClass(t.prisma, schoolId, 7, 'A')).id;
    classB = (await createClass(t.prisma, schoolId, 7, 'B')).id;
    director = await login(t.app, 'direktor');
  });

  afterAll(() => t.close());

  it('siyosat: standart o\'chiq; yoqish, validatsiya, ruxsat va audit', async () => {
    await lessonAroundNow();
    const policy = (await call(director, 'GET', '/policy')).json();
    expect(policy).toMatchObject({ enabled: false, alwaysAllowCalls: true, blockedCategories: ['GAME', 'SOCIAL', 'VIDEO'], shiftIds: [shiftId] });
    expect((await call(director, 'GET', '/overview')).json().classes[0].state.kind).toBe('DISABLED');

    expect((await call(director, 'PUT', '/policy', { blockedCategories: [] })).json().message).toBe('blockedCategories: errors.form.selectAtLeastOne');
    expect((await call(director, 'PUT', '/policy', { shiftIds: ['nope'] })).statusCode).toBe(400);
    const updated = (await call(director, 'PUT', '/policy', { enabled: true, relaxDuringBreaks: true })).json();
    expect(updated).toMatchObject({ enabled: true, relaxDuringBreaks: true });
    const overview = (await call(director, 'GET', '/overview')).json();
    expect(overview).toMatchObject({ policyEnabled: true, today: tashkentDay(), emergency: { active: false } });
    expect(overview.classes[0].state).toMatchObject({ kind: 'LESSON', restricted: true });
    expect(overview.totals).toMatchObject({ classes: 2, restrictedClasses: 2 });

    await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar', [classA]);
    const homeroom = await login(t.app, 'rahbar');
    expect((await call(homeroom, 'GET', '/overview')).json().classes.map((c: { classId: string }) => c.classId)).toEqual([classA]);
    expect((await call(homeroom, 'PUT', '/policy', { enabled: false })).statusCode).toBe(403);
    expect(await t.prisma.schoolModePolicy.count()).toBe(1);
    expect(await t.prisma.schoolAuditLog.count({ where: { action: 'policy.update' } })).toBe(1);
  });

  it('ruxsat etilgan ilovalar va smena jadvali', async () => {
    const added = await call(director, 'POST', '/policy/apps', { name: 'YouTube', category: 'VIDEO' });
    expect(added.statusCode).toBe(201);
    const app = added.json().allowedApps[0];
    expect((await call(director, 'POST', '/policy/apps', { name: 'youtube', category: 'VIDEO' })).json()).toMatchObject({
      code: 'CONFLICT', message: 'name: schoolMode.validation.appExists',
    });
    expect((await call(director, 'DELETE', `/policy/apps/${app.id}`)).json().allowedApps).toEqual([]);
    expect((await call(director, 'DELETE', `/policy/apps/${app.id}`)).statusCode).toBe(404);

    const shift = await call(director, 'PUT', `/shifts/${shiftId}`, {
      weekdays: [5, 1, 3],
      periods: [
        { start: '08:00', end: '08:45', kind: 'LESSON' },
        { start: '08:45', end: '08:55', kind: 'BREAK' },
        { start: '08:55', end: '09:40', kind: 'LESSON' },
      ],
    });
    expect(shift.json()).toMatchObject({ weekdays: [1, 3, 5], start: '08:00', end: '09:40', periods: [{ no: 1 }, { no: 1 }, { no: 2 }] });
    const overlap = await call(director, 'PUT', `/shifts/${shiftId}`, {
      weekdays: [1],
      periods: [{ start: '08:00', end: '08:45', kind: 'LESSON' }, { start: '08:40', end: '09:00', kind: 'LESSON' }],
    });
    expect(overlap.json().message).toBe('periods.1.start: schoolMode.validation.overlap');
    const edge = await call(director, 'PUT', `/shifts/${shiftId}`, { weekdays: [1], periods: [{ start: '08:00', end: '08:45', kind: 'BREAK' }] });
    expect(edge.json().message).toBe('periods: schoolMode.validation.edgeLesson');
    const shifts = (await call(director, 'GET', '/shifts')).json();
    expect(shifts[0]).toMatchObject({ lessonCount: 2, classes: [{ name: '7-A' }, { name: '7-B' }], studentCount: 0 });
  });

  it('istisno: muddat chegaralari, ustma-ust, doira, bekor qilish', async () => {
    const now = Date.now();
    const endOfDay = tashkentDayStart(addDays(tashkentDay(), 1)).getTime();
    if (endOfDay - now < 20 * 60_000) return; // yarim tunga 20 daqiqadan kam — muddat oynasi yo'q
    const a = await createStudent(t.prisma, schoolId, classA);
    const b = await createStudent(t.prisma, schoolId, classB, { firstName: 'Bobur' });
    const until = new Date(Math.min(now + 30 * 60_000, endOfDay - 60_000)).toISOString();

    const tooSoon = await call(director, 'POST', '/exceptions', { studentId: a.id, until: new Date(now + 60_000).toISOString(), reason: 'Shifokor' });
    expect(tooSoon.json().message).toBe('until: schoolMode.validation.untilPast');
    const tooFar = await call(director, 'POST', '/exceptions', { studentId: a.id, until: new Date(endOfDay + 3_600_000).toISOString(), reason: 'X' });
    expect(tooFar.json().message).toBe('until: schoolMode.validation.untilTooFar');

    const created = await call(director, 'POST', '/exceptions', { studentId: a.id, until, reason: 'Ota-onasiga qo\'ng\'iroq' });
    expect(created.statusCode).toBe(201);
    expect((await call(director, 'POST', '/exceptions', { studentId: a.id, until, reason: 'Yana' })).json().message).toBe('studentId: schoolMode.validation.alreadyActive');

    await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar', [classA]);
    const homeroom = await login(t.app, 'rahbar');
    expect((await call(homeroom, 'POST', '/exceptions', { studentId: b.id, until, reason: 'X' })).statusCode).toBe(403);
    const list = (await call(homeroom, 'GET', '/exceptions')).json();
    expect(list.counts).toMatchObject({ ACTIVE: 1 });
    expect(list.items[0]).toMatchObject({ studentName: 'Karimov Aziz', className: '7-A', byName: 'Karimov Akmal', status: 'ACTIVE' });

    const id = created.json().id;
    expect((await call(homeroom, 'POST', `/exceptions/${id}/revoke`)).json().revokedAt).toEqual(expect.any(String));
    expect((await call(homeroom, 'POST', `/exceptions/${id}/revoke`)).statusCode).toBe(409);
    expect((await call(director, 'GET', '/exceptions?status=REVOKED')).json().items).toHaveLength(1);
  });

  it('favqulodda o\'chirish: sinflar qo\'shiladi, maktab bo\'yicha toraytirilmaydi', async () => {
    await lessonAroundNow();
    await call(director, 'PUT', '/policy', { enabled: true });
    const on = await call(director, 'POST', '/emergency', { scope: 'CLASS', classIds: [classA], reason: 'Evakuatsiya mashqi' });
    expect(on.json()).toMatchObject({ active: true, scope: 'CLASS', classIds: [classA] });
    const merged = (await call(director, 'POST', '/emergency', { scope: 'CLASS', classIds: [classB], reason: 'Mashq' })).json();
    expect(merged.classIds.sort()).toEqual([classA, classB].sort());
    const states = (await t.app.inject({ method: 'GET', url: '/api/school/school-mode/classes/now', headers: { authorization: `Bearer ${director.token}` } })).json();
    expect(states[classA].kind).toBe('EMERGENCY_OFF');

    expect((await call(director, 'POST', '/emergency', { scope: 'CLASS', classIds: [], reason: 'x' })).json().message).toBe('classIds: errors.form.selectAtLeastOne');
    await call(director, 'POST', '/emergency', { scope: 'SCHOOL', reason: 'Yong\'in signali' });
    expect((await call(director, 'POST', '/emergency', { scope: 'CLASS', classIds: [classA], reason: 'x' })).json().message).toBe('scope: schoolMode.validation.emergencySchoolActive');
    const overview = (await call(director, 'GET', '/overview')).json();
    expect(overview.emergency).toMatchObject({ active: true, scope: 'SCHOOL', byName: 'Karimov Akmal' });
    expect(overview.totals.restrictedClasses).toBe(0);

    expect((await call(director, 'POST', '/emergency/off')).json()).toMatchObject({ active: false, classIds: [] });
    expect((await call(director, 'POST', '/emergency/off')).statusCode).toBe(409);
    expect(await t.prisma.schoolAuditLog.count({ where: { action: { in: ['emergency.on', 'emergency.off'] } } })).toBe(4);
  });

  it('qurilmalar va ota-onaga eslatma (faqat ruxsati yo\'q, Parents\'ga ulanganlar)', async () => {
    const ok = await linkedChild(classA);
    const noPerm = await linkedChild(classA);
    await t.prisma.child.update({ where: { id: noPerm.kid.childId }, data: { accessibilityEnabled: false } });
    const unlinked = await createStudent(t.prisma, schoolId, classB, { firstName: 'Ulanmagan' });
    await createStudent(t.prisma, schoolId, classB, { firstName: 'Telefonsiz', device: 'NONE' });

    const devices = (await call(director, 'GET', '/devices')).json();
    expect(devices.items.map((d: { status: string }) => d.status)).toEqual(['NO_PERMISSION', 'NO_PERMISSION', 'NO_PHONE', 'APPLIED']);
    expect((await call(director, 'GET', '/devices?status=APPLIED')).json().items[0].studentId).toBe(ok.studentId);

    const res = await call(director, 'POST', '/remind', { studentIds: [ok.studentId, noPerm.studentId, unlinked.id] });
    expect(res.json()).toEqual({ sent: 1, skipped: 2 });
    const push = t.fcm.pushesTo(noPerm.parentUserId)[0];
    expect(push).toMatchObject({ title: 'Maktab: telefon tartibi', data: { type: 'SCHOOL_MODE_REMIND', studentId: noPerm.studentId } });
    expect(push?.body).toContain('Aziz');
    expect(t.fcm.pushesTo(ok.parentUserId)).toHaveLength(0);
    expect((await call(director, 'POST', '/remind', { studentIds: [] })).statusCode).toBe(400);
  });

  it('bola qurilmasi: virtual "Maktab" jadvali — toifalar, ruxsat etilgan ilova, favqulodda, istisno', async () => {
    await lessonAroundNow();
    const { kid, studentId, parentToken } = await linkedChild(classA);
    const schoolRoutines = async () =>
      (await routines(kid.token, kid.childId)).json().routines.filter((r: { type: string; title: string }) => r.title.startsWith('Maktab'));

    expect(await schoolRoutines()).toEqual([]); // siyosat o'chiq
    const spy = jest.spyOn(t.fcm, 'pushChildResync');
    await call(director, 'PUT', '/policy', { enabled: true });
    await call(director, 'POST', '/policy/apps', { name: 'YouTube', category: 'VIDEO' });
    await settle();
    expect(spy).toHaveBeenCalledWith(kid.userId);

    const [routine] = await schoolRoutines();
    expect(routine).toMatchObject({ type: 'SCHOOL', isActive: true, source: 'SCHOOL_MODE' });
    expect(routine.blockedApps).toEqual(['com.supercell.clashofclans', 'org.telegram.messenger']);
    const nowMin = tashkentMinute(new Date());
    expect(routine.startHour * 60 + routine.startMinute).toBeLessThanOrEqual(nowMin);
    expect(routine.endHour * 60 + routine.endMinute).toBeGreaterThan(nowMin);
    expect((await routines(parentToken, kid.childId)).json().routines).toEqual([]);

    await call(director, 'POST', '/emergency', { scope: 'CLASS', classIds: [classA], reason: 'Mashq' });
    expect(await schoolRoutines()).toEqual([]);
    await call(director, 'POST', '/emergency/off');
    expect(await schoolRoutines()).toHaveLength(1);

    const endOfDay = tashkentDayStart(addDays(tashkentDay(), 1)).getTime();
    if (endOfDay - Date.now() > 20 * 60_000) {
      await call(director, 'POST', '/exceptions', { studentId, until: new Date(Date.now() + 15 * 60_000).toISOString(), reason: 'Shifokorga' });
      const cut = await schoolRoutines();
      expect(cut.every((r: { startHour: number; startMinute: number; endHour: number; endMinute: number }) =>
        r.endHour * 60 + r.endMinute <= nowMin || r.startHour * 60 + r.startMinute > nowMin)).toBe(true);
    }
    spy.mockRestore();
  });
});
