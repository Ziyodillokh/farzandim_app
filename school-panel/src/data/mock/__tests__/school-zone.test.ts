import { beforeEach, describe, expect, it } from 'vitest';

import { clockNow } from '../clock';
import { getTables } from '../db';
import { liveEmergency } from '../school-mode-state';
import { schoolService } from '../services/school';
import { schoolModeService } from '../services/school-mode';
import { freshDb, loginAs } from './helpers';

const ZONE = { latitude: 41.311081, longitude: 69.240562, radiusM: 120 };

describe('maktab hududi va School Mode «faqat hududda»', () => {
  beforeEach(() => {
    freshDb();
    loginAs('DIRECTOR');
  });

  it('hududsiz «faqat hududda» yoqilmaydi; hudud belgilangach — yoqiladi', async () => {
    await expect(schoolModeService.updatePolicy({ zoneRequired: true })).rejects.toMatchObject({
      code: 'VALIDATION',
      message: 'zoneRequired: schoolMode.validation.zoneMissing',
    });

    const school = await schoolService.setZone(ZONE);
    const policy = await schoolModeService.updatePolicy({ zoneRequired: true });

    expect(school).toMatchObject({ latitude: ZONE.latitude, longitude: ZONE.longitude, zoneRadiusM: 120 });
    expect(policy.zoneRequired).toBe(true);
  });

  it('noto\'g\'ri radius va koordinata — forma xatosi', async () => {
    await expect(schoolService.setZone({ ...ZONE, radiusM: 20 })).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(schoolService.setZone({ ...ZONE, latitude: 141 })).rejects.toMatchObject({ code: 'VALIDATION' });
  });

  it('«faqat hududda» yoqilgan bo\'lsa hudud olib tashlanmaydi (ZONE_IN_USE)', async () => {
    await schoolService.setZone(ZONE);
    await schoolModeService.updatePolicy({ zoneRequired: true });

    await expect(schoolService.clearZone()).rejects.toMatchObject({ code: 'CONFLICT', detail: 'ZONE_IN_USE' });
    await schoolModeService.updatePolicy({ zoneRequired: false });
    expect(await schoolService.clearZone()).toMatchObject({ latitude: null, longitude: null, zoneRadiusM: null });
    expect(getTables().audit.filter((a) => a.action === 'school.zone' || a.action === 'school.zoneRemove')).toHaveLength(2);
  });

  it('favqulodda o\'chirish shu kun oxirigacha; muddati o\'tgach o\'chiq ko\'rinadi', async () => {
    const on = await schoolModeService.activateEmergency({ scope: 'SCHOOL', classIds: [], reason: 'Tadbir' });
    expect(on.until).toBeTruthy();
    expect(liveEmergency(on).active).toBe(true);

    const tomorrow = new Date(Date.parse(on.until!) + 60_000);
    expect(liveEmergency(on, tomorrow)).toMatchObject({ active: false, until: null });
    // `until`siz eski yozuv — faqat yoqilgan kuni.
    const threeDaysAgo = new Date(clockNow().getTime() - 3 * 86_400_000).toISOString();
    expect(liveEmergency({ ...on, until: null, at: threeDaysAgo }).active).toBe(false);
    expect(liveEmergency({ ...on, until: null, at: clockNow().toISOString() }).active).toBe(true);
  });
});
