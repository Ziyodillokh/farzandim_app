// Kirish (K1): kirish maʼlumotlarini tiklash so'rovi (A03/A04), bola tomoni: ommaviy so'rov DOIM bir xil 202 (mavjudlik
// fosh bo'lmaydi), poll tokeni faqat xesh, ota-onaga neytral push, poll holatlari, limitlar. Maktab xodimlariga
// bildirishnoma: `kirish-recovery-notify.e2e-spec.ts`.

import { createHash } from 'node:crypto';
import { ChildRecoveryService } from '../../src/modules/child-auth/child-recovery.service';
import { resetDb } from './db';
import { createChild, createParent } from './factories';
import {
  api,
  dbContains,
  issueAsParent,
  IssuedCredential,
  restoreClock,
} from './kirish-fixtures';
import { seedWorld, World } from './school-attendance-fixtures';
import { createTestApp, TestApp } from './test-app';

const DAY = 24 * 60 * 60 * 1000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

interface Requested {
  requestId: string;
  pollToken: string;
}

describe('Kirish K1: tiklash so\'rovi (bola tomoni)', () => {
  let t: TestApp;
  let w: World;
  let cred: IssuedCredential;
  let unknownSeq = 0;
  let testSeq = 0;
  const unknownLogin = () => `nobody.r${(unknownSeq += 1)}`;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    w = await seedWorld(t);
    // Har testga o'z logini: kunlik limit (3/login) throttler xotirasida testlar orasida yig'ilmasin.
    cred = await issueAsParent(t, w.parent, w.child.childId, { login: `vali.t${(testSeq += 1)}` });
  });

  afterEach(() => {
    jest.restoreAllMocks();
    restoreClock(t);
  });

  afterAll(() => t.close());

  const service = () => t.app.get(ChildRecoveryService);
  const settle = () => service().drainEffects();
  const request = (login: string, channel: 'PARENT' | 'SCHOOL' = 'PARENT', ip?: string) =>
    api(t, 'POST', '/auth/child-recovery', { payload: { login, channel }, ip });
  const requested = async (login = cred.login, channel: 'PARENT' | 'SCHOOL' = 'PARENT'): Promise<Requested> => {
    const res = await request(login, channel);
    expect(res.statusCode).toBe(202);
    await settle();
    return res.json();
  };
  const poll = (r: Requested, token = r.pollToken) =>
    api(t, 'GET', `/auth/child-recovery/${r.requestId}?token=${encodeURIComponent(token)}`);
  const recoveryPushes = () => t.fcm.pushesTo(w.parent.userId).filter((p) => p.data?.type === 'CHILD_RECOVERY_REQUEST');
  const stored = () => t.prisma.schoolStaffNotification.findMany({ where: { kind: 'CHILD_RECOVERY_REQUEST' } });

  describe('POST /auth/child-recovery', () => {
    it('answers 202 { requestId, pollToken } and stores only the hash of the poll token', async () => {
      const res = await request(cred.login);

      expect(res.statusCode).toBe(202);
      expect(res.headers['cache-control']).toBe('no-store');
      const body = res.json();
      expect(Object.keys(body).sort()).toEqual(['pollToken', 'requestId']);
      expect(body.requestId).toMatch(UUID);
      expect(body.pollToken).toMatch(/^[A-Za-z0-9_-]{43}$/);
      const row = await t.prisma.childRecoveryRequest.findUniqueOrThrow({ where: { id: body.requestId } });
      expect(row).toMatchObject({
        childId: w.child.childId,
        channel: 'PARENT',
        requestedChannel: 'PARENT',
        status: 'RECEIVED',
        restoredAt: null,
        signedOutAt: null,
        rejectedAt: null,
      });
      expect(row.pollTokenHash).toBe(createHash('sha256').update(body.pollToken).digest('hex'));
      expect(await dbContains(t, body.pollToken)).toEqual([]);
    });

    it('answers the same 202 shape for an unknown login, a malformed login and a normalized login', async () => {
      const shapes = [
        await request(cred.login),
        await request(unknownLogin()),
        await request('N o!'),
        await request(`  ${cred.login.toUpperCase()} `),
        await request('x'),
      ].map((r) => ({ status: r.statusCode, keys: Object.keys(r.json()).sort(), cc: r.headers['cache-control'] }));

      for (const shape of shapes) expect(shape).toEqual({ status: 202, keys: ['pollToken', 'requestId'], cc: 'no-store' });
    });

    it('stores an unknown login as a dead request without a child that never resolves', async () => {
      const dead = await requested(unknownLogin());

      const row = await t.prisma.childRecoveryRequest.findUniqueOrThrow({ where: { id: dead.requestId } });
      expect(row.childId).toBeNull();
      expect(await poll(dead)).toMatchObject({ statusCode: 200 });
      expect((await poll(dead)).json()).toMatchObject({ status: 'RECEIVED', restoredAt: null, signedOutAt: null });
      // Hech qanday xabar ketmagan.
      expect(t.fcm.sent).toEqual([]);
      expect(await stored()).toEqual([]);
    });

    it('rejects malformed bodies with 400', async () => {
      const post = (payload: object) => api(t, 'POST', '/auth/child-recovery', { payload });

      expect((await post({ login: cred.login })).statusCode).toBe(400);
      expect((await post({ channel: 'PARENT' })).statusCode).toBe(400);
      expect((await post({ login: cred.login, channel: 'EMAIL' })).statusCode).toBe(400);
      expect((await post({ login: cred.login, channel: 'PARENT', extra: 1 })).statusCode).toBe(400);
      expect((await post({ login: 'a'.repeat(65), channel: 'PARENT' })).statusCode).toBe(400);
    });

    it('returns before the push is delivered (a slow FCM must not make existing logins slower)', async () => {
      jest.spyOn(t.fcm, 'sendPushToUser').mockImplementation(
        () => new Promise((resolve) => setTimeout(() => resolve({ sent: 1, failed: 0, invalidTokens: [] }), 2_000)),
      );

      const start = Date.now();
      const res = await request(cred.login);
      const elapsed = Date.now() - start;

      expect(res.statusCode).toBe(202);
      expect(elapsed).toBeLessThan(1_200);
      await settle();
    });

    it('still answers 202 and stores the request when the push fails', async () => {
      jest.spyOn(t.fcm, 'sendPushToUser').mockRejectedValue(new Error('fcm down'));

      const res = await request(cred.login);
      await settle();

      expect(res.statusCode).toBe(202);
      expect(await t.prisma.childRecoveryRequest.count({ where: { childId: w.child.childId } })).toBe(1);
    });
  });

  describe('PARENT kanali: ota-onaga neytral push', () => {
    it('pushes only a neutral message with the type and childId (no child name, no login)', async () => {
      await requested();

      expect(recoveryPushes()).toEqual([
        {
          title: 'Parvoz',
          body: 'Farzandingiz kirish maʼlumotlarini tiklashni soʻradi',
          data: { type: 'CHILD_RECOVERY_REQUEST', childId: w.child.childId },
        },
      ]);
      const dump = JSON.stringify(t.fcm.sent);
      expect(dump).not.toContain('Vali');
      expect(dump).not.toContain(cred.login);
    });

    it('speaks the language of the parent', async () => {
      await t.prisma.user.update({ where: { id: w.parent.userId }, data: { language: 'ru' } });

      await requested();

      expect(recoveryPushes()[0]?.body).toBe('Ваш ребёнок просит восстановить данные для входа');
    });

    it('pushes only the parent of that child (never another family)', async () => {
      const other = await createParent(t.prisma);

      await requested();

      expect(t.fcm.pushesTo(other.userId)).toEqual([]);
      expect(t.fcm.sent.every((p) => p.userId === w.parent.userId)).toBe(true);
    });

    it('SCHOOL falls back to the parent when the child is not linked to a school (the poll still reports the REQUESTED channel)', async () => {
      const lone = await createParent(t.prisma);
      const loneChild = await createChild(t.prisma, lone, { name: 'Yolgiz Bola' });
      const loneCred = await issueAsParent(t, lone, loneChild.childId);

      const r = await requested(loneCred.login, 'SCHOOL');

      expect(t.fcm.pushesTo(lone.userId).filter((p) => p.data?.type === 'CHILD_RECOVERY_REQUEST')).toHaveLength(1);
      expect(await stored()).toEqual([]);
      // Poll bola SO'RAGAN kanalni qaytaradi: samarali kanal ("PARENT") login mavjudligini fosh qilardi.
      expect((await poll(r)).json()).toMatchObject({ channel: 'SCHOOL', status: 'RECEIVED' });
      expect(await t.prisma.childRecoveryRequest.findUniqueOrThrow({ where: { id: r.requestId } })).toMatchObject({
        channel: 'PARENT',
        requestedChannel: 'SCHOOL',
      });
    });

    it('the poll of an existing but unlinked child is indistinguishable from the poll of an unknown login (no existence oracle)', async () => {
      const lone = await createParent(t.prisma);
      const loneChild = await createChild(t.prisma, lone, { name: 'Yolgiz Bola' });
      const loneCred = await issueAsParent(t, lone, loneChild.childId);

      const existing = (await poll(await requested(loneCred.login, 'SCHOOL'))).json();
      const unknown = (await poll(await requested(unknownLogin(), 'SCHOOL'))).json();

      for (const answer of [existing, unknown]) {
        expect(answer).toMatchObject({ status: 'RECEIVED', channel: 'SCHOOL', restoredAt: null, signedOutAt: null });
      }
      expect(Object.keys(existing).sort()).toEqual(Object.keys(unknown).sort());
    });

    it.each([
      ['an archived student', () => t.prisma.schoolStudent.update({ where: { id: w.vali }, data: { archived: true } })],
      ['a suspended school', () => t.prisma.school.update({ where: { id: w.schoolId }, data: { status: 'SUSPENDED' } })],
    ])('SCHOOL falls back to the parent for %s', async (_name, change) => {
      await change();

      const r = await requested(cred.login, 'SCHOOL');

      expect(recoveryPushes()).toHaveLength(1);
      expect(await stored()).toEqual([]);
      expect((await poll(r)).json().channel).toBe('SCHOOL');
      expect((await t.prisma.childRecoveryRequest.findUniqueOrThrow({ where: { id: r.requestId } })).channel).toBe('PARENT');
    });
  });

  describe('GET /auth/child-recovery/:requestId?token=', () => {
    it('returns exactly { status, channel, createdAt, restoredAt, signedOutAt }', async () => {
      const r = await requested();

      const res = await poll(r);

      expect(res.statusCode).toBe(200);
      expect(res.headers['cache-control']).toBe('no-store');
      expect(Object.keys(res.json()).sort()).toEqual(['channel', 'createdAt', 'restoredAt', 'signedOutAt', 'status']);
      expect(res.json()).toEqual({
        status: 'RECEIVED',
        channel: 'PARENT',
        createdAt: expect.stringMatching(/^\d{4}-\d\d-\d\dT.*Z$/),
        restoredAt: null,
        signedOutAt: null,
      });
    });

    it('answers the identical 404 for a wrong token, a wrong id, a missing token and an unrelated token', async () => {
      const a = await requested();
      const b = await requested(unknownLogin());

      const answers = [
        await poll(a, 'wrong-token'),
        await poll({ ...a, requestId: '00000000-0000-4000-8000-000000000000' }),
        await api(t, 'GET', `/auth/child-recovery/${a.requestId}`),
        await poll(a, b.pollToken),
        await poll(a, ''),
        await poll({ requestId: 'not-an-id', pollToken: a.pollToken }),
      ];

      for (const res of answers) {
        expect(res.statusCode).toBe(404);
        expect(res.json()).toEqual({ statusCode: 404, code: 'NOT_FOUND', message: 'Request not found' });
      }
    });

    it('turns RESTORED after a credential reset, with signedOutAt only when devices were signed out', async () => {
      const first = await requested();
      await issueAsParent(t, w.parent, w.child.childId, { signOutDevices: false });
      const second = await requested();
      await issueAsParent(t, w.parent, w.child.childId, { signOutDevices: true });

      const a = (await poll(first)).json();
      const b = (await poll(second)).json();

      expect(a).toMatchObject({ status: 'RESTORED', signedOutAt: null });
      expect(a.restoredAt).toEqual(expect.any(String));
      expect(b).toMatchObject({ status: 'RESTORED' });
      expect(b.signedOutAt).toEqual(expect.any(String));
    });

    it('turns REJECTED after a rejection', async () => {
      const r = await requested();
      const list = (await api(t, 'GET', `/children/${w.child.childId}/recovery-requests`, { token: w.parent.token })).json();
      await api(t, 'POST', `/children/${w.child.childId}/recovery-requests/${list[0].id}/reject`, { token: w.parent.token });

      expect((await poll(r)).json()).toMatchObject({ status: 'REJECTED', restoredAt: null });
    });

    it('stops answering when the child profile is deleted', async () => {
      const r = await requested();
      await api(t, 'DELETE', `/children/${w.child.childId}`, { token: w.parent.token });

      expect((await poll(r)).statusCode).toBe(404);
    });
  });

  describe('limitlar', () => {
    it('allows 3 requests per day for one login text (any IP, any casing) and answers 429 RATE_LIMITED after that', async () => {
      const results = [];
      for (const login of [cred.login, cred.login.toUpperCase(), ` ${cred.login} `, cred.login]) results.push(await request(login));

      expect(results.map((r) => r.statusCode)).toEqual([202, 202, 202, 429]);
      expect(results[3]!.json()).toMatchObject({ statusCode: 429, code: 'RATE_LIMITED', retryAfterSeconds: expect.any(Number) });
    });

    it('limits an unknown login exactly like an existing one (no enumeration through the limit)', async () => {
      const sequence = async (login: string) => {
        const out = [];
        for (let i = 0; i < 5; i++) {
          const r = await request(login);
          out.push({ status: r.statusCode, code: r.statusCode === 429 ? r.json().code : undefined });
        }
        return out;
      };

      expect(await sequence(cred.login)).toEqual(await sequence(unknownLogin()));
      expect((await sequence(unknownLogin())).map((x) => x.status)).toEqual([202, 202, 202, 429, 429]);
    });

    it('allows 30 requests per day per IP (a school Wi-Fi) and then answers 429 RATE_LIMITED', async () => {
      const ip = '198.51.100.20';
      const statuses: number[] = [];
      for (let i = 0; i < 31; i++) statuses.push((await request(unknownLogin(), 'PARENT', ip)).statusCode);

      expect(statuses).toEqual([...Array<number>(30).fill(202), 429]);
      const blocked = await request(unknownLogin(), 'PARENT', ip);
      expect(blocked.json()).toMatchObject({ statusCode: 429, code: 'RATE_LIMITED', retryAfterSeconds: expect.any(Number) });
      expect((await request(unknownLogin(), 'PARENT', '198.51.100.21')).statusCode).toBe(202);
    }, 60_000);

    it('stops sending notifications after 3 requests for the same child in a day, but still answers 202 (the cap survives a restart)', async () => {
      for (let i = 0; i < 3; i++) {
        await t.prisma.childRecoveryRequest.create({
          data: {
            childId: w.child.childId,
            channel: 'PARENT',
            requestedChannel: 'PARENT',
            pollTokenHash: `h${i}`,
            createdAt: new Date(Date.now() - i * 1000),
          },
        });
      }

      const r = await requested();

      expect(r.requestId).toMatch(UUID);
      expect(recoveryPushes()).toEqual([]);
      expect((await poll(r)).statusCode).toBe(200);
    });

    it('does not count requests older than a day toward that cap', async () => {
      for (let i = 0; i < 3; i++) {
        await t.prisma.childRecoveryRequest.create({
          data: {
            childId: w.child.childId,
            channel: 'PARENT',
            requestedChannel: 'PARENT',
            pollTokenHash: `h${i}`,
            createdAt: new Date(Date.now() - DAY - 60_000),
          },
        });
      }

      await requested();

      expect(recoveryPushes()).toHaveLength(1);
    });
  });

});
