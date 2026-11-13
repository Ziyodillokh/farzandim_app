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
    await t.prisma.child.update({
      where: { id: kid.childId },
      data: { lastSeenAt: new Date(), androidVersion: 'Android 14', usagePermission: true, overlayPermission: true },
    });
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
    // Android: blok ekrani ruxsati («ustida ko'rsatish») o'chiq — Accessibility endi shart emas.
    await t.prisma.child.update({ where: { id: noPerm.kid.childId }, data: { overlayPermission: false, accessibilityEnabled: false } });
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

  it('favqulodda o\'chirish shu kun oxirigacha: ertasi kuni o\'z-o\'zidan tugaydi', async () => {
    await lessonAroundNow();
    await call(director, 'PUT', '/policy', { enabled: true });
    const { kid } = await linkedChild(classA);
    const schoolRoutines = async () =>
      (await routines(kid.token, kid.childId)).json().routines.filter((r: { title: string }) => r.title.startsWith('Maktab'));

    const on = (await call(director, 'POST', '/emergency', { scope: 'SCHOOL', reason: 'Tadbir' })).json();
    expect(on).toMatchObject({ active: true, until: tashkentDayStart(addDays(tashkentDay(), 1)).toISOString() });
    expect(await schoolRoutines()).toEqual([]);

    // Kecha yoqilib, o'chirilmay qolgan: muddati o'tgan — School Mode qayta ishlaydi, "o'chirish" endi 409.
    await t.prisma.schoolEmergency.update({ where: { schoolId }, data: { until: new Date(Date.now() - 60_000) } });
    await call(director, 'PUT', '/policy', { relaxDuringBreaks: true }); // kesh: maktab versiyasi oshadi
    expect((await call(director, 'GET', '/overview')).json().emergency).toMatchObject({ active: false, until: null });
    expect(await schoolRoutines()).toHaveLength(1);
    expect((await call(director, 'POST', '/emergency/off')).statusCode).toBe(409);

    // `until`siz eski yozuv — yoqilgan kunigina amal qiladi.
    await t.prisma.schoolEmergency.update({ where: { schoolId }, data: { active: true, until: null, at: new Date(Date.now() - 2 * 86_400_000) } });
    expect((await call(director, 'GET', '/overview')).json().emergency.active).toBe(false);
    expect((await call(director, 'POST', '/emergency', { scope: 'CLASS', classIds: [classA], reason: 'Yangi' })).json()).toMatchObject({ active: true, scope: 'CLASS' });
  });

  it('maktab hududi: belgilash va olib tashlash; «faqat hududda» hududsiz yoqilmaydi; jadvalda hudud', async () => {
    await lessonAroundNow();
    const { kid } = await linkedChild(classA);
    const zone = (method: 'PUT' | 'DELETE', payload?: unknown) =>
      t.app.inject({ method, url: '/api/school/zone', payload: payload as object, headers: { authorization: `Bearer ${director.token}` } });

    expect((await call(director, 'PUT', '/policy', { enabled: true, zoneRequired: true })).json().message).toBe('zoneRequired: schoolMode.validation.zoneMissing');
    expect((await zone('PUT', { latitude: 41.31, longitude: 69.28, radiusM: 20 })).json().message).toBe('radiusM: errors.form.radiusRange');
    expect((await zone('PUT', { latitude: 141, longitude: 69.28, radiusM: 100 })).json().message).toBe('latitude: errors.form.invalidCoordinates');

    const saved = await zone('PUT', { latitude: 41.311081, longitude: 69.240562, radiusM: 120 });
    expect(saved.statusCode).toBe(200);
    expect(saved.json()).toMatchObject({ latitude: 41.311081, longitude: 69.240562, zoneRadiusM: 120 });
    const policy = (await call(director, 'PUT', '/policy', { enabled: true, zoneRequired: true })).json();
    expect(policy).toMatchObject({ enabled: true, zoneRequired: true });

    const [routine] = (await routines(kid.token, kid.childId)).json().routines.filter((r: { title: string }) => r.title.startsWith('Maktab'));
    expect(routine.schoolMode.zone).toEqual({ latitude: 41.311081, longitude: 69.240562, radiusM: 120 });

    // Hudud o'zgarsa telefon darhol yangisini oladi (kesh bekor + jim push), 60 soniyalik keshni kutmaydi.
    const spy = jest.spyOn(t.fcm, 'pushChildResync');
    await settle();
    spy.mockClear();
    await zone('PUT', { latitude: 41.3115, longitude: 69.2401, radiusM: 200 });
    await settle();
    expect(spy).toHaveBeenCalledWith(kid.userId);
    const [moved] = (await routines(kid.token, kid.childId)).json().routines.filter((r: { title: string }) => r.title.startsWith('Maktab'));
    expect(moved.schoolMode.zone).toEqual({ latitude: 41.3115, longitude: 69.2401, radiusM: 200 });

    const inUse = await zone('DELETE');
    expect(inUse.statusCode).toBe(409);
    expect(inUse.json().code).toBe('ZONE_IN_USE');
    await call(director, 'PUT', '/policy', { zoneRequired: false });
    expect((await zone('DELETE')).json()).toMatchObject({ latitude: null, longitude: null, zoneRadiusM: null });
    expect(await t.prisma.schoolAuditLog.count({ where: { action: { in: ['school.zone', 'school.zoneRemove'] } } })).toBe(3);
  });

  it('bugungi bayram kuni qo\'shilsa yoki olib tashlansa telefon darhol qayta sync qiladi', async () => {
    await lessonAroundNow();
    await call(director, 'PUT', '/policy', { enabled: true });
    const { kid } = await linkedChild(classA);
    const holidays = (method: 'POST' | 'DELETE', url = '', payload?: unknown) =>
      t.app.inject({ method, url: `/api/school/holidays${url}`, payload: payload as object, headers: { authorization: `Bearer ${director.token}` } });
    const schoolRoutines = async () =>
      (await routines(kid.token, kid.childId)).json().routines.filter((r: { title: string }) => r.title.startsWith('Maktab'));
    expect(await schoolRoutines()).toHaveLength(1);
    const spy = jest.spyOn(t.fcm, 'pushChildResync');
    await settle();
    spy.mockClear();

    const holiday = (await holidays('POST', '', { date: tashkentDay(), name: 'Tadbir kuni' })).json();
    await settle();
    expect(spy).toHaveBeenCalledWith(kid.userId);
    expect(await schoolRoutines()).toEqual([]);

    spy.mockClear();
    expect((await holidays('DELETE', `/${holiday.id}`)).statusCode).toBe(204);
    await settle();
    expect(spy).toHaveBeenCalledWith(kid.userId);
    expect(await schoolRoutines()).toHaveLength(1);

    // Boshqa kun — bugungi jadvalga ta'sir qilmaydi, push yo'q.
    spy.mockClear();
    await holidays('POST', '', { date: addDays(tashkentDay(), 7), name: 'Keyingi hafta' });
    await settle();
    expect(spy).not.toHaveBeenCalled();
  });

  it('server ro\'yxati bo\'sh bo\'lsa ham jadval keladi — qurilma toifa bo\'yicha bloklaydi', async () => {
    await lessonAroundNow();
    await call(director, 'PUT', '/policy', { enabled: true });
    const { kid } = await linkedChild(classA);
    await t.prisma.installedApp.deleteMany({ where: { childId: kid.childId } });

    const [routine] = (await routines(kid.token, kid.childId)).json().routines.filter((r: { title: string }) => r.title.startsWith('Maktab'));

    expect(routine.blockedApps).toEqual([]);
    expect(routine.schoolMode.blockedCategories).toEqual(['GAME', 'SOCIAL', 'VIDEO']);
  });

  it('telefon yangi ilovalar ro\'yxatini yuborsa keyingi so\'rovda u bloklanadi (kesh kutilmaydi)', async () => {
    await lessonAroundNow();
    await call(director, 'PUT', '/policy', { enabled: true });
    const { kid } = await linkedChild(classA);
    const blockedNow = async () =>
      (await routines(kid.token, kid.childId)).json().routines.find((r: { title: string }) => r.title.startsWith('Maktab')).blockedApps;
    expect(await blockedNow()).not.toContain('com.mojang.minecraftpe');

    const upload = await t.app.inject({
      method: 'POST',
      url: `/api/children/${kid.childId}/installed-apps`,
      headers: { authorization: `Bearer ${kid.token}` },
      payload: { apps: [{ packageName: 'com.mojang.minecraftpe', appName: 'Minecraft', category: 'GAME' }] },
    });

    expect(upload.statusCode).toBe(201);
    expect(await blockedNow()).toContain('com.mojang.minecraftpe');
  });

  it('qurilma ruxsatlari: «ustida ko\'rsatish» va «foydalanish ma\'lumotlari» saqlanadi; o\'chirilsa ota-onaga xabar', async () => {
    const { kid, studentId, parentUserId } = await linkedChild(classA);
    const deviceInfo = (payload: object) =>
      t.app.inject({ method: 'POST', url: `/api/children/${kid.childId}/device-info`, payload, headers: { authorization: `Bearer ${kid.token}` } });
    const status = async () =>
      (await call(director, 'GET', '/devices')).json().items.find((d: { studentId: string }) => d.studentId === studentId).status;

    expect(await status()).toBe('APPLIED');
    expect((await deviceInfo({ overlayPermission: false, usagePermission: true })).statusCode).toBe(200);
    expect(await t.prisma.child.findUniqueOrThrow({ where: { id: kid.childId } })).toMatchObject({ overlayPermission: false });
    expect(await status()).toBe('NO_PERMISSION');
    const alert = t.fcm.pushesTo(parentUserId).find((p) => p.data?.type === 'permission_changed');
    expect(alert?.body).toContain("Boshqa ilovalar ustidan ko'rsatish");
    await deviceInfo({ overlayPermission: true });
    expect(await status()).toBe('APPLIED');
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
    // Qurilma uchun: toifalar (yangi o'yin server ro'yxatiga tushmasdan ham bloklanadi), ruxsat etilganlar, hudud yo'q.
    expect(routine.schoolMode).toEqual({ blockedCategories: ['GAME', 'SOCIAL', 'VIDEO'], allowedApps: ['YouTube'], zone: null });
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
