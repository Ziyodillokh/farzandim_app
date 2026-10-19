// Growth Daily Learning API — to'liq oqim haqiqiy Postgres'da.

import { LearningInsightsService } from '../../src/modules/learning/learning-insights.service';
import { donFor, xpFor } from '../../src/modules/learning/domain/rewards';
import { tashkentDay, addDays } from '../../src/common/time/tashkent';
import { createChild, createParent, TestChild, TestParent } from './factories';
import { resetDb } from './db';
import { seedQuestionBank } from './learning-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('Learning API', () => {
  let t: TestApp;
  let parent: TestParent;
  let child: TestChild;

  const call = (
    token: string,
    method: 'GET' | 'POST' | 'PUT',
    url: string,
    payload?: object,
  ) =>
    t.app.inject({
      method,
      url: `/api${url}`,
      headers: { authorization: `Bearer ${token}` },
      ...(payload && { payload }),
    });

  const setProfile = (grade = 7, subjects = ['math', 'english', 'native']) =>
    call(child.token, 'PUT', '/learning/profile', { grade, subjects });

  /** Barcha savollarga javob: [correctCount] tasi to'g'ri. */
  async function answerAll(attempt: { id: string; questions: { id: string }[] }, correctCount: number) {
    const questions = await t.prisma.learningQuestion.findMany({
      where: { id: { in: attempt.questions.map((q) => q.id) } },
    });
    const answer = new Map(questions.map((q) => [q.id, q.answerIndex]));
    for (const [i, q] of attempt.questions.entries()) {
      const right = answer.get(q.id)!;
      const res = await call(child.token, 'POST', `/learning/attempts/${attempt.id}/answers`, {
        questionId: q.id,
        selectedIndex: i < correctCount ? right : (right + 1) % 4,
      });
      expect(res.statusCode).toBe(200);
    }
  }

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    await seedQuestionBank(t.prisma);
    t.fcm.reset();
    parent = await createParent(t.prisma, { language: 'uz' });
    child = await createChild(t.prisma, parent, { name: 'Aziz' });
  });

  afterAll(() => t.close());

  describe('profil', () => {
    it('tanlanmagan → null; saqlash va o\'qish', async () => {
      expect((await call(child.token, 'GET', '/learning/profile')).json()).toEqual({ profile: null });
      const saved = await setProfile(8, ['physics', 'math']);
      expect(saved.statusCode).toBe(200);
      expect(saved.json().profile).toMatchObject({ grade: 8, subjects: ['physics', 'math'] });
      expect((await call(child.token, 'GET', '/learning/profile')).json().profile.grade).toBe(8);
    });

    it('sinfda o\'qitilmaydigan fan, noma\'lum fan, ortiqcha fan — 400', async () => {
      expect((await setProfile(5, ['physics'])).statusCode).toBe(400);
      expect((await setProfile(7, ['astrology'])).statusCode).toBe(400);
      expect(
        (await setProfile(9, ['math', 'english', 'native', 'history', 'biology', 'physics'])).statusCode,
      ).toBe(400);
    });

    it('ota-ona o\'z bolasini o\'zgartiradi, begona ota-ona — 403', async () => {
      const ok = await call(parent.token, 'PUT', `/children/${child.childId}/learning/profile`, {
        grade: 6,
        subjects: ['math'],
      });
      expect(ok.statusCode).toBe(200);
      const stranger = await createParent(t.prisma);
      const denied = await call(stranger.token, 'GET', `/children/${child.childId}/learning/profile`);
      expect(denied.statusCode).toBe(403);
      // Bola tokeni ota-ona yo'liga kira olmaydi.
      expect((await call(child.token, 'GET', `/children/${child.childId}/learning/summary`)).statusCode).toBe(403);
    });
  });

  describe('urinish', () => {
    it('profilsiz boshlash — 409 PROFILE_REQUIRED', async () => {
      const res = await call(child.token, 'POST', '/learning/attempts', { subject: 'math' });
      expect(res.statusCode).toBe(409);
      expect(res.json().code).toBe('PROFILE_REQUIRED');
    });

    it('boshlash: 10 savol, to\'g\'ri javobsiz, osondan qiyinga; qayta — davom ettirish', async () => {
      await setProfile();
      const first = await call(child.token, 'POST', '/learning/attempts', { subject: 'math' });
      expect(first.statusCode).toBe(200);
      const attempt = first.json();
      expect(attempt).toMatchObject({ subject: 'math', status: 'IN_PROGRESS', isDaily: true, total: 10 });
      expect(attempt.questions).toHaveLength(10);
      const raw = JSON.stringify(attempt.questions);
      expect(raw).not.toContain('answerIndex');
      expect(raw).not.toContain('explanation');
      const difficulties = attempt.questions.map((q: { difficulty: number }) => q.difficulty);
      expect(difficulties).toEqual([...difficulties].sort());
      expect(attempt.questions[0].prompt).toHaveProperty('ru');

      await call(child.token, 'POST', `/learning/attempts/${attempt.id}/answers`, {
        questionId: attempt.questions[0].id,
        selectedIndex: 0,
      });
      const resumed = (await call(child.token, 'POST', '/learning/attempts', { subject: 'math' })).json();
      expect(resumed.id).toBe(attempt.id);
      expect(resumed.answers).toHaveLength(1);
      expect(resumed.answers[0]).toHaveProperty('correctIndex');
    });

    it('javob: to\'g\'ri javob va izoh qaytadi, qayta yuborish natijani o\'zgartirmaydi', async () => {
      await setProfile();
      const attempt = (await call(child.token, 'POST', '/learning/attempts', { subject: 'english' })).json();
      const q = attempt.questions[0];
      const stored = await t.prisma.learningQuestion.findUniqueOrThrow({ where: { id: q.id } });
      const wrong = (stored.answerIndex + 1) % 4;

      const first = (await call(child.token, 'POST', `/learning/attempts/${attempt.id}/answers`, {
        questionId: q.id,
        selectedIndex: wrong,
      })).json();
      expect(first).toMatchObject({ isCorrect: false, correctIndex: stored.answerIndex, selectedIndex: wrong });
      expect(first.explanation.uz.length).toBeGreaterThan(0);

      const again = (await call(child.token, 'POST', `/learning/attempts/${attempt.id}/answers`, {
        questionId: q.id,
        selectedIndex: stored.answerIndex,
      })).json();
      expect(again).toMatchObject({ isCorrect: false, selectedIndex: wrong });

      const foreign = await call(child.token, 'POST', `/learning/attempts/${attempt.id}/answers`, {
        questionId: '00000000-0000-4000-8000-000000000000',
        selectedIndex: 0,
      });
      expect(foreign.statusCode).toBe(400);
    });

    it('hammasiga javobsiz yakunlash — 400 UNANSWERED', async () => {
      await setProfile();
      const attempt = (await call(child.token, 'POST', '/learning/attempts', { subject: 'math' })).json();
      const res = await call(child.token, 'POST', `/learning/attempts/${attempt.id}/complete`);
      expect(res.statusCode).toBe(400);
      expect(res.json()).toMatchObject({ code: 'UNANSWERED', remaining: 10 });
    });

    it('yakun: DON / XP bir marta (parallel yakunlashda ham), streak yangilanadi', async () => {
      await setProfile();
      const attempt = (await call(child.token, 'POST', '/learning/attempts', { subject: 'math' })).json();
      await answerAll(attempt, 7);

      const results = await Promise.all(
        Array.from({ length: 5 }, () =>
          call(child.token, 'POST', `/learning/attempts/${attempt.id}/complete`),
        ),
      );
      for (const r of results) {
        expect(r.statusCode).toBe(200);
        expect(r.json()).toMatchObject({ correct: 7, total: 10, percent: 70, donEarned: donFor(7, 10) });
      }

      const profile = await t.prisma.childProfile.findUniqueOrThrow({ where: { childId: child.childId } });
      expect(profile.donBalance).toBe(donFor(7, 10));
      expect(profile.xp).toBe(xpFor(7, 10));
      expect(profile.streakDays).toBe(1);
      expect(
        await t.prisma.xpEvent.count({ where: { childId: child.childId, type: 'DAILY_LEARNING' } }),
      ).toBe(1);
    });

    it('kunning ikkinchi urinishi — amaliyot (DON yo\'q, boshqa savollar)', async () => {
      await setProfile();
      const daily = (await call(child.token, 'POST', '/learning/attempts', { subject: 'math' })).json();
      await answerAll(daily, 10);
      const dailyResult = (await call(child.token, 'POST', `/learning/attempts/${daily.id}/complete`)).json();
      expect(dailyResult.donEarned).toBe(donFor(10, 10));

      const practice = (await call(child.token, 'POST', '/learning/attempts', { subject: 'math' })).json();
      expect(practice.isDaily).toBe(false);
      expect(practice.id).not.toBe(daily.id);
      await answerAll(practice, 10);
      const result = (await call(child.token, 'POST', `/learning/attempts/${practice.id}/complete`)).json();
      expect(result.donEarned).toBe(0);
      const profile = await t.prisma.childProfile.findUniqueOrThrow({ where: { childId: child.childId } });
      expect(profile.donBalance).toBe(donFor(10, 10));
    });

    it('kechagi yarim qolgan urinish yangi boshlashda yopiladi', async () => {
      await setProfile();
      const yesterday = addDays(tashkentDay(), -1);
      const stale = await t.prisma.learningAttempt.create({
        data: { childId: child.childId, subject: 'MATH', day: yesterday, isDaily: true, questionIds: [], total: 10 },
      });
      const fresh = (await call(child.token, 'POST', '/learning/attempts', { subject: 'math' })).json();
      expect(fresh.id).not.toBe(stale.id);
      expect(fresh.isDaily).toBe(true);
      const closed = await t.prisma.learningAttempt.findUniqueOrThrow({ where: { id: stale.id } });
      expect(closed.status).toBe('ABANDONED');
      const res = await call(child.token, 'POST', `/learning/attempts/${stale.id}/complete`);
      expect(res.statusCode).toBe(409);
    });

    it('begona bolaning urinishi — 404; fan savolsiz — 404 NO_QUESTIONS', async () => {
      await setProfile();
      const attempt = (await call(child.token, 'POST', '/learning/attempts', { subject: 'math' })).json();
      const other = await createChild(t.prisma, parent, { name: 'Malika' });
      expect((await call(other.token, 'GET', `/learning/attempts/${attempt.id}`)).statusCode).toBe(404);

      await t.prisma.learningQuestion.updateMany({ where: { subject: 'NATIVE' }, data: { status: 'ARCHIVED' } });
      const none = await call(child.token, 'POST', '/learning/attempts', { subject: 'native' });
      expect(none.statusCode).toBe(404);
      expect(none.json().code).toBe('NO_QUESTIONS');
    });
  });

  describe('natijalar, tahlil, ota-ona', () => {
    async function finish(subject: string, correct: number) {
      const attempt = (await call(child.token, 'POST', '/learning/attempts', { subject })).json();
      await answerAll(attempt, correct);
      return (await call(child.token, 'POST', `/learning/attempts/${attempt.id}/complete`)).json();
    }

    it('natijalar yangisi birinchi, kursor bilan; tahlil to\'liq', async () => {
      await setProfile();
      const first = await finish('math', 9);
      const second = await finish('english', 5);

      const page1 = (await call(child.token, 'GET', '/learning/results?limit=1')).json();
      expect(page1.items.map((r: { id: string }) => r.id)).toEqual([second.id]);
      expect(page1.nextBefore).not.toBeNull();
      const page2 = (await call(child.token, 'GET', `/learning/results?limit=1&before=${encodeURIComponent(page1.nextBefore)}`)).json();
      expect(page2.items.map((r: { id: string }) => r.id)).toEqual([first.id]);
      expect(page2.items[0].topic).toHaveProperty('uz');

      const review = (await call(child.token, 'GET', `/learning/attempts/${first.id}/review`)).json();
      expect(review.result.correct).toBe(9);
      expect(review.items).toHaveLength(10);
      expect(review.items[0].question).toHaveProperty('correctIndex');
      expect(review.items.filter((i: { isCorrect: boolean }) => i.isCorrect)).toHaveLength(9);
    });

    it('ota-ona xulosasi va haftalik hisobot (bir marta, faqat ota-onaga)', async () => {
      await setProfile();
      await finish('math', 9);
      await finish('english', 5);

      const summary = (await call(parent.token, 'GET', `/children/${child.childId}/learning/summary?days=7`)).json();
      expect(summary).toMatchObject({
        testsCount: 2,
        correctAnswers: 14,
        overallPercent: 70,
        strongSubject: 'math',
        focusSubject: 'english',
        activeDays: 1,
        streakDays: 1,
        profile: { grade: 7 },
      });

      const insights = t.app.get(LearningInsightsService);
      expect(await insights.sendWeeklyReports()).toEqual({ sent: 1 });
      expect(await insights.sendWeeklyReports()).toEqual({ sent: 0 });

      const pushes = t.fcm.pushesTo(parent.userId);
      expect(pushes).toHaveLength(1);
      expect(pushes[0].title).toContain('Aziz');
      expect(pushes[0].body).toContain('70%');
      expect(pushes[0].body).toContain('Matematika');

      const parentFeed = (await call(parent.token, 'GET', `/children/${child.childId}/notifications`)).json();
      expect(parentFeed.notifications.map((n: { type: string }) => n.type)).toContain('LEARNING_REPORT');
      const childFeed = (await call(child.token, 'GET', `/children/${child.childId}/notifications`)).json();
      expect(childFeed.notifications.map((n: { type: string }) => n.type)).not.toContain('LEARNING_REPORT');
    });
  });
});
