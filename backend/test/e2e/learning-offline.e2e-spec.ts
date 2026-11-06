// U10 · Oflayn to'plam: imzolangan haftalik to'plam, oflayn urinishni serverda
// baholash, DON bir marta, qayta yuborish — o'sha natija, soxta to'plam rad.

import { randomUUID } from 'node:crypto';
import { tashkentDay } from '../../src/common/time/tashkent';
import { createChild, createParent, TestChild } from './factories';
import { resetDb } from './db';
import { seedQuestionBank } from './learning-fixtures';
import { createTestApp, TestApp } from './test-app';

interface PackSet {
  subject: string;
  signature: string;
  questions: Array<{ id: string; correctIndex: number }>;
}

describe('Learning: oflayn to\'plam (U10)', () => {
  let t: TestApp;
  let child: TestChild;

  const call = (token: string, method: 'GET' | 'POST' | 'PUT', url: string, payload?: object) =>
    t.app.inject({
      method,
      url: `/api${url}`,
      headers: { authorization: `Bearer ${token}` },
      ...(payload && { payload }),
    });

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    await seedQuestionBank(t.prisma);
    const parent = await createParent(t.prisma, { language: 'uz' });
    child = await createChild(t.prisma, parent, { name: 'Aziz' });
    await call(child.token, 'PUT', '/learning/profile', { grade: 7, subjects: ['math', 'english'] });
  });

  afterAll(() => t.close());

  async function pack() {
    const res = await call(child.token, 'GET', '/learning/offline-pack');
    expect(res.statusCode).toBe(200);
    return res.json() as { packId: string; expiresAt: string; sets: PackSet[] };
  }

  function upload(
    p: { packId: string; expiresAt: string },
    set: PackSet,
    opts: { correct?: number; id?: string; signature?: string } = {},
  ) {
    const correct = opts.correct ?? set.questions.length;
    return call(child.token, 'POST', '/learning/offline-attempts', {
      clientAttemptId: opts.id ?? randomUUID(),
      packId: p.packId,
      expiresAt: p.expiresAt,
      signature: opts.signature ?? set.signature,
      subject: set.subject,
      questionIds: set.questions.map((q) => q.id),
      answers: set.questions.map((q, i) => ({
        questionId: q.id,
        selectedIndex: i < correct ? q.correctIndex : (q.correctIndex + 1) % 4,
      })),
      completedAt: new Date().toISOString(),
    });
  }

  it('to\'plam: profil fanlari, imzo, 7 kun', async () => {
    const p = await pack();
    expect(p.sets.map((s) => s.subject).sort()).toEqual(['english', 'math']);
    expect(p.sets[0].signature).toMatch(/^[0-9a-f]{64}$/);
    expect(p.sets[0].questions.length).toBeGreaterThan(0);
    const days = (new Date(p.expiresAt).getTime() - Date.now()) / 86_400_000;
    expect(days).toBeGreaterThan(6.9);
    expect(days).toBeLessThanOrEqual(7);
  });

  it('yuborish: serverda baholanadi, DON bir marta; takror — o\'sha natija', async () => {
    const p = await pack();
    const set = p.sets.find((s) => s.subject === 'math')!;
    const id = randomUUID();
    const first = await upload(p, set, { id, correct: 7 });
    expect(first.statusCode).toBe(200);
    const result = first.json();
    expect(result.correct).toBe(Math.min(7, set.questions.length));
    expect(result.donEarned).toBeGreaterThan(0);

    const again = await upload(p, set, { id, correct: 0 });
    expect(again.statusCode).toBe(200);
    expect(again.json().correct).toBe(result.correct);

    const attempts = await t.prisma.learningAttempt.findMany({ where: { childId: child.childId } });
    expect(attempts).toHaveLength(1);
    expect(attempts[0]).toMatchObject({ id, status: 'COMPLETED', day: tashkentDay(new Date()) });

    // Shu kunning ikkinchi urinishi — mashq, DON yo'q.
    const second = await upload(p, set);
    expect(second.json().donEarned).toBe(0);
  });

  it('soxta imzo, boshqa savollar va kelajakdagi vaqt rad etiladi', async () => {
    const p = await pack();
    const [set] = p.sets;
    const forged = await upload(p, set, { signature: 'f'.repeat(64) });
    expect(forged.statusCode).toBe(403);
    expect(forged.json().code).toBe('PACK_SIGNATURE_INVALID');

    const other = await t.prisma.learningQuestion.findFirstOrThrow({
      where: { id: { notIn: set.questions.map((q) => q.id) } },
    });
    const swapped = { ...set, questions: [{ id: other.id, correctIndex: other.answerIndex }, ...set.questions.slice(1)] };
    expect((await upload(p, swapped)).statusCode).toBe(403);

    const future = await call(child.token, 'POST', '/learning/offline-attempts', {
      clientAttemptId: randomUUID(),
      packId: p.packId,
      expiresAt: p.expiresAt,
      signature: set.signature,
      subject: set.subject,
      questionIds: set.questions.map((q) => q.id),
      answers: set.questions.map((q) => ({ questionId: q.id, selectedIndex: q.correctIndex })),
      completedAt: new Date(Date.now() + 3_600_000).toISOString(),
    });
    expect(future.statusCode).toBe(400);
  });

  it('boshqa bolaning to\'plami bilan yuborib bo\'lmaydi', async () => {
    const p = await pack();
    const [set] = p.sets;
    const parent = await createParent(t.prisma, { language: 'uz' });
    const stranger = await createChild(t.prisma, parent, { name: 'Bobur' });
    await call(stranger.token, 'PUT', '/learning/profile', { grade: 7, subjects: ['math', 'english'] });
    const res = await call(stranger.token, 'POST', '/learning/offline-attempts', {
      clientAttemptId: randomUUID(),
      packId: p.packId,
      expiresAt: p.expiresAt,
      signature: set.signature,
      subject: set.subject,
      questionIds: set.questions.map((q) => q.id),
      answers: set.questions.map((q) => ({ questionId: q.id, selectedIndex: q.correctIndex })),
      completedAt: new Date().toISOString(),
    });
    expect(res.statusCode).toBe(403);
  });
});
