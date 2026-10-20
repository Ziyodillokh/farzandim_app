// Xavfsizlik ko'rigi tuzatishlari (M1–M5, LOW) — regressiya testlari:
// bloklash poygasi, audit ko'rinishi, kiosk ma'lumoti, QR va xodim qarori,
// parallel yozuvlar, saralash kaliti.

import { resetDb } from './db';
import { at, consumerCall, DAY, seedWorld, setNow, staffCall, World } from './school-attendance-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School security review fixes', () => {
  let t: TestApp;
  let w: World;

  const school = (token: string, method: 'GET' | 'POST' | 'PUT', url: string, payload?: object) =>
    t.app.inject({ method, url: `/api/school${url}`, headers: { authorization: `Bearer ${token}` }, ...(payload && { payload }) });
  const login = (password: string) =>
    t.app.inject({ method: 'POST', url: '/api/school/auth/login', payload: { school: 'test-school', username: 'admin', password } });
  const kioskToken = async () => (await staffCall(t, w.duty, 'GET', '/kiosk/token')).json().token as string;
  const scan = async () => consumerCall(t, w.child.token, 'POST', '/child/school/check-in', { token: await kioskToken() });

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    w = await seedWorld(t);
    setNow(t, at(DAY, '07:55'));
  });

  afterAll(() => t.close());

  it('M1: parallel noto\'g\'ri parollar ham hisobni bloklaydi', async () => {
    await Promise.all(Array.from({ length: 8 }, () => login('wrong-password-1')));
    const locked = await login('Parvoz-School-2026');
    expect(locked.statusCode).toBe(429);
    expect(locked.json().code).toBe('LOCKED');
  });

  it('M2: ?module=CARE so\'rovi CARE yozuvlarini direktorga ochmaydi', async () => {
    await t.prisma.schoolAuditLog.create({
      data: { schoolId: w.schoolId, actorName: 'Psixolog', module: 'CARE', action: 'care.request.note', summary: 'Bola ovozi: ichki eslatma' },
    });
    const res = (await school(w.director.token, 'GET', '/audit?module=CARE')).json();
    expect(res.items).toEqual([]);
    expect((await school(w.psych.token, 'GET', '/audit?module=CARE')).statusCode).toBe(403);
  });

  it('M3: kiosk javobida tug\'ilgan sana, ota-onalar va qurilma yo\'q', async () => {
    setNow(t, at(DAY, '08:05'));
    const code = (await t.prisma.schoolStudent.findUniqueOrThrow({ where: { id: w.malika } })).studentCode;
    const res = (await staffCall(t, w.duty, 'POST', '/kiosk/check-in', { code })).json();
    expect(res.student).toEqual({ id: w.malika, lastName: 'Karimova', firstName: 'Malika', classId: w.classA, studentCode: code });
  });

  it('M4: QR faqat o\'quv vaqtida; xodim qarorini (sababli) bosib ketmaydi', async () => {
    setNow(t, at(DAY, '21:30'));
    expect((await scan()).json().code).toBe('OUTSIDE_SCHOOL_HOURS');
    setNow(t, at('2026-10-25', '09:00')); // yakshanba
    expect((await scan()).json().code).toBe('OUTSIDE_SCHOOL_HOURS');

    setNow(t, at(DAY, '08:00'));
    await staffCall(t, w.admin, 'POST', '/mark', { studentId: w.vali, status: 'EXCUSED' });
    setNow(t, at(DAY, '08:30'));
    expect((await scan()).json()).toMatchObject({ action: 'NONE', today: { record: { status: 'EXCUSED' } } });
  });

  it('M5: parallel eslatmalar yo\'qolmaydi; himoya protokoli bir marta', async () => {
    const created = await consumerCall(t, w.child.token, 'POST', '/child/school/care/requests', { topic: 'OTHER', message: 'Yordam kerak', urgency: 'URGENT' });
    const id = created.json().id as string;
    await Promise.all(Array.from({ length: 6 }, (_, i) => school(w.psych.token, 'POST', `/care/requests/${id}/notes`, { text: `Eslatma ${i}` })));
    expect((await school(w.psych.token, 'GET', `/care/requests/${id}`)).json().notes).toHaveLength(6);
    await Promise.all([school(w.psych.token, 'POST', `/care/requests/${id}/protocol`), school(w.psych.token, 'POST', `/care/requests/${id}/protocol`)]);
    expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'SAFETY_SIGNAL' } })).toBe(1);
  });

  it('LOW: sortBy=__proto__ — 500 emas', async () => {
    expect((await school(w.director.token, 'GET', '/students?sortBy=__proto__')).statusCode).toBe(200);
  });
});
