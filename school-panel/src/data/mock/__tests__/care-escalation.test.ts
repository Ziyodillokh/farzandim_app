import { beforeEach, describe, expect, it } from 'vitest';

import { clockNow } from '../clock';
import { getTables, transact } from '../db';
import { FIXED_STAFF } from '../seed/people';
import { escalateOverdueRequests, slaMinutes, workingMinutesBetween } from '../services/care-escalation';
import { careService } from '../services/care';
import { freshDb, loginAs } from './helpers';

const WEEK = { workDays: [1, 2, 3, 4, 5], workStart: '09:00', workEnd: '17:00' };
const NO_HOLIDAYS = new Set<string>();
/** Mahalliy vaqt (ms): oy 0-asosli emas — o'qishga qulay. */
const at = (y: number, m: number, d: number, h: number, min = 0) => new Date(y, m - 1, d, h, min).getTime();

describe('ish vaqti daqiqalari', () => {
  // 2026-10-12 — dushanba.
  it('bir kun ichida: faqat ish soatlari hisoblanadi', () => {
    expect(workingMinutesBetween(at(2026, 10, 12, 8), at(2026, 10, 12, 10), WEEK, NO_HOLIDAYS)).toBe(60);
    expect(workingMinutesBetween(at(2026, 10, 12, 16, 30), at(2026, 10, 12, 20), WEEK, NO_HOLIDAYS)).toBe(30);
    expect(workingMinutesBetween(at(2026, 10, 12, 18), at(2026, 10, 12, 20), WEEK, NO_HOLIDAYS)).toBe(0);
  });

  it('kechadan ertasiga: kechki va ertalabki soatlar o\'tkazib yuboriladi', () => {
    // Dushanba 16:00 → seshanba 10:00 = 60 + 60.
    expect(workingMinutesBetween(at(2026, 10, 12, 16), at(2026, 10, 13, 10), WEEK, NO_HOLIDAYS)).toBe(120);
  });

  it('dam olish kunlari (shanba/yakshanba) hisoblanmaydi', () => {
    // Juma 16:00 → dushanba 10:00 = 60 + 60.
    expect(workingMinutesBetween(at(2026, 10, 9, 16), at(2026, 10, 12, 10), WEEK, NO_HOLIDAYS)).toBe(120);
    // Shanba kuni yozilgan murojaat dushanbadan hisoblanadi.
    expect(workingMinutesBetween(at(2026, 10, 10, 12), at(2026, 10, 12, 10), WEEK, NO_HOLIDAYS)).toBe(60);
  });

  it('bayram kuni hisoblanmaydi', () => {
    const holidays = new Set(['2026-10-13']);
    expect(workingMinutesBetween(at(2026, 10, 12, 16), at(2026, 10, 14, 10), WEEK, holidays)).toBe(120);
  });

  it('ish kunlari sozlamasi hisobga olinadi (shanba ish kuni bo\'lsa — hisoblanadi)', () => {
    const withSaturday = { ...WEEK, workDays: [1, 2, 3, 4, 5, 6] };
    expect(workingMinutesBetween(at(2026, 10, 10, 9), at(2026, 10, 10, 11), withSaturday, NO_HOLIDAYS)).toBe(120);
  });

  it('noto\'g\'ri sozlama yoki teskari oraliq — 0', () => {
    expect(workingMinutesBetween(at(2026, 10, 12, 10), at(2026, 10, 12, 9), WEEK, NO_HOLIDAYS)).toBe(0);
    expect(workingMinutesBetween(at(2026, 10, 12, 8), at(2026, 10, 12, 12), { ...WEEK, workDays: [] }, NO_HOLIDAYS)).toBe(0);
    expect(workingMinutesBetween(at(2026, 10, 12, 8), at(2026, 10, 12, 12), { ...WEEK, workStart: '17:00', workEnd: '09:00' }, NO_HOLIDAYS)).toBe(0);
  });

  it('muddat: shoshilinch — daqiqa, oddiy — soat × 60', () => {
    expect(slaMinutes('URGENT', { urgentSlaMinutes: 45, normalSlaHours: 24 })).toBe(45);
    expect(slaMinutes('NORMAL', { urgentSlaMinutes: 45, normalSlaHours: 24 })).toBe(1440);
  });
});

