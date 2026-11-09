import { beforeEach, describe, expect, it } from 'vitest';

import { ServiceError } from '@/data/contracts';
import { getTables } from '../db';
import { inboxService } from '../services/inbox';
import { buildFeed } from '../services/notifications';
import { currentActor } from '../context';
import { clockNow } from '../clock';
import { freshDb, loginAs } from './helpers';

describe('Ota-onalar xabarlari (mock)', () => {
  beforeEach(() => {
    freshDb();
  });

  it('har demo xodim faqat o\'ziga yozilgan yozishmalarni ko\'radi', async () => {
    const seen = new Map<string, string[]>();
    for (const role of ['HOMEROOM', 'DIRECTOR', 'ADMIN', 'PSYCHOLOGIST'] as const) {
      loginAs(role);
      const page = await inboxService.list({ status: 'ALL' });
      expect(page.items.length).toBeGreaterThan(0);
      seen.set(role, page.items.map((t) => t.id));
    }
    const all = [...seen.values()].flat();
    expect(new Set(all).size).toBe(all.length);

    loginAs('DIRECTOR');
    const homeroomThread = seen.get('HOMEROOM')![0]!;
    await expect(inboxService.get(homeroomThread)).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('navbatchida ruxsat yo\'q', async () => {
    loginAs('DUTY');
    await expect(inboxService.list({ status: 'OPEN' })).rejects.toBeInstanceOf(ServiceError);
  });

  it('ochiq / hal qilingan filtri, qidiruv va o\'qilmaganlar soni', async () => {
    loginAs('HOMEROOM');
    const open = await inboxService.list({ status: 'OPEN' });
    const resolved = await inboxService.list({ status: 'RESOLVED' });
    expect(open.items.every((t) => t.status === 'OPEN')).toBe(true);
    expect(resolved.items.every((t) => t.status === 'RESOLVED')).toBe(true);
    // 7-A: kasallik xabari (yangi) va uy vazifasi (javobdan keyin ota-ona "rahmat" yozgan) — ikkalasi o'qilmagan.
    expect(open.counts).toEqual({ unread: 2, open: 2 });
    const name = open.items[0]!.guardian.fullName.split(' ')[0]!;
    const found = await inboxService.list({ status: 'ALL', search: name.toLowerCase() });
    expect(found.items.some((t) => t.guardian.fullName.startsWith(name))).toBe(true);
  });

  it('o\'qildi, javob va holat: nishon, "o\'qildi" belgisi va audit (matnsiz)', async () => {
    loginAs('HOMEROOM');
    const unreadThread = (await inboxService.list({ status: 'OPEN' })).items.find((t) => t.unread > 0)!;
    const before = await inboxService.get(unreadThread.id);
    expect(before.messages.at(-1)).toMatchObject({ author: 'PARENT', seen: false });

    const unreadBefore = (await inboxService.summary()).unread;
    await inboxService.markRead(unreadThread.id);
    expect((await inboxService.summary()).unread).toBe(unreadBefore - 1);
    expect((await inboxService.get(unreadThread.id)).messages.at(-1)!.seen).toBe(true);

    const replied = await inboxService.reply(unreadThread.id, '  Rahmat, qabul qildim.  ');
    expect(replied.messages.at(-1)).toMatchObject({ author: 'STAFF', body: 'Rahmat, qabul qildim.', seen: false });
    expect(replied.lastAuthor).toBe('STAFF');

    const resolved = await inboxService.setStatus(unreadThread.id, 'RESOLVED');
    expect(resolved.status).toBe('RESOLVED');
    const audit = getTables().audit.filter((a) => a.action.startsWith('parentThread.'));
    expect(audit.map((a) => a.action)).toEqual(['parentThread.reply', 'parentThread.resolve']);
    expect(JSON.stringify(audit)).not.toContain('qabul qildim');

    await expect(inboxService.reply(unreadThread.id, '   ')).rejects.toMatchObject({ code: 'VALIDATION' });
  });

  it('bildirishnoma — faqat qabul qiluvchiga, o\'qilgach yo\'qoladi', async () => {
    loginAs('PSYCHOLOGIST');
    const feed = buildFeed(getTables(), currentActor(), new Date(clockNow().getTime() + 86_400_000));
    const item = feed.find((n) => n.kind === 'PARENT_MESSAGE');
    expect(item).toMatchObject({ href: expect.stringMatching(/^\/inbox\?thread=/), subject: { uz: 'Kayfiyat va holat' } });

    loginAs('DIRECTOR');
    const directorFeed = buildFeed(getTables(), currentActor(), new Date(clockNow().getTime() + 86_400_000));
    expect(directorFeed.filter((n) => n.kind === 'PARENT_MESSAGE').every((n) => !n.href?.endsWith(item!.href!.split('=')[1]!))).toBe(true);

    loginAs('PSYCHOLOGIST');
    await inboxService.markRead(item!.href!.split('=')[1]!);
    const after = buildFeed(getTables(), currentActor(), new Date(clockNow().getTime() + 86_400_000));
    expect(after.some((n) => n.kind === 'PARENT_MESSAGE')).toBe(false);
  });
});
