/**
 * Mavzu "Savollar" paneli: so'rov parametrlari, "Mavzusiz" skaneri va tanlov.
 *
 *   npx tsx --test src/components/learning/topic-questions.test.ts
 */
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import type { LearningQuestionListParams } from '@/lib/api/admin.api';
import type { LearningQuestion, Paginated } from '@/types/api.types';
import {
  EMPTY_SELECTION,
  MAX_SCAN_PAGES,
  QUESTION_PAGE_SIZE,
  QUESTION_SCAN_LIMIT,
  countMoved,
  fetchQuestionsPage,
  flattenPages,
  isSelectable,
  overlapsGrades,
  toQuestionParams,
  toggleAllVisible,
  toggleSelected,
  type FetchQuestions,
  type QuestionsQuery,
  type Selection,
} from './topic-questions';

const TOPIC = 'topic-1';

const question = (id: string, topicId: string | null = null): LearningQuestion => ({
  id,
  externalId: `math-${id}`,
  subject: 'math',
  difficulty: 1,
  minGrade: 5,
  maxGrade: 6,
  topic: { uz: 'Kasrlar' },
  prompt: { uz: `Savol ${id}` },
  status: 'ACTIVE',
  topicId,
  answers: 0,
  correctRate: null,
});

const query = (patch: Partial<QuestionsQuery> = {}): QuestionsQuery => ({
  subject: 'math',
  topicId: TOPIC,
  scope: 'all',
  q: '',
  ...patch,
});

/** `pages[i]` — i+1-sahifa; so'rovlarni `calls`ga yozadi. */
function fakeFetch(pages: LearningQuestion[][]) {
  const calls: LearningQuestionListParams[] = [];
  const fetchPage: FetchQuestions = async (params) => {
    calls.push(params);
    const page = params.page ?? 1;
    const result: Paginated<LearningQuestion> = {
      items: pages[page - 1] ?? [],
      page,
      totalPages: pages.length,
      total: pages.flat().length,
    };
    return result;
  };
  return { fetchPage, calls };
}

const range = (from: number, count: number, topicId: string | null = null) =>
  Array.from({ length: count }, (_, i) => question(`q${from + i}`, topicId));

describe('toQuestionParams', () => {
  it('"Shu mavzudagi" rejimida topicId yuboriladi', () => {
    assert.deepEqual(toQuestionParams(query({ scope: 'linked' }), 2, 40), {
      page: 2,
      limit: 40,
      subject: 'math',
      topicId: TOPIC,
    });
  });

  it('"Barchasi" va "Mavzusiz" rejimlarida topicId yuborilmaydi', () => {
    for (const scope of ['all', 'unlinked'] as const) {
      assert.equal('topicId' in toQuestionParams(query({ scope }), 1, 40), false, scope);
    }
  });

  it('bo‘sh qidiruv yuborilmaydi, to‘ldirilgani yuboriladi', () => {
    assert.equal('q' in toQuestionParams(query(), 1, 40), false);
    assert.equal(toQuestionParams(query({ q: 'kasr' }), 1, 40).q, 'kasr');
  });
});

describe('fetchQuestionsPage — oddiy rejimlar', () => {
  it('bitta so‘rov qiladi va keyingi sahifani bildiradi', async () => {
    const { fetchPage, calls } = fakeFetch([range(1, 3), range(4, 3)]);
    const page = await fetchQuestionsPage(fetchPage, query({ scope: 'linked' }), 1);
    assert.equal(calls.length, 1);
    assert.equal(calls[0]?.limit, QUESTION_PAGE_SIZE);
    assert.equal(page.items.length, 3);
    assert.equal(page.nextPage, 2);
    assert.equal(page.total, 6);
  });

  it('oxirgi sahifada nextPage null', async () => {
    const { fetchPage } = fakeFetch([range(1, 3), range(4, 3)]);
    const page = await fetchQuestionsPage(fetchPage, query(), 2);
    assert.equal(page.nextPage, null);
  });
});

