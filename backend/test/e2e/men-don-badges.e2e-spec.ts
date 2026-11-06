// I06: yutuqlar (badge) — voqea bo'yicha ochilish, mavjud ma'lumotdan kechiktirilgan
// to'ldirish (idempotent), parallel ochilish, kirish huquqi. Yutuq DON bermaydi.

import { buildIqBankRows } from '../../scripts/iq/build-bank-migration';
import { BADGE_IDS } from '../../src/modules/gamification/badges/badge-catalog';
import { XpEventType } from '../../src/modules/gamification/dto/create-xp-event.dto';
import { GamificationService } from '../../src/modules/gamification/gamification.service';
import { resetDb } from './db';
import { createChild, createParent, TestChild, TestParent } from './factories';
import { Call, caller, setChildAge } from './kelajak-fixtures';
import { createQuestions, createTopic, recordAttempt } from './learning-topics-fixtures';
import { createTestApp, TestApp } from './test-app';

interface BadgesBody {
  items: Array<{ id: string; earned: boolean; earnedAt: string | null }>;
}

const DAY_MS = 86_400_000;

describe('Yutuqlar (GET /children/:id/badges)', () => {
  let t: TestApp;
  let call: Call;
  let gamification: GamificationService;
  let parent: TestParent;
  let child: TestChild;

  const badges = async (token = child.token, childId = child.childId) => {
    const res = await call(token, 'GET', `/children/${childId}/badges`);
    return { res, body: res.json() as BadgesBody };
  };
  const earnedIds = (body: BadgesBody) => body.items.filter((i) => i.earned).map((i) => i.id);
  const item = (body: BadgesBody, id: string) => body.items.find((i) => i.id === id)!;
  const profile = () => t.prisma.childProfile.findUniqueOrThrow({ where: { childId: child.childId } });

  /** Kecha faol bo'lgan, `streakDays` kunlik streakli profil. */
  const profileWithStreak = (streakDays: number) =>
    t.prisma.childProfile.upsert({
      where: { childId: child.childId },
      create: { childId: child.childId, streakDays, lastActivityDate: new Date(Date.now() - DAY_MS) },
      update: { streakDays, lastActivityDate: new Date(Date.now() - DAY_MS) },
    });

  const award = (relatedId: string) =>
    gamification.awardXp(child.childId, { type: XpEventType.CONTEST_WIN, xpDelta: 5, donDelta: 3, relatedId });

  beforeAll(async () => {
    t = await createTestApp();
    call = caller(t);
    gamification = t.app.get(GamificationService);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    parent = await createParent(t.prisma);
    child = await createChild(t.prisma, parent);
  });

  afterAll(() => t.close());

  it('yangi bola: katalog tartibida 6 ta yutuq, hech biri ochilmagan', async () => {
    const { res, body } = await badges();
    expect(res.statusCode).toBe(200);
    expect(body.items).toEqual(BADGE_IDS.map((id) => ({ id, earned: false, earnedAt: null })));
    expect(body.items.map((i) => i.id)).toEqual(['streak_7', 'streak_30', 'first_book', 'olympian', 'topic_master', 'thinker']);
  });

  describe('streak (applyAward ichida, bir tranzaksiyada)', () => {
    it('6 → 7 kun: streak_7 ochiladi (vaqt bilan), DON faqat mukofotdan', async () => {
      await profileWithStreak(6);
      await award('b1');

      const p = await profile();
      expect(p.streakDays).toBe(7);
      expect(p.achievements).toEqual(['streak_7']);
      expect(p.donBalance).toBe(3); // yutuq DON bermaydi
      const { body } = await badges();
      expect(earnedIds(body)).toEqual(['streak_7']);
      expect(Math.abs(Date.parse(item(body, 'streak_7').earnedAt!) - Date.now())).toBeLessThan(60_000);
    });

    it('5 → 6 kun: hali ochilmaydi', async () => {
      await profileWithStreak(5);
      await award('b1');
      expect((await profile()).achievements).toEqual([]);
    });

    it('29 → 30 kun: streak_30 ochiladi, avvalgi streak_7 vaqti o\'zgarmaydi', async () => {
      await profileWithStreak(6);
      await award('b1');
      const firstDate = item((await badges()).body, 'streak_7').earnedAt;
      await profileWithStreak(29);
      await award('b2');

      const { body } = await badges();
      expect(earnedIds(body)).toEqual(['streak_7', 'streak_30']);
      expect(item(body, 'streak_7').earnedAt).toBe(firstDate);
      expect(item(body, 'streak_30').earnedAt).not.toBeNull();
    });

    it('xuddi shu kundagi keyingi mukofot yutuqni takrorlamaydi', async () => {
      await profileWithStreak(6);
      await award('b1');
      await award('b2');
      await award('b3');
      expect((await profile()).achievements).toEqual(['streak_7']);
    });

    it('qadam sinxronida ham streak yutug\'i ochiladi', async () => {
      await profileWithStreak(6);
      await gamification.awardStepDon(child.childId, 0, true);
      expect((await profile()).achievements).toEqual(['streak_7']);
    });
  });

  describe('kechiktirilgan to\'ldirish (GET o\'qishda, idempotent)', () => {
    it('mavjud streak profilidan; vaqti noma\'lum (null); qayta chaqiruv takrorlamaydi', async () => {
      await t.prisma.childProfile.create({ data: { childId: child.childId, streakDays: 31 } });
      const first = (await badges()).body;
      expect(earnedIds(first)).toEqual(['streak_7', 'streak_30']);
      expect(first.items.filter((i) => i.earned).every((i) => i.earnedAt === null)).toBe(true);

      const second = (await badges()).body;
      expect(second).toEqual(first);
      expect((await profile()).achievements).toEqual(['streak_7', 'streak_30']);
      expect((await profile()).donBalance).toBe(0);
    });

    it('first_book / olympian / thinker / topic_master — mavjud ma\'lumotdan', async () => {
      await t.prisma.xpEvent.create({ data: { childId: child.childId, type: 'BOOK_READ', xpDelta: 50, donDelta: 0, relatedId: 'ab' } });
      const olympiad = await t.prisma.olympiad.create({
        data: { title: 'T', subject: 'Matematika', ageFrom: 6, ageTo: 16, startTime: new Date(), endTime: new Date(), status: 'published' },
      });
      await t.prisma.olympiadAttempt.create({ data: { olympiadId: olympiad.id, childId: child.childId } });
      await t.prisma.iqSession.create({
        data: { childId: child.childId, level: 1, form: 'L1A', ageYears: 9, status: 'COMPLETED', itemIds: [], total: 0, firstAttempt: true, completedAt: new Date() },
      });
      const topic = await createTopic(t.prisma);
      const questions = await createQuestions(t.prisma, 10, topic.id);
      await recordAttempt(t.prisma, child.childId, questions, Array(10).fill(true), { attemptTopicId: topic.id });

      const { body } = await badges();
      expect(earnedIds(body)).toEqual(['first_book', 'olympian', 'topic_master', 'thinker']);
      expect(body.items.every((i) => i.earnedAt === null)).toBe(true);
      expect((await profile()).achievements).toEqual(['first_book', 'olympian', 'topic_master', 'thinker']);
    });

    it('tugallanmagan IQ sessiya, tugallanmagan / past natijali mavzu — yutuq emas', async () => {
      await t.prisma.iqSession.create({
        data: { childId: child.childId, level: 1, form: 'L1A', ageYears: 9, status: 'IN_PROGRESS', itemIds: [], total: 0, firstAttempt: true },
      });
      const topic = await createTopic(t.prisma);
      const questions = await createQuestions(t.prisma, 10, topic.id);
      // 7/10 = 70% < 80%
      await recordAttempt(t.prisma, child.childId, questions, [true, true, true, true, true, true, true, false, false, false], { attemptTopicId: topic.id });
      // 4 ta javob < 5 (baholash uchun yetarli emas), alohida mavzu
      const small = await createTopic(t.prisma);
      const smallQs = await createQuestions(t.prisma, 10, small.id);
      await recordAttempt(t.prisma, child.childId, smallQs, [true, true, true, true], { attemptTopicId: small.id, startedAt: new Date('2026-11-02T09:00:00.000Z') });
      // IN_PROGRESS urinish dalil emas
      const third = await createTopic(t.prisma);
      const thirdQs = await createQuestions(t.prisma, 10, third.id);
      await recordAttempt(t.prisma, child.childId, thirdQs, Array(10).fill(true), { attemptTopicId: third.id, status: 'IN_PROGRESS' });

      expect(earnedIds((await badges()).body)).toEqual([]);
    });

    it('begona bolaning ma\'lumoti yutuq bermaydi', async () => {
      const other = await createChild(t.prisma, await createParent(t.prisma));
      await t.prisma.xpEvent.create({ data: { childId: other.childId, type: 'BOOK_READ', xpDelta: 50, donDelta: 0 } });
      await t.prisma.childProfile.create({ data: { childId: other.childId, streakDays: 40 } });
      expect(earnedIds((await badges()).body)).toEqual([]);
    });

    it('ro\'yxatdagi katalogda yo\'q eski id saqlanadi, javobga chiqmaydi', async () => {
      await t.prisma.childProfile.create({ data: { childId: child.childId, achievements: ['legacy_x'], streakDays: 7 } });
      const { body } = await badges();
      expect(earnedIds(body)).toEqual(['streak_7']);
      expect((await profile()).achievements).toEqual(['legacy_x', 'streak_7']);
    });
  });

  describe('voqea bo\'yicha ochilish (haqiqiy oqimlar)', () => {
    it('audiokitob yakuni → first_book (vaqt bilan); DON/XP summasi o\'zgarmagan', async () => {
      const book = await t.prisma.audiobook.create({
        data: { title: 'Kitob', author: 'A', audioUrl: 'http://x/a.mp3', status: 'approved', xpReward: 40 },
      });
      const res = await call(child.token, 'POST', `/content/audiobooks/${book.id}/complete`);
      expect(res.statusCode).toBe(201);
      const { body } = await badges();
      expect(earnedIds(body)).toEqual(['first_book']);
      expect(item(body, 'first_book').earnedAt).not.toBeNull();
      const p = await profile();
      expect(p.donBalance).toBe(40);
      expect(p.xp).toBe(50);
    });

    it('olimpiadaga qo\'shilish → olympian; ishtirok mukofoti (5 DON) o\'zgarmagan', async () => {
      const olympiad = await t.prisma.olympiad.create({
        data: {
          title: 'Olimpiada', subject: 'Matematika', ageFrom: 1, ageTo: 18, status: 'published',
          startTime: new Date(Date.now() - DAY_MS), endTime: new Date(Date.now() + DAY_MS),
        },
      });
      const res = await call(child.token, 'POST', `/content/olympiads/${olympiad.id}/start`);
      expect(res.statusCode).toBe(201);

      const { body } = await badges();
      expect(earnedIds(body)).toEqual(['olympian']);
      expect(item(body, 'olympian').earnedAt).not.toBeNull();
      expect((await profile()).donBalance).toBe(5);

      // Qayta boshlash (davom ettirish) yutuqni takrorlamaydi
      await call(child.token, 'POST', `/content/olympiads/${olympiad.id}/start`);
      expect((await profile()).achievements).toEqual(['olympian']);
    });

    it('IQ testni yakunlash → thinker (vaqt bilan)', async () => {
      await t.prisma.iqItem.createMany({
        data: buildIqBankRows().map(({ options, ...row }) => ({ ...row, options })),
      });
      await setChildAge(t.prisma, child.childId, { via: 'age', years: 9 });
      const session = (await call(child.token, 'POST', '/iq/sessions')).json() as { id: string; items: Array<{ id: string }> };
      const keys = await t.prisma.iqItem.findMany({ where: { id: { in: session.items.map((i) => i.id) } } });
      const answerOf = new Map(keys.map((k) => [k.id, k.answer]));
      for (const it of session.items) {
        const res = await call(child.token, 'PUT', `/iq/sessions/${session.id}/answers/${it.id}`, { choice: answerOf.get(it.id), durationMs: 5000 });
        expect(res.statusCode).toBe(200);
      }
      // Yakunlashgacha — hali yo'q
      expect(earnedIds((await badges()).body)).toEqual([]);
      expect((await call(child.token, 'POST', `/iq/sessions/${session.id}/complete`)).statusCode).toBe(200);

      const { body } = await badges();
      expect(earnedIds(body)).toEqual(['thinker']);
      expect(item(body, 'thinker').earnedAt).not.toBeNull();
      expect((await profile()).donBalance).toBe(0);
    });

    it('mavzu testi 100% → topic_master; past natija → yo\'q', async () => {
      const topic = await createTopic(t.prisma, { subject: 'MATH', minGrade: 5, maxGrade: 9 });
      await createQuestions(t.prisma, 12, topic.id);
      expect((await call(child.token, 'PUT', '/learning/profile', { grade: 7, subjects: ['math'] })).statusCode).toBe(200);

      const run = async (selectedIndex: number) => {
        const attempt = (await call(child.token, 'POST', '/learning/attempts', { subject: 'math', topicId: topic.id })).json() as {
          id: string;
          questions: Array<{ id: string }>;
        };
        for (const q of attempt.questions) {
          await call(child.token, 'POST', `/learning/attempts/${attempt.id}/answers`, { questionId: q.id, selectedIndex });
        }
        expect((await call(child.token, 'POST', `/learning/attempts/${attempt.id}/complete`)).statusCode).toBe(200);
      };

      await run(1); // hammasi xato (javob kaliti 0)
      expect(earnedIds((await badges()).body)).toEqual([]);

      // Kunlik urinish yakunlangan — keyingi urinish uchun kunni "o'tgan"ga o'tkazamiz
      await t.prisma.learningAttempt.updateMany({ where: { childId: child.childId }, data: { day: '2026-01-01', status: 'COMPLETED' } });
      await run(0);

      const { body } = await badges();
      expect(earnedIds(body)).toEqual(['topic_master']);
      expect(item(body, 'topic_master').earnedAt).not.toBeNull();
    });
  });

  describe('parallel xavfsizlik', () => {
    it('6 ta yutuq bir vaqtda ochiladi — birortasi yo\'qolmaydi', async () => {
      await Promise.all(BADGE_IDS.map((id) => gamification.unlockAchievement(child.childId, id)));
      const p = await profile();
      expect([...(p.achievements as string[])].sort()).toEqual([...BADGE_IDS].sort());
      expect(Object.keys(p.achievementDates as object).sort()).toEqual([...BADGE_IDS].sort());
    });

    it('mukofot (streak) va qo\'lda ochish bir vaqtda — ikkalasi saqlanadi', async () => {
      await profileWithStreak(6);
      await Promise.all([
        award('p1'),
        gamification.unlockAchievement(child.childId, 'first_book'),
        gamification.unlockAchievement(child.childId, 'thinker'),
        gamification.unlockAchievement(child.childId, 'olympian'),
      ]);
      expect([...((await profile()).achievements as string[])].sort()).toEqual(['first_book', 'olympian', 'streak_7', 'thinker']);
    });

    it('parallel GET o\'qishlar (backfill) bir xil natija, takror yozuv yo\'q', async () => {
      await t.prisma.childProfile.create({ data: { childId: child.childId, streakDays: 8 } });
      const results = await Promise.all(Array.from({ length: 8 }, () => badges()));
      expect(new Set(results.map((r) => JSON.stringify(r.body))).size).toBe(1);
      expect((await profile()).achievements).toEqual(['streak_7']);
    });
  });

  describe('kirish huquqi', () => {
    it('bola va ota-ona — 200; begona ota-ona / begona bola — 403; yo\'q bola — 404; tokensiz — 401', async () => {
      const stranger = await createParent(t.prisma);
      const strangerChild = await createChild(t.prisma, stranger);
      expect((await badges(child.token)).res.statusCode).toBe(200);
      expect((await badges(parent.token)).res.statusCode).toBe(200);
      expect((await badges(stranger.token)).res.statusCode).toBe(403);
      expect((await badges(strangerChild.token)).res.statusCode).toBe(403);
      expect((await badges(child.token, '00000000-0000-4000-8000-000000000000')).res.statusCode).toBe(404);
      expect((await t.app.inject({ method: 'GET', url: `/api/children/${child.childId}/badges` })).statusCode).toBe(401);
    });
  });
});
