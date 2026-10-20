import { beforeEach, describe, expect, it } from 'vitest';

import type { NotificationItem, NotificationKind } from '@/data/contracts';
import {
  emptyReadState,
  groupByDay,
  markAllRead,
  markRead,
  normalizeReadState,
  READ_CAP,
  readKey,
  unreadCount,
} from '@/features/notifications/read-state';
import { currentActor } from '../context';
import { getTables, transact } from '../db';
import { pushNotification } from '../notify';
import { buildFeed, FEED_LIMIT, notificationsService, openRequests } from '../services/notifications';
import { freshDb, loginAs } from './helpers';

const NOW = new Date(2026, 9, 12, 10, 0, 0);

function kindsOf(items: readonly NotificationItem[]): Set<NotificationKind> {
  return new Set(items.map((i) => i.kind));
}

function feedAs(role: Parameters<typeof loginAs>[0]): NotificationItem[] {
  loginAs(role);
  return buildFeed(getTables(), currentActor(), NOW);
}

describe('bildirishnomalar lentasi: rolga mos', () => {
  beforeEach(freshDb);

  it('direktor: erta ketish, to\'lov tekshiruvi va xabarlar; Bola ovozi murojaatlari yo\'q', () => {
    const kinds = kindsOf(feedAs('DIRECTOR'));
    expect(kinds.has('EARLY_EXIT_PENDING')).toBe(true);
    expect(kinds.has('VERIFICATION_OPEN')).toBe(true);
    expect(kinds.has('MESSAGE_SENT')).toBe(true);
    expect(kinds.has('CARE_NEW')).toBe(false);
    expect(kinds.has('CARE_URGENT')).toBe(false);
  });

  it('psixolog: faqat murojaatlar (shaxsiy), davomat/to\'lov/xabar yo\'q', () => {
    const items = feedAs('PSYCHOLOGIST');
    const kinds = kindsOf(items);
    expect(kinds.has('CARE_URGENT') || kinds.has('CARE_NEW')).toBe(true);
    for (const k of ['EARLY_EXIT_PENDING', 'VERIFICATION_OPEN', 'MESSAGE_SENT', 'EMERGENCY'] as const) expect(kinds.has(k)).toBe(false);
    // Murojaat elementida ism yo'q — faqat sinf.
    const care = items.find((i) => i.kind.startsWith('CARE_'));
    expect(Object.keys(care?.params ?? {})).toEqual(['className']);
    expect(care?.subject?.uz).toBeTruthy();
  });

  it('sinf rahbari: faqat o\'z sinfining erta ketish so\'rovlari, to\'lov yo\'q', () => {
    const items = feedAs('HOMEROOM');
    const exits = items.filter((i) => i.kind === 'EARLY_EXIT_PENDING');
    expect(exits.length).toBeGreaterThan(0);
    const ids = exits.map((i) => i.id.replace('exit:', ''));
    const classIds = getTables().earlyExits.filter((e) => ids.includes(e.id)).map((e) => e.classId);
    expect(new Set(classIds)).toEqual(new Set(['cls-7a']));
    expect(kindsOf(items).has('VERIFICATION_OPEN')).toBe(false);
  });

  it('navbatchi: erta ketish va xavfsizlik signali, xabarlar yo\'q', () => {
    const kinds = kindsOf(feedAs('DUTY'));
    expect(kinds.has('EARLY_EXIT_PENDING')).toBe(true);
    expect(kinds.has('MESSAGE_SENT')).toBe(false);
    expect(kinds.has('VERIFICATION_OPEN')).toBe(false);
  });

  it('erta ketish: tarix ruxsatisiz (navbatchi) — faqat bugungi va sababsiz; sinf rahbari sababni ko\'radi', () => {
    transact((t) => {
      const today = t.earlyExits.find((e) => e.status === 'PENDING' && e.classId === 'cls-7a');
      if (!today) throw new Error('seed: pending early exit in 7-A');
      t.earlyExits.push({ ...today, id: 'ee-old', date: '2026-10-09', requestedAt: '2026-10-09T09:00:00', reason: 'Shifokor ko\'rigi' });
      t.earlyExits = t.earlyExits.map((e) => (e.id === today.id ? { ...e, date: '2026-10-12', requestedAt: '2026-10-12T08:30:00' } : e));
    });
    const duty = feedAs('DUTY').filter((i) => i.kind === 'EARLY_EXIT_PENDING');
    expect(duty.length).toBeGreaterThan(0);
    expect(duty.map((i) => i.id)).not.toContain('exit:ee-old');
    for (const item of duty) expect(item.subject).toBeNull();
    const homeroom = feedAs('HOMEROOM').filter((i) => i.kind === 'EARLY_EXIT_PENDING');
    expect(homeroom.find((i) => i.id === 'exit:ee-old')?.subject?.uz).toBe('Shifokor ko\'rigi');
  });

  it('id\'lar barqaror va manbaga ko\'ra prefiksli', () => {
    const items = feedAs('DIRECTOR');
    for (const item of items) {
      const prefix = { EARLY_EXIT_PENDING: 'exit:', VERIFICATION_OPEN: 'ver:', MESSAGE_SENT: 'ann:', EMERGENCY: 'emg:' }[item.kind as string];
      if (prefix) expect(item.id.startsWith(prefix)).toBe(true);
    }
    expect(buildFeed(getTables(), currentActor(), NOW).map((i) => i.id)).toEqual(items.map((i) => i.id));
  });

  it('xavfsizlik signali: params {} va subject null (saqlangan yozuvda bo\'lsa ham)', () => {
    transact((t) => {
      pushNotification(t, {
        id: 'ntf-leak',
        kind: 'SAFETY_SIGNAL',
        at: '2026-10-12T09:30:00',
        roles: ['DIRECTOR'],
        classIds: null,
        params: { name: 'Aliyev Vali', className: '7-A' },
        subject: { uz: 'Matn', ru: 'Текст' },
        href: null,
      });
    });
    const signals = feedAs('DIRECTOR').filter((i) => i.kind === 'SAFETY_SIGNAL');
    expect(signals.length).toBeGreaterThan(0);
    for (const s of signals) {
      expect(s.params).toEqual({});
      expect(s.subject).toBeNull();
      expect(s.tone).toBe('destructive');
    }
  });

  it('eng yangilari birinchi, ko\'pi bilan 30 ta; demo soatidan keyingilar ko\'rinmaydi', () => {
    transact((t) => {
      for (let i = 0; i < 40; i++) {
        const minute = String(i % 60).padStart(2, '0');
        pushNotification(t, { id: `ntf-test-${i}`, kind: 'TEST_COMPLETED', at: `2026-10-12T08:${minute}:00`, roles: ['PSYCHOLOGIST'], classIds: null, params: { count: 2 }, subject: { uz: 'Test', ru: 'Тест' }, href: null });
      }
      pushNotification(t, { id: 'ntf-future', kind: 'TEST_COMPLETED', at: '2026-10-12T15:00:00', roles: ['PSYCHOLOGIST'], classIds: null, params: {}, subject: null, href: null });
    });
    const items = feedAs('PSYCHOLOGIST');
    expect(items).toHaveLength(FEED_LIMIT);
    const times = items.map((i) => Date.parse(i.at));
    expect([...times].sort((a, b) => b - a)).toEqual(times);
    expect(items.some((i) => i.id === 'ntf-future')).toBe(false);
  });

  it('TEST_COMPLETED: count bo\'lmasa — 1', () => {
    transact((t) => {
      pushNotification(t, { id: 'ntf-nocount', kind: 'TEST_COMPLETED', at: '2026-10-12T09:59:00', roles: ['PSYCHOLOGIST'], classIds: null, params: {}, subject: null, href: null });
    });
    expect(feedAs('PSYCHOLOGIST').find((i) => i.id === 'ntf-nocount')?.params.count).toBe(1);
  });

  it('favqulodda rejim: maktab rejimini ko\'radiganlarga', () => {
    transact((t) => {
      t.emergency = { active: true, scope: 'SCHOOL', classIds: [], reason: 'Mashq', byStaffId: 'stf-director', at: '2026-10-12T09:45:00' };
    });
    expect(kindsOf(feedAs('DIRECTOR')).has('EMERGENCY')).toBe(true);
    expect(kindsOf(feedAs('HOMEROOM')).has('EMERGENCY')).toBe(true);
    expect(kindsOf(feedAs('PSYCHOLOGIST')).has('EMERGENCY')).toBe(false);
  });

  it('demo soatidan keyingi ochiq so\'rovlar vaqti kelguncha yashirin (favqulodda — har doim)', () => {
    transact((t) => {
      t.verifications = t.verifications.map((v, i) => (i === 0 ? { ...v, status: 'OPEN' as const, createdAt: '2026-10-12T11:30:00' } : v));
      t.emergency = { active: true, scope: 'SCHOOL', classIds: [], reason: '', byStaffId: 'stf-director', at: '2026-10-12T14:00:00' };
    });
    const firstId = `ver:${getTables().verifications[0]?.id}`;
    const items = feedAs('DIRECTOR');
    expect(items.some((i) => i.id === firstId)).toBe(false);
    expect(kindsOf(items).has('EMERGENCY')).toBe(true);
    loginAs('DIRECTOR');
    expect(buildFeed(getTables(), currentActor(), new Date(2026, 9, 12, 11, 31)).some((i) => i.id === firstId)).toBe(true);
  });

  it('servis: sessiya talab qilinadi va lenta qaytadi', async () => {
    loginAs('ADMIN');
    const items = await notificationsService.feed();
    expect(items.length).toBeGreaterThan(0);
    expect(items.length).toBeLessThanOrEqual(FEED_LIMIT);
  });
});