describe('o\'rinbosarga o\'tkazish', () => {
  beforeEach(() => {
    freshDb();
    loginAs('PSYCHOLOGIST');
  });

  const nowMs = () => clockNow().getTime();
  const find = (id: string) => getTables().careRequests.find((r) => r.id === id);

  it('muddatdan o\'tgan ochilmagan shoshilinch murojaat o\'rinbosarga o\'tadi; qolganlari joyida', () => {
    // Demo vaqti dushanba 10:00; care-1 — bugun 07:52 (ish vaqti 08:30 dan, muddat 60 daqiqa).
    const count = transact((t) => escalateOverdueRequests(t, nowMs()));
    expect(count).toBe(1);
    const escalated = find('care-1');
    expect(escalated).toMatchObject({ assignedStaffId: FIXED_STAFF.psychologistDeputy, status: 'NEW' });
    expect(escalated?.escalatedAt).not.toBeNull();
    // Oddiy (24 ish soati) hali muddatdan o'tmagan; ochilganlari tegilmaydi.
    expect(find('care-2')).toMatchObject({ assignedStaffId: FIXED_STAFF.psychologist, escalatedAt: null });
    expect(find('care-3')?.escalatedAt).toBeNull();
  });

  it('idempotent: ikkinchi marta o\'zgarish yo\'q', () => {
    transact((t) => escalateOverdueRequests(t, nowMs()));
    const first = find('care-1')?.escalatedAt;
    expect(transact((t) => escalateOverdueRequests(t, nowMs() + 60_000))).toBe(0);
    expect(find('care-1')?.escalatedAt).toBe(first);
  });

  it('o\'rinbosar belgilanmagan bo\'lsa o\'tkazilmaydi', async () => {
    await careService.updateSettings({ ...(await careService.getSettings()), deputyStaffId: null, deputyDisplayName: null });
    expect(transact((t) => escalateOverdueRequests(t, nowMs()))).toBe(0);
    expect(find('care-1')?.escalatedAt).toBeNull();
  });

  it('muddat uzaytirilsa (180 daqiqa) hali o\'tmagan', async () => {
    await careService.updateSettings({ ...(await careService.getSettings()), urgentSlaMinutes: 180 });
    expect(transact((t) => escalateOverdueRequests(t, nowMs()))).toBe(0);
  });

  it('ochilgan murojaat o\'tkazilmaydi; ochilmagan oddiy murojaat 24 ish soatidan keyin o\'tadi', async () => {
    await careService.getRequest('care-1');
    expect(transact((t) => escalateOverdueRequests(t, nowMs()))).toBe(0);
    // care-2: 24 ish soati (3 ish kuni, 08:30–16:30) o'tgach.
    const later = nowMs() + 4 * 24 * 3_600_000;
    expect(transact((t) => escalateOverdueRequests(t, later))).toBe(1);
    expect(find('care-2')).toMatchObject({ assignedStaffId: FIXED_STAFF.psychologistDeputy });
  });

  it('o\'tkazilgan murojaat ro\'yxatda mas\'ul sifatida o\'rinbosarni ko\'rsatadi', async () => {
    transact((t) => escalateOverdueRequests(t, nowMs()));
    const row = (await careService.listRequests()).items.find((r) => r.id === 'care-1');
    expect(row?.escalatedAt).not.toBeNull();
    expect(row?.assignedTo).toMatchObject({ id: FIXED_STAFF.psychologistDeputy, name: 'Karimova Kamola Rustamovna' });
  });
});
