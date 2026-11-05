/**
 * Mavzu formasi: kalit (slug), validatsiya va payload'lar.
 * admin-web'da test yuguruvchi yo'q — Node'ning o'z test runner'i bilan:
 *
 *   npm test
 *   npx tsx --test src/components/learning/topic-form.test.ts
 */
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { TOPIC_KEY_MAX, TOPIC_KEY_PATTERN } from '@/lib/constants/learning';
import type { LearningTopic } from '@/types/api.types';
import {
  emptyTopicForm,
  formFromTopic,
  hasTopicFormErrors,
  normalizeKeyInput,
  parseGrade,
  slugify,
  toTopicCreatePayload,
  toTopicPatchPayload,
  validateTopicForm,
  withKey,
  withTitleUz,
  type TopicForm,
} from './topic-form';

const topic = (patch: Partial<LearningTopic> = {}): LearningTopic => ({
  id: 't-1',
  subject: 'math',
  key: 'oddiy-kasrlar',
  title: { uz: 'Oddiy kasrlar', ru: 'Обыкновенные дроби' },
  goal: { uz: 'Kasrlarni solishtirishni oʻrganasan' },
  minGrade: 5,
  maxGrade: 6,
  position: 1,
  status: 'ACTIVE',
  questionCount: 12,
  createdAt: '2026-11-01T10:00:00.000Z',
  updatedAt: '2026-11-01T10:00:00.000Z',
  ...patch,
});

const validForm = (patch: Partial<TopicForm> = {}): TopicForm => ({
  ...emptyTopicForm('math'),
  key: 'oddiy-kasrlar',
  keyTouched: true,
  title: { uz: 'Oddiy kasrlar', ru: '', en: '' },
  minGrade: '5',
  maxGrade: '6',
  ...patch,
});

describe('slugify', () => {
  it('lotincha sarlavhadan kalit yasaydi', () => {
    assert.equal(slugify('Oddiy kasrlar'), 'oddiy-kasrlar');
    assert.equal(slugify('  Kasrlar va ularning xossalari!  '), 'kasrlar-va-ularning-xossalari');
  });

  it("oʻ / gʻ / ' belgilarini tushirib harfni saqlaydi", () => {
    assert.equal(slugify('Oʻzbekiston tarixi'), 'ozbekiston-tarixi');
    assert.equal(slugify("G‘alla va yem-xashak"), 'galla-va-yem-xashak');
    assert.equal(slugify("Ma'lumotlar bazasi"), 'malumotlar-bazasi');
  });

  it('kirill sarlavhani lotinga oʻgiradi', () => {
    assert.equal(slugify('Оддий касрлар'), 'oddiy-kasrlar');
    assert.equal(slugify('Ўзбекистон тарихи'), 'ozbekiston-tarixi');
  });

  it('raqamlarni saqlaydi, takroriy va chetki chiziqlarni olib tashlaydi', () => {
    assert.equal(slugify('5-sinf: 2 xonali sonlar'), '5-sinf-2-xonali-sonlar');
    assert.equal(slugify('--a   b--'), 'a-b');
  });

  it("belgisiz yoki yaroqsiz matndan boʻsh satr qaytaradi", () => {
    assert.equal(slugify(''), '');
    assert.equal(slugify('?!…'), '');
  });

  it('80 belgidan oshmaydi va chiziq bilan tugamaydi', () => {
    const slug = slugify('a '.repeat(60));
    assert.ok(slug.length <= TOPIC_KEY_MAX);
    assert.ok(!slug.endsWith('-'));
    assert.match(slug, TOPIC_KEY_PATTERN);
  });

  it('natija har doim kalit andozasiga mos keladi', () => {
    for (const title of ['Oʻzbekiston', 'Кўпайтириш жадвали', 'Tenglama #1', 'e = mc²']) {
      assert.match(slugify(title), TOPIC_KEY_PATTERN, title);
    }
  });
});

