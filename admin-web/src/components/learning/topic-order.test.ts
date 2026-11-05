/**
 * Mavzular tartibi: ko'chirish, optimistik yangilash va xatoda tiklash.
 *
 *   npx tsx --test src/components/learning/topic-order.test.ts
 */
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import type { LearningTopic } from '@/types/api.types';
import {
  applyOrder,
  isUnderfilled,
  moveId,
  restorePositions,
  setStatusInList,
  sortTopics,
  summarizeBySubject,
  topicsOfSubject,
} from './topic-order';

const topic = (id: string, patch: Partial<LearningTopic> = {}): LearningTopic => ({
  id,
  subject: 'math',
  key: `key-${id}`,
  title: { uz: `Mavzu ${id}` },
  goal: null,
  minGrade: 1,
  maxGrade: 11,
  position: 1,
  status: 'ACTIVE',
  questionCount: 10,
  createdAt: '2026-11-01T10:00:00.000Z',
  updatedAt: '2026-11-01T10:00:00.000Z',
  ...patch,
});

const mathTopics = [
  topic('a', { position: 1 }),
  topic('b', { position: 2 }),
  topic('c', { position: 3 }),
];
const ids = (list: LearningTopic[]) => list.map((t) => t.id);

describe('sortTopics / topicsOfSubject', () => {
  it('position boʻyicha tartiblaydi va kirishni oʻzgartirmaydi', () => {
    const input = [topic('b', { position: 2 }), topic('a', { position: 1 })];
    assert.deepEqual(ids(sortTopics(input)), ['a', 'b']);
    assert.deepEqual(ids(input), ['b', 'a']);
  });

  it('position teng boʻlsa yaratilgan vaqt, keyin id boʻyicha barqaror', () => {
    const list = [
      topic('z', { position: 0, createdAt: '2026-11-02T00:00:00.000Z' }),
      topic('y', { position: 0, createdAt: '2026-11-01T00:00:00.000Z' }),
      topic('x', { position: 0, createdAt: '2026-11-01T00:00:00.000Z' }),
    ];
    assert.deepEqual(ids(sortTopics(list)), ['x', 'y', 'z']);
  });

  it('faqat tanlangan fan mavzularini qaytaradi', () => {
    const list = [...mathTopics, topic('e1', { subject: 'native', position: 1 })];
    assert.deepEqual(ids(topicsOfSubject(list, 'math')), ['a', 'b', 'c']);
    assert.deepEqual(ids(topicsOfSubject(list, 'native')), ['e1']);
    assert.deepEqual(topicsOfSubject(list, 'physics'), []);
  });
});

describe('moveId', () => {
  const order = ['a', 'b', 'c'];

  it('bir oʻrin yuqoriga va pastga suradi', () => {
    assert.deepEqual(moveId(order, 'b', -1), ['b', 'a', 'c']);
    assert.deepEqual(moveId(order, 'b', 1), ['a', 'c', 'b']);
  });

  it('chekkadan tashqariga chiqarmaydi (null)', () => {
    assert.equal(moveId(order, 'a', -1), null);
    assert.equal(moveId(order, 'c', 1), null);
  });

  it('nomaʼlum id uchun null', () => {
    assert.equal(moveId(order, 'zzz', 1), null);
  });

  it('kirish massivini oʻzgartirmaydi', () => {
    moveId(order, 'b', 1);
    assert.deepEqual(order, ['a', 'b', 'c']);
  });

  it('bitta elementli roʻyxatda ko‘chirib boʻlmaydi', () => {
    assert.equal(moveId(['a'], 'a', 1), null);
    assert.equal(moveId(['a'], 'a', -1), null);
  });
});

