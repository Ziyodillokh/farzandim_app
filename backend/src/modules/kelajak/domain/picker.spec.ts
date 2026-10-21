import { buildKelajakBankRows } from '../../../../scripts/kelajak/build-bank-migration';
import { KELAJAK_AGE_GROUPS, KelajakAgeGroup } from './age';
import { categoryOrder, KELAJAK_TEST_TYPES, KELAJAK_TESTS, KelajakTestType, testCategories } from './catalog';
import { kelajakCandidates, kelajakSeed, pickKelajakQuestions, PickerQuestion } from './picker';

const bank = buildKelajakBankRows();
const bankById = new Map(bank.map((row) => [row.id, row]));
const NONE = new Map<string, number>();

const pick = (
  type: KelajakTestType,
  ageGroup: KelajakAgeGroup,
  options: { seed?: number; last?: ReadonlyMap<string, number>; pool?: readonly PickerQuestion[] } = {},
) =>
  pickKelajakQuestions({
    config: KELAJAK_TESTS[type],
    ageGroup,
    pool: options.pool ?? bank,
    lastAnsweredAt: options.last ?? NONE,
    seed: options.seed ?? kelajakSeed('2026-10-21', type, 'child-1'),
  });

const countBy = (items: readonly PickerQuestion[]) =>
  items.reduce<Record<string, number>>((acc, q) => ({ ...acc, [q.category]: (acc[q.category] ?? 0) + 1 }), {});

describe('kelajak picker — qoidalar (haqiqiy bank)', () => {
  const cases = KELAJAK_AGE_GROUPS.flatMap((g) => KELAJAK_TEST_TYPES.map((t) => [t, g] as const));

  it.each(cases)('%s / %s: faqat o\'z guruhi, faol, mos kategoriya, chegaralar', (type, ageGroup) => {
    const config = KELAJAK_TESTS[type];
    const picked = pick(type, ageGroup);
    const allowed = new Set<string>(testCategories(config));
    expect(picked.every((q) => q.ageGroup === ageGroup && q.active && allowed.has(q.category))).toBe(true);
    expect(new Set(picked.map((q) => q.id)).size).toBe(picked.length);
    const cap = config.perCategoryMax ?? Infinity;
    const perCategory = Object.values(countBy(kelajakCandidates(bank, config, ageGroup)));
    const capacity = perCategory.reduce((sum, n) => sum + Math.min(n, cap), 0);
    expect(picked.length).toBe(Math.min(config.count, capacity));
    expect(Math.max(0, ...Object.values(countBy(picked)))).toBeLessThanOrEqual(cap);
    // Yakuniy tartib: kategoriya tartibi bo'yicha.
    const orders = picked.map((q) => categoryOrder(q.category));
    expect(orders).toEqual([...orders].sort((a, b) => a - b));
  });

  it('nofaol savol hech qachon tanlanmaydi', () => {
    const inactive = new Set(bank.filter((q) => !q.active).map((q) => q.id));
    const all = cases.flatMap(([t, g]) => pick(t, g));
    expect(all.some((q) => inactive.has(q.id))).toBe(false);
  });

  it('daily: 10 ta, kategoriyadan ≤2, Career Lab va ochiq matn yo\'q', () => {
    for (const g of KELAJAK_AGE_GROUPS) {
      const picked = pick('daily', g);
      expect(picked).toHaveLength(10);
      expect(picked.some((q) => q.category === 'career_lab' || q.category === 'child_voice')).toBe(false);
    }
  });

  it('career: barcha qiziqish savollari (RIASEC qamrovi) + rejalashtirish bilan to\'ldiriladi', () => {
    for (const g of KELAJAK_AGE_GROUPS) {
      const picked = pick('career', g);
      const interest = bank.filter((q) => q.ageGroup === g && q.category === 'career_interest');
      expect(picked.filter((q) => q.category === 'career_interest')).toHaveLength(interest.length);
      expect(new Set(picked.filter((q) => q.category === 'career_interest').map((q) => bankById.get(q.id)?.scoring?.dimension))).toEqual(
        new Set(['R', 'I', 'A', 'S', 'E', 'C']),
      );
    }
    // 7–9 da rejalashtirish savollari 2 ta — jami 17; 13–15 da to'liq 20.
    expect(pick('career', '7-9')).toHaveLength(17);
    expect(pick('career', '13-15')).toHaveLength(20);
  });

  it('wellbeing: avval barcha wellbeing, keyin safety', () => {
    const picked = pick('wellbeing', '10-12');
    expect(countBy(picked)).toEqual({ wellbeing: 5, safety: 3 });
  });

  it('determinizm: bir xil urug\' — bir xil tanlov; boshqa bola — boshqa tartib', () => {
    const a = pick('daily', '13-15');
    expect(pick('daily', '13-15').map((q) => q.id)).toEqual(a.map((q) => q.id));
    const seeds = ['child-2', 'child-3', 'child-4'].map((c) => kelajakSeed('2026-10-21', 'daily', c));
    const others = seeds.map((seed) => pick('daily', '13-15', { seed }).map((q) => q.id).join());
    expect(others.some((ids) => ids !== a.map((q) => q.id).join())).toBe(true);
  });

  it.each(KELAJAK_AGE_GROUPS)('aylanma (%s): kunlik savollar keyingi kunlarda takrorlanmaydi', (g) => {
    // 3 kun — har kategoriyada chegara ichida javobsiz savol yetarli bo'lgan kafolatli oraliq.
    const last = [0, 1, 2].reduce<ReadonlyMap<string, number>>((seen, day) => {
      const picked = pick('daily', g, { seed: kelajakSeed(`2026-10-2${day}`, 'daily', 'c1'), last: seen });
      expect(picked).toHaveLength(10);
      expect(picked.some((q) => seen.has(q.id))).toBe(false);
      return new Map([...seen, ...picked.map((q) => [q.id, day] as const)]);
    }, new Map());
    expect(last.size).toBe(30);
  });
});