describe('kalitni avtomatik taklif qilish', () => {
  it('kalit qoʻlda yozilmaguncha sarlavhadan yangilanadi', () => {
    const a = withTitleUz(emptyTopicForm('math'), 'Kasrlar');
    assert.equal(a.key, 'kasrlar');
    const b = withTitleUz(a, 'Kasrlar va foizlar');
    assert.equal(b.key, 'kasrlar-va-foizlar');
    assert.equal(b.keyTouched, false);
  });

  it('qoʻlda yozilgan kalit sarlavha oʻzgarganda saqlanadi', () => {
    const typed = withKey(withTitleUz(emptyTopicForm('math'), 'Kasrlar'), 'my-key');
    assert.equal(typed.keyTouched, true);
    assert.equal(withTitleUz(typed, 'Boshqa nom').key, 'my-key');
  });

  it('kalit maydoni tozalansa avtomatik taklif qayta yoqiladi', () => {
    const typed = withKey(withTitleUz(emptyTopicForm('math'), 'Kasrlar'), 'my-key');
    const cleared = withKey(typed, '');
    assert.equal(cleared.keyTouched, false);
    assert.equal(cleared.key, 'kasrlar');
  });

  it('yozilgan kalit kichik harfga oʻtadi, boʻshliq chiziqqa aylanadi', () => {
    assert.equal(normalizeKeyInput('Oddiy Kasrlar'), 'oddiy-kasrlar');
    assert.equal(withKey(emptyTopicForm('math'), 'ABC def').key, 'abc-def');
  });

  it('tahrirlashda mavjud kalit sarlavhadan oʻzgarib ketmaydi', () => {
    const form = withTitleUz(formFromTopic(topic()), 'Butunlay boshqa nom');
    assert.equal(form.key, 'oddiy-kasrlar');
  });
});

describe('parseGrade', () => {
  it('1–11 oraligʻidagi butun sonlarni qabul qiladi', () => {
    assert.equal(parseGrade('1'), 1);
    assert.equal(parseGrade('11'), 11);
  });

  it('chegaradan tashqari va yaroqsiz qiymatlarni rad etadi', () => {
    for (const raw of ['', '0', '12', '-1', '5.5', 'abc', ' ']) {
      assert.equal(parseGrade(raw), null, JSON.stringify(raw));
    }
  });
});

describe('validateTopicForm', () => {
  it("toʻgʻri formada xato yoʻq", () => {
    assert.deepEqual(validateTopicForm(validForm(), 'create'), {});
  });

  it('yaratishda fan majburiy, tahrirlashda tekshirilmaydi', () => {
    assert.ok(validateTopicForm(validForm({ subject: '' }), 'create').subject);
    assert.equal(validateTopicForm(validForm({ subject: '' }), 'edit').subject, undefined);
  });

  it("o'zbekcha nom majburiy (ru/en yetmaydi)", () => {
    const errors = validateTopicForm(
      validForm({ title: { uz: '   ', ru: 'Дроби', en: 'Fractions' } }),
      'create',
    );
    assert.ok(errors.title);
  });

  it('kalit: boʻsh, notoʻgʻri andoza va uzun kalit rad etiladi', () => {
    assert.ok(validateTopicForm(validForm({ key: '' }), 'create').key);
    for (const key of ['Kasr', 'a--b', '-a', 'a-', 'a_b', 'kasr lar', 'oʻzbek']) {
      assert.ok(validateTopicForm(validForm({ key }), 'create').key, key);
    }
    const tooLong = 'a'.repeat(TOPIC_KEY_MAX + 1);
    assert.ok(validateTopicForm(validForm({ key: tooLong }), 'create').key);
  });

  it('kalit: toʻgʻri variantlar va 80 belgi chegarasi qabul qilinadi', () => {
    for (const key of ['kasr', 'kasr-2', '5-sinf', 'a-b-c', 'a'.repeat(TOPIC_KEY_MAX)]) {
      assert.equal(validateTopicForm(validForm({ key }), 'create').key, undefined, key);
    }
  });

  it('sinflar: tanlanmagan yoki 1–11 dan tashqari boʻlsa xato', () => {
    const errors = validateTopicForm(validForm({ minGrade: '', maxGrade: '12' }), 'create');
    assert.ok(errors.minGrade);
    assert.ok(errors.maxGrade);
  });

  it("sinflar: minGrade > maxGrade xato, teng boʻlsa mumkin", () => {
    assert.ok(validateTopicForm(validForm({ minGrade: '7', maxGrade: '5' }), 'create').maxGrade);
    assert.deepEqual(validateTopicForm(validForm({ minGrade: '5', maxGrade: '5' }), 'create'), {});
  });

  it('hasTopicFormErrors', () => {
    assert.equal(hasTopicFormErrors({}), false);
    assert.equal(hasTopicFormErrors({ key: 'x' }), true);
  });
});

