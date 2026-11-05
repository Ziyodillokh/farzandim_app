// Bola ilovasi: maktab e'lonlari — `includeStudents` auditoriyasi, ko'rinish izolyatsiyasi
// (boshqa sinf / maktab / qoralama / vasiylar), kursor, o'qildi belgisi, ruxsatlar.

import { resetDb } from './db';
import { consumerToken } from './factories';
import { seedWorld, World } from './school-attendance-fixtures';
import { appReq, linkNewChild, schoolReq, unlinkedChild } from './school-child-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School child app: e\'lonlar (includeStudents)', () => {
  let t: TestApp;
  let w: World;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    w = await seedWorld(t);
  });

  afterAll(() => t.close());

  const audience = (kind: string, extra: Record<string, unknown> = {}) => ({ kind, classIds: [], guardianIds: [], ...extra });
  const input = (aud: object, title = 'Sinov', extra: Record<string, unknown> = {}) => ({
    title,
    body: "Ertaga soat 09:00 da yig'ilish.",
    priority: 'NORMAL',
    audience: aud,
    ...extra,
  });
  const send = async (s: World['admin'], aud: object, title?: string) => {
    const res = await schoolReq(t, s, 'POST', '/comms/announcements/send', input(aud, title));
    expect(res.statusCode).toBe(200);
    return res.json() as { id: string; audience: Record<string, unknown> };
  };
  const feed = (token = w.child.token, query = '') => appReq(t, token, 'GET', `/child/school/announcements${query}`);
  const titles = (res: { json(): { items: { title: string }[] } }) => res.json().items.map((i) => i.title);

  it('staff: includeStudents is stored, returned by detail and list, and normalized for GUARDIANS', async () => {
    const created = await send(w.admin, audience('SCHOOL', { includeStudents: true }), 'Maktab');
    expect(created.audience).toEqual({ kind: 'SCHOOL', classIds: [], guardianIds: [], includeStudents: true });

    const detail = (await schoolReq(t, w.admin, 'GET', `/comms/announcements/${created.id}`)).json();
    expect(detail.audience.includeStudents).toBe(true);
    const list = (await schoolReq(t, w.admin, 'GET', '/comms/announcements')).json();
    expect(list.items[0].audience.includeStudents).toBe(true);

    const plain = await send(w.admin, audience('SCHOOL'), 'Oddiy');
    expect(plain.audience.includeStudents).toBe(false);

    const guardians = await send(w.admin, audience('GUARDIANS', { guardianIds: [w.guardianId], includeStudents: true }), 'Vasiy');
    expect(guardians.audience.includeStudents).toBe(false);

    const draft = await schoolReq(t, w.admin, 'POST', '/comms/announcements/drafts', input(audience('CLASSES', { classIds: [w.classA], includeStudents: true })));
    expect(draft.statusCode).toBe(201);
    expect(draft.json().audience).toMatchObject({ kind: 'CLASSES', includeStudents: true });

    const bad = await schoolReq(t, w.admin, 'POST', '/comms/announcements/send', input(audience('SCHOOL', { includeStudents: 'yes' })));
    expect(bad.statusCode).toBe(400);
  });

  it('shows SCHOOL and own-CLASS announcements with includeStudents only; never other classes, guardians or unsent', async () => {
    await send(w.admin, audience('SCHOOL', { includeStudents: true }), 'Butun maktab');
    await send(w.admin, audience('CLASSES', { classIds: [w.classA], includeStudents: true }), '7-A uchun');
    await send(w.admin, audience('CLASSES', { classIds: [w.classA, w.classB], includeStudents: true }), '7-A va 8-B');
    await send(w.admin, audience('CLASSES', { classIds: [w.classB], includeStudents: true }), '8-B uchun');
    await send(w.admin, audience('SCHOOL'), 'Faqat ota-onalar');
    await send(w.admin, audience('CLASSES', { classIds: [w.classA] }), '7-A ota-onalar');
    await send(w.admin, audience('GUARDIANS', { guardianIds: [w.guardianId], includeStudents: true }), 'Vasiy');
    await schoolReq(t, w.admin, 'POST', '/comms/announcements/drafts', input(audience('SCHOOL', { includeStudents: true }), 'Qoralama'));
    const future = new Date(Date.now() + 86_400_000 + 5 * 3_600_000).toISOString().slice(0, 16);
    await schoolReq(t, w.admin, 'POST', '/comms/announcements/send', {
      ...input(audience('SCHOOL', { includeStudents: true }), 'Rejali'),
      scheduledAt: future,
    });

    const res = await feed();
    expect(res.statusCode).toBe(200);
    expect(titles(res).sort()).toEqual(['7-A uchun', '7-A va 8-B', 'Butun maktab']);
    expect(res.json()).toMatchObject({ unreadCount: 3, nextCursor: null });

    const school = res.json().items.find((i: { title: string }) => i.title === 'Butun maktab');
    expect(school).toMatchObject({
      priority: 'NORMAL',
      audienceLabel: 'SCHOOL',
      read: false,
      author: { name: 'ADMIN xodim', role: 'ADMIN' },
    });
    expect(school.className).toBeUndefined();
    expect(school.sentAt).toEqual(expect.any(String));
    const klass = res.json().items.find((i: { title: string }) => i.title === '7-A uchun');
    expect(klass).toMatchObject({ audienceLabel: 'CLASS', className: '7-A', author: { name: 'ADMIN xodim', role: 'ADMIN' } });
  });

  it('a child in another class sees the other class announcements, not this one', async () => {
    const bekChild = await linkNewChild(t, w.bek);
    await send(w.admin, audience('CLASSES', { classIds: [w.classA], includeStudents: true }), '7-A uchun');
    await send(w.admin, audience('CLASSES', { classIds: [w.classB], includeStudents: true }), '8-B uchun');

    expect(titles(await feed(bekChild.token))).toEqual(['8-B uchun']);
    expect(titles(await feed())).toEqual(['7-A uchun']);
  });

  it('follows the child when the student moves class', async () => {
    await send(w.admin, audience('CLASSES', { classIds: [w.classB], includeStudents: true }), '8-B uchun');
    expect(titles(await feed())).toEqual([]);

    await t.prisma.schoolStudent.update({ where: { id: w.vali }, data: { classId: w.classB } });

    expect(titles(await feed())).toEqual(['8-B uchun']);
  });

  it("a homeroom teacher's class announcement reaches own class students", async () => {
    const res = await schoolReq(t, w.homeroom, 'POST', '/comms/announcements/send', input(audience('CLASSES', { classIds: [w.classA], includeStudents: true }), 'Rahbardan'));
    expect(res.statusCode).toBe(200);

    expect(titles(await feed())).toEqual(['Rahbardan']);
    expect((await feed()).json().items[0].author).toEqual({ name: 'HOMEROOM xodim', role: 'HOMEROOM' });
  });

  it("never shows another school's announcements", async () => {
    const other = await seedWorld(t, 'other-school');
    await send(other.admin, audience('SCHOOL', { includeStudents: true }), 'Boshqa maktab');
    await send(other.admin, audience('CLASSES', { classIds: [other.classA], includeStudents: true }), 'Boshqa sinf');

    expect(titles(await feed())).toEqual([]);
    expect((await feed()).json().unreadCount).toBe(0);
  });

  it('orders newest first, paginates with an opaque cursor and rejects a broken one', async () => {
    const ids: string[] = [];
    for (const title of ['A', 'B', 'C', 'D', 'E']) ids.push((await send(w.admin, audience('SCHOOL', { includeStudents: true }), title)).id);
    // aniq tartib: A eng eski ... E eng yangi
    for (const [i, id] of ids.entries()) {
      await t.prisma.schoolAnnouncement.update({ where: { id }, data: { sentAt: new Date(Date.UTC(2026, 9, 20, 5, i)) } });
    }
    // E bilan bir xil vaqt — id bo'yicha ajratiladi
    const tie = await send(w.admin, audience('SCHOOL', { includeStudents: true }), 'E2');
    await t.prisma.schoolAnnouncement.update({ where: { id: tie.id }, data: { sentAt: new Date(Date.UTC(2026, 9, 20, 5, 4)) } });

    const first = (await feed(w.child.token, '?limit=2')).json();
    expect(first.items).toHaveLength(2);
    expect(first.nextCursor).toEqual(expect.any(String));
    const second = (await feed(w.child.token, `?limit=2&cursor=${first.nextCursor}`)).json();
    const third = (await feed(w.child.token, `?limit=2&cursor=${second.nextCursor}`)).json();

    const all = [...first.items, ...second.items, ...third.items].map((i: { title: string }) => i.title);
    expect(all).toHaveLength(6);
    expect(new Set(all).size).toBe(6);
    expect(all.slice(0, 2).sort()).toEqual(['E', 'E2']);
    expect(all.slice(2)).toEqual(['D', 'C', 'B', 'A']);
    expect(third.nextCursor).toBeNull();
    expect(first.unreadCount).toBe(6);

    expect((await feed(w.child.token, '?cursor=%25%25')).statusCode).toBe(400);
    expect((await feed(w.child.token, '?limit=0')).statusCode).toBe(400);
    expect((await feed(w.child.token, '?limit=51')).statusCode).toBe(400);
  });

  it('marks as read idempotently and keeps the first read time; unreadCount follows', async () => {
    const a = await send(w.admin, audience('SCHOOL', { includeStudents: true }), 'A');
    await send(w.admin, audience('SCHOOL', { includeStudents: true }), 'B');

    const first = await appReq(t, w.child.token, 'POST', `/child/school/announcements/${a.id}/read`);
    expect(first.statusCode).toBe(200);
    const again = await appReq(t, w.child.token, 'POST', `/child/school/announcements/${a.id}/read`);
    expect(again.json()).toEqual(first.json());
    expect(await t.prisma.schoolAnnouncementStudentRead.count()).toBe(1);

    const res = (await feed()).json();
    expect(res.unreadCount).toBe(1);
    expect(res.items.find((i: { id: string }) => i.id === a.id).read).toBe(true);
    // ota-ona o'qishi (Delivery) tegilmagan
    expect(await t.prisma.schoolAnnouncementDelivery.count({ where: { readAt: { not: null } } })).toBe(0);
  });

  it('read is per student: a classmate is unaffected', async () => {
    const malikaChild = await linkNewChild(t, w.malika);
    const a = await send(w.admin, audience('SCHOOL', { includeStudents: true }), 'A');
    await appReq(t, w.child.token, 'POST', `/child/school/announcements/${a.id}/read`);

    expect((await feed(malikaChild.token)).json().items[0].read).toBe(false);
    expect((await feed(malikaChild.token)).json().unreadCount).toBe(1);
  });

  it('read returns 404 for invisible announcements (other class, other school, parents-only, draft, unknown)', async () => {
    const other = await seedWorld(t, 'other-school');
    const otherClass = await send(w.admin, audience('CLASSES', { classIds: [w.classB], includeStudents: true }), '8-B');
    const foreign = await send(other.admin, audience('SCHOOL', { includeStudents: true }), 'Boshqa');
    const parentsOnly = await send(w.admin, audience('SCHOOL'), 'Ota-onalar');
    const draft = (await schoolReq(t, w.admin, 'POST', '/comms/announcements/drafts', input(audience('SCHOOL', { includeStudents: true })))).json();

    for (const id of [otherClass.id, foreign.id, parentsOnly.id, draft.id, 'no-such-id']) {
      const res = await appReq(t, w.child.token, 'POST', `/child/school/announcements/${id}/read`);
      expect(res.statusCode).toBe(404);
    }
    expect(await t.prisma.schoolAnnouncementStudentRead.count()).toBe(0);
  });

  it('auth: parent and anonymous callers are rejected; unlinked or archived children get 404 NOT_ENROLLED', async () => {
    const a = await send(w.admin, audience('SCHOOL', { includeStudents: true }), 'A');

    expect((await appReq(t, w.parent.token, 'GET', '/child/school/announcements')).statusCode).toBe(403);
    expect((await appReq(t, w.parent.token, 'POST', `/child/school/announcements/${a.id}/read`)).statusCode).toBe(403);
    expect((await t.app.inject({ method: 'GET', url: '/api/child/school/announcements' })).statusCode).toBe(401);
    expect((await appReq(t, consumerToken('ghost', 'CHILD'), 'GET', '/child/school/announcements')).statusCode).toBe(404);

    const lonely = await unlinkedChild(t);
    const res = await appReq(t, lonely.token, 'GET', '/child/school/announcements');
    expect(res.statusCode).toBe(404);
    expect(res.json()).toMatchObject({ code: 'NOT_ENROLLED' });
    expect((await appReq(t, lonely.token, 'POST', `/child/school/announcements/${a.id}/read`)).statusCode).toBe(404);

    await t.prisma.schoolStudent.update({ where: { id: w.vali }, data: { archived: true } });
    expect((await feed()).statusCode).toBe(404);
  });
});
