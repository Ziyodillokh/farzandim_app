// Parvoz Kelajak — overview, progress, natijalar va ota-ona xulosasi haqiqiy
// Postgres'da: bugungi holatlar, oldingi va oxirgi ball, ruxsatlar va
// maxfiylik (wellbeing / safety raqamlari hech kimga chiqmaydi).

import { randomUUID } from 'node:crypto';
import { addDays, tashkentDay } from '../../src/common/time/tashkent';
import { KELAJAK_TEST_TYPES } from '../../src/modules/kelajak/domain/catalog';
import { resetDb } from './db';
import { createChild, createParent, TestChild, TestParent } from './factories';
import {
  answerCalm,
  answerScale,
  Call,
  caller,
  lowest,
  seedKelajakBank,
  setChildAge,
  shiftSessionDays,
} from './kelajak-fixtures';
import { createTestApp, TestApp } from './test-app';

interface Q {
  id: string;
  externalId: string;
  answerType: string;
  options: Array<{ value: number }>;
}

const SUPPORT_CATEGORIES = ['wellbeing', 'safety'];
const categoryKeys = (list: Array<{ category: string }>) => list.map((c) => c.category);
const supportKeys = (list: Array<{ category: string }>) =>
  categoryKeys(list).filter((key) => SUPPORT_CATEGORIES.includes(key));

