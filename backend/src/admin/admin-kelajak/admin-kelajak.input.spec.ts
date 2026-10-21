import { EXTERNAL_ID_PATTERN, KelajakQuestionData, parseKelajakQuestion } from '../../modules/kelajak/domain/bank';
import { LOCKED_WHEN_ANSWERED } from '../../modules/kelajak/domain/import-plan';
import {
  ADMIN_LOCKED_WHEN_ANSWERED,
  changedFields,
  definedFields,
  generateExternalId,
  isReservedExternalId,
  lockedFields,
  mergeQuestionPatch,
  rebaseScoring,
  StoredKelajakQuestion,
} from './admin-kelajak.input';
import { countByKey, toStatsView } from './admin-kelajak.views';

const stored = (patch: Partial<Omit<KelajakQuestionData, 'externalId'>> = {}): StoredKelajakQuestion => ({
  externalId: 'PARVOZ-Q090',
  category: 'learning',
  ageGroup: '10-12',
  text: { uz: 'Darsning eng yoqimli qismi qaysi?' },
  answerType: 'likert_5',
  options: [1, 2, 3, 4, 5].map((value) => ({ value, label: { uz: `V${value}` } })),
  scoring: { method: 'simple_sum', min: 1, max: 5 },
  reverse: false,
  required: true,
  followUp: null,
  notes: null,
  reviewNote: 'Ochiq savol',
  sourceType: 'parvoz_original',
  sourceName: 'Parvoz',
  sourceVersion: 'original-draft-2026-10',
  active: false,
  ...patch,
});

const parse = (raw: object): KelajakQuestionData => {
  const parsed = parseKelajakQuestion(raw);
  if (!parsed.ok) throw new Error(parsed.error);
  return parsed.value;
};

