// Kod ko'rigi topilmalari bo'yicha regressiya testlari (B0/G1).

import { tashkentDay } from '../../src/common/time/tashkent';
import { LearningInsightsService } from '../../src/modules/learning/learning-insights.service';
import { createChild, createModerator, createParent, TestChild, TestParent } from './factories';
import { resetDb } from './db';
import { seedQuestionBank } from './learning-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('Review fixes', () => {
  let t: TestApp;
  let parent: TestParent;
  let child: TestChild;

  const call = (token: string, method: 'GET' | 'POST' | 'PUT' | 'DELETE', url: string, payload?: object) =>
    t.app.inject({ method, url: `/api${url}`, headers: { authorization: `Bearer ${token}` }, ...(payload && { payload }) });

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    await seedQuestionBank(t.prisma);
    parent = await createParent(t.prisma);
    child = await createChild(t.prisma, parent);
  });

  afterAll(() => t.close());

  it('qadam sync: parallel so\'rovlar DON\'ni ikki marta bermaydi', async () => {
    const entries = [{ date: tashkentDay(), steps: 2000 }];
    const results = await Promise.all(
      Array.from({ length: 5 }, () => call(child.token, 'POST', `/children/${child.childId}/steps`, { entries })),
    );
    expect(results.every((r) => r.statusCode < 300)).toBe(true);
    const profile = await t.prisma.childProfile.findUniqueOrThrow({ where: { childId: child.childId } });
    expect(profile.donBalance).toBe(10);
    expect(await t.prisma.xpEvent.count({ where: { childId: child.childId } })).toBe(1);
  });

  it('ota-onaning 0/0 XP yozuvi 500 bermaydi', async () => {
    const res = await call(parent.token, 'POST', `/children/${child.childId}/xp-events`, {
      type: 'OTHER',
      xpDelta: 0,
    });
    expect(res.statusCode).toBe(201);
    expect(res.json().event.id).toEqual(expect.any(String));
  });

  it('profilda yo\'q fan — amaliyot (DON yo\'q)', async () => {
    await call(child.token, 'PUT', '/learning/profile', { grade: 8, subjects: ['math'] });
    const attempt = (await call(child.token, 'POST', '/learning/attempts', { subject: 'physics' })).json();
    expect(attempt.isDaily).toBe(false);
  });

  it('ochiq urinishdagi savol o\'chirilmaydi — arxivlanadi', async () => {
    await call(child.token, 'PUT', '/learning/profile', { grade: 7, subjects: ['math'] });
    const attempt = (await call(child.token, 'POST', '/learning/attempts', { subject: 'math' })).json();
    const admin = await createModerator(t.prisma, ['manage_learning']);
    const res = await call(admin.token, 'DELETE', `/admin/learning/questions/${attempt.questions[0].id}`);
    expect(res.json()).toEqual({ archived: true });
    const view = (await call(child.token, 'GET', `/learning/attempts/${attempt.id}`)).json();
    expect(view.questions).toHaveLength(attempt.questions.length);
  });

  it('bola ota-onaga tegishli bildirishnomani o\'qilgan / o\'chirilgan qila olmaydi', async () => {
    await call(child.token, 'PUT', '/learning/profile', { grade: 7, subjects: ['math'] });
    const attempt = (await call(child.token, 'POST', '/learning/attempts', { subject: 'math' })).json();
    for (const q of attempt.questions) {
      await call(child.token, 'POST', `/learning/attempts/${attempt.id}/answers`, { questionId: q.id, selectedIndex: 0 });
    }
    await call(child.token, 'POST', `/learning/attempts/${attempt.id}/complete`);
    await t.app.get(LearningInsightsService).sendWeeklyReports();
    const report = await t.prisma.notification.findFirstOrThrow({ where: { type: 'LEARNING_REPORT' } });

    const readAll = await call(child.token, 'PUT', `/children/${child.childId}/notifications/read-all`);
    expect(readAll.json().updated).toBe(0);
    expect((await call(child.token, 'DELETE', `/notifications/${report.id}`)).statusCode).toBe(404);
    expect((await t.prisma.notification.findUniqueOrThrow({ where: { id: report.id } })).isRead).toBe(false);
  });

  it('natijalar kursori: yaroqsiz sana — 400 (500 emas)', async () => {
    const res = await call(child.token, 'GET', '/learning/results?before=2026-W42-1');
    expect(res.statusCode).toBe(400);
  });
});
