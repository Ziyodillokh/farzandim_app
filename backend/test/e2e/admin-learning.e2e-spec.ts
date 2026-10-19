// Admin — Daily Learning savollar banki: ruxsat, CRUD, import, statistika.

import { createChild, createModerator, createParent, TestModerator } from './factories';
import { resetDb } from './db';
import { seedQuestionBank } from './learning-fixtures';
import { createTestApp, TestApp } from './test-app';

const question = (patch: object = {}) => ({
  subject: 'math',
  externalId: 'math-900',
  difficulty: 2,
  minGrade: 5,
  maxGrade: 9,
  topic: { uz: 'Foizlar', ru: 'Проценты', en: 'Percent' },
  prompt: { uz: '200 ning 10% i?', ru: '10% от 200?', en: '10% of 200?' },
  options: ['10', '20', '30', '40'].map((v) => ({ uz: v, ru: v, en: v })),
  answerIndex: 1,
  explanation: { uz: '200 × 0,1 = 20', ru: '200 × 0,1 = 20', en: '200 × 0.1 = 20' },
  ...patch,
});

describe('Admin learning API', () => {
  let t: TestApp;
  let admin: TestModerator;

  const call = (method: 'GET' | 'POST' | 'PATCH' | 'DELETE', url: string, payload?: object, token = admin.token) =>
    t.app.inject({
      method,
      url: `/api/admin/learning${url}`,
      headers: { authorization: `Bearer ${token}` },
      ...(payload && { payload }),
    });

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    await seedQuestionBank(t.prisma);
    admin = await createModerator(t.prisma, ['manage_learning']);
  });

  afterAll(() => t.close());

  it('ruxsatsiz moderator — 403, ro\'yxat filtr bilan', async () => {
    const other = await createModerator(t.prisma, ['view_users']);
    expect((await call('GET', '/questions', undefined, other.token)).statusCode).toBe(403);

    const res = (await call('GET', '/questions?subject=physics&difficulty=3&limit=50')).json();
    expect(res.pagination.total).toBe(5);
    expect(res.items.every((q: { subject: string; difficulty: number }) => q.subject === 'physics' && q.difficulty === 3)).toBe(true);
    const primary = (await call('GET', '/questions?subject=math&grade=2')).json();
    expect(primary.pagination.total).toBe(6);
  });

  it('qo\'shish, validatsiya va takroriy externalId', async () => {
    const created = await call('POST', '/questions', question());
    expect(created.statusCode).toBe(201);
    expect(created.json()).toMatchObject({ subject: 'math', externalId: 'math-900', status: 'ACTIVE', answers: 0 });

    expect((await call('POST', '/questions', question({ externalId: 'math-901', answerIndex: 7 }))).statusCode).toBe(400);
    expect((await call('POST', '/questions', question({ externalId: 'math-902', topic: { uz: 'x' } }))).statusCode).toBe(400);
    expect((await call('POST', '/questions', question())).statusCode).toBe(409);
  });

  it('javob berilgan savol: matn tuzatiladi, to\'g\'ri javob o\'zgarmaydi; o\'chirish = arxiv', async () => {
    const id = (await call('POST', '/questions', question())).json().id;
    const parent = await createParent(t.prisma);
    const child = await createChild(t.prisma, parent);
    const attempt = await t.prisma.learningAttempt.create({
      data: { childId: child.childId, subject: 'MATH', day: '2026-10-19', isDaily: true, questionIds: [id], total: 1 },
    });
    await t.prisma.learningAnswer.create({
      data: { attemptId: attempt.id, questionId: id, position: 0, selectedIndex: 1, isCorrect: true },
    });

    const typo = await call('PATCH', `/questions/${id}`, {
      prompt: { uz: '200 sonining 10% i?', ru: '10% от 200?', en: '10% of 200?' },
    });
    expect(typo.statusCode).toBe(200);
    expect(typo.json().prompt.uz).toBe('200 sonining 10% i?');

    const answer = await call('PATCH', `/questions/${id}`, { answerIndex: 2 });
    expect(answer.statusCode).toBe(409);
    expect(answer.json().code).toBe('QUESTION_IN_USE');

    expect((await call('DELETE', `/questions/${id}`)).json()).toEqual({ archived: true });
    const unused = (await call('POST', '/questions', question({ externalId: 'math-903' }))).json().id;
    expect((await call('DELETE', `/questions/${unused}`)).json()).toEqual({ deleted: true });
  });

  it('import: yangilari qo\'shiladi, mavjudlari o\'tkaziladi yoki yangilanadi, xatolar hisobotda', async () => {
    const bank = (id: string, answer = 0) => ({
      id,
      difficulty: 1,
      grades: [5, 9],
      topic: 'Tarix',
      question: `${id}?`,
      options: ['a', 'b', 'c', 'd'],
      answer,
      explanation: 'izoh',
    });
    const first = (await call('POST', '/questions/import', {
      subject: 'history',
      questions: [bank('history-90'), bank('history-01'), { id: 'history-91', difficulty: 9 }],
    })).json();
    expect(first).toMatchObject({ created: 1, skipped: 1, updated: 0 });
    expect(first.errors).toEqual([expect.objectContaining({ index: 2, id: 'history-91' })]);

    const second = (await call('POST', '/questions/import', {
      subject: 'history',
      questions: [bank('history-90', 2)],
      existing: 'update',
    })).json();
    expect(second).toMatchObject({ updated: 1, errors: [] });
    const stored = await t.prisma.learningQuestion.findUniqueOrThrow({ where: { externalId: 'history-90' } });
    expect(stored.answerIndex).toBe(2);
  });

  it('statistika', async () => {
    const stats = (await call('GET', '/stats')).json();
    const math = stats.subjects.find((s: { subject: string }) => s.subject === 'math');
    expect(math).toMatchObject({ active: 21, draft: 0, archived: 0 });
    expect(math.byDifficulty['3']).toBe(5);
    expect(stats.hardest).toEqual([]);
  });
});