describe('admin kelajak kiritmasi', () => {
  it('generateExternalId: ADMIN- + 8 katta hex, pattern\'ga mos va har safar boshqa', () => {
    const ids = Array.from({ length: 20 }, generateExternalId);
    expect(ids.every((id) => /^ADMIN-[0-9A-F]{8}$/.test(id) && EXTERNAL_ID_PATTERN.test(id))).toBe(true);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it('PARVOZ- prefiksi bank uchun band; ADMIN- va boshqalar — yo\'q', () => {
    expect(isReservedExternalId('PARVOZ-Q279')).toBe(true);
    expect(isReservedExternalId('ADMIN-0000ABCD')).toBe(false);
    expect(isReservedExternalId('SCHOOL-PARVOZ-1')).toBe(false);
  });

  it('import va admin bloklash ro\'yxati bir xil', () => {
    expect(ADMIN_LOCKED_WHEN_ANSWERED).toEqual(LOCKED_WHEN_ANSWERED);
  });

  it('definedFields: undefined tashlanadi, null saqlanadi', () => {
    expect(definedFields({ a: undefined, b: null, c: 0 })).toEqual({ b: null, c: 0 });
  });

  it('rebaseScoring: text — null; min/max yangi variantlarga; dimension saqlanadi', () => {
    const scoring = { method: 'dimension_sum', dimension: 'R', min: 1, max: 4 };
    const options = [{ value: 0 }, { value: 1 }, { value: 2 }];
    expect(rebaseScoring(scoring, 'text', [])).toBeNull();
    expect(rebaseScoring(scoring, 'interest_4', options)).toEqual({ ...scoring, min: 0, max: 2 });
    expect(rebaseScoring({ method: 'support_signal' }, 'likert_5', options)).toEqual({ method: 'support_signal' });
    expect(rebaseScoring(null, 'likert_5', options)).toBeNull();
    expect(rebaseScoring(scoring, 'interest_4', 'yaroqsiz')).toBe(scoring);
  });

  it('PATCH: text turiga o\'tkazish — scoring null, required tur qoidasidan (ixtiyoriy)', () => {
    const existing = stored();
    const next = parse(mergeQuestionPatch(existing, { answerType: 'text', options: [], active: true }));
    expect(next).toMatchObject({ answerType: 'text', options: [], scoring: null, required: false, active: true });
    expect(changedFields(existing, next).sort()).toEqual(['active', 'answerType', 'options', 'required', 'scoring']);
  });

  it('PATCH: yes_no variantlari — scoring min/max moslanadi; required aniq berilsa saqlanadi', () => {
    const existing = stored();
    const options = [1, 2].map((value) => ({ value, label: { uz: value === 1 ? 'Yo\'q' : 'Ha' } }));
    const next = parse(mergeQuestionPatch(existing, { answerType: 'yes_no', options, required: false }));
    expect(next.scoring).toEqual({ method: 'simple_sum', min: 1, max: 2 });
    expect(next.required).toBe(false);
  });

  it('PATCH: faqat matn — boshqa maydonlar o\'zgarmaydi, bloklanganlari yo\'q', () => {
    const existing = stored();
    const next = parse(mergeQuestionPatch(existing, { text: { uz: 'Darsda vaqt tez o\'tadimi?' }, reviewNote: null }));
    const changed = changedFields(existing, next);
    expect(changed.sort()).toEqual(['reviewNote', 'text']);
    expect(lockedFields(changed)).toEqual([]);
  });

  it('lockedFields: kategoriya, yosh, tur, variantlar, scoring va reverse', () => {
    expect(
      lockedFields(['text', 'category', 'ageGroup', 'answerType', 'options', 'scoring', 'reverse', 'active', 'required']),
    ).toEqual(['category', 'ageGroup', 'answerType', 'options', 'scoring', 'reverse']);
  });

  it('PATCH: ochiq javobga o\'tkazib required: true — parser rad etadi', () => {
    const merged = mergeQuestionPatch(stored(), { answerType: 'text', options: [], required: true });
    expect(parseKelajakQuestion(merged).ok).toBe(false);
  });

  it('bir xil qiymatlar (JSON kalit tartibi boshqa) — o\'zgarish emas', () => {
    const existing = stored({ scoring: { min: 1, max: 5, method: 'simple_sum' } });
    const next = parse(mergeQuestionPatch(existing, { options: existing.options }));
    expect(changedFields(existing, next)).toEqual([]);
  });
});

describe('admin kelajak statistikasi', () => {
  it('countByKey: katalog tartibi, nollar va katalogdan tashqari qiymat oxirida', () => {
    const rows = countByKey(['a', 'b'], [
      { key: 'b', active: true, count: 3 },
      { key: 'b', active: false, count: 1 },
      { key: 'z', active: true, count: 2 },
    ]);
    expect(rows).toEqual([
      { key: 'a', total: 0, active: 0 },
      { key: 'b', total: 4, active: 3 },
      { key: 'z', total: 2, active: 2 },
    ]);
  });

  it('toStatsView: jami, faol, nofaol va kategoriya nomi', () => {
    const view = toStatsView({
      byCategory: [
        { key: 'learning', active: true, count: 5 },
        { key: 'learning', active: false, count: 2 },
      ],
      byAgeGroup: [],
      byAnswerType: [],
      needsReview: 2,
      sessions: { total: 3, completed: 1, completedLast7Days: 1 },
    });
    expect(view).toMatchObject({ total: 7, active: 5, inactive: 2, needsReview: 2 });
    expect(view.byCategory).toHaveLength(12);
    expect(view.byCategory.find((c) => c.category === 'learning')).toMatchObject({ total: 7, active: 5 });
    expect(view.byCategory[0].name.uz).toBe('Kasbiy qiziqishlar');
    expect(view.byAgeGroup.map((g) => g.ageGroup)).toEqual(['7-9', '10-12', '13-15', '16-18']);
    expect(view.byAnswerType.every((a) => a.total === 0)).toBe(true);
  });
});