describe('toTopicCreatePayload', () => {
  it('ixtiyoriy maydonlarsiz minimal payload', () => {
    assert.deepEqual(toTopicCreatePayload(validForm()), {
      subject: 'math',
      key: 'oddiy-kasrlar',
      title: { uz: 'Oddiy kasrlar' },
      minGrade: 5,
      maxGrade: 6,
      status: 'ACTIVE',
    });
  });

  it('matnlar trim qilinadi, boʻsh tillar va boʻsh maqsad yuborilmaydi', () => {
    const payload = toTopicCreatePayload(
      validForm({
        title: { uz: '  Kasrlar  ', ru: ' Дроби ', en: '  ' },
        goal: { uz: '', ru: '  ', en: '' },
      }),
    );
    assert.deepEqual(payload.title, { uz: 'Kasrlar', ru: 'Дроби' });
    assert.equal('goal' in payload, false);
  });

  it('maqsad kamida bitta tilda boʻlsa yuboriladi', () => {
    const payload = toTopicCreatePayload(validForm({ goal: { uz: ' Maqsad ', ru: '', en: 'Goal' } }));
    assert.deepEqual(payload.goal, { uz: 'Maqsad', en: 'Goal' });
  });

  it('holat va sinflar son sifatida yuboriladi', () => {
    const payload = toTopicCreatePayload(validForm({ status: 'HIDDEN', minGrade: '1', maxGrade: '11' }));
    assert.equal(payload.status, 'HIDDEN');
    assert.equal(payload.minGrade, 1);
    assert.equal(payload.maxGrade, 11);
  });

  it('validatsiyasiz forma uchun xato tashlaydi', () => {
    assert.throws(() => toTopicCreatePayload(validForm({ subject: '' })), /Fan tanlanmagan/);
    assert.throws(() => toTopicCreatePayload(validForm({ minGrade: '' })), /Sinflar/);
  });
});

describe('toTopicPatchPayload', () => {
  it("oʻzgarmagan formada boʻsh patch", () => {
    assert.deepEqual(toTopicPatchPayload(formFromTopic(topic()), topic()), {});
  });

  it('faqat oʻzgargan maydonlarni yuboradi', () => {
    const original = topic();
    const form: TopicForm = {
      ...formFromTopic(original),
      title: { uz: 'Kasrlar', ru: 'Обыкновенные дроби', en: '' },
      maxGrade: '7',
      status: 'HIDDEN',
    };
    assert.deepEqual(toTopicPatchPayload(form, original), {
      title: { uz: 'Kasrlar', ru: 'Обыкновенные дроби' },
      maxGrade: 7,
      status: 'HIDDEN',
    });
  });

  it('kalit oʻzgarsa yuboriladi', () => {
    const original = topic();
    const form = { ...formFromTopic(original), key: 'kasrlar' };
    assert.deepEqual(toTopicPatchPayload(form, original), { key: 'kasrlar' });
  });

  it("maqsad butunlay tozalansa goal: null yuboriladi", () => {
    const original = topic();
    const form = { ...formFromTopic(original), goal: { uz: '', ru: '', en: '' } };
    assert.deepEqual(toTopicPatchPayload(form, original), { goal: null });
  });

  it("maqsadi yoʻq mavzuga maqsad qoʻshilsa goal yuboriladi", () => {
    const original = topic({ goal: null });
    const form = { ...formFromTopic(original), goal: { uz: 'Yangi maqsad', ru: '', en: '' } };
    assert.deepEqual(toTopicPatchPayload(form, original), { goal: { uz: 'Yangi maqsad' } });
  });

  it("maqsadi yoʻq mavzu boʻsh qolsa patch boʻsh", () => {
    const original = topic({ goal: null });
    assert.deepEqual(toTopicPatchPayload(formFromTopic(original), original), {});
  });

  it('server qiymatidagi boʻsh tillar (ru: "") farq sanalmaydi', () => {
    const original = topic({ title: { uz: 'Kasrlar', ru: '' }, goal: { uz: 'Maqsad', en: '' } });
    assert.deepEqual(toTopicPatchPayload(formFromTopic(original), original), {});
  });
});
