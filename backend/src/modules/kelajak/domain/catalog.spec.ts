import { readFileSync } from 'node:fs';
import path from 'node:path';
import {
  categoryOrder,
  defaultRequired,
  isKelajakTestType,
  KELAJAK_CATEGORIES,
  KELAJAK_CATEGORY_IDS,
  KELAJAK_TEST_TYPES,
  KELAJAK_TESTS,
  SCORED_CATEGORY_IDS,
  SUPPORT_CATEGORY_IDS,
  testCategories,
} from './catalog';

const bank = JSON.parse(
  readFileSync(
    path.resolve(__dirname, '../../../../prisma/data/kelajak/parvoz_question_bank_278.json'),
    'utf8',
  ),
) as { categories: Array<{ id: string; name: string }> };

describe('kelajak catalog', () => {
  it('12 kategoriya — JSON tartibi va o\'zbekcha nomlari bilan bir xil', () => {
    expect(KELAJAK_CATEGORIES.map((c) => c.id)).toEqual(bank.categories.map((c) => c.id));
    expect(KELAJAK_CATEGORIES.map((c) => c.name.uz)).toEqual(bank.categories.map((c) => c.name));
    expect(KELAJAK_CATEGORIES.map((c) => c.order)).toEqual(KELAJAK_CATEGORY_IDS.map((_, i) => i + 1));
    expect(categoryOrder('safety')).toBeLessThan(categoryOrder('wellbeing'));
    expect(categoryOrder('unknown')).toBe(Number.MAX_SAFE_INTEGER);
  });

  it('ballanadigan va signal kategoriyalari kesishmaydi', () => {
    const scored = new Set<string>(SCORED_CATEGORY_IDS);
    expect(SUPPORT_CATEGORY_IDS.some((c) => scored.has(c))).toBe(false);
    expect(scored.size).toBe(7);
  });

  it('majburiylik qoidasi: career_lab_5 va text ixtiyoriy', () => {
    expect(defaultRequired('likert_5')).toBe(true);
    expect(defaultRequired('interest_4')).toBe(true);
    expect(defaultRequired('yes_no')).toBe(true);
    expect(defaultRequired('career_lab_5')).toBe(false);
    expect(defaultRequired('text')).toBe(false);
  });

  it('test turlari §3 jadvali bo\'yicha', () => {
    expect(Object.keys(KELAJAK_TESTS)).toEqual([...KELAJAK_TEST_TYPES]);
    const summary = Object.fromEntries(
      KELAJAK_TEST_TYPES.map((t) => [t, [KELAJAK_TESTS[t].count, KELAJAK_TESTS[t].perCategoryMax]]),
    );
    expect(summary).toEqual({
      daily: [10, 2],
      career: [20, null],
      wellbeing: [8, null],
      learning: [10, 4],
      self: [10, 4],
      career_lab: [5, null],
      voice: [3, null],
    });
    expect(testCategories(KELAJAK_TESTS.daily)).not.toContain('career_lab');
    expect(testCategories(KELAJAK_TESTS.daily)).not.toContain('child_voice');
    expect(testCategories(KELAJAK_TESTS.daily)).toHaveLength(10);
    expect(KELAJAK_TESTS.career.full).toEqual(['career_interest']);
    expect(KELAJAK_TESTS.wellbeing.full).toEqual(['wellbeing']);
    expect(isKelajakTestType('voice')).toBe(true);
    expect(isKelajakTestType('exam')).toBe(false);
  });
});
