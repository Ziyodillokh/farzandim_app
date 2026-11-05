// Growth Daily Learning — mavzular katalogi (bola ilovasi): bilim xaritasi,
// mavzu tafsilotlari, mavzu bo'yicha urinish. Haqiqiy Postgres'da.

import { createChild, createParent, TestChild, TestParent } from './factories';
import { resetDb } from './db';
import { seedQuestionBank } from './learning-fixtures';
import { createQuestions, createTopic, recordAttempt } from './learning-topics-fixtures';
import { createTestApp, TestApp } from './test-app';

const UNKNOWN_ID = '00000000-0000-4000-8000-000000000000';

describe('Learning topics API (child)', () => {
  let t: TestApp;
  let parent: TestParent;
  let child: TestChild;

  const call = (token: string | null, method: 'GET' | 'POST' | 'PUT', url: string, payload?: object) =>
    t.app.inject({
      method,
      url: `/api${url}`,
      ...(token && { headers: { authorization: `Bearer ${token}` } }),
      ...(payload && { payload }),
    });

  const setProfile = (grade = 7, subjects = ['math', 'english']) =>
    call(child.token, 'PUT', '/learning/profile', { grade, subjects });
  const listTopics = (subject = 'math') => call(child.token, 'GET', `/learning/subjects/${subject}/topics`);
  const startTopic = (topicId: string, subject = 'math') =>
    call(child.token, 'POST', '/learning/attempts', { subject, topicId });
  /** Fixture savollarida to'g'ri javob — 0-variant. */
  const answer = (attemptId: string, questionId: string, isCorrect: boolean) =>
    call(child.token, 'POST', `/learning/attempts/${attemptId}/answers`, {
      questionId,
      selectedIndex: isCorrect ? 0 : 1,
    });

  /** Mavzu + `count` ta faol savol (5–9-sinf). */
  async function topicWithQuestions(count: number, patch: Parameters<typeof createTopic>[1] = {}) {
    const topic = await createTopic(t.prisma, patch);
    const questions = await createQuestions(t.prisma, count, topic.id, { subject: patch.subject ?? 'MATH' });
    return { topic, questions };
  }

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    parent = await createParent(t.prisma, { language: 'uz' });
    child = await createChild(t.prisma, parent, { name: 'Aziz' });
  });

  afterAll(() => t.close());

  describe('kirish huquqi va umumiy xatolar', () => {
    it('tokensiz — 401; ota-ona tokeni bola endpointlariga kira olmaydi — 403', async () => {
      const { topic } = await topicWithQuestions(10);
      for (const [method, url] of [
        ['GET', '/learning/subjects/math/topics'],
        ['GET', `/learning/topics/${topic.id}`],
      ] as const) {
        expect((await call(null, method, url)).statusCode).toBe(401);
        expect((await call(parent.token, method, url)).statusCode).toBe(403);
      }
      const post = await call(parent.token, 'POST', '/learning/attempts', { subject: 'math', topicId: topic.id });
      expect(post.statusCode).toBe(403);
    });

    it('o\'quv profilisiz — 409 PROFILE_REQUIRED (ro\'yxat, tafsilot, boshlash)', async () => {
      const { topic } = await topicWithQuestions(10);
      for (const res of [
        await listTopics(),
        await call(child.token, 'GET', `/learning/topics/${topic.id}`),
        await startTopic(topic.id),
      ]) {
        expect(res.statusCode).toBe(409);
        expect(res.json().code).toBe('PROFILE_REQUIRED');
      }
    });

    it('noma\'lum fan — 400; noto\'g\'ri topicId formati — 400', async () => {
      await setProfile();
      expect((await listTopics('astrology')).statusCode).toBe(400);
      expect((await call(child.token, 'GET', '/learning/topics/not-a-uuid')).statusCode).toBe(400);
      expect((await call(child.token, 'POST', '/learning/attempts', { subject: 'math', topicId: 'nope' })).statusCode).toBe(400);
    });
  });

  describe('GET /learning/subjects/:subject/topics', () => {
    it('faqat faol va sinfga mos mavzular, position tartibida; shartnoma shakli', async () => {
      await setProfile(7);
      const second = await topicWithQuestions(12, { key: 'second', position: 2, title: { uz: 'Ikkinchi' }, goal: { uz: 'Maqsad 2', en: 'Goal 2' } });
      const first = await topicWithQuestions(10, { key: 'first', position: 1, title: { uz: 'Birinchi', ru: 'Первая', en: 'First' } });
      await topicWithQuestions(10, { key: 'hidden', position: 0, status: 'HIDDEN' });
      await topicWithQuestions(10, { key: 'young', position: 0, minGrade: 1, maxGrade: 4 });
      await topicWithQuestions(10, { key: 'physics-topic', position: 0, subject: 'PHYSICS', minGrade: 6, maxGrade: 9 });

      const res = await listTopics();
      expect(res.statusCode).toBe(200);
      const body = res.json();
      expect(body).toMatchObject({ subject: 'math', grade: 7, currentTopicId: first.topic.id });
      expect(body.topics.map((x: { key: string }) => x.key)).toEqual(['first', 'second']);
      expect(body.topics[0]).toEqual({
        id: first.topic.id,
        key: 'first',
        title: { uz: 'Birinchi', ru: 'Первая', en: 'First' },
        goal: { uz: 'Maqsad first', ru: 'Maqsad first', en: 'Maqsad first' },
        position: 1,
        minGrade: 5,
        maxGrade: 9,
        questionCount: 10,
        available: true,
        mastery: 'NOT_ASSESSED',
        evidenceCount: 0,
        evidenceCorrect: 0,
        lastAssessedAt: null,
        completedAttempts: 0,
        lastResult: null,
      });
      // Yetishmayotgan tillar uz bilan to'ldiriladi.
      expect(body.topics[1].title).toEqual({ uz: 'Ikkinchi', ru: 'Ikkinchi', en: 'Ikkinchi' });
      expect(body.topics[1].goal).toEqual({ uz: 'Maqsad 2', ru: 'Maqsad 2', en: 'Goal 2' });
      expect(body.topics[1].questionCount).toBe(second.questions.length);
    });

    it('goal yo\'q — null; fanda mavzu yo\'q — bo\'sh ro\'yxat va currentTopicId null', async () => {
      await setProfile();
      expect((await listTopics()).json()).toMatchObject({ topics: [], currentTopicId: null });
      await topicWithQuestions(10, { goal: null });
      expect((await listTopics()).json().topics[0].goal).toBeNull();
    });

    it('questionCount faqat faol va bola sinfiga mos savollar; yetarli bo\'lmasa available=false', async () => {
      await setProfile(7);
      const topic = await createTopic(t.prisma, { key: 'mixed' });
      await createQuestions(t.prisma, 6, topic.id);
      await createQuestions(t.prisma, 3, topic.id, { status: 'ARCHIVED' });
      await createQuestions(t.prisma, 2, topic.id, { status: 'DRAFT' });
      await createQuestions(t.prisma, 4, topic.id, { minGrade: 1, maxGrade: 4 });

      const view = (await listTopics()).json().topics[0];
      expect(view).toMatchObject({ questionCount: 6, available: false });
      await createQuestions(t.prisma, 4, topic.id);
      expect((await listTopics()).json().topics[0]).toMatchObject({ questionCount: 10, available: true });
    });

    it('currentTopicId: birinchi MAVJUD va o\'zlashtirilmagan mavzu', async () => {
      await setProfile();
      await topicWithQuestions(3, { key: 'not-ready', position: 0 });
      const mastered = await topicWithQuestions(10, { key: 'mastered', position: 1 });
      const practice = await topicWithQuestions(10, { key: 'practice', position: 2 });
      await topicWithQuestions(10, { key: 'fresh', position: 3 });

      await recordAttempt(t.prisma, child.childId, mastered.questions.slice(0, 5), [true, true, true, true, true]);
      await recordAttempt(t.prisma, child.childId, practice.questions.slice(0, 5), [true, false, false, true, false]);

      const body = (await listTopics()).json();
      const byKey = Object.fromEntries(body.topics.map((x: { key: string }) => [x.key, x]));
      expect(byKey['not-ready']).toMatchObject({ available: false, mastery: 'NOT_ASSESSED' });
      expect(byKey.mastered).toMatchObject({ mastery: 'MASTERED', evidenceCount: 5, evidenceCorrect: 5 });
      expect(byKey.practice).toMatchObject({ mastery: 'PRACTICE', evidenceCount: 5, evidenceCorrect: 2 });
      expect(byKey.fresh).toMatchObject({ mastery: 'NOT_ASSESSED' });
      expect(body.currentTopicId).toBe(practice.topic.id);

      await recordAttempt(t.prisma, child.childId, practice.questions.slice(5, 10), [true, true, true, true, true], {
        startedAt: new Date('2026-11-02T09:00:00.000Z'),
      });
      // practice: eng yangi 10 ta javobdan 7 tasi to'g'ri → hali PRACTICE.
      expect((await listTopics()).json().currentTopicId).toBe(practice.topic.id);
    });

    it('hamma mavjud mavzu o\'zlashtirilgan yoki mavjud emas — currentTopicId null', async () => {
      await setProfile();
      const done = await topicWithQuestions(10, { key: 'done', position: 0 });
      await topicWithQuestions(2, { key: 'tiny', position: 1 });
      await recordAttempt(t.prisma, child.childId, done.questions.slice(0, 5), [true, true, true, true, true]);
      expect((await listTopics()).json().currentTopicId).toBeNull();
    });

    it('dalil: 5 dan kam — NOT_ASSESSED (0% emas); faqat YAKUNLANGAN urinishlar; eng yangi 10 ta', async () => {
      await setProfile();
      const { topic, questions } = await topicWithQuestions(20);
      const mastery = async () => (await listTopics()).json().topics.find((x: { id: string }) => x.id === topic.id);

      await recordAttempt(t.prisma, child.childId, questions.slice(0, 4), [false, false, false, false]);
      expect(await mastery()).toMatchObject({ mastery: 'NOT_ASSESSED', evidenceCount: 4, evidenceCorrect: 0 });

      // Tugallanmagan / tashlab ketilgan urinishlar dalil emas.
      await recordAttempt(t.prisma, child.childId, questions.slice(4, 12), Array(8).fill(true), { status: 'IN_PROGRESS' });
      await recordAttempt(t.prisma, child.childId, questions.slice(4, 12), Array(8).fill(true), { status: 'ABANDONED' });
      expect(await mastery()).toMatchObject({ mastery: 'NOT_ASSESSED', evidenceCount: 4 });

      // Eski 4 ta xato + yangi 10 ta to'g'ri → faqat yangi 10 ta hisoblanadi.
      await recordAttempt(t.prisma, child.childId, questions.slice(0, 10), Array(10).fill(true), {
        startedAt: new Date('2026-11-03T09:00:00.000Z'),
      });
      expect(await mastery()).toMatchObject({ mastery: 'MASTERED', evidenceCount: 10, evidenceCorrect: 10 });
    });

    it('oddiy (aralash) yakunlangan urinishdagi mavzu savollari ham dalil; boshqa bola dalili hisoblanmaydi', async () => {
      await setProfile();
      const { topic, questions } = await topicWithQuestions(10);
      await recordAttempt(t.prisma, child.childId, questions.slice(0, 5), [true, true, true, true, false], { attemptTopicId: null });

      const other = await createChild(t.prisma, parent, { name: 'Malika' });
      await recordAttempt(t.prisma, other.childId, questions.slice(5, 10), Array(5).fill(false));

      const view = (await listTopics()).json().topics.find((x: { id: string }) => x.id === topic.id);
      expect(view).toMatchObject({ mastery: 'MASTERED', evidenceCount: 5, evidenceCorrect: 4, completedAttempts: 0, lastResult: null });
      expect(view.lastAssessedAt).toBe('2026-11-01T09:05:00.000Z');
    });

    it('completedAttempts va lastResult — faqat shu mavzu bo\'yicha yakunlangan urinishlar', async () => {
      await setProfile();
      const { topic, questions } = await topicWithQuestions(10);
      await recordAttempt(t.prisma, child.childId, questions, Array(10).fill(false).map((_, i) => i < 6), {
        attemptTopicId: topic.id,
        startedAt: new Date('2026-11-01T09:00:00.000Z'),
      });
      await recordAttempt(t.prisma, child.childId, questions, Array(10).fill(true), {
        attemptTopicId: topic.id,
        startedAt: new Date('2026-11-04T09:00:00.000Z'),
      });
      await recordAttempt(t.prisma, child.childId, questions, Array(3).fill(true), {
        attemptTopicId: topic.id,
        status: 'IN_PROGRESS',
        startedAt: new Date('2026-11-05T09:00:00.000Z'),
      });

      const view = (await listTopics()).json().topics[0];
      expect(view.completedAttempts).toBe(2);
      expect(view.lastResult).toEqual({ correct: 10, total: 10, completedAt: '2026-11-04T09:10:00.000Z' });
      expect(view.evidenceCount).toBe(10);
    });

    it('ko\'p mavzu bilan ham to\'g\'ri (agregatlar mavzularni aralashtirmaydi)', async () => {
      await setProfile();
      const topics = [];
      for (let i = 0; i < 12; i++) topics.push(await topicWithQuestions(10, { key: `t-${i}`, position: i }));
      await recordAttempt(t.prisma, child.childId, topics[7].questions.slice(0, 5), Array(5).fill(true), { attemptTopicId: topics[7].topic.id });
      await recordAttempt(t.prisma, child.childId, topics[3].questions.slice(0, 6), [false, false, true, false, false, false], { attemptTopicId: topics[3].topic.id });

      const body = (await listTopics()).json();
      const mastery = Object.fromEntries(body.topics.map((x: { key: string; mastery: string }) => [x.key, x.mastery]));
      expect(mastery['t-7']).toBe('MASTERED');
      expect(mastery['t-3']).toBe('PRACTICE');
      expect(Object.entries(mastery).filter(([, m]) => m === 'NOT_ASSESSED')).toHaveLength(10);
      expect(body.currentTopicId).toBe(topics[0].topic.id);
    });
  });

  describe('GET /learning/topics/:topicId', () => {
    it('mavzu + subject + inProgressAttempt (savollar 4/10)', async () => {
      await setProfile();
      const { topic } = await topicWithQuestions(12, { key: 'detail', goal: { uz: 'Kasrlarni solishtirish' } });

      const before = await call(child.token, 'GET', `/learning/topics/${topic.id}`);
      expect(before.statusCode).toBe(200);
      expect(before.json()).toMatchObject({
        id: topic.id,
        key: 'detail',
        subject: 'math',
        goal: { uz: 'Kasrlarni solishtirish' },
        questionCount: 12,
        available: true,
        mastery: 'NOT_ASSESSED',
        lastResult: null,
        inProgressAttempt: null,
      });

      const attempt = (await startTopic(topic.id)).json();
      for (const q of attempt.questions.slice(0, 4)) await answer(attempt.id, q.id, true);
      const during = (await call(child.token, 'GET', `/learning/topics/${topic.id}`)).json();
      expect(during.inProgressAttempt).toEqual({ id: attempt.id, answered: 4, total: 10 });
    });

    it('yakunlangan urinishdan keyin inProgressAttempt yo\'q, natija va daraja yangilanadi', async () => {
      await setProfile();
      const { topic } = await topicWithQuestions(10);
      const attempt = (await startTopic(topic.id)).json();
      for (const [i, q] of attempt.questions.entries()) await answer(attempt.id, q.id, i < 9);
      expect((await call(child.token, 'POST', `/learning/attempts/${attempt.id}/complete`)).statusCode).toBe(200);

      const detail = (await call(child.token, 'GET', `/learning/topics/${topic.id}`)).json();
      expect(detail).toMatchObject({
        inProgressAttempt: null,
        mastery: 'MASTERED',
        evidenceCount: 10,
        evidenceCorrect: 9,
        completedAttempts: 1,
        lastResult: { correct: 9, total: 10 },
      });
      expect(typeof detail.lastResult.completedAt).toBe('string');
    });

    it('boshqa bolaning urinishi inProgressAttempt sifatida ko\'rinmaydi', async () => {
      await setProfile();
      const { topic } = await topicWithQuestions(10);
      const other = await createChild(t.prisma, parent, { name: 'Malika' });
      await t.prisma.learningProfile.create({ data: { childId: other.childId, grade: 7, subjects: ['MATH'] } });
      const res = await call(other.token, 'POST', '/learning/attempts', { subject: 'math', topicId: topic.id });
      expect(res.statusCode).toBe(200);
      expect((await call(child.token, 'GET', `/learning/topics/${topic.id}`)).json().inProgressAttempt).toBeNull();
    });

    it('mavjud emas yoki HIDDEN — 404; sinfga mos savol yo\'q — available=false', async () => {
      await setProfile(7);
      expect((await call(child.token, 'GET', `/learning/topics/${UNKNOWN_ID}`)).statusCode).toBe(404);
      const hidden = await topicWithQuestions(10, { status: 'HIDDEN' });
      expect((await call(child.token, 'GET', `/learning/topics/${hidden.topic.id}`)).statusCode).toBe(404);

      const young = await createTopic(t.prisma, { minGrade: 1, maxGrade: 3 });
      await createQuestions(t.prisma, 10, young.id, { minGrade: 1, maxGrade: 3 });
      const view = (await call(child.token, 'GET', `/learning/topics/${young.id}`)).json();
      expect(view).toMatchObject({ questionCount: 0, available: false });
    });
  });

  describe('POST /learning/attempts + topicId', () => {
    it('mavzu puldan 10 savol, topicId saqlanadi, javobda topic {id,key,title}', async () => {
      await setProfile();
      const { topic, questions } = await topicWithQuestions(15, { key: 'fractions', title: { uz: 'Kasrlar', ru: 'Дроби', en: 'Fractions' } });
      // Boshqa mavzu va bog'lanmagan savollar tanlanmasligi kerak.
      await topicWithQuestions(15, { key: 'other' });
      await createQuestions(t.prisma, 15, null);
      await createQuestions(t.prisma, 5, topic.id, { minGrade: 1, maxGrade: 4 });
      await createQuestions(t.prisma, 5, topic.id, { status: 'ARCHIVED' });

      const res = await startTopic(topic.id);
      expect(res.statusCode).toBe(200);
      const attempt = res.json();
      expect(attempt).toMatchObject({
        subject: 'math',
        status: 'IN_PROGRESS',
        isDaily: true,
        total: 10,
        topic: { id: topic.id, key: 'fractions', title: { uz: 'Kasrlar', ru: 'Дроби', en: 'Fractions' } },
      });
      expect(attempt.questions).toHaveLength(10);
      const raw = JSON.stringify(attempt.questions);
      expect(raw).not.toContain('answerIndex');
      expect(raw).not.toContain('explanation');

      const poolIds = new Set(questions.map((q) => q.id));
      expect(attempt.questions.every((q: { id: string }) => poolIds.has(q.id))).toBe(true);
      const difficulties = attempt.questions.map((q: { difficulty: number }) => q.difficulty);
      expect(difficulties).toEqual([...difficulties].sort());

      const stored = await t.prisma.learningAttempt.findUniqueOrThrow({ where: { id: attempt.id } });
      expect(stored.topicId).toBe(topic.id);
      expect(stored.topic).toEqual({ uz: 'Kasrlar', ru: 'Дроби', en: 'Fractions' });
    });

    it('qayta boshlash shu mavzudagi urinishni davom ettiradi; oddiy urinish bilan aralashmaydi', async () => {
      await setProfile();
      await seedQuestionBank(t.prisma);
      const { topic } = await topicWithQuestions(12);

      const first = (await startTopic(topic.id)).json();
      await answer(first.id, first.questions[0].id, true);
      const resumed = (await startTopic(topic.id)).json();
      expect(resumed.id).toBe(first.id);
      expect(resumed.answers).toHaveLength(1);
      expect(resumed.topic.id).toBe(topic.id);

      // Oddiy boshlash mavzu urinishini qaytarmaydi — alohida urinish.
      const classic = (await call(child.token, 'POST', '/learning/attempts', { subject: 'math' })).json();
      expect(classic.id).not.toBe(first.id);
      expect(classic.topic).toBeNull();
      expect((await call(child.token, 'POST', '/learning/attempts', { subject: 'math' })).json().id).toBe(classic.id);
      expect((await startTopic(topic.id)).json().id).toBe(first.id);
      // Ikkinchisi — kunning birinchi urinishi emas.
      expect(classic.isDaily).toBe(false);
    });

    it('parallel boshlash (qo\'sh bosish) — bitta urinish', async () => {
      await setProfile();
      const { topic } = await topicWithQuestions(10);
      const results = await Promise.all(Array.from({ length: 4 }, () => startTopic(topic.id)));
      expect(results.every((r) => r.statusCode === 200)).toBe(true);
      expect(new Set(results.map((r) => r.json().id)).size).toBe(1);
      expect(await t.prisma.learningAttempt.count()).toBe(1);
    });

    it('kechagi yarim qolgan mavzu urinishi yopiladi va yangisi boshlanadi', async () => {
      await setProfile();
      const { topic, questions } = await topicWithQuestions(10);
      const stale = await t.prisma.learningAttempt.create({
        data: { childId: child.childId, subject: 'MATH', day: '2020-01-01', isDaily: true, questionIds: questions.map((q) => q.id), topicId: topic.id, total: 10 },
      });
      const fresh = (await startTopic(topic.id)).json();
      expect(fresh.id).not.toBe(stale.id);
      expect((await t.prisma.learningAttempt.findUniqueOrThrow({ where: { id: stale.id } })).status).toBe('ABANDONED');
    });

    it('422 TOPIC_NOT_AVAILABLE: savol yetarli emas', async () => {
      await setProfile(7);
      const few = await topicWithQuestions(9);
      const res = await startTopic(few.topic.id);
      expect(res.statusCode).toBe(422);
      expect(res.json().code).toBe('TOPIC_NOT_AVAILABLE');
      expect(await t.prisma.learningAttempt.count()).toBe(0);
    });

    it('422 TOPIC_NOT_AVAILABLE: savollar bola sinfiga mos emas / arxivlangan', async () => {
      await setProfile(7);
      const young = await createTopic(t.prisma, { minGrade: 1, maxGrade: 4 });
      await createQuestions(t.prisma, 12, young.id, { minGrade: 1, maxGrade: 4 });
      const archived = await createTopic(t.prisma);
      await createQuestions(t.prisma, 12, archived.id, { status: 'ARCHIVED' });
      for (const id of [young.id, archived.id]) {
        const res = await startTopic(id);
        expect(res.statusCode).toBe(422);
        expect(res.json().code).toBe('TOPIC_NOT_AVAILABLE');
      }
    });

    it('422 TOPIC_NOT_AVAILABLE: HIDDEN, boshqa fan, mavjud bo\'lmagan mavzu', async () => {
      await setProfile(7);
      const hidden = await topicWithQuestions(12, { status: 'HIDDEN' });
      const physics = await topicWithQuestions(12, { subject: 'PHYSICS', minGrade: 6, maxGrade: 9 });
      const cases = [
        await startTopic(hidden.topic.id),
        await startTopic(physics.topic.id, 'math'),
        await startTopic(UNKNOWN_ID),
      ];
      for (const res of cases) {
        expect(res.statusCode).toBe(422);
        expect(res.json().code).toBe('TOPIC_NOT_AVAILABLE');
      }
      // To'g'ri fan bilan fizika mavzusi boshlanadi (profilga fizika qo'shamiz).
      await setProfile(7, ['math', 'physics']);
      expect((await startTopic(physics.topic.id, 'physics')).statusCode).toBe(200);
    });

    it('yakunlash: natijada topic / topicRef; DON qoidasi o\'zgarmagan (kunning birinchi urinishi)', async () => {
      await setProfile();
      const { topic } = await topicWithQuestions(10, { key: 'fractions', title: { uz: 'Kasrlar' } });
      const attempt = (await startTopic(topic.id)).json();
      for (const [i, q] of attempt.questions.entries()) await answer(attempt.id, q.id, i < 6);

      const done = await call(child.token, 'POST', `/learning/attempts/${attempt.id}/complete`);
      expect(done.statusCode).toBe(200);
      const result = done.json();
      expect(result).toMatchObject({
        correct: 6,
        total: 10,
        percent: 60,
        isDaily: true,
        donEarned: 12,
        xpEarned: 30,
        topicRef: { id: topic.id, key: 'fractions', title: { uz: 'Kasrlar', ru: 'Kasrlar', en: 'Kasrlar' } },
      });
      // Eski ilovalar `topic.uz` ni o'qiydi; yangi maydonlar qo'shimcha.
      expect(result.topic).toMatchObject({ uz: 'Kasrlar', id: topic.id, key: 'fractions', title: { uz: 'Kasrlar' } });

      const results = (await call(child.token, 'GET', '/learning/results')).json();
      expect(results.items[0]).toMatchObject({ id: attempt.id, topicRef: { id: topic.id } });
      const review = (await call(child.token, 'GET', `/learning/attempts/${attempt.id}/review`)).json();
      expect(review.result.topicRef.id).toBe(topic.id);

      const view = (await call(child.token, 'GET', `/learning/attempts/${attempt.id}`)).json();
      expect(view.topic).toMatchObject({ id: topic.id, key: 'fractions' });
    });

    it('ikkinchi mavzu urinishi (shu kun) — amaliyot: DON yo\'q', async () => {
      await setProfile();
      const a = await topicWithQuestions(10, { key: 'a' });
      const b = await topicWithQuestions(10, { key: 'b' });
      const first = (await startTopic(a.topic.id)).json();
      for (const q of first.questions) await answer(first.id, q.id, true);
      expect((await call(child.token, 'POST', `/learning/attempts/${first.id}/complete`)).json().donEarned).toBe(30);

      const second = (await startTopic(b.topic.id)).json();
      expect(second.isDaily).toBe(false);
      for (const q of second.questions) await answer(second.id, q.id, true);
      expect((await call(child.token, 'POST', `/learning/attempts/${second.id}/complete`)).json().donEarned).toBe(0);
    });
  });

  describe('oddiy (topicId\'siz) urinish — eskicha', () => {
    it('topic null, topicId saqlanmaydi, eski topic sarlavhasi va natija shakli o\'zgarmagan', async () => {
      await setProfile();
      await seedQuestionBank(t.prisma);
      // Mavzu katalogi mavjud bo'lsa ham oddiy boshlash fan bankidan.
      await topicWithQuestions(12);

      const res = await call(child.token, 'POST', '/learning/attempts', { subject: 'english' });
      expect(res.statusCode).toBe(200);
      const attempt = res.json();
      expect(attempt).toMatchObject({ subject: 'english', status: 'IN_PROGRESS', isDaily: true, total: 10, topic: null });
      expect(attempt.questions[0]).toHaveProperty('topic.uz');

      const stored = await t.prisma.learningAttempt.findUniqueOrThrow({ where: { id: attempt.id } });
      expect(stored.topicId).toBeNull();
      expect(stored.topic).toHaveProperty('uz');

    });

    it('natijalar: topic eski {uz,ru,en}, topicRef null', async () => {
      await setProfile();
      await seedQuestionBank(t.prisma);
      const attempt = (await call(child.token, 'POST', '/learning/attempts', { subject: 'math' })).json();
      const stored = await t.prisma.learningQuestion.findMany({ where: { id: { in: attempt.questions.map((q: { id: string }) => q.id) } } });
      const right = new Map(stored.map((q) => [q.id, q.answerIndex]));
      for (const q of attempt.questions) {
        await call(child.token, 'POST', `/learning/attempts/${attempt.id}/answers`, { questionId: q.id, selectedIndex: right.get(q.id) });
      }
      const done = (await call(child.token, 'POST', `/learning/attempts/${attempt.id}/complete`)).json();
      expect(done).toMatchObject({ correct: 10, topicRef: null });
      expect(Object.keys(done.topic).sort()).toEqual(['en', 'ru', 'uz']);

      const results = (await call(child.token, 'GET', '/learning/results')).json();
      expect(Object.keys(results.items[0].topic).sort()).toEqual(['en', 'ru', 'uz']);
      expect(results.items[0].topicRef).toBeNull();
    });
  });
});