describe('applyOrder', () => {
  it('fan mavzularini yangi tartibga keltiradi', () => {
    const result = applyOrder(mathTopics, 'math', ['c', 'a', 'b']);
    assert.deepEqual(ids(topicsOfSubject(result, 'math')), ['c', 'a', 'b']);
  });

  it('positionlarni fandagi eng kichik position dan boshlab beradi (0-asosli ham)', () => {
    const zeroBased = [topic('a', { position: 0 }), topic('b', { position: 1 })];
    const result = applyOrder(zeroBased, 'math', ['b', 'a']);
    assert.deepEqual(
      result.map((t) => [t.id, t.position]),
      [['a', 1], ['b', 0]],
    );
  });

  it('barcha positionlar teng boʻlsa ham tartib oʻzgaradi', () => {
    const flat = [topic('a', { position: 0 }), topic('b', { position: 0 })];
    const result = applyOrder(flat, 'math', ['b', 'a']);
    assert.deepEqual(ids(topicsOfSubject(result, 'math')), ['b', 'a']);
  });

  it('boshqa fanlarga tegmaydi', () => {
    const other = topic('n1', { subject: 'native', position: 5 });
    const result = applyOrder([...mathTopics, other], 'math', ['c', 'b', 'a']);
    assert.deepEqual(result.find((t) => t.id === 'n1'), other);
  });

  it('kirishni oʻzgartirmaydi', () => {
    const snapshot = JSON.stringify(mathTopics);
    applyOrder(mathTopics, 'math', ['c', 'b', 'a']);
    assert.equal(JSON.stringify(mathTopics), snapshot);
  });

  it("yetishmayotgan id'lar oxirida joriy tartibda qoladi, notanish id'lar eʼtiborsiz", () => {
    const result = applyOrder(mathTopics, 'math', ['c', 'ghost']);
    assert.deepEqual(ids(topicsOfSubject(result, 'math')), ['c', 'a', 'b']);
  });

  it('boʻsh fan uchun oʻzgarishsiz nusxa qaytaradi', () => {
    const result = applyOrder(mathTopics, 'physics', ['a']);
    assert.deepEqual(result, mathTopics);
  });
});

describe('restorePositions (xatoda orqaga qaytarish)', () => {
  it('positionlarni snapshotdagidek qiladi', () => {
    const optimistic = applyOrder(mathTopics, 'math', ['c', 'b', 'a']);
    const restored = restorePositions(optimistic, mathTopics);
    assert.deepEqual(ids(topicsOfSubject(restored, 'math')), ['a', 'b', 'c']);
  });

  it('shu orada oʻzgargan holatga tegmaydi', () => {
    const optimistic = setStatusInList(applyOrder(mathTopics, 'math', ['b', 'a', 'c']), 'c', 'HIDDEN');
    const restored = restorePositions(optimistic, mathTopics);
    assert.deepEqual(ids(topicsOfSubject(restored, 'math')), ['a', 'b', 'c']);
    assert.equal(restored.find((t) => t.id === 'c')?.status, 'HIDDEN');
  });

  it('snapshotda yoʻq mavzuga tegmaydi', () => {
    const fresh = topic('new', { position: 9 });
    const restored = restorePositions([...mathTopics, fresh], mathTopics);
    assert.deepEqual(restored.find((t) => t.id === 'new'), fresh);
  });
});

describe('setStatusInList', () => {
  it('faqat bitta mavzu holatini almashtiradi', () => {
    const result = setStatusInList(mathTopics, 'b', 'HIDDEN');
    assert.deepEqual(result.map((t) => t.status), ['ACTIVE', 'HIDDEN', 'ACTIVE']);
    assert.equal(mathTopics[1]?.status, 'ACTIVE');
  });
});

describe('isUnderfilled / summarizeBySubject', () => {
  it('10 tadan kam savol — ogohlantirish, 10 va undan koʻp — yoʻq', () => {
    assert.equal(isUnderfilled({ questionCount: 9 }), true);
    assert.equal(isUnderfilled({ questionCount: 0 }), true);
    assert.equal(isUnderfilled({ questionCount: 10 }), false);
    assert.equal(isUnderfilled({ questionCount: 25 }), false);
  });

  it('fanlar boʻyicha jami va savoli yetishmaydigan faol mavzular', () => {
    const list = [
      topic('a', { questionCount: 3 }),
      topic('b', { questionCount: 12 }),
      topic('c', { questionCount: 1, status: 'HIDDEN' }),
      topic('d', { subject: 'native', questionCount: 0 }),
    ];
    assert.deepEqual(summarizeBySubject(list), {
      math: { total: 3, underfilled: 1 },
      native: { total: 1, underfilled: 1 },
    });
  });
});
