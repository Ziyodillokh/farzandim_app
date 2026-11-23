import { createParent } from './factories';
import { resetDb } from './db';
import { seedWorld, World } from './school-attendance-fixtures';
import { createGuardian } from './school-students-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('SOS — bolaning barcha ota-onalariga', () => {
  let t: TestApp;
  let w: World;

  const call = (token: string, method: 'GET' | 'POST' | 'PUT', url: string, payload?: object) =>
    t.app.inject({ method, url: `/api${url}`, headers: { authorization: `Bearer ${token}` }, ...(payload && { payload }) });

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    w = await seedWorld(t);
  });

  afterAll(() => t.close());

  it('bolani yaratgan ota-ona VA maktab tasdiqlagan ikkinchi ota-ona push oladi, ro\'yxatni ko\'radi va hal qila oladi; begona — yo\'q', async () => {
    // Ikkinchi ota-ona: Parvoz'da bolani yaratmagan, lekin maktab orqali shu o'quvchiga ulangan.
    const dad = await createParent(t.prisma, { name: 'Ota' });
    await createGuardian(t.prisma, w.schoolId, [w.vali], { fullName: 'Aliyev Akmal', linkStatus: 'LINKED', userId: dad.userId });
    // Taklif qilingan, lekin ulanmagan vasiy — SOS olmaydi.
    const pending = await createParent(t.prisma, { name: 'Kutmoqda' });
    await createGuardian(t.prisma, w.schoolId, [w.vali], { fullName: 'Kutayotgan', linkStatus: 'INVITED', userId: pending.userId });
    const stranger = await createParent(t.prisma, { name: 'Begona' });

    const sos = await call(w.child.token, 'POST', `/children/${w.child.childId}/sos-alerts`, { latitude: 41.3, longitude: 69.24 });
    expect(sos.statusCode).toBe(201);
    const alertId = sos.json().id as string;

    const sosPushes = (userId: string) => t.fcm.pushesTo(userId).filter((p) => p.data?.type === 'sos');
    expect(sosPushes(w.parent.userId)).toHaveLength(1);
    expect(sosPushes(dad.userId)).toHaveLength(1);
    expect(sosPushes(dad.userId)[0]).toMatchObject({ data: { alertId, childId: w.child.childId, latitude: '41.3' } });
    expect(sosPushes(pending.userId)).toHaveLength(0);
    expect(sosPushes(stranger.userId)).toHaveLength(0);

    // Ikkinchi ota-ona ilovada SOS'ni ko'radi va hal qiladi; begona — ko'rmaydi, hal qila olmaydi.
    expect((await call(dad.token, 'GET', '/sos-alerts')).json().alerts.map((a: { id: string }) => a.id)).toEqual([alertId]);
    expect((await call(stranger.token, 'GET', '/sos-alerts')).json().alerts).toEqual([]);
    expect((await call(stranger.token, 'PUT', `/sos-alerts/${alertId}/resolve`)).statusCode).toBe(403);
    const resolved = await call(dad.token, 'PUT', `/sos-alerts/${alertId}/resolve`);
    expect(resolved.statusCode).toBe(200);
    expect(resolved.json()).toMatchObject({ status: 'RESOLVED', resolvedBy: dad.userId });
  });

  it('maktabga ulanmagan oilada — avvalgidek faqat bolani yaratgan ota-ona', async () => {
    await t.prisma.schoolStudent.update({ where: { id: w.vali }, data: { childId: null } });
    expect((await call(w.child.token, 'POST', `/children/${w.child.childId}/sos-alerts`, {})).statusCode).toBe(201);
    expect(t.fcm.pushesTo(w.parent.userId).filter((p) => p.data?.type === 'sos')).toHaveLength(1);
  });
});
