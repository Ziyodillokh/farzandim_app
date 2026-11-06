import { beforeEach, describe, expect, it } from 'vitest';

import { getDb, getTables } from '../db';
import { FIXED_STAFF } from '../seed/people';
import { careService } from '../services/care';
import { freshDb, loginAs } from './helpers';

const PSYCHOLOGIST_NAME = 'Sobirova Lola Baxromovna';
/** Seed: o'qilmagan bola xabari bor, psixolog javob bergan, jarayonda. */
const WITH_UNREAD = 'care-3';
const URGENT_UNOPENED = 'care-1';
const NORMAL_UNOPENED = 'care-2';
const SCHEDULED = 'care-4';
const RESOLVED = 'care-5';

describe('Bola ovozi — yozishma (seed va ro\'yxat)', () => {
  beforeEach(() => {
    freshDb();
    loginAs('PSYCHOLOGIST');
  });

  it('har murojaatning birinchi xabari — bolaning murojaati; mas\'ul psixologga biriktirilgan', () => {
    for (const r of getTables().careRequests) {
      expect(r.messages[0]).toMatchObject({ author: 'CHILD', text: r.message, createdAt: r.createdAt });
      expect(r.assignedStaffId).toBe(FIXED_STAFF.psychologist);
      expect(r.lastMessageAt).not.toBeNull();
    }
  });

  it('qatorlar: ochilgan/ochilmagan, javob, mas\'ul va o\'qilmagan xabar soni; shoshilinch tepada', async () => {
    const { items } = await careService.listRequests();
    expect(items[0]?.id).toBe(URGENT_UNOPENED);
    // Ochilmagan murojaatda bolaning birinchi xabari ham o'qilmagan hisoblanadi.
    expect(items[0]).toMatchObject({ openedAt: null, repliedAt: null, unreadFromChild: 1, escalatedAt: null, assignedTo: { id: FIXED_STAFF.psychologist, name: PSYCHOLOGIST_NAME } });
    const withUnread = items.find((r) => r.id === WITH_UNREAD);
    expect(withUnread).toMatchObject({ unreadFromChild: 1 });
    expect(withUnread?.openedAt).not.toBeNull();
    expect(withUnread?.repliedAt).not.toBeNull();
    // Ro'yxatda o'qilmagan xabar soni ko'rinadi, lekin ro'yxat yozuvni o'qilgan qilmaydi.
    expect((await careService.listRequests()).items.find((r) => r.id === WITH_UNREAD)?.unreadFromChild).toBe(1);
  });

  it('shoshilinch va yopilmagan murojaatlar har doim yopilganlardan oldin', async () => {
    const { items } = await careService.listRequests();
    const lastOpenUrgent = items.map((r) => r.urgency === 'URGENT' && r.status !== 'RESOLVED').lastIndexOf(true);
    const firstOther = items.findIndex((r) => !(r.urgency === 'URGENT' && r.status !== 'RESOLVED'));
    expect(lastOpenUrgent).toBeLessThan(firstOther);
  });

  it('ro\'yxat qatorida bola xabari matni dublikat emas (faqat murojaat matni) va ism/sinf bor', async () => {
    const row = (await careService.listRequests()).items.find((r) => r.id === URGENT_UNOPENED);
    expect(row?.studentName).not.toBe('—');
    expect(row?.className).toBe('8-B');
    expect(row?.notesCount).toBe(0);
  });
});

