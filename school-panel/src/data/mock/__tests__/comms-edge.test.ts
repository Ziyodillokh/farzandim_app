import { beforeEach, describe, expect, it } from 'vitest';

import type { Announcement, PaymentReminder, Reminder } from '@/data/contracts';
import { clockNow } from '../clock';
import { getTables, transact } from '../db';
import { commsService } from '../services/comms';
import { localIso } from '../services/comms-shared';
import { nextOccurrence, occurrenceAt } from '../services/comms-reminders';
import { freshDb, loginAs } from './helpers';

/** `paginate` sahifani 500 bilan cheklaydi — undan ko'p yozuv bilan sinaymiz. */
const BIG = 700;
const SCHOOL = { kind: 'SCHOOL' as const, classIds: [], guardianIds: [] };

describe('katta ro\'yxatlar: 500 chegarasi ma\'lumotni kesmaydi', () => {
  beforeEach(freshDb);

  it('to\'lov eksporti barcha oilalarni qaytaradi (500 dan ko\'p bo\'lsa ham)', async () => {
    loginAs('ADMIN');
    transact((t) => {
      const base = t.payments[0]!;
      const extra: PaymentReminder[] = Array.from({ length: BIG }, (_, i) => ({ ...base, id: `pay-x${i}`, paused: i % 2 === 0 }));
      t.payments.push(...extra);
    });
    const total = getTables().payments.length;
    expect(total).toBeGreaterThan(500);
    const all = await commsService.payments.exportRows();
    expect(all).toHaveLength(total);
    const paused = await commsService.payments.exportRows({ filter: 'PAUSED' });
    expect(paused).toHaveLength(getTables().payments.filter((p) => p.paused).length);
    expect((await commsService.payments.stats()).families).toBe(total);
  });

  it('eslatmalar ko\'rsatkichlari sahifalashdan qat\'i nazar butun ro\'yxat bo\'yicha', async () => {
    loginAs('ADMIN');
    transact((t) => {
      const extra: Reminder[] = Array.from({ length: BIG }, (_, i) => ({
        id: `rem-x${i}`,
        kind: 'EVENT',
        title: `Tadbir ${i}`,
        body: 'Sinov',
        audience: SCHOOL,
        sendAt: `2099-03-${String((i % 28) + 1).padStart(2, '0')}T09:00:00`,
        repeat: 'NONE',
        active: i % 7 !== 0,
        byStaffId: 'stf-admin',
      }));
      t.reminders.push(...extra);
    });
    const page = await commsService.reminders.list({ when: 'UPCOMING', limit: 5 });
    expect(page.items).toHaveLength(5);
    expect(page.counts.UPCOMING).toBeGreaterThan(BIG);
    expect(page.stats.upcoming).toBe(page.counts.UPCOMING);
    expect(page.stats.paused).toBeGreaterThanOrEqual(BIG / 7);
  });
});

describe('vaqt belgilari: mahalliy va UTC formatlar aralash', () => {
  beforeEach(freshDb);

  it('rejalashtirilganlar xronologik tartibda (satr tartibida emas)', async () => {
    loginAs('ADMIN');
    const anchor = new Date(2099, 0, 1, 10, 0, 0);
    const earlierUtc = new Date(anchor.getTime() - 60_000).toISOString();
    const laterUtc = new Date(anchor.getTime() + 60_000).toISOString();
    const make = (id: string, scheduledAt: string): Announcement => ({
      id,
      title: id,
      body: 'Sinov',
      audience: SCHOOL,
      priority: 'NORMAL',
      status: 'SCHEDULED',
      scheduledAt,
      sentAt: null,
      byStaffId: 'stf-admin',
      stats: { recipients: 0, delivered: 0, read: 0 },
    });
    transact((t) => {
      t.announcements.push(make('ann-later', laterUtc), make('ann-local', localIso(anchor)), make('ann-earlier', earlierUtc));
    });
    const list = await commsService.announcements.list({ status: 'SCHEDULED', limit: 100 });
    const ids = list.items.map((a) => a.id).filter((id) => ['ann-later', 'ann-local', 'ann-earlier'].includes(id));
    expect(ids).toEqual(['ann-earlier', 'ann-local', 'ann-later']);
  });

  it('UTC formatidagi o\'tgan rejalashtirilgan vaqt — yuborilgan deb ko\'rsatiladi', async () => {
    loginAs('ADMIN');
    const past = new Date(clockNow().getTime() - 5 * 60_000).toISOString();
    transact((t) => {
      const seed = t.announcements.find((a) => a.id === 'ann-4')!;
      t.announcements.push({ ...seed, id: 'ann-utc', scheduledAt: past });
    });
    const detail = await commsService.announcements.get('ann-utc');
    expect(detail.status).toBe('SENT');
    expect(detail.sentAt).toBe(past);
  });
});

describe('Smart Reminder: oylik takrorlanish siljimaydi', () => {
  const monthly = { sendAt: '2027-01-31T09:00:00', repeat: 'MONTHLY' as const };

  it('31-yanvar → 28-fevral → 31-mart → 30-aprel', () => {
    const anchor = new Date(2027, 0, 31, 9, 0);
    expect(localIso(occurrenceAt(anchor, 'MONTHLY', 1))).toBe('2027-02-28T09:00:00');
    expect(localIso(occurrenceAt(anchor, 'MONTHLY', 2))).toBe('2027-03-31T09:00:00');
    expect(localIso(occurrenceAt(anchor, 'MONTHLY', 3))).toBe('2027-04-30T09:00:00');
    expect(localIso(occurrenceAt(new Date(2028, 0, 31, 9, 0), 'MONTHLY', 1))).toBe('2028-02-29T09:00:00');
  });

  it('nextOccurrence oyning oxirgi kuniga qisqaradi, keyin asl kunga qaytadi', () => {
    expect(localIso(nextOccurrence(monthly, new Date(2027, 1, 5))!)).toBe('2027-02-28T09:00:00');
    expect(localIso(nextOccurrence(monthly, new Date(2027, 2, 1))!)).toBe('2027-03-31T09:00:00');
    expect(localIso(nextOccurrence(monthly, new Date(2027, 3, 1))!)).toBe('2027-04-30T09:00:00');
  });

  it('haftalik — 7 kun qadam, bir martalik o\'tgani — null', () => {
    expect(localIso(nextOccurrence({ sendAt: '2027-01-04T08:30:00', repeat: 'WEEKLY' }, new Date(2027, 0, 12))!)).toBe('2027-01-18T08:30:00');
    expect(nextOccurrence({ sendAt: '2027-01-04T08:30:00', repeat: 'NONE' }, new Date(2027, 0, 12))).toBeNull();
  });
});
