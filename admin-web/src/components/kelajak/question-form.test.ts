/**
 * Savol formasi: validatsiya va payload'lar (backend kontrakti, §6).
 * admin-web'da test yuguruvchi yo'q — Node'ning o'z test runner'i bilan:
 *
 *   npx tsx --test src/components/kelajak/question-form.test.ts
 */
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import type { KelajakQuestion } from '@/types/api.types';
import { setActiveInList } from './list-cache';
import {
  emptyForm,
  formFromQuestion,
  toCreatePayload,
  toPatchPayload,
  validateForm,
  withAnswerType,
  withCategory,
  type QuestionForm,
} from './question-form';

const interestOptions = [1, 2, 3, 4].map((value) => ({ value, label: { uz: `V${value}` } }));

const question = (patch: Partial<KelajakQuestion> = {}): KelajakQuestion => ({
  id: 'q-1',
  externalId: 'PARVOZ-Q062',
  category: 'learning',
  categoryName: { uz: 'Fanlar' },
  ageGroup: '10-12',
  text: { uz: 'Yangi mavzu senga qiziqmi?' },
  answerType: 'likert_5',
  options: [1, 2, 3, 4, 5].map((value) => ({ value, label: { uz: `L${value}` } })),
  scoring: { method: 'simple_sum', min: 1, max: 5 },
  reverse: false,
  required: true,
  followUp: null,
  notes: null,
  reviewNote: null,
  sourceType: 'parvoz_original',
  sourceName: 'Parvoz',
  sourceVersion: 'v1',
  active: true,
  answerCount: 0,
  createdAt: '2026-10-21T00:00:00.000Z',
  updatedAt: '2026-10-21T00:00:00.000Z',
  ...patch,
});

const careerForm = (patch: Partial<QuestionForm> = {}): QuestionForm => ({
  ...withAnswerType(withCategory(emptyForm({ ageGroup: '13-15' }), 'career_interest'), 'interest_4'),
  text: { uz: 'Odamlarga o‘rgatish senga yoqadimi?', ru: '', en: '' },
  ...patch,
});

describe('Kasbiy qiziqishlar (RIASEC)', () => {
  it('yo‘nalish tanlanmasa — xato; ochiq javob turi ham mumkin emas', () => {
    assert.ok(validateForm(careerForm(), 'create').scoringTag);
    assert.equal(validateForm(careerForm({ scoringTag: 'S' }), 'create').scoringTag, undefined);
    const asText = withAnswerType(careerForm({ scoringTag: 'S' }), 'text');
    assert.ok(validateForm(asText, 'create').answerType);
  });

  it('yaratish payload‘i backend kutgan scoring bilan (min/max variantlardan)', () => {
    const payload = toCreatePayload(careerForm({ scoringTag: 'S' }));
    assert.deepEqual(payload.scoring, { method: 'dimension_sum', dimension: 'S', min: 1, max: 4 });
    assert.equal(payload.category, 'career_interest');
    assert.equal(payload.required, true);
  });

  it('javobsiz savolni career_interest‘ga o‘tkazish — scoring (asl maydonlar saqlanadi)', () => {
    const original = question();
    const form = withAnswerType(withCategory(formFromQuestion(original), 'career_interest'), 'interest_4');
    const patch = toPatchPayload({ ...form, scoringTag: 'I' }, original, false);
    assert.equal(patch.category, 'career_interest');
    const labels = ['Umuman yoqmaydi', 'Unchalik yoqmaydi', 'Yoqadi', 'Juda yoqadi'];
    assert.deepEqual(patch.options, labels.map((uz, i) => ({ value: i + 1, label: { uz } })));
    assert.deepEqual(patch.scoring, { method: 'dimension_sum', dimension: 'I', min: 1, max: 4 });
  });

  it('yo‘nalishni almashtirish — faqat dimension o‘zgaradi; bloklangan savolda scoring yuborilmaydi', () => {
    const original = question({
      category: 'career_interest',
      answerType: 'interest_4',
      options: interestOptions,
      scoring: { method: 'dimension_sum', dimension: 'R', min: 1, max: 4, interpretation: 'exploratory' },
    });
    const form = formFromQuestion(original);
    assert.equal(form.scoringTag, 'R');
    assert.deepEqual(toPatchPayload(form, original, false), {});
    assert.deepEqual(toPatchPayload({ ...form, scoringTag: 'A' }, original, false).scoring, {
      method: 'dimension_sum',
      dimension: 'A',
      min: 1,
      max: 4,
      interpretation: 'exploratory',
    });
    assert.equal(toPatchPayload({ ...form, scoringTag: 'A' }, { ...original, answerCount: 3 }, true).scoring, undefined);
  });
});