describe('Kelajak API — overview, progress, ota-ona', () => {
  let t: TestApp;
  let call: Call;
  let parent: TestParent;
  let child: TestChild;

  const startOk = async (type: string) => {
    const res = await call(child.token, 'POST', '/kelajak/sessions', { type });
    expect(res.statusCode).toBe(200);
    return res.json();
  };
  const completeOk = async (sessionId: string) => {
    const res = await call(child.token, 'POST', `/kelajak/sessions/${sessionId}/complete`);
    expect(res.statusCode).toBe(200);
    return res.json();
  };
  const finish = async (type: string, pick?: (values: number[]) => number) => {
    const session = await startOk(type);
    await answerScale(call, child.token, session, pick);
    return completeOk(session.id);
  };
  const overview = async () => (await call(child.token, 'GET', '/kelajak/overview')).json();
  const todayOf = (view: { tests: Array<{ type: string; today: object }> }, type: string) =>
    view.tests.find((x) => x.type === type)?.today;

  beforeAll(async () => {
    t = await createTestApp();
    call = caller(t);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    await seedKelajakBank(t.prisma);
    parent = await createParent(t.prisma);
    child = await createChild(t.prisma, parent, { name: 'Aziz' });
    await setChildAge(t.prisma, child.childId, { via: 'age', years: 11 });
  });

  afterAll(() => t.close());

  describe('overview', () => {
    it('bugungi holat NEW → STARTED → IN_PROGRESS → COMPLETED; savollar soni POST bilan mos', async () => {
      const initial = await overview();
      expect(initial.age).toEqual({ status: 'OK', age: 11, ageGroup: '10-12' });
      expect(initial.tests.map((x: { type: string }) => x.type)).toEqual([...KELAJAK_TEST_TYPES]);
      expect(initial.tests.every((x: { today: { status: string } }) => x.today.status === 'NEW')).toBe(true);
      expect(initial.categories).toHaveLength(12);
      expect(initial.profile).toBeNull();

      const career = await startOk('career');
      const careerTest = initial.tests.find((x: { type: string }) => x.type === 'career');
      expect(careerTest.questionCount).toBe(career.total);
      expect(todayOf(await overview(), 'career')).toEqual({ status: 'STARTED', sessionId: career.id });

      await call(child.token, 'PUT', `/kelajak/sessions/${career.id}/answers/${career.questions[0].id}`, { value: 3 });
      expect(todayOf(await overview(), 'career')).toEqual({ status: 'IN_PROGRESS', sessionId: career.id });

      const lab = await startOk('career_lab');
      await call(child.token, 'PUT', `/kelajak/sessions/${lab.id}/answers/${lab.questions[0].id}`, { value: 5 });
      await completeOk(lab.id);
      const after = await overview();
      expect(todayOf(after, 'career_lab')).toEqual({ status: 'COMPLETED', sessionId: lab.id });
      expect(todayOf(after, 'daily')).toEqual({ status: 'NEW', sessionId: null });
      expect(after.profile).toMatchObject({ answeredQuestions: 1, disclaimer: { uz: expect.any(String) } });
      expect(after.profile.availableQuestions).toBeGreaterThan(1);
      // Career Lab tavsiyasida faoliyat id'si bor (keyingi Career Lab bosqichi uchun).
      for (const n of after.profile.insights.next) expect(n).toHaveProperty('externalId');
    });

    it('yosh noma\'lum — testlar ro\'yxati bo\'sh, holat AGE_REQUIRED', async () => {
      await setChildAge(t.prisma, child.childId, { via: 'none' });
      const view = await overview();
      expect(view.age).toEqual({ status: 'AGE_REQUIRED', age: null, ageGroup: null });
      expect(view.tests).toEqual([]);
      expect(view.categories).toHaveLength(12);
    });

    it('19 yosh — AGE_OUT_OF_RANGE, testlar ro\'yxati bo\'sh', async () => {
      await setChildAge(t.prisma, child.childId, { via: 'age', years: 19 });
      const view = await overview();
      expect(view.age).toEqual({ status: 'AGE_OUT_OF_RANGE', age: 19, ageGroup: null });
      expect(view.tests).toEqual([]);
    });
  });

  describe('progress va natijalar', () => {
    it('ikki sessiyadan keyin oldingi va oxirgi ball, o\'sish, tarix va kursor', async () => {
      const first = await finish('learning', lowest);
      await shiftSessionDays(t.prisma, first.id, 1);
      const second = await finish('learning');

      const progress = (await call(child.token, 'GET', '/kelajak/progress')).json();
      expect(progress.sessionsCompleted).toBe(2);
      expect(progress.firstCompletedAt).not.toBeNull();
      expect(progress.lastCompletedAt).toBe(second.completedAt);
      const learning = progress.categories.find((c: { category: string }) => c.category === 'learning');
      expect(learning).toMatchObject({
        latest: 100,
        previous: 0,
        delta: 100,
        points: [{ day: addDays(tashkentDay(), -1), score: 0 }, { day: tashkentDay(), score: 100 }],
      });
      expect(learning.name.uz.length).toBeGreaterThan(0);
      expect(progress.improved).toContain('learning');
      expect(progress.history.map((h: { id: string }) => h.id)).toEqual([second.id, first.id]);
      expect(progress.history[0]).toMatchObject({ type: 'learning', status: 'COMPLETED', answered: second.total });

      const page1 = (await call(child.token, 'GET', '/kelajak/results?limit=1')).json();
      expect(page1.items.map((r: { id: string }) => r.id)).toEqual([second.id]);
      expect(page1.nextBefore).not.toBeNull();
      const page2 = (
        await call(child.token, 'GET', `/kelajak/results?limit=1&before=${encodeURIComponent(page1.nextBefore)}`)
      ).json();
      expect(page2).toEqual({ items: [expect.objectContaining({ id: first.id, day: addDays(tashkentDay(), -1) })], nextBefore: null });
    });

    it('wellbeing sessiyasidan keyin ham progress va profilda wellbeing/safety raqami yo\'q', async () => {
      await finish('wellbeing', lowest);
      await finish('learning');
      const progress = (await call(child.token, 'GET', '/kelajak/progress')).json();
      expect(progress.sessionsCompleted).toBe(2);
      expect(categoryKeys(progress.categories)).toContain('learning');
      expect(supportKeys(progress.categories)).toEqual([]);
      const profile = (await overview()).profile;
      expect(categoryKeys(profile.categories)).toContain('learning');
      expect(supportKeys(profile.categories)).toEqual([]);
      expect(profile.insights.support.level).toBe('support');
    });
  });

  describe('ota-ona xulosasi', () => {
    const summaryUrl = () => `/children/${child.childId}/kelajak/summary`;

    it('ruxsatlar: egasi 200, begona 403, bola tokeni 403, bola yo\'q 404', async () => {
      const own = await call(parent.token, 'GET', summaryUrl());
      expect(own.statusCode).toBe(200);
      expect(own.json()).toMatchObject({
        age: { status: 'OK', ageGroup: '10-12' },
        sessionsCompleted: 0,
        lastCompletedAt: null,
        categories: [],
        interests: null,
        support: null,
        progress: { categories: [], interests: [] },
        disclaimer: { uz: expect.any(String) },
      });
      const stranger = await createParent(t.prisma);
      expect((await call(stranger.token, 'GET', summaryUrl())).statusCode).toBe(403);
      expect((await call(child.token, 'GET', summaryUrl())).statusCode).toBe(403);
      expect((await call(parent.token, 'GET', `/children/${randomUUID()}/kelajak/summary`)).statusCode).toBe(404);
    });

    it('qiziqishlar va signal: ota-onaga daraja va soha, raqam ham savol ham yo\'q', async () => {
      await finish('career');
      const wellbeing = await startOk('wellbeing');
      await answerScale(call, child.token, wellbeing, lowest);
      // Xavfsizlik bilimi savollari signalga kirmaydi — safety sohasi faqat holat savoli bo'lsa.
      const picked = await t.prisma.kelajakQuestion.findMany({ where: { id: { in: wellbeing.questions.map((q: Q) => q.id) } } });
      const distressSafety = picked.some(
        (q) => q.category === 'safety' && (q.scoring as { signal?: string } | null)?.signal !== 'knowledge',
      );
      const childResult = (await completeOk(wellbeing.id)).result;
      // Bolaga: wellbeing/safety balli yo'q, faqat mehribon xabar.
      expect(categoryKeys(childResult.categories)).toEqual([]);
      expect(childResult.insights.support).toEqual({ level: 'support', message: expect.objectContaining({ uz: expect.any(String) }) });

      const res = await call(parent.token, 'GET', summaryUrl());
      expect(res.statusCode).toBe(200);
      const summary = res.json();
      expect(summary.sessionsCompleted).toBe(2);
      expect(summary.interests.top.length).toBeGreaterThan(0);
      expect(summary.insights.interests.length).toBeGreaterThan(0);
      expect(summary.insights).not.toHaveProperty('support');
      expect(summary.support).toEqual({
        level: 'support',
        areas: [
          ...(distressSafety ? [{ key: 'safety', name: expect.objectContaining({ uz: expect.any(String) }) }] : []),
          { key: 'wellbeing', name: expect.objectContaining({ uz: expect.any(String) }) },
        ],
        day: tashkentDay(),
        guidance: expect.objectContaining({ uz: expect.any(String) }),
      });
      expect(categoryKeys(summary.categories)).toContain('career_planning');
      expect(supportKeys(summary.categories)).toEqual([]);
      expect(supportKeys(summary.progress.categories)).toEqual([]);

      const raw = res.body;
      for (const q of wellbeing.questions as Q[]) {
        expect(raw).not.toContain(q.id);
        expect(raw).not.toContain(q.externalId);
      }
      expect(raw).not.toContain('"category":"wellbeing"');
      expect(raw).not.toContain('"category":"safety"');
      expect(raw).not.toContain('questionId');
    });

    it('tashvishsiz wellbeing: bolaga "none" xabari, ota-onaga support: null', async () => {
      const wellbeing = await startOk('wellbeing');
      await answerCalm(t.prisma, call, child.token, wellbeing);
      const childResult = (await completeOk(wellbeing.id)).result;
      expect(childResult.insights.support).toEqual({ level: 'none', message: expect.objectContaining({ uz: expect.any(String) }) });
      const summary = (await call(parent.token, 'GET', summaryUrl())).json();
      expect(summary.sessionsCompleted).toBe(1);
      expect(summary.support).toBeNull();
    });

    it('bitta tashvishli javob — ota-onaga "watch" (raqamsiz)', async () => {
      const wellbeing = await startOk('wellbeing');
      const reversed = new Set(
        (await t.prisma.kelajakQuestion.findMany({ where: { reverse: true } })).map((q) => q.id),
      );
      const [worried] = (wellbeing.questions as Array<Q & { category: string }>).filter(
        (q) => q.category === 'wellbeing' && !reversed.has(q.id),
      );
      await answerCalm(t.prisma, call, child.token, wellbeing);
      await call(child.token, 'PUT', `/kelajak/sessions/${wellbeing.id}/answers/${worried.id}`, { value: 1 });
      await completeOk(wellbeing.id);
      const summary = (await call(parent.token, 'GET', summaryUrl())).json();
      expect(summary.support).toEqual({
        level: 'watch',
        areas: [{ key: 'wellbeing', name: expect.objectContaining({ uz: expect.any(String) }) }],
        day: tashkentDay(),
        guidance: expect.objectContaining({ uz: expect.any(String) }),
      });
    });

    it('"Ota-ona bilan muloqot" ota-onaga ko\'rsatilmaydi (bolaga ko\'rinadi); 1 javobli kategoriya ham yo\'q', async () => {
      await finish('self', lowest);
      const progress = (await call(child.token, 'GET', '/kelajak/progress')).json();
      expect(categoryKeys(progress.categories)).toContain('parent_communication');

      const res = await call(parent.token, 'GET', summaryUrl());
      const summary = res.json();
      expect(categoryKeys(summary.categories)).not.toContain('parent_communication');
      expect(categoryKeys(summary.progress.categories)).not.toContain('parent_communication');
      expect(summary.insights.growthAreas.map((g: { key: string }) => g.key)).not.toContain('parent_communication');
      expect(summary.insights.strengths.map((g: { key: string }) => g.key)).not.toContain('parent_communication');
      expect(summary.categories.every((c: { answered: number }) => c.answered >= 2)).toBe(true);
      expect(res.body).not.toContain('parent_communication');
    });

    it('Career Lab: ota-onaga faoliyat va xulosa — savol id\'si va xom reytingsiz', async () => {
      const lab = await startOk('career_lab');
      await answerScale(call, child.token, lab);
      const childView = (await completeOk(lab.id)).result.insights;
      expect(childView.likedDirections[0]).toMatchObject({ externalId: expect.any(String), rating: 5 });
      const summary = (await call(parent.token, 'GET', summaryUrl())).json();
      expect(summary.insights.likedDirections.length).toBe(lab.questions.length);
      for (const d of [...summary.insights.likedDirections, ...summary.insights.triedDirections]) {
        expect(d).not.toHaveProperty('rating');
        expect(d).not.toHaveProperty('externalId');
        expect(d.activity.uz.length).toBeGreaterThan(0);
      }
      expect(summary.insights.triedDirections[0]).toMatchObject({ verdict: 'liked' });
    });
  });
});
