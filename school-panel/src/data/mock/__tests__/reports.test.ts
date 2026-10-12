import { beforeEach, describe, expect, it } from 'vitest';

import { ServiceError } from '@/data/contracts';
import { CARE_MIN_GROUP } from '@/lib/k-anon';
import { reportsService } from '../services/reports';
import { freshDb, loginAs } from './helpers';

describe('reportsService', () => {
  beforeEach(() => freshDb());

  it('oylar ro\'yxati o\'quv yili boshidan joriy oygacha, yangisi birinchi', () => {
    loginAs('DIRECTOR');
    const months = reportsService.months();
    expect(months[0]).toBe('2026-10');
    expect(months).toContain('2026-09');
  });

  it('sentabr hisoboti: davomat, ota-onalar va Care bo\'limlari to\'ldirilgan', async () => {
    loginAs('DIRECTOR');
    const r = await reportsService.monthly('2026-09');
    expect(r.until).toBe('2026-09-30');
    expect(r.schoolDays).toBeGreaterThan(15);
    expect(r.attendance?.rate).toBeGreaterThan(80);
    expect(r.attendance?.byClass.length).toBe(22);
    expect(r.parents?.byClass.length).toBe(22);
    expect(r.care).not.toBeNull();
  });

  it('Care guruhlari k-anonim: yashirin guruhda son va natija yo\'q', async () => {
    loginAs('DIRECTOR');
    const r = await reportsService.monthly('2026-10');
    for (const g of r.care?.groups ?? []) {
      if (g.hidden) expect(g.wellbeing).toBeNull();
      else expect(g.respondents).toBeGreaterThanOrEqual(CARE_MIN_GROUP);
    }
  });

  it('joriy oy bugungi kunni hisobga olmaydi', async () => {
    loginAs('ADMIN');
    const r = await reportsService.monthly('2026-10');
    expect(r.until).toBe('2026-10-11');
  });

  it('ruxsatsiz rol va noto\'g\'ri oy rad etiladi', async () => {
    loginAs('HOMEROOM');
    await expect(reportsService.monthly('2026-09')).rejects.toBeInstanceOf(ServiceError);
    loginAs('DIRECTOR');
    await expect(reportsService.monthly('2026-13')).rejects.toMatchObject({ code: 'VALIDATION' });
  });
});