describe('Career Lab va signal teglari', () => {
  it('Career Lab: RIASEC ixtiyoriy; tanlansa — riasec, olib tashlansa — o‘chadi', () => {
    const lab = withAnswerType(withCategory(emptyForm({ ageGroup: '10-12' }), 'career_lab'), 'career_lab_5');
    const base = { ...lab, text: { uz: 'Tajriba yoqdimi?', ru: '', en: '' } };
    assert.equal(validateForm(base, 'create').scoringTag, undefined);
    assert.equal(toCreatePayload(base).scoring, undefined);
    assert.deepEqual(toCreatePayload({ ...base, scoringTag: 'C' }).scoring, {
      method: 'reflection_rating',
      riasec: 'C',
      min: 1,
      max: 5,
    });
    const original = question({
      category: 'career_lab',
      answerType: 'career_lab_5',
      scoring: { method: 'reflection_rating', dimension: 'career_lab_enjoyment', min: 1, max: 5, riasec: 'I' },
    });
    const cleared = toPatchPayload({ ...formFromQuestion(original), scoringTag: '' }, original, false);
    assert.deepEqual(cleared.scoring, { method: 'reflection_rating', dimension: 'career_lab_enjoyment', min: 1, max: 5 });
  });

  it('wellbeing / safety: standart — holat (scoring yuborilmaydi), bilim savoli — signal: knowledge', () => {
    const safety = { ...withCategory(emptyForm({ ageGroup: '7-9' }), 'safety'), text: { uz: 'Bilasanmi?', ru: '', en: '' } };
    assert.equal(safety.scoringTag, 'distress');
    assert.equal(toCreatePayload(safety).scoring, undefined);
    assert.deepEqual(toCreatePayload({ ...safety, scoringTag: 'knowledge' }).scoring, {
      method: 'support_signal',
      signal: 'knowledge',
    });
    const original = question({
      category: 'safety',
      scoring: { method: 'support_signal', direction: 'review_needed', note: 'Signal only' },
    });
    assert.deepEqual(toPatchPayload(formFromQuestion(original), original, false), {});
    assert.deepEqual(toPatchPayload({ ...formFromQuestion(original), scoringTag: 'knowledge' }, original, false).scoring, {
      method: 'support_signal',
      direction: 'review_needed',
      note: 'Signal only',
      signal: 'knowledge',
    });
  });
});

describe('Validatsiya va chegaralar', () => {
  const valid = (): QuestionForm => ({
    ...emptyForm({ category: 'learning', ageGroup: '10-12' }),
    text: { uz: 'Savol?', ru: '', en: '' },
  });

  it('PARVOZ- prefiksi bank uchun band', () => {
    assert.ok(validateForm({ ...valid(), externalId: 'PARVOZ-Q279' }, 'create').externalId);
    assert.equal(validateForm({ ...valid(), externalId: 'ADMIN-0001' }, 'create').externalId, undefined);
  });

  it('variant yorlig‘i 120, follow-up 500, izohlar 1000 belgidan oshmaydi', () => {
    const form = valid();
    const longLabel = form.options.map((o, i) => (i === 0 ? { ...o, label: { ...o.label, ru: 'x'.repeat(121) } } : o));
    assert.ok(validateForm({ ...form, options: longLabel }, 'create').options);
    assert.ok(validateForm({ ...form, followUp: 'x'.repeat(501) }, 'create').followUp);
    assert.ok(validateForm({ ...form, notes: 'x'.repeat(1001) }, 'create').notes);
    assert.ok(validateForm({ ...form, reviewNote: 'x'.repeat(1001) }, 'create').reviewNote);
    assert.deepEqual(validateForm(form, 'create'), {});
  });

  it('ochiq javob hech qachon majburiy yuborilmaydi', () => {
    const text = { ...withAnswerType(valid(), 'text'), category: 'child_voice', required: true };
    assert.equal(toCreatePayload(text).required, false);
    assert.equal(toCreatePayload(text).scoring, undefined);
  });
});

describe('Tahrir — eskirgan ro‘yxat qatori', () => {
  it('PATCH forma to‘ldirilgan holatga nisbatan — boshqa admin tuzatgan maydon qaytarilmaydi', () => {
    const seen = question();
    // Admin faqat izoh yozdi; shu orada boshqa admin matnni tuzatgan (serverdagi yangi holat).
    const form = { ...formFromQuestion(seen), notes: 'Tekshirildi' };
    assert.deepEqual(toPatchPayload(form, seen, false), { notes: 'Tekshirildi' });
  });
});

describe('Ro‘yxat keshi', () => {
  it('faqat tanlangan qator o‘zgaradi', () => {
    const list = { items: [question(), question({ id: 'q-2', active: false })], page: 1, totalPages: 1, total: 2 };
    const next = setActiveInList(list, 'q-2', true);
    assert.deepEqual(next?.items.map((q) => [q.id, q.active]), [['q-1', true], ['q-2', true]]);
    assert.equal(next?.items[0], list.items[0]);
    assert.equal(setActiveInList(undefined, 'q-1', false), undefined);
  });
});