describe('ochiq so\'rovlar (bosh sahifa KPI)', () => {
  beforeEach(freshDb);

  it('direktor: erta ketish + to\'lov tekshiruvlari', () => {
    loginAs('DIRECTOR');
    const t = getTables();
    const r = openRequests(t, currentActor());
    const pending = t.earlyExits.filter((e) => e.status === 'PENDING').length;
    const open = t.verifications.filter((v) => v.status === 'OPEN').length;
    expect(r).toEqual({ earlyExits: pending, verifications: open, total: pending + open, href: '/attendance/early-exit' });
  });

  it('sinf rahbari: faqat o\'z sinfi, to\'lov — null', () => {
    loginAs('HOMEROOM');
    const r = openRequests(getTables(), currentActor());
    expect(r?.verifications).toBeNull();
    expect(r?.earlyExits).toBe(getTables().earlyExits.filter((e) => e.status === 'PENDING' && e.classId === 'cls-7a').length);
  });

  it('psixolog (davomat ruxsati yo\'q) — null', () => {
    loginAs('PSYCHOLOGIST');
    expect(openRequests(getTables(), currentActor())).toBeNull();
  });

  it('erta ketish bo\'lmasa — tekshiruvlar sahifasiga', () => {
    loginAs('ADMIN');
    transact((t) => {
      t.earlyExits = t.earlyExits.map((e) => ({ ...e, status: 'APPROVED' as const }));
    });
    const r = openRequests(getTables(), currentActor());
    expect(r?.earlyExits).toBe(0);
    expect(r?.href).toBe('/reminders/verifications');
  });
});

