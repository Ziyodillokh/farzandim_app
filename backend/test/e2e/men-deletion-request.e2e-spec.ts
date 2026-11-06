// Men (I09): bolaning "ma'lumotlarimni o'chiring" so'rovi — yaratish (201), takroriy (200, dublikat xabarsiz),
// limit (sutkada 3), eng so'nggisi, ruxsatlar, ota-ona push'i, maktab rahbariyatiga ma'lumotsiz bildirishnoma,
// audit va bola ma'lumotlari o'chirilganda so'rovlar ham ketishi. Hech narsa avtomatik o'chmaydi.

import { resetDb } from './db';
import { createChild, createParent } from './factories';
import { seedWorld, World } from './school-attendance-fixtures';
import { appReq, schoolReq } from './school-child-fixtures';
import { createTestApp, TestApp } from './test-app';

const DAY_MS = 24 * 60 * 60 * 1000;

describe('Men notify: ma\'lumot o\'chirish so\'rovi', () => {
  let t: TestApp;
  let w: World;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    w = await seedWorld(t);
  });

  afterAll(() => t.close());

  const url = (id = w.child.childId) => `/children/${id}/deletion-requests`;
  const create = (token = w.child.token, id?: string) => appReq(t, token, 'POST', url(id));
  const latest = (token = w.child.token, id?: string) => appReq(t, token, 'GET', `${url(id)}/latest`);
  const deletionPushes = () => t.fcm.pushesTo(w.parent.userId).filter((p) => p.data?.type === 'DATA_DELETION_REQUEST');
  const feed = async (s: World['director']) => {
    const res = await schoolReq(t, s, 'GET', '/notifications/feed');
    expect(res.statusCode).toBe(200);
    return (res.json() as Array<{ kind: string; params: Record<string, unknown>; subject: unknown; href: unknown }>).filter(
      (n) => n.kind === 'DATA_DELETION_REQUEST',
    );
  };

  describe('POST /children/:childId/deletion-requests', () => {
    it('creates a RECEIVED request (201) with the contract shape', async () => {
      const res = await create();

      expect(res.statusCode).toBe(201);
      expect(res.json()).toEqual({ id: expect.any(String), status: 'RECEIVED', createdAt: expect.stringMatching(/^\d{4}-\d\d-\d\dT.*Z$/) });
      expect(Object.keys(res.json()).sort()).toEqual(['createdAt', 'id', 'status']);
      const row = await t.prisma.childDataDeletionRequest.findUniqueOrThrow({ where: { id: res.json().id } });
      expect(row).toMatchObject({ childId: w.child.childId, status: 'RECEIVED', closedAt: null });
    });

    it('deletes nothing automatically', async () => {
      await t.prisma.notification.create({ data: { childId: w.child.childId, type: 'SYSTEM', title: 'x', body: 'y' } });

      await create();

      expect(await t.prisma.child.count({ where: { id: w.child.childId } })).toBe(1);
      expect(await t.prisma.user.count({ where: { id: w.child.userId } })).toBe(1);
      expect(await t.prisma.notification.count({ where: { childId: w.child.childId } })).toBe(1);
      expect(await t.prisma.schoolStudent.count({ where: { id: w.vali, childId: w.child.childId } })).toBe(1);
    });

    it('pushes a neutral message to the parent (no child name), in the parent language', async () => {
      const res = await create();

      expect(deletionPushes()).toEqual([
        {
          title: 'Parvoz',
          body: 'Farzandingiz maʼlumotlarini oʻchirishni soʻradi',
          data: { type: 'DATA_DELETION_REQUEST', childId: w.child.childId },
        },
      ]);
      expect(res.statusCode).toBe(201);
      expect(JSON.stringify(deletionPushes())).not.toContain('Vali');
    });

    it('speaks Russian to a Russian-speaking parent', async () => {
      await t.prisma.user.update({ where: { id: w.parent.userId }, data: { language: 'ru' } });

      await create();

      expect(deletionPushes()[0]?.body).toBe('Ваш ребёнок попросил удалить свои данные');
    });

    it('writes an audit entry without personal data', async () => {
      const res = await create();

      const rows = await t.prisma.auditLog.findMany({ where: { resourceId: res.json().id } });
      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({ userId: w.child.userId, resourceType: 'child', action: 'CHILD_DATA_DELETION_REQUEST' });
      expect(rows[0]?.data).toEqual({ childId: w.child.childId });
    });

    it('stores a staff notification for DIRECTOR and ADMIN with only the student name and class', async () => {
      const res = await create();

      const stored = await t.prisma.schoolStaffNotification.findMany({ where: { kind: 'DATA_DELETION_REQUEST' } });
      expect(stored).toHaveLength(1);
      expect(stored[0]).toMatchObject({
        id: `data-deletion:${res.json().id}`,
        schoolId: w.schoolId,
        roles: ['DIRECTOR', 'ADMIN'],
        classIds: [],
        staffIds: [],
        params: { studentName: 'Aliyev Vali', className: '7-A' },
        subject: null,
        href: null,
      });
      expect(Object.keys(stored[0]!.params as object).sort()).toEqual(['className', 'studentName']);
      // Bola id'si, sabab yoki boshqa ma'lumot bildirishnomada yo'q.
      expect(JSON.stringify(stored[0])).not.toContain(w.child.childId);
    });

    it('shows up in the notification feed of the director and the administrator only, without extra fields', async () => {
      await create();

      for (const session of [w.director, w.admin]) {
        const items = await feed(session);
        expect(items).toHaveLength(1);
        expect(items[0]).toMatchObject({ params: { studentName: 'Aliyev Vali', className: '7-A' }, subject: null, href: null });
      }
      for (const session of [w.homeroom, w.duty, w.teacher, w.psych]) {
        expect(await feed(session)).toHaveLength(0);
      }
    });

    it('does not create a staff notification for a child that is not linked to a school', async () => {
      const parent = await createParent(t.prisma);
      const lonely = await createChild(t.prisma, parent, { name: 'Yolg\'iz' });

      const res = await create(lonely.token, lonely.childId);

      expect(res.statusCode).toBe(201);
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'DATA_DELETION_REQUEST' } })).toBe(0);
      expect(t.fcm.pushesTo(parent.userId).filter((p) => p.data?.type === 'DATA_DELETION_REQUEST')).toHaveLength(1);
    });

    it('still succeeds when the push and the staff notification fail (best effort)', async () => {
      const spy = jest.spyOn(t.fcm, 'sendPushToUser').mockRejectedValue(new Error('fcm down'));
      const notify = jest.spyOn(t.prisma.schoolStaffNotification, 'upsert').mockRejectedValue(new Error('db hiccup'));

      try {
        const res = await create();
        expect(res.statusCode).toBe(201);
      } finally {
        spy.mockRestore();
        notify.mockRestore();
      }

      expect(await t.prisma.childDataDeletionRequest.count({ where: { childId: w.child.childId } })).toBe(1);
    });

    describe('idempotency', () => {
      it('returns the existing RECEIVED request (200) without duplicate notifications', async () => {
        const first = await create();
        t.fcm.reset();

        const again = await create();

        expect(again.statusCode).toBe(200);
        expect(again.json()).toEqual(first.json());
        expect(await t.prisma.childDataDeletionRequest.count({ where: { childId: w.child.childId } })).toBe(1);
        expect(deletionPushes()).toHaveLength(0);
        expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'DATA_DELETION_REQUEST' } })).toBe(1);
        expect(await t.prisma.auditLog.count({ where: { action: 'CHILD_DATA_DELETION_REQUEST' } })).toBe(1);
      });

      it('creates only one request and one notification when three calls race', async () => {
        const results = await Promise.all([create(), create(), create()]);

        expect(results.map((r) => r.statusCode).sort()).toEqual([200, 200, 201]);
        expect(new Set(results.map((r) => r.json().id)).size).toBe(1);
        expect(await t.prisma.childDataDeletionRequest.count({ where: { childId: w.child.childId } })).toBe(1);
        expect(deletionPushes()).toHaveLength(1);
        expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'DATA_DELETION_REQUEST' } })).toBe(1);
      });

      it('creates a new request when the previous RECEIVED one is older than 30 days', async () => {
        const old = await t.prisma.childDataDeletionRequest.create({
          data: { childId: w.child.childId, createdAt: new Date(Date.now() - 31 * DAY_MS) },
        });

        const res = await create();

        expect(res.statusCode).toBe(201);
        expect(res.json().id).not.toBe(old.id);
      });

      it('still reuses a RECEIVED request from 29 days ago', async () => {
        const recent = await t.prisma.childDataDeletionRequest.create({
          data: { childId: w.child.childId, createdAt: new Date(Date.now() - 29 * DAY_MS) },
        });

        const res = await create();

        expect(res.statusCode).toBe(200);
        expect(res.json().id).toBe(recent.id);
      });

      it('creates a new request after the previous one was CLOSED', async () => {
        const closed = await t.prisma.childDataDeletionRequest.create({
          data: { childId: w.child.childId, status: 'CLOSED', closedAt: new Date() },
        });

        const res = await create();

        expect(res.statusCode).toBe(201);
        expect(res.json().id).not.toBe(closed.id);
      });
    });

    it('rate limits to 3 requests per day per user: the 4th is 429 (repeated calls count too)', async () => {
      const codes: number[] = [];
      for (let i = 0; i < 4; i++) codes.push((await create()).statusCode);

      expect(codes).toEqual([201, 200, 200, 429]);
      expect(await t.prisma.childDataDeletionRequest.count({ where: { childId: w.child.childId } })).toBe(1);
    });

    it('rate limits per user, not per IP: another child is not affected', async () => {
      for (let i = 0; i < 4; i++) await create();
      const parent = await createParent(t.prisma);
      const other = await createChild(t.prisma, parent, { name: 'Boshqa' });

      expect((await create(other.token, other.childId)).statusCode).toBe(201);
    });

    describe('access control', () => {
      it('forbids the parent (child only)', async () => {
        expect((await create(w.parent.token)).statusCode).toBe(403);
        expect(await t.prisma.childDataDeletionRequest.count()).toBe(0);
      });

      it("forbids another child's id and a stranger parent", async () => {
        const parent = await createParent(t.prisma);
        const other = await createChild(t.prisma, parent, { name: 'Boshqa' });

        expect((await create(other.token, w.child.childId)).statusCode).toBe(403);
        expect((await create((await createParent(t.prisma)).token)).statusCode).toBe(403);
        expect(await t.prisma.childDataDeletionRequest.count()).toBe(0);
      });

      it('404s an unknown child and 401s a missing token', async () => {
        expect((await create(w.child.token, '00000000-0000-0000-0000-000000000000')).statusCode).toBe(404);
        expect((await t.app.inject({ method: 'POST', url: `/api${url()}` })).statusCode).toBe(401);
      });
    });
  });

  describe('GET /children/:childId/deletion-requests/latest', () => {
    it('returns JSON null when there is no request (child and parent)', async () => {
      for (const token of [w.child.token, w.parent.token]) {
        const res = await latest(token);
        expect(res.statusCode).toBe(200);
        expect(res.body).toBe('null');
      }
    });

    it('returns the latest request to the child and to the parent', async () => {
      const created = (await create()).json();

      for (const token of [w.child.token, w.parent.token]) {
        const res = await latest(token);
        expect(res.statusCode).toBe(200);
        expect(res.json()).toEqual(created);
      }
    });

    it('returns the newest of several requests', async () => {
      await t.prisma.childDataDeletionRequest.create({
        data: { childId: w.child.childId, status: 'CLOSED', closedAt: new Date(), createdAt: new Date(Date.now() - 40 * DAY_MS) },
      });
      const newer = await t.prisma.childDataDeletionRequest.create({
        data: { childId: w.child.childId, createdAt: new Date(Date.now() - 2 * DAY_MS) },
      });

      const res = await latest();

      expect(res.json()).toMatchObject({ id: newer.id, status: 'RECEIVED' });
    });

    it('reports a CLOSED request as CLOSED', async () => {
      const closed = await t.prisma.childDataDeletionRequest.create({ data: { childId: w.child.childId, status: 'CLOSED', closedAt: new Date() } });

      expect((await latest()).json()).toEqual({ id: closed.id, status: 'CLOSED', createdAt: closed.createdAt.toISOString() });
    });

    it('forbids strangers (another family), 404s an unknown child, requires a token', async () => {
      const stranger = await createParent(t.prisma);
      const otherChild = await createChild(t.prisma, stranger, { name: 'Boshqa' });
      await create();

      expect((await latest(stranger.token)).statusCode).toBe(403);
      expect((await latest(otherChild.token)).statusCode).toBe(403);
      expect((await latest(w.child.token, '00000000-0000-0000-0000-000000000000')).statusCode).toBe(404);
      expect((await t.app.inject({ method: 'GET', url: `/api${url()}/latest` })).statusCode).toBe(401);
    });
  });

  describe('purge', () => {
    const counts = async () => ({
      requests: await t.prisma.childDataDeletionRequest.count(),
      staff: await t.prisma.schoolStaffNotification.count({ where: { kind: 'DATA_DELETION_REQUEST' } }),
    });

    it('removes the requests and their staff notification when the child deletes their own account', async () => {
      await create();
      expect(await counts()).toEqual({ requests: 1, staff: 1 });

      const res = await appReq(t, w.child.token, 'DELETE', '/users/me');

      expect(res.statusCode).toBe(200);
      expect(await counts()).toEqual({ requests: 0, staff: 0 });
      // Profil (ota-onaniki) qoladi.
      expect(await t.prisma.child.count({ where: { id: w.child.childId } })).toBe(1);
    });

    it('removes them when the parent deletes the child profile', async () => {
      await create();

      const res = await appReq(t, w.parent.token, 'DELETE', `/children/${w.child.childId}`);

      expect(res.statusCode).toBe(200);
      expect(await counts()).toEqual({ requests: 0, staff: 0 });
    });

    it('removes them when the parent deletes the whole account', async () => {
      await create();

      const res = await appReq(t, w.parent.token, 'DELETE', '/users/me');

      expect(res.statusCode).toBe(200);
      expect(await counts()).toEqual({ requests: 0, staff: 0 });
    });

    it("leaves other children's requests alone", async () => {
      const parent = await createParent(t.prisma);
      const other = await createChild(t.prisma, parent, { name: 'Boshqa' });
      await create();
      await create(other.token, other.childId);

      await appReq(t, w.parent.token, 'DELETE', `/children/${w.child.childId}`);

      expect(await t.prisma.childDataDeletionRequest.count({ where: { childId: other.childId } })).toBe(1);
    });
  });
});
