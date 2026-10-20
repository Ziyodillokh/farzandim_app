import { beforeEach, describe, expect, it } from 'vitest';

import type { AnnouncementInput } from '@/data/schemas/comms';
import { getTables } from '../db';
import { commsService } from '../services/comms';
import { freshDb, loginAs } from './helpers';

const draft = (audience: AnnouncementInput['audience']): AnnouncementInput => ({
  title: 'Sinov xabari',
  body: 'Ertaga soat 09:00 da yig\'ilish bo\'ladi.',
  priority: 'NORMAL',
  audience,
});

const SCHOOL = { kind: 'SCHOOL' as const, classIds: [], guardianIds: [] };
const OWN_CLASS = { kind: 'CLASSES' as const, classIds: ['cls-7a'], guardianIds: [] };

describe('xabarlar: doira va ruxsatlar', () => {
  beforeEach(freshDb);

  it('sinf rahbari butun maktabga yoki boshqa sinfga yubora olmaydi', async () => {
    loginAs('HOMEROOM');
    await expect(commsService.announcements.send(draft(SCHOOL))).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(commsService.announcements.send(draft({ kind: 'CLASSES', classIds: ['cls-8b'], guardianIds: [] }))).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(commsService.announcements.saveDraft(draft({ kind: 'CLASSES', classIds: ['cls-7a', 'cls-7b'], guardianIds: [] }))).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('sinf rahbari boshqa sinf ota-onasiga yubora olmaydi, o\'z sinfiga yuboradi', async () => {
    loginAs('HOMEROOM');
    const t = getTables();
    const foreign = t.students.find((s) => s.classId === 'cls-8b')!.guardianIds[0]!;
    await expect(commsService.announcements.send(draft({ kind: 'GUARDIANS', classIds: [], guardianIds: [foreign] }))).rejects.toMatchObject({ code: 'FORBIDDEN' });
    const sent = await commsService.announcements.send(draft(OWN_CLASS));
    expect(sent.status).toBe('SENT');
    expect(sent.byStaffId).toBe('stf-homeroom-7a');
  });

  it('sinf rahbari ro\'yxatda faqat maktab va o\'z sinfi xabarlarini ko\'radi (begona qoralamalarsiz)', async () => {
    loginAs('HOMEROOM');
    const list = await commsService.announcements.list({ limit: 100 });
    const ids = list.items.map((a) => a.id);
    expect(ids).toContain('ann-1');
    expect(ids).toContain('ann-3');
    expect(ids).not.toContain('ann-5');
    expect(ids).not.toContain('ann-6');
    expect(list.items.find((a) => a.id === 'ann-1')?.canManage).toBe(false);
  });

  it('psixolog xabarlarni ko\'ra olmaydi', async () => {
    loginAs('PSYCHOLOGIST');
    await expect(commsService.announcements.list()).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});

describe('xabarlar: yuborish va statistika', () => {
  beforeEach(freshDb);

  it('yuborishda statistika hisoblanadi: push (ulangan) + SMS zaxira', async () => {
    loginAs('ADMIN');
    const reach = await commsService.audienceSize(OWN_CLASS);
    expect(reach.guardians).toBe(reach.linked + reach.sms);
    expect(reach.students).toBeGreaterThan(20);
    const sent = await commsService.announcements.send(draft(OWN_CLASS));
    expect(sent.stats.recipients).toBe(reach.guardians);
    expect(sent.stats.delivered).toBeGreaterThanOrEqual(reach.linked);
    expect(sent.stats.delivered).toBeLessThanOrEqual(reach.guardians);
    expect(sent.stats.read).toBe(0);
    expect(getTables().audit.at(-1)?.action).toBe('announcement.send');
  });

  it('rejalashtirish: o\'tgan vaqt rad etiladi, kelajakdagi SCHEDULED bo\'ladi', async () => {
    loginAs('ADMIN');
    await expect(commsService.announcements.send(draft(SCHOOL), { scheduledAt: '2020-01-01T08:00' })).rejects.toMatchObject({ code: 'VALIDATION' });
    const scheduled = await commsService.announcements.send(draft(SCHOOL), { scheduledAt: '2099-01-01T08:00' });
    expect(scheduled.status).toBe('SCHEDULED');
    const now = await commsService.announcements.sendNow(scheduled.id);
    expect(now.status).toBe('SENT');
    await expect(commsService.announcements.remove(now.id)).rejects.toMatchObject({ code: 'CONFLICT' });
  });

  it('qoralama → nusxa → o\'chirish audit jurnaliga yoziladi', async () => {
    loginAs('DIRECTOR');
    const saved = await commsService.announcements.saveDraft(draft(SCHOOL));
    const copy = await commsService.announcements.duplicate(saved.id);
    expect(copy.status).toBe('DRAFT');
    await commsService.announcements.remove(copy.id);
    const actions = getTables().audit.slice(-3).map((a) => a.action);
    expect(actions).toEqual(['announcement.draft', 'announcement.duplicate', 'announcement.delete']);
  });

  it('sinf rahbari maktab xabarini nusxalasa — auditoriya o\'z sinfiga o\'tadi', async () => {
    loginAs('HOMEROOM');
    const copy = await commsService.announcements.duplicate('ann-1');
    expect(copy.audience).toEqual(OWN_CLASS);
  });
});

describe('to\'lov eslatmalari: moliyaviy chegara', () => {
  beforeEach(freshDb);
  const CONTRACT_KEYS = ['guardianId', 'history', 'id', 'nextDate', 'paused', 'prepaidMonths', 'studentIds'];

  it('ommaviy surish audit qilinadi va hech qanday qarz maydoni yaratmaydi', async () => {
    loginAs('ADMIN');
    const ids = getTables().payments.slice(0, 4).map((p) => p.id);
    const before = new Map(getTables().payments.map((p) => [p.id, p]));
    const result = await commsService.payments.bulkShift({ ids, months: 4, note: '4 oy oldindan to\'lov (buxgalteriya)', markPrepaid: true });
    expect(result.updated).toBe(4);
    const t = getTables();
    for (const id of ids) {
      const p = t.payments.find((x) => x.id === id)!;
      expect(Object.keys(p).sort()).toEqual(CONTRACT_KEYS);
      expect(JSON.stringify(p)).not.toMatch(/debt|qarz|balance|amount|owed/i);
      expect(p.nextDate > before.get(id)!.nextDate).toBe(true);
      expect(p.prepaidMonths).toBe(before.get(id)!.prepaidMonths + 4);
      expect(p.history.at(-1)?.action).toBe('BULK_SHIFT');
    }
    const audit = t.audit.at(-1);
    expect(audit?.module).toBe('PAYMENTS');
    expect(audit?.action).toBe('payment.bulkShift');
    expect(Object.keys(t).some((k) => /debt|qarz/i.test(k))).toBe(false);
  });

  it('to\'xtatish va surish faqat payments.manage bilan', async () => {
    loginAs('HOMEROOM');
    await expect(commsService.payments.list()).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('ADMIN');
    const id = getTables().payments.find((p) => !p.paused)!.id;
    const paused = await commsService.payments.pause(id, { note: 'Oila iltimosi' });
    expect(paused.paused).toBe(true);
    await expect(commsService.payments.pause(id, { note: 'Yana' })).rejects.toMatchObject({ code: 'CONFLICT' });
    const shifted = await commsService.payments.shift(id, { nextDate: '2026-12-10', note: 'Maosh 10-sanada' });
    expect(shifted.nextDate).toBe('2026-12-10');
    const history = await commsService.payments.history(id);
    expect(history[0]?.action).toBe('SHIFTED');
  });
});

describe('tekshiruv so\'rovlari', () => {
  beforeEach(freshDb);

  it('javob berish (yangi sana bilan) to\'lov eslatmasini suradi va yopish ishlaydi', async () => {
    loginAs('ADMIN');
    const list = await commsService.verifications.list({ status: 'OPEN' });
    expect(list.counts.OPEN).toBeGreaterThan(0);
    const target = list.items[0]!;
    const answered = await commsService.verifications.answer(target.id, { text: 'Tekshirdik, sana to\'g\'rilandi.', newDate: '2027-02-05' });
    expect(answered.status).toBe('ANSWERED');
    expect(answered.answeredByStaffId).toBe('stf-admin');
    const payment = getTables().payments.find((p) => p.id === target.paymentReminderId)!;
    expect(payment.nextDate).toBe('2027-02-05');
    expect(payment.history.at(-1)?.action).toBe('VERIFIED');
    const closed = await commsService.verifications.close(target.id);
    expect(closed.status).toBe('CLOSED');
    await expect(commsService.verifications.answer(target.id, { text: 'x' })).rejects.toMatchObject({ code: 'CONFLICT' });
    expect(getTables().audit.slice(-2).map((a) => a.action)).toEqual(['verification.answer', 'verification.close']);
  });
});

describe('Smart Reminder', () => {
  beforeEach(freshDb);

  it('yaratish, o\'chirib-yoqish va o\'chirish', async () => {
    loginAs('ADMIN');
    const created = await commsService.reminders.create({
      kind: 'EXAM',
      title: 'Chorak imtihoni',
      body: 'Jadval ilovada.',
      audience: SCHOOL,
      sendAt: '2099-05-01T09:00',
      repeat: 'NONE',
    });
    expect(created.sendAt).toBe('2099-05-01T09:00:00');
    const toggled = await commsService.reminders.setActive(created.id, false);
    expect(toggled.active).toBe(false);
    const upcoming = await commsService.reminders.list({ when: 'UPCOMING' });
    expect(upcoming.items.some((r) => r.id === created.id)).toBe(true);
    await commsService.reminders.remove(created.id);
    expect(getTables().reminders.some((r) => r.id === created.id)).toBe(false);
    loginAs('HOMEROOM');
    await expect(commsService.reminders.list()).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});