describe('o\'qildi holati (read-state)', () => {
  const items: NotificationItem[] = [
    { id: 'a', kind: 'EARLY_EXIT_PENDING', at: '2026-10-12T09:00:00', tone: 'warning', params: {}, subject: null, href: null },
    { id: 'b', kind: 'VERIFICATION_OPEN', at: '2026-10-11T12:00:00', tone: 'info', params: {}, subject: null, href: null },
    { id: 'c', kind: 'MESSAGE_SENT', at: '2026-10-12T11:00:00', tone: 'success', params: {}, subject: null, href: null },
  ];

  it('bo\'sh holat — hammasi o\'qilmagan; markRead bittasini kamaytiradi', () => {
    const state = emptyReadState(1);
    expect(unreadCount(items, state)).toBe(3);
    expect(unreadCount(items, markRead(state, items[1]!))).toBe(2);
  });

  it('markAllRead — kelajak vaqtlilari ham o\'qiladi; keyingi yangi element o\'qilmagan', () => {
    const all = markAllRead(emptyReadState(1), items, '2026-10-12T10:00:00');
    expect(unreadCount(items, all)).toBe(0);
    const fresh = { ...items[0]!, id: 'd', at: '2026-10-12T10:05:00' };
    expect(unreadCount([...items, fresh], all)).toBe(1);
    // Xuddi o'sha soniyada kelgan yangi hodisa ham o'qilmagan.
    const sameSecond = { ...items[0]!, id: 'e', at: '2026-10-12T10:00:00' };
    expect(unreadCount([...items, sameSecond], all)).toBe(1);
  });

  it('epoch o\'zgarsa seenAt tashlanadi, alohida o\'qilganlar qoladi', () => {
    const state = markRead({ epoch: 1, seenAt: '2026-10-12T18:00:00', read: [] }, items[0]!);
    const next = normalizeReadState(state, 2);
    expect(next).toEqual({ epoch: 2, seenAt: null, read: [readKey(items[0]!)] });
    expect(unreadCount(items, next)).toBe(2);
    expect(normalizeReadState(state, 1).seenAt).toBe('2026-10-12T18:00:00');
  });

  it('read ro\'yxati 300 ta bilan cheklanadi va noto\'g\'ri qiymat tozalanadi', () => {
    let state = emptyReadState(0);
    for (let i = 0; i < READ_CAP + 25; i++) state = markRead(state, { id: `id-${i}`, at: '2026-10-12T09:00:00' });
    expect(state.read).toHaveLength(READ_CAP);
    expect(state.read.at(-1)).toBe(`id-${READ_CAP + 24}@2026-10-12T09:00:00`);
    expect(normalizeReadState({ read: [1, 'x', null], seenAt: 5 }, 3)).toEqual({ epoch: 3, seenAt: null, read: ['x'] });
    expect(normalizeReadState('garbage', 3)).toEqual(emptyReadState(3));
  });

  it('joyida yangilangan bildirishnoma (yangi vaqt) yana o\'qilmagan bo\'ladi', () => {
    const test = { ...items[0]!, id: 'ntf-test-pa-1-2026-10-12', kind: 'TEST_COMPLETED' as const, at: '2026-10-12T09:10:00' };
    const read = markRead(emptyReadState(1), test);
    expect(unreadCount([test], read)).toBe(0);
    expect(unreadCount([{ ...test, at: '2026-10-12T09:40:00' }], read)).toBe(1);
  });

  it('Bugun / Oldinroq guruhlari', () => {
    const groups = groupByDay(items, '2026-10-12');
    expect(groups.today.map((i) => i.id)).toEqual(['a', 'c']);
    expect(groups.earlier.map((i) => i.id)).toEqual(['b']);
  });
});