describe('Bola ovozi — murojaatni ochish', () => {
  beforeEach(() => {
    freshDb();
    loginAs('PSYCHOLOGIST');
  });

  it('birinchi ochishda openedAt/openedBy qo\'yiladi, auditga matnsiz yoziladi; qayta ochilganda yozuv yo\'q', async () => {
    const detail = await careService.getRequest(URGENT_UNOPENED);
    expect(detail.openedAt).not.toBeNull();
    expect(detail.openedBy).toEqual({ id: FIXED_STAFF.psychologist, name: PSYCHOLOGIST_NAME });
    const opens = getTables().audit.filter((a) => a.action === 'care.request.open');
    expect(opens).toHaveLength(1);
    expect(opens[0]).toMatchObject({ module: 'CARE', entityId: null, before: null, after: null });
    expect(JSON.stringify(opens[0]).includes(URGENT_UNOPENED)).toBe(false);

    const before = getDb();
    const again = await careService.getRequest(URGENT_UNOPENED);
    expect(again.openedAt).toBe(detail.openedAt);
    expect(getDb()).toBe(before); // hech narsa o'zgarmasa bazaga yozilmaydi (yangilanish aylanishi yo'q)
    expect(getTables().audit.filter((a) => a.action === 'care.request.open')).toHaveLength(1);
  });

  it('ochilganda bolaning o\'qilmagan xabarlari o\'qilgan bo\'ladi', async () => {
    await careService.getRequest(WITH_UNREAD);
    const row = (await careService.listRequests()).items.find((r) => r.id === WITH_UNREAD);
    expect(row?.unreadFromChild).toBe(0);
  });

  it('yozishma xronologik: bola va xodim xabarlari, xodim ismi bilan', async () => {
    const detail = await careService.getRequest(WITH_UNREAD);
    expect(detail.messages.map((m) => m.author)).toEqual(['CHILD', 'STAFF', 'CHILD']);
    expect(detail.messages[0]?.authorName).toBeNull();
    expect(detail.messages[1]?.authorName).toBe(PSYCHOLOGIST_NAME);
    const times = detail.messages.map((m) => Date.parse(m.createdAt));
    expect([...times].sort((a, b) => a - b)).toEqual(times);
  });

  it('boshqa rollar ko\'ra olmaydi (FORBIDDEN)', async () => {
    for (const role of ['DIRECTOR', 'ADMIN', 'HOMEROOM', 'DUTY'] as const) {
      loginAs(role);
      await expect(careService.getRequest(URGENT_UNOPENED)).rejects.toMatchObject({ code: 'FORBIDDEN' });
      await expect(careService.replyToRequest(URGENT_UNOPENED, 'Salom')).rejects.toMatchObject({ code: 'FORBIDDEN' });
    }
  });

  it('noma\'lum murojaat — NOT_FOUND', async () => {
    await expect(careService.getRequest('care-yoq')).rejects.toMatchObject({ code: 'NOT_FOUND' });
    await expect(careService.replyToRequest('care-yoq', 'Salom')).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });
});

describe('Bola ovozi — bolaga javob', () => {
  beforeEach(() => {
    freshDb();
    loginAs('PSYCHOLOGIST');
  });

  it('javob yozishmaga qo\'shiladi: xodim ismi bilan; birinchi javobda repliedAt, holat NEW → IN_PROGRESS', async () => {
    const message = await careService.replyToRequest(NORMAL_UNOPENED, '  Salom! Seni eshitaman.  ');
    expect(message).toMatchObject({ author: 'STAFF', authorName: PSYCHOLOGIST_NAME, text: 'Salom! Seni eshitaman.' });
    const detail = await careService.getRequest(NORMAL_UNOPENED);
    expect(detail.messages.at(-1)).toMatchObject({ id: message.id, author: 'STAFF', text: 'Salom! Seni eshitaman.' });
    expect(detail.status).toBe('IN_PROGRESS');
    expect(detail.repliedAt).not.toBeNull();
    expect(detail.openedAt).not.toBeNull();
  });

  it('ikkinchi javob repliedAt ni o\'zgartirmaydi; SCHEDULED holat saqlanadi', async () => {
    await careService.replyToRequest(SCHEDULED, 'Yana bir narsa.');
    const first = (await careService.getRequest(SCHEDULED)).repliedAt;
    await careService.replyToRequest(SCHEDULED, 'Va yana.');
    const detail = await careService.getRequest(SCHEDULED);
    expect(detail.repliedAt).toBe(first);
    expect(detail.status).toBe('SCHEDULED');
    expect(detail.messages.filter((m) => m.author === 'STAFF')).toHaveLength(3);
  });

  it('IKKI ALOHIDA KANAL: javob ichki eslatmalarga tushmaydi, eslatma esa yozishmada (bola ko\'radigan xabarlarda) ko\'rinmaydi', async () => {
    await careService.replyToRequest(WITH_UNREAD, 'Bolaga ko\'rinadigan javob');
    await careService.addRequestNote(WITH_UNREAD, 'FAQAT-ICHKI eslatma');
    const detail = await careService.getRequest(WITH_UNREAD);
    expect(detail.notes.map((n) => n.text)).toContain('FAQAT-ICHKI eslatma');
    expect(detail.notes.map((n) => n.text)).not.toContain('Bolaga ko\'rinadigan javob');
    const childVisible = JSON.stringify(detail.messages);
    expect(childVisible.includes('FAQAT-ICHKI')).toBe(false);
    expect(childVisible.includes('Bolaga ko\'rinadigan javob')).toBe(true);
    // Saqlangan yozuvda ham ichki eslatma xabarlar massiviga aralashmagan.
    const stored = getTables().careRequests.find((r) => r.id === WITH_UNREAD);
    expect(stored?.messages.some((m) => m.text.includes('FAQAT-ICHKI'))).toBe(false);
  });

  it('yopilgan murojaatga javob — CONFLICT; qayta ochilgach yuboriladi', async () => {
    await expect(careService.replyToRequest(RESOLVED, 'Salom')).rejects.toMatchObject({ code: 'CONFLICT' });
    await careService.updateRequestStatus(RESOLVED, 'IN_PROGRESS');
    await expect(careService.replyToRequest(RESOLVED, 'Salom')).resolves.toMatchObject({ author: 'STAFF' });
  });

  it('matn: bo\'sh/bo\'shliq — VALIDATION; 2000 belgi mumkin, 2001 — rad', async () => {
    await expect(careService.replyToRequest(NORMAL_UNOPENED, '   ')).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(careService.replyToRequest(NORMAL_UNOPENED, 'x'.repeat(2001))).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(careService.replyToRequest(NORMAL_UNOPENED, 'x'.repeat(2000))).resolves.toMatchObject({ author: 'STAFF' });
  });

  it('auditga matn va murojaat ID\'si yozilmaydi', async () => {
    await careService.replyToRequest(NORMAL_UNOPENED, 'Maxfiy matn 123');
    const entry = getTables().audit.filter((a) => a.action === 'care.request.reply').at(-1);
    expect(entry).toMatchObject({ module: 'CARE', entityId: null, before: null, after: null });
    const json = JSON.stringify(entry);
    // Kim qilgani (actorName) auditda bo'ladi; matn va murojaat ID'si — yo'q.
    for (const secret of ['Maxfiy', NORMAL_UNOPENED]) expect(json.includes(secret)).toBe(false);
  });

  it('yopish resolvedAt ni qo\'yadi, qayta ochish tozalaydi', async () => {
    await careService.updateRequestStatus(NORMAL_UNOPENED, 'RESOLVED');
    expect((await careService.getRequest(NORMAL_UNOPENED)).resolvedAt).not.toBeNull();
    await careService.updateRequestStatus(NORMAL_UNOPENED, 'IN_PROGRESS');
    expect((await careService.getRequest(NORMAL_UNOPENED)).resolvedAt).toBeNull();
  });
});