describe('kelajak picker — sintetik', () => {
  const q = (id: string, category: string, answerType = 'likert_5', ageGroup = '10-12'): PickerQuestion => ({
    id,
    category,
    ageGroup,
    answerType,
    active: true,
  });

  it('javobsizlar, keyin eng eski javoblar; boshqa guruh aralashmaydi', () => {
    const pool = [q('a', 'learning'), q('b', 'learning'), q('c', 'learning'), q('x', 'learning', 'likert_5', '13-15')];
    const last = new Map([
      ['a', 300],
      ['b', 100],
    ]);
    const picked = pickKelajakQuestions({
      config: { ...KELAJAK_TESTS.learning, count: 2 },
      ageGroup: '10-12',
      pool,
      lastAnsweredAt: last,
      seed: 1,
    });
    expect(picked.map((p) => p.id)).toEqual(['c', 'b']);
  });

  it('ochiq matn savollari oxirida, qolgani kategoriya tartibida', () => {
    const pool = [q('t', 'learning', 'text'), q('tq', 'teacher_relation'), q('l', 'learning'), q('s', 'school_quality')];
    const picked = pickKelajakQuestions({
      config: KELAJAK_TESTS.learning,
      ageGroup: '10-12',
      pool,
      lastAnsweredAt: NONE,
      seed: 5,
    });
    expect(picked.map((p) => p.id)).toEqual(['l', 's', 'tq', 't']);
  });

  it('nomzod yo\'q — bo\'sh', () => {
    expect(pick('voice', '7-9', { pool: [] })).toEqual([]);
  });

  it('urug\': kun, tur va bola bo\'yicha farqlanadi', () => {
    const base = kelajakSeed('2026-10-21', 'daily', 'c1');
    expect(kelajakSeed('2026-10-21', 'daily', 'c1')).toBe(base);
    expect(kelajakSeed('2026-10-22', 'daily', 'c1')).not.toBe(base);
    expect(kelajakSeed('2026-10-21', 'career', 'c1')).not.toBe(base);
    expect(kelajakSeed('2026-10-21', 'daily', 'c2')).not.toBe(base);
  });
});
