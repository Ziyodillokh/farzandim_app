import { beforeEach, describe, expect, it } from 'vitest';

import { dashboardService } from '../services/dashboard';
import { freshDb, loginAs } from './helpers';

describe('dashboardService.overview', () => {
  beforeEach(() => freshDb());

  it('direktor: butun maktab, Care faqat umumlashgan', async () => {
    loginAs('DIRECTOR');
    const o = await dashboardService.overview();
    expect(o.attendance).not.toBeNull();
    expect(o.classes?.length).toBeGreaterThan(10);
    expect(o.schoolMode).not.toBeNull();
    expect(o.parents?.students.total).toBeGreaterThan(400);
    expect(o.care).not.toBeNull();
    expect(o.careInbox).toBeNull();
  });

  it('sinf rahbari faqat o\'z sinfini ko\'radi', async () => {
    loginAs('HOMEROOM');
    const o = await dashboardService.overview();
    expect(o.classes?.map((c) => c.classId)).toEqual(['cls-7a']);
    expect(o.care).toBeNull();
    expect(o.parents && o.parents.students.total).toBeLessThan(40);
  });

  it('psixolog: murojaatlar qutisi bor, davomat yo\'q', async () => {
    loginAs('PSYCHOLOGIST');
    const o = await dashboardService.overview();
    expect(o.attendance).toBeNull();
    expect(o.schoolMode).toBeNull();
    expect(o.careInbox).not.toBeNull();
    expect(o.careInbox?.recent.length).toBeLessThanOrEqual(5);
  });

  it('navbatchi: davomat bor, School Mode va xabarlar yo\'q', async () => {
    loginAs('DUTY');
    const o = await dashboardService.overview();
    expect(o.attendance).not.toBeNull();
    expect(o.schoolMode).toBeNull();
    expect(o.upcoming).toBeNull();
    expect(o.care).toBeNull();
  });

  it('kichik murojaat soni maskalanadi', async () => {
    loginAs('DIRECTOR');
    const o = await dashboardService.overview();
    const n = o.care?.requestsThisWeek ?? '';
    expect(n === '0' || n === '<5' || Number(n) >= 5).toBe(true);
  });
});
