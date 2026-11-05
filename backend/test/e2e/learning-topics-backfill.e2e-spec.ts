// scripts/learning/backfill-topics.ts — dry-run, apply, idempotentlik.

import { formatReport, parseArgs, runBackfill } from '../../scripts/learning/backfill-topics';
import { isValidTopicKey } from '../../src/modules/learning/domain/topic-input';
import { MIN_TOPIC_QUESTIONS } from '../../src/modules/learning/domain/topic-mastery';
import { resetDb } from './db';
import { seedQuestionBank } from './learning-fixtures';
import { createQuestions, createTopic } from './learning-topics-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('Learning topics backfill script', () => {
  let t: TestApp;

  const snapshot = async () => ({
    topics: await t.prisma.learningTopic.findMany({ orderBy: [{ subject: 'asc' }, { key: 'asc' }] }),
    links: await t.prisma.learningQuestion.findMany({ select: { id: true, topicId: true }, orderBy: { id: 'asc' } }),
  });

  /** Bank savollaridan mustaqil hisob: fan bo'yicha noyob normallashtirilgan topic.uz. */
  async function distinctTopics() {
    const questions = await t.prisma.learningQuestion.findMany({ select: { subject: true, topic: true } });
    return new Set(
      questions.map((q) => `${q.subject}:${(q.topic as { uz: string }).uz.trim().replace(/\s+/g, ' ').toLowerCase()}`),
    );
  }

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
  });

  afterAll(() => t.close());

  it('parseArgs: faqat --apply; noma\'lum parametr — xato', () => {
    expect(parseArgs([])).toEqual({ apply: false });
    expect(parseArgs(['--apply'])).toEqual({ apply: true });
    expect(() => parseArgs(['--aply'])).toThrow(/Noma'lum parametr/);
    expect(() => parseArgs(['--dry-run'])).toThrow(/Noma'lum parametr/);
  });

  it('DRY-RUN (standart): hisobot to\'g\'ri, bazaga hech narsa yozilmaydi', async () => {
    const total = await seedQuestionBank(t.prisma);
    const before = await snapshot();

    const report = await runBackfill(t.prisma, { apply: false });

    expect(await snapshot()).toEqual(before);
    expect(report).toMatchObject({
      apply: false,
      topicsCreated: (await distinctTopics()).size,
      topicsReused: 0,
      questionsLinked: total,
      skipped: [],
    });
    // Bankda har mavzuga ~1 savol: deyarli hammasi "kam savolli".
    expect(report.underfilled.length).toBe(report.topicsCreated);
    const text = formatReport(report);
    expect(text).toContain('DRY-RUN');
    expect(text).toContain('--apply');
    expect(text).toContain(`Savollar bog'lanadi: ${total}`);
  });

  it('--apply: mavzular yaratiladi, savollar bog\'lanadi; eski topic ustuni o\'zgarmaydi', async () => {
    const total = await seedQuestionBank(t.prisma);
    const oldTopics = new Map((await t.prisma.learningQuestion.findMany()).map((q) => [q.id, q.topic]));

    const report = await runBackfill(t.prisma, { apply: true });

    expect(report).toMatchObject({ apply: true, topicsCreated: (await distinctTopics()).size, questionsLinked: total });
    const topics = await t.prisma.learningTopic.findMany();
    expect(topics).toHaveLength(report.topicsCreated);
    expect(await t.prisma.learningQuestion.count({ where: { topicId: null } })).toBe(0);

    for (const topic of topics) {
      expect(isValidTopicKey(topic.key)).toBe(true);
      expect(topic.status).toBe('ACTIVE');
      expect(topic.createdBy).toBeNull();
      const linked = await t.prisma.learningQuestion.findMany({ where: { topicId: topic.id } });
      expect(linked.length).toBeGreaterThan(0);
      expect(linked.every((q) => q.subject === topic.subject)).toBe(true);
      expect(topic.minGrade).toBe(Math.min(...linked.map((q) => q.minGrade)));
      expect(topic.maxGrade).toBe(Math.max(...linked.map((q) => q.maxGrade)));
      expect(linked.some((q) => JSON.stringify(q.topic) === JSON.stringify(topic.title))).toBe(true);
    }
    for (const q of await t.prisma.learningQuestion.findMany()) {
      expect(q.topic).toEqual(oldTopics.get(q.id));
    }
  });

  it('--apply: pozitsiya fan ichida 0..n-1, (minGrade, title.uz) tartibida; kalit fan ichida noyob', async () => {
    await seedQuestionBank(t.prisma);
    await runBackfill(t.prisma, { apply: true });
    const topics = await t.prisma.learningTopic.findMany({ where: { subject: 'MATH' }, orderBy: { position: 'asc' } });
    expect(topics.map((x) => x.position)).toEqual(topics.map((_, i) => i));
    const order = topics.map((x) => [x.minGrade, (x.title as { uz: string }).uz] as const);
    const expected = [...order].sort((a, b) => a[0] - b[0] || (a[1] < b[1] ? -1 : a[1] > b[1] ? 1 : 0));
    expect(order).toEqual(expected);
    expect(new Set(topics.map((x) => x.key)).size).toBe(topics.length);
  });

  it('qayta ishga tushirish (idempotent): hech narsa yaratilmaydi / bog\'lanmaydi, baza o\'zgarmaydi', async () => {
    await seedQuestionBank(t.prisma);
    await runBackfill(t.prisma, { apply: true });
    const after = await snapshot();

    const again = await runBackfill(t.prisma, { apply: true });
    expect(again).toMatchObject({ topicsCreated: 0, topicsReused: 0, questionsLinked: 0 });
    expect(await snapshot()).toEqual(after);
    const dry = await runBackfill(t.prisma, { apply: false });
    expect(dry).toMatchObject({ topicsCreated: 0, questionsLinked: 0 });
  });

  it('keyingi ishga tushirish: yangi savol mavjud mavzuni qayta ishlatadi, yangi nom yangi mavzu oladi', async () => {
    const [seed] = await createQuestions(t.prisma, 1, null);
    await t.prisma.learningQuestion.update({ where: { id: seed.id }, data: { topic: { uz: 'Kasrlar', ru: 'Дроби', en: 'Fractions' } } });
    await runBackfill(t.prisma, { apply: true });
    const first = await t.prisma.learningTopic.findFirstOrThrow({ where: { key: 'kasrlar' } });

    const [reused, fresh] = await createQuestions(t.prisma, 2, null);
    await t.prisma.learningQuestion.update({ where: { id: reused.id }, data: { topic: { uz: '  KASRLAR ', ru: 'Дроби', en: 'Fractions' } } });
    await t.prisma.learningQuestion.update({ where: { id: fresh.id }, data: { topic: { uz: 'Foizlar', ru: 'Проценты', en: 'Percent' } } });

    const report = await runBackfill(t.prisma, { apply: true });
    expect(report).toMatchObject({ topicsCreated: 1, topicsReused: 1, questionsLinked: 2 });
    expect((await t.prisma.learningQuestion.findUniqueOrThrow({ where: { id: reused.id } })).topicId).toBe(first.id);
    const percent = await t.prisma.learningTopic.findFirstOrThrow({ where: { key: 'foizlar' } });
    expect(percent.position).toBe(first.position + 1);
    // Mavjud mavzu o'zgartirilmagan.
    expect(await t.prisma.learningTopic.findUniqueOrThrow({ where: { id: first.id } })).toMatchObject({
      title: first.title,
      minGrade: first.minGrade,
      maxGrade: first.maxGrade,
      position: first.position,
    });
  });

  it('kalit to\'qnashuvi: bir xil slug beradigan turli nomlar -2 oladi; admin yaratgan mavzu kaliti band', async () => {
    await createTopic(t.prisma, { key: 'kasrlar', title: { uz: 'Oddiy kasrlar' }, position: 3 });
    const qs = await createQuestions(t.prisma, 3, null);
    const names = ['Kasrlar', 'Kasrlar!', 'KASRLAR?'];
    for (const [i, q] of qs.entries()) {
      await t.prisma.learningQuestion.update({ where: { id: q.id }, data: { topic: { uz: names[i], ru: names[i], en: names[i] } } });
    }
    await runBackfill(t.prisma, { apply: true });
    const keys = (await t.prisma.learningTopic.findMany({ orderBy: { key: 'asc' } })).map((x) => x.key);
    expect(keys).toEqual(['kasrlar', 'kasrlar-2', 'kasrlar-3', 'kasrlar-4']);
  });

  it('kam savolli mavzular hisobotda: >= MIN_TOPIC_QUESTIONS faol savol bo\'lsa kiritilmaydi', async () => {
    const big = await createQuestions(t.prisma, MIN_TOPIC_QUESTIONS, null);
    const exactlyShort = await createQuestions(t.prisma, MIN_TOPIC_QUESTIONS - 1, null);
    const archived = await createQuestions(t.prisma, 3, null, { status: 'ARCHIVED' });
    const set = async (list: typeof big, uz: string) => {
      for (const q of list) {
        await t.prisma.learningQuestion.update({ where: { id: q.id }, data: { topic: { uz, ru: uz, en: uz } } });
      }
    };
    await set(big, 'Katta');
    await set(exactlyShort, 'Yetmaydi');
    await set(archived, 'Arxiv');

    const report = await runBackfill(t.prisma, { apply: false });
    expect(report.underfilled).toEqual([
      { subject: 'math', key: 'arxiv', activeQuestions: 0 },
      { subject: 'math', key: 'yetmaydi', activeQuestions: MIN_TOPIC_QUESTIONS - 1 },
    ]);
    expect(report.topicsCreated).toBe(3);
  });

  it('yaroqsiz topic JSON o\'tkazib yuboriladi va hisobotga tushadi', async () => {
    const [good, bad] = await createQuestions(t.prisma, 2, null);
    await t.prisma.learningQuestion.update({ where: { id: bad.id }, data: { topic: { ru: 'Дроби' } } });
    const report = await runBackfill(t.prisma, { apply: true });
    expect(report).toMatchObject({ topicsCreated: 1, questionsLinked: 1 });
    expect(report.skipped.map((s) => s.questionId)).toEqual([bad.id]);
    expect((await t.prisma.learningQuestion.findUniqueOrThrow({ where: { id: bad.id } })).topicId).toBeNull();
    expect((await t.prisma.learningQuestion.findUniqueOrThrow({ where: { id: good.id } })).topicId).not.toBeNull();
  });
});
