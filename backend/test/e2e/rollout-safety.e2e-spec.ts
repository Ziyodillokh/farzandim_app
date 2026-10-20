// Production'ga chiqarish xavfsizligi: ilova Swagger bilan (production kabi)
// ishga tushadi; School Mode xatosi store'dagi bola ilovalarining jadval
// sinxronini to'xtatmaydi.

import { SchoolModeMorningCron } from '../../src/school/school-mode/school-mode-morning.cron';
import { SchoolModeStore } from '../../src/school/school-mode/school-mode-store';
import { SchoolModeSyncService } from '../../src/school/school-mode/school-mode-sync.service';
import { resetDb } from './db';
import { createChild, createParent } from './factories';
import { seedWorld } from './school-attendance-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('Rollout safety', () => {
  describe('Swagger bilan ishga tushish (production kabi)', () => {
    let t: TestApp;

    beforeAll(async () => {
      t = await createTestApp({ swagger: true });
    });

    afterAll(() => t.close());

    it('hujjat quriladi va yangi hamda eski marshrutlarni o\'z ichiga oladi', async () => {
      const res = await t.app.inject({ method: 'GET', url: '/api/docs-json' });
      expect(res.statusCode).toBe(200);
      const paths = Object.keys(res.json().paths as Record<string, unknown>);
      expect(paths).toEqual(expect.arrayContaining(['/api/children/{childId}/routines', '/api/school/auth/login', '/api/learning/attempts']));
    });
  });

  describe('School Mode xatosi', () => {
    let t: TestApp;

    beforeAll(async () => {
      t = await createTestApp();
    });

    beforeEach(() => resetDb(t.prisma));

    afterAll(() => t.close());

    it('ertalabki sinxron: siyosati yoqilgan maktabning bog\'langan bolalariga jim push', async () => {
      const w = await seedWorld(t);
      // Standart siyosat o'chiq — maktab yoqqandagina School Mode ishlaydi.
      await t.app.get(SchoolModeStore).policy(w.schoolId);
      expect(await t.app.get(SchoolModeMorningCron).resyncEnabledSchools()).toBe(0);
      await t.prisma.schoolModePolicy.updateMany({ where: { schoolId: w.schoolId }, data: { enabled: true } });
      const push = jest.spyOn(t.fcm, 'pushChildResync');
      try {
        expect(await t.app.get(SchoolModeMorningCron).resyncEnabledSchools()).toBe(1);
        expect(push).toHaveBeenCalledWith(w.child.userId);
        push.mockClear();
        await t.prisma.schoolModePolicy.updateMany({ where: { schoolId: w.schoolId }, data: { enabled: false } });
        expect(await t.app.get(SchoolModeMorningCron).resyncEnabledSchools()).toBe(0);
        expect(push).not.toHaveBeenCalled();
      } finally {
        push.mockRestore();
      }
    });

    it('bolaning o\'z jadvallari baribir qaytadi (500 emas)', async () => {
      const parent = await createParent(t.prisma);
      const child = await createChild(t.prisma, parent);
      await t.prisma.routine.create({
        data: { childId: child.childId, title: 'Uyqu', type: 'SLEEP', startHour: 22, startMinute: 0, endHour: 7, endMinute: 0, weekdays: [1, 2, 3, 4, 5, 6, 7] },
      });
      const spy = jest.spyOn(t.app.get(SchoolModeSyncService), 'routinesForChild').mockRejectedValue(new Error('boom'));
      try {
        const res = await t.app.inject({
          method: 'GET',
          url: `/api/children/${child.childId}/routines`,
          headers: { authorization: `Bearer ${child.token}` },
        });
        expect(res.statusCode).toBe(200);
        expect(res.json()).toMatchObject({ count: 1, routines: [{ title: 'Uyqu' }] });
      } finally {
        spy.mockRestore();
      }
    });
  });
});