describe('fetchQuestionsPage — "Mavzusiz" skaneri', () => {
  it('mavzusi borlarni chiqarib tashlaydi', async () => {
    const mixed = [question('a'), question('b', 'other'), question('c', TOPIC), question('d')];
    const { fetchPage } = fakeFetch([mixed]);
    const page = await fetchQuestionsPage(fetchPage, query({ scope: 'unlinked' }), 1);
    assert.deepEqual(page.items.map((q) => q.id), ['a', 'd']);
    assert.equal(page.nextPage, null);
    assert.equal(page.total, null);
  });

  it('yetarli savol yig‘ilmaguncha keyingi sahifalarni o‘qiydi', async () => {
    // 1-sahifa: deyarli hammasi biriktirilgan, 2- va 3-sahifada mavzusizlar.
    const { fetchPage, calls } = fakeFetch([
      range(1, 5).concat(range(100, 95, 'other')),
      range(200, 30),
      range(300, 30),
      range(400, 30),
    ]);
    const page = await fetchQuestionsPage(fetchPage, query({ scope: 'unlinked' }), 1);
    assert.ok(page.items.length >= QUESTION_PAGE_SIZE);
    assert.equal(calls.length, 3);
    assert.ok(calls.every((c) => c.limit === QUESTION_SCAN_LIMIT));
    assert.equal(page.nextPage, 4);
  });

  it('keyingi yuklash qolgan joydan davom etadi', async () => {
    const { fetchPage, calls } = fakeFetch([range(1, 50), range(100, 50), range(200, 50)]);
    const first = await fetchQuestionsPage(fetchPage, query({ scope: 'unlinked' }), 1);
    assert.equal(first.nextPage, 2);
    const second = await fetchQuestionsPage(fetchPage, query({ scope: 'unlinked' }), first.nextPage ?? 0);
    assert.equal(calls[1]?.page, 2);
    assert.ok(second.items.every((q) => !first.items.some((f) => f.id === q.id)));
  });

  it('bir yuklashda MAX_SCAN_PAGES dan ko‘p sahifa o‘qimaydi', async () => {
    const allLinked = Array.from({ length: MAX_SCAN_PAGES + 5 }, (_, i) =>
      range(i * 1000, 5, 'other'),
    );
    const { fetchPage, calls } = fakeFetch(allLinked);
    const page = await fetchQuestionsPage(fetchPage, query({ scope: 'unlinked' }), 1);
    assert.equal(calls.length, MAX_SCAN_PAGES);
    assert.equal(page.items.length, 0);
    assert.equal(page.nextPage, MAX_SCAN_PAGES + 1);
  });

  it('bo‘sh ro‘yxatda to‘xtaydi', async () => {
    const { fetchPage, calls } = fakeFetch([[]]);
    const page = await fetchQuestionsPage(fetchPage, query({ scope: 'unlinked' }), 1);
    assert.equal(calls.length, 1);
    assert.deepEqual(page, { items: [], nextPage: null, total: null });
  });
});

describe('flattenPages', () => {
  it('sahifalarni birlashtiradi va takroriy id’larni olib tashlaydi', () => {
    const pages = [
      { items: [question('a'), question('b')], nextPage: 2, total: 3 },
      { items: [question('b'), question('c')], nextPage: null, total: 3 },
    ];
    assert.deepEqual(flattenPages(pages).map((q) => q.id), ['a', 'b', 'c']);
  });
});

describe('tanlov', () => {
  const a = question('a');
  const b = question('b', 'other');
  const c = question('c', TOPIC);
  const list = [a, b, c];

  it('shu mavzudagi savol qayta tanlanmaydi', () => {
    assert.equal(isSelectable(c, TOPIC), false);
    assert.equal(isSelectable(a, TOPIC), true);
    assert.equal(isSelectable(b, TOPIC), true);
  });

  it('toggleSelected o‘zgarmas: qo‘shadi va olib tashlaydi', () => {
    const one = toggleSelected(EMPTY_SELECTION, a);
    assert.deepEqual([...one.keys()], ['a']);
    assert.equal(EMPTY_SELECTION.size, 0);
    assert.deepEqual([...toggleSelected(one, a).keys()], []);
  });

  it('toggleAllVisible faqat tanlanadiganlarni belgilaydi', () => {
    const all = toggleAllVisible(EMPTY_SELECTION, list, TOPIC);
    assert.deepEqual([...all.keys()].sort(), ['a', 'b']);
  });

  it('toggleAllVisible hammasi tanlangan bo‘lsa ularni bekor qiladi, ko‘rinmaydigan tanlovga tegmaydi', () => {
    const elsewhere = question('elsewhere');
    const selected: Selection = new Map([a, b, elsewhere].map((q) => [q.id, q]));
    const result = toggleAllVisible(selected, list, TOPIC);
    assert.deepEqual([...result.keys()], ['elsewhere']);
    assert.equal(selected.size, 3);
  });

  it('toggleAllVisible tanlanadigan savol bo‘lmasa o‘zgarmaydi', () => {
    const selected: Selection = new Map([[a.id, a]]);
    assert.deepEqual([...toggleAllVisible(selected, [c], TOPIC).keys()], ['a']);
  });

  it('countMoved boshqa mavzudan ko‘chiriladiganlarni sanaydi (ko‘rinmayotganlarni ham)', () => {
    assert.equal(countMoved(new Map([[a.id, a], [b.id, b]]), TOPIC), 1);
    assert.equal(countMoved(new Map([[a.id, a]]), TOPIC), 0);
    assert.equal(countMoved(EMPTY_SELECTION, TOPIC), 0);
  });
});

describe('overlapsGrades', () => {
  const topic = { minGrade: 5, maxGrade: 7 };

  it('sinflar kesishsa true (chegarada ham)', () => {
    assert.equal(overlapsGrades({ minGrade: 6, maxGrade: 6 }, topic), true);
    assert.equal(overlapsGrades({ minGrade: 1, maxGrade: 5 }, topic), true);
    assert.equal(overlapsGrades({ minGrade: 7, maxGrade: 11 }, topic), true);
    assert.equal(overlapsGrades({ minGrade: 1, maxGrade: 11 }, topic), true);
  });

  it('kesishmasa false', () => {
    assert.equal(overlapsGrades({ minGrade: 1, maxGrade: 4 }, topic), false);
    assert.equal(overlapsGrades({ minGrade: 8, maxGrade: 11 }, topic), false);
  });
});
