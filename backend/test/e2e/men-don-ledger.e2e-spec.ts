// I03: DON daftari — haqiqiy Postgres'da: tur xaritasi, qadam kunlari guruhi
// (Toshkent chegarasi), kursor sahifalash, kirish huquqi, mavjud mukofot summalari o'zgarmasligi.

import { Prisma, XpEventType } from '@prisma/client';
import { GamificationService } from '../../src/modules/gamification/gamification.service';
import { donFor } from '../../src/modules/learning/domain/rewards';
import { tashkentDay } from '../../src/common/time/tashkent';
import { resetDb } from './db';
import { createChild, createParent, TestChild, TestParent } from './factories';
import { Call, caller } from './kelajak-fixtures';
import { seedQuestionBank } from './learning-fixtures';
import { createTestApp, TestApp } from './test-app';

interface LedgerBody {
  balance: number;
  pending: number;
  items: Array<{
    id: string;
    kind: string;
    amount: number;
    status: string;
    at: string;
    subject: string | null;
    title: string | null;
    relatedId: string | null;
  }>;
  nextCursor: string | null;
}

describe('DON daftari (GET /children/:id/don-ledger)', () => {
  let t: TestApp;
  let call: Call;
  let parent: TestParent;
  let child: TestChild;

  const ledger = async (token: string, query = '', childId = child.childId) => {
    const res = await call(token, 'GET', `/children/${childId}/don-ledger${query}`);
    return { res, body: res.json() as LedgerBody };
  };

  const event = (
    type: XpEventType,
    donDelta: number,
    createdAt: string,
    relatedId?: string,
    childId = child.childId,
    id?: string,
  ) =>
    t.prisma.xpEvent.create({
      data: { id, childId, type, xpDelta: 0, donDelta, relatedId, createdAt: new Date(createdAt) },
    });

  beforeAll(async () => {
    t = await createTestApp();
    call = caller(t);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    parent = await createParent(t.prisma);
    child = await createChild(t.prisma, parent);
  });

  afterAll(() => t.close());

  describe('shakl va tur xaritasi', () => {
    it('yozuv yo\'q: balans 0, items [], nextCursor null', async () => {
      const { res, body } = await ledger(child.token);
      expect(res.statusCode).toBe(200);
      expect(body).toEqual({ balance: 0, pending: 0, items: [], nextCursor: null });
    });

    it('har tur: LEARNING / OLYMPIAD / BOOK / VIDEO / OTHER, sarlavha va fan, yangisi birinchi', async () => {
      const other = await createChild(t.prisma, await createParent(t.prisma));
      const attempt = await t.prisma.learningAttempt.create({
        data: { childId: child.childId, subject: 'MATH', day: '2026-11-05', isDaily: true, status: 'COMPLETED', questionIds: [], total: 10, correct: 8 },
      });
      const foreignAttempt = await t.prisma.learningAttempt.create({
        data: { childId: other.childId, subject: 'PHYSICS', day: '2026-11-05', isDaily: true, status: 'COMPLETED', questionIds: [], total: 10 },
      });
      const olympiad = await t.prisma.olympiad.create({
        data: { title: 'Bahor olimpiadasi', subject: 'Matematika', ageFrom: 6, ageTo: 16, startTime: new Date('2026-01-01'), endTime: new Date('2026-12-31'), status: 'published' },
      });
      const contestAttempt = await t.prisma.olympiadAttempt.create({
        data: { olympiadId: olympiad.id, childId: child.childId, status: 'finished' },
      });
      const audiobook = await t.prisma.audiobook.create({
        data: { title: 'Alisher Navoiy hikoyalari', author: 'A', audioUrl: 'http://x/a.mp3', status: 'approved' },
      });
      const book = await t.prisma.book.create({ data: { title: 'Qadimgi qissalar', author: 'B', status: 'approved' } });
      const video = await t.prisma.video.create({
        data: { title: 'Quyosh tizimi', url: 'http://x/v.mp4', status: 'approved' },
      });

      await event('DAILY_LEARNING', 16, '2026-11-05T09:00:00.000Z', attempt.id);
      await event('CONTEST_JOIN', 5, '2026-11-05T09:01:00.000Z', olympiad.id);
      await event('CONTEST_WIN', 12, '2026-11-05T09:02:00.000Z', contestAttempt.id);
      await event('BOOK_READ', 50, '2026-11-05T09:03:00.000Z', audiobook.id);
      await event('BOOK_READ', 20, '2026-11-05T09:04:00.000Z', book.id);
      await event('OTHER', 7, '2026-11-05T09:05:00.000Z', video.id);
      await event('OTHER', 3, '2026-11-05T09:06:00.000Z', 'nomalum-id');
      await event('CREATIVE_WIN', 9, '2026-11-05T09:07:00.000Z');
      await event('OTHER', -4, '2026-11-05T09:08:00.000Z');
      await event('OTHER', 0, '2026-11-05T09:09:00.000Z'); // DON yo'q — daftarda ko'rinmaydi
      await event('DAILY_LEARNING', 6, '2026-11-05T09:10:00.000Z', foreignAttempt.id); // begona urinish
      await t.prisma.childProfile.create({ data: { childId: child.childId, donBalance: 480 } });

      const { res, body } = await ledger(child.token);
      expect(res.statusCode).toBe(200);
      expect(body.balance).toBe(480);
      expect(body.pending).toBe(0);
      expect(body.nextCursor).toBeNull();
      expect(body.items.every((i) => i.status === 'CONFIRMED')).toBe(true);
      // Yangisi birinchi (09:10 → 09:00), 0-don yozuvi yo'q.
      expect(body.items.map((i) => i.amount)).toEqual([6, -4, 9, 3, 7, 20, 50, 12, 5, 16]);

      const by = (amount: number) => body.items.find((i) => i.amount === amount)!;
      expect(by(16)).toMatchObject({ kind: 'LEARNING', subject: 'math', title: null, relatedId: attempt.id, at: '2026-11-05T09:00:00.000Z' });
      expect(by(5)).toMatchObject({ kind: 'OLYMPIAD', title: 'Bahor olimpiadasi', subject: null, relatedId: olympiad.id });
      expect(by(12)).toMatchObject({ kind: 'OLYMPIAD', title: 'Bahor olimpiadasi', relatedId: contestAttempt.id });
      expect(by(50)).toMatchObject({ kind: 'BOOK', title: 'Alisher Navoiy hikoyalari' });
      expect(by(20)).toMatchObject({ kind: 'BOOK', title: 'Qadimgi qissalar' });
      expect(by(7)).toMatchObject({ kind: 'VIDEO', title: 'Quyosh tizimi', relatedId: video.id });
      expect(by(3)).toMatchObject({ kind: 'OTHER', title: null, relatedId: 'nomalum-id' });
      expect(by(9)).toMatchObject({ kind: 'OTHER', title: null, relatedId: null });
      expect(by(-4)).toMatchObject({ kind: 'OTHER' });
      // Begona bolaning urinishi ochilmaydi: fan oshkor qilinmaydi.
      expect(by(6)).toMatchObject({ kind: 'LEARNING', subject: null });
      // Har elementda 8 ta kalit — shakl barqaror.
      for (const item of body.items) {
        expect(Object.keys(item).sort()).toEqual(['amount', 'at', 'id', 'kind', 'relatedId', 'status', 'subject', 'title']);
      }
    });

    it('qadam yozuvlari Toshkent kuni bo\'yicha BITTA element (yig\'indi, id=steps:KUN, at=oxirgi qator)', async () => {
      // Toshkent 2026-11-03: 04:00Z(+5), 09:00Z(+10), 18:59:59Z = 23:59:59 (+5). 19:00:00Z = 2026-11-04 00:00:00 (+5).
      await event('DAILY_GOAL', 5, '2026-11-03T04:00:00.000Z');
      await event('DAILY_GOAL', 10, '2026-11-03T09:00:00.000Z');
      await event('DAILY_GOAL', 5, '2026-11-03T18:59:59.000Z');
      await event('DAILY_GOAL', 5, '2026-11-03T19:00:00.000Z');
      await event('BOOK_READ', 8, '2026-11-03T12:00:00.000Z');

      const { body } = await ledger(child.token);
      expect(body.items.map((i) => [i.id, i.kind, i.amount, i.at])).toEqual([
        ['steps:2026-11-04', 'STEPS', 5, '2026-11-03T19:00:00.000Z'],
        ['steps:2026-11-03', 'STEPS', 20, '2026-11-03T18:59:59.000Z'],
        [expect.any(String), 'BOOK', 8, '2026-11-03T12:00:00.000Z'],
      ]);
      expect(body.items[0]).toMatchObject({ relatedId: null, subject: null, title: null });
    });
  });

  describe('kursor sahifalash', () => {
    /** 11-05 kuni qadamlar boshqa yozuvlar bilan aralash, 11-04 da yana qadam. */
    async function seedInterleaved() {
      await event('DAILY_GOAL', 5, '2026-11-05T04:00:00.000Z');
      await event('DAILY_LEARNING', 16, '2026-11-05T05:00:00.000Z');
      await event('DAILY_GOAL', 10, '2026-11-05T06:00:00.000Z');
      await event('BOOK_READ', 20, '2026-11-05T07:00:00.000Z');
      await event('DAILY_GOAL', 5, '2026-11-05T08:00:00.000Z');
      await event('CONTEST_JOIN', 5, '2026-11-05T09:00:00.000Z');
      await event('DAILY_GOAL', 15, '2026-11-04T08:00:00.000Z');
      await event('OTHER', 3, '2026-11-04T07:00:00.000Z');
    }

    async function walk(limit: number) {
      const ids: string[] = [];
      let cursor: string | null = null;
      for (let guard = 0; guard < 50; guard++) {
        const { res, body }: { res: { statusCode: number }; body: LedgerBody } = await ledger(
          child.token,
          `?limit=${limit}${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`,
        );
        expect(res.statusCode).toBe(200);
        expect(body.items.length).toBeLessThanOrEqual(limit);
        ids.push(...body.items.map((i) => i.id));
        if (!body.nextCursor) return ids;
        expect(body.items).toHaveLength(limit);
        cursor = body.nextCursor;
      }
      throw new Error('kursor tugamadi');
    }

    it.each([1, 2, 3, 4, 5, 7])('limit=%i: sahifalar birlashmasi to\'liq ro\'yxatga teng, takror yo\'q', async (limit) => {
      await seedInterleaved();
      const full = (await ledger(child.token)).body.items.map((i) => i.id);
      expect(full).toHaveLength(6);
      expect(full.filter((id) => id.startsWith('steps:'))).toEqual(['steps:2026-11-05', 'steps:2026-11-04']);
      expect(await walk(limit)).toEqual(full);
    });

    it('qadam guruhi sahifa chegarasida: 11-05 guruhi keyingi sahifada qaytadan chiqmaydi', async () => {
      await seedInterleaved();
      const first = (await ledger(child.token, '?limit=2')).body;
      expect(first.items.map((i) => i.id)).toEqual([expect.any(String), 'steps:2026-11-05']);
      expect(first.items[1].amount).toBe(20); // 5 + 10 + 5 — kunning HAMMA qatorlari
      const second = (await ledger(child.token, `?limit=2&cursor=${encodeURIComponent(first.nextCursor!)}`)).body;
      expect(second.items.map((i) => i.kind)).toEqual(['BOOK', 'LEARNING']);
      expect(second.items.map((i) => i.id)).not.toContain('steps:2026-11-05');
    });

    it('bir xil createdAt (teng vaqt): id bo\'yicha aniq tartib, hech narsa yo\'qolmaydi', async () => {
      const same = '2026-11-05T09:00:00.000Z';
      const ids = ['a', 'b', 'c', 'd', 'e'].map((c) => `00000000-0000-4000-8000-00000000000${c}`);
      for (const id of ids) await event('BOOK_READ', 1, same, undefined, child.childId, id);
      expect(await walk(2)).toEqual([...ids].reverse());
    });

    it('kursor yangi yozuvlar paydo bo\'lgach ham barqaror (eski sahifa siljimaydi)', async () => {
      await seedInterleaved();
      const first = (await ledger(child.token, '?limit=2')).body;
      await event('BOOK_READ', 99, '2026-11-06T09:00:00.000Z'); // yangi, kursordan yuqorida
      const second = (await ledger(child.token, `?limit=2&cursor=${encodeURIComponent(first.nextCursor!)}`)).body;
      expect(second.items.map((i) => i.kind)).toEqual(['BOOK', 'LEARNING']);
    });

    it('katta daftar: 700 qator (30 kun qadam + boshqa), sahifa ≤ limit, yo\'qolish yo\'q', async () => {
      const base = Date.parse('2026-10-01T00:00:00.000Z');
      const data: Prisma.XpEventCreateManyInput[] = [];
      for (let i = 0; i < 700; i++) {
        data.push({
          childId: child.childId,
          type: i % 2 === 0 ? 'DAILY_GOAL' : 'OTHER',
          xpDelta: 0,
          donDelta: 5,
          createdAt: new Date(base + i * 60 * 60 * 1000), // har soatda 1 qator
        });
      }
      await t.prisma.xpEvent.createMany({ data });
      const ids = await walk(100);
      // 350 ta OTHER + qadam kunlari (700 soat ≈ 29.2 kun → 30 Toshkent kuni)
      const steps = ids.filter((id) => id.startsWith('steps:'));
      expect(new Set(ids).size).toBe(ids.length);
      expect(ids.length - steps.length).toBe(350);
      expect(steps.length).toBe(new Set(Array.from({ length: 350 }, (_, i) => tashkentDay(new Date(base + i * 2 * 3_600_000)))).size);
      // Yig'indi saqlanadi: barcha element summasi = 700 * 5
      let total = 0;
      let cursor: string | null = null;
      do {
        const { body }: { body: LedgerBody } = await ledger(child.token, `?limit=100${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`);
        total += body.items.reduce((s, i) => s + i.amount, 0);
        cursor = body.nextCursor;
      } while (cursor);
      expect(total).toBe(3500);
    });
  });

  describe('tekshiruv', () => {
    it.each(['?limit=0', '?limit=101', '?limit=abc', '?limit=1.5', '?foo=bar'])('%s — 400', async (query) => {
      expect((await ledger(child.token, query)).res.statusCode).toBe(400);
    });

    it('limit=100 va limit=1 qabul qilinadi', async () => {
      expect((await ledger(child.token, '?limit=100')).res.statusCode).toBe(200);
      expect((await ledger(child.token, '?limit=1')).res.statusCode).toBe(200);
    });

    it('buzilgan kursor — 400 VALIDATION', async () => {
      const { res } = await ledger(child.token, '?cursor=garbage');
      expect(res.statusCode).toBe(400);
      expect(res.json()).toMatchObject({ code: 'VALIDATION', message: 'cursor: invalid' });
    });

    describe('yasalgan kursorlar (500 emas, 400 VALIDATION)', () => {
      const ID = '3f2b8c1e-9a4d-4e7b-8c51-0d6f2a9b7e14';
      const craft = (t: unknown, i: unknown) =>
        encodeURIComponent(Buffer.from(JSON.stringify({ t, i })).toString('base64url'));

      it.each([
        ['kengaytirilgan yil +275760', '+275760-09-13T00:00:00.000Z', ID],
        ['manfiy yil -000001', '-000001-01-01T00:00:00.000Z', ID],
        ['0000 yil', '0000-01-01T00:00:00.000Z', ID],
        ['id ichida NUL', '2026-11-05T09:12:00.000Z', `${ID}\u0000`],
        ['id UUID emas', '2026-11-05T09:12:00.000Z', 'not-a-uuid'],
        ['id SQL bo\'lagi', '2026-11-05T09:12:00.000Z', `${ID}' OR '1'='1`],
      ])('%s', async (_name, t, i) => {
        const { res } = await ledger(child.token, `?cursor=${craft(t, i)}`);
        expect(res.statusCode).toBe(400);
        expect(res.json()).toMatchObject({ code: 'VALIDATION', message: 'cursor: invalid' });
      });

      it('to\'g\'ri shakldagi chekka qiymatlar (9999 yil, mavjud bo\'lmagan id) — 200', async () => {
        await event('OTHER', 4, '2026-11-05T09:00:00.000Z');
        const far = await ledger(child.token, `?cursor=${craft('9999-12-31T23:59:59.999Z', ID)}`);
        expect(far.res.statusCode).toBe(200);
        expect(far.body.items.map((i) => i.amount)).toEqual([4]);
        const none = await ledger(child.token, `?cursor=${craft('2000-01-01T00:00:00.000Z', ID)}`);
        expect(none.res.statusCode).toBe(200);
        expect(none.body.items).toEqual([]);
      });
    });
  });

  describe('kirish huquqi', () => {
    it('bolaning o\'zi va ota-onasi — 200', async () => {
      expect((await ledger(child.token)).res.statusCode).toBe(200);
      expect((await ledger(parent.token)).res.statusCode).toBe(200);
    });

    it('begona ota-ona va begona bola — 403; yo\'q bola — 404; tokensiz — 401', async () => {
      const stranger = await createParent(t.prisma);
      const strangerChild = await createChild(t.prisma, stranger);
      await event('OTHER', 5, '2026-11-05T09:00:00.000Z');
      expect((await ledger(stranger.token)).res.statusCode).toBe(403);
      expect((await ledger(strangerChild.token)).res.statusCode).toBe(403);
      expect((await ledger(child.token, '', '00000000-0000-4000-8000-000000000000')).res.statusCode).toBe(404);
      const noAuth = await t.app.inject({ method: 'GET', url: `/api/children/${child.childId}/don-ledger` });
      expect(noAuth.statusCode).toBe(401);
    });

    it('boshqa bolaning yozuvlari aralashmaydi', async () => {
      const sibling = await createChild(t.prisma, parent, { name: 'Zilola' });
      await event('OTHER', 5, '2026-11-05T09:00:00.000Z', undefined, sibling.childId);
      await event('OTHER', 7, '2026-11-05T09:01:00.000Z');
      expect((await ledger(child.token)).body.items.map((i) => i.amount)).toEqual([7]);
      expect((await ledger(sibling.token, '', sibling.childId)).body.items.map((i) => i.amount)).toEqual([5]);
    });
  });

  describe('haqiqiy oqim (mukofot summalari o\'zgarmagan)', () => {
    it('kunlik test yakuni → LEARNING (fan, attemptId), qadam mukofoti → STEPS; balans = donBalance', async () => {
      await seedQuestionBank(t.prisma);
      const asChild = (method: 'GET' | 'POST' | 'PUT', url: string, payload?: object) => call(child.token, method, url, payload);
      expect((await asChild('PUT', '/learning/profile', { grade: 7, subjects: ['math'] })).statusCode).toBe(200);
      const attempt = (await asChild('POST', '/learning/attempts', { subject: 'math' })).json();
      for (const q of attempt.questions as Array<{ id: string }>) {
        const row = await t.prisma.learningQuestion.findUniqueOrThrow({ where: { id: q.id } });
        await asChild('POST', `/learning/attempts/${attempt.id}/answers`, { questionId: q.id, selectedIndex: row.answerIndex });
      }
      expect((await asChild('POST', `/learning/attempts/${attempt.id}/complete`)).statusCode).toBe(200);
      await t.app.get(GamificationService).awardStepDon(child.childId, 5, true);

      const { body } = await ledger(parent.token);
      const expectedLearningDon = donFor(10, 10); // 30 — o'zgarmagan qoida
      expect(body.items).toHaveLength(2);
      expect(body.items[0]).toMatchObject({
        id: `steps:${tashkentDay(new Date())}`,
        kind: 'STEPS',
        amount: 5,
      });
      expect(body.items[1]).toMatchObject({ kind: 'LEARNING', subject: 'math', relatedId: attempt.id, amount: expectedLearningDon });
      expect(body.balance).toBe(expectedLearningDon + 5);
      const profile = await t.prisma.childProfile.findUniqueOrThrow({ where: { childId: child.childId } });
      expect(body.balance).toBe(profile.donBalance);
    });
  });
});