describe('Bola ovozi — eski bazadagi murojaatlar', () => {
  it('yozishmasiz murojaatdan `initial` xabari yasaladi (migratsiya)', async () => {
    const { migrate, createFreshSnapshot } = await import('../db');
    const fresh = createFreshSnapshot(new Date(2026, 9, 14, 10));
    const legacyRequests = fresh.tables.careRequests.map((r) => {
      const { messages: _m, assignedStaffId: _a, openedAt: _o, openedByStaffId: _ob, repliedAt: _r, resolvedAt: _rs, escalatedAt: _e, lastMessageAt: _l, ...rest } = r;
      void [_m, _a, _o, _ob, _r, _rs, _e, _l];
      return rest;
    }) as unknown as typeof fresh.tables.careRequests;
    const migrated = migrate({ ...fresh, tables: { ...fresh.tables, careRequests: legacyRequests } });
    for (const r of migrated.tables.careRequests) {
      expect(r.messages).toHaveLength(1);
      expect(r.messages[0]).toMatchObject({ id: 'initial', author: 'CHILD', text: r.message });
      expect(r.escalatedAt).toBeNull();
      expect(r.status === 'NEW' ? r.openedAt === null : r.openedAt !== null).toBe(true);
    }
    expect(migrate(migrated)).toBe(migrated);
  });
});

describe('demo: yangi shoshilinch murojaat', () => {
  it('bolaning birinchi xabari bilan, mas\'ul psixologga biriktirilgan, ochilmagan', async () => {
    freshDb();
    loginAs('PSYCHOLOGIST');
    const { demoService } = await import('../services/demo');
    demoService.trigger('CARE_URGENT');
    const created = getTables().careRequests.at(-1);
    expect(created).toMatchObject({ urgency: 'URGENT', status: 'NEW', openedAt: null, assignedStaffId: FIXED_STAFF.psychologist });
    expect(created?.messages).toHaveLength(1);
    expect(created?.messages[0]).toMatchObject({ author: 'CHILD', text: created?.message });
  });
});
