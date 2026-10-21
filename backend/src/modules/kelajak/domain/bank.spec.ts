import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import {
  ADMIN_SOURCE,
  NO_OVERRIDES,
  parseKelajakBank,
  parseKelajakQuestion,
  parseReviewOverrides,
  ReviewOverrides,
} from './bank';

const DATA_DIR = path.resolve(__dirname, '../../../../prisma/data/kelajak');
const BANK_FILE = 'parvoz_question_bank_278.json';
/** docs/KELAJAK-REJA.md §1 — foydalanuvchi bergan fayl, baytma-bayt. */
const BANK_SHA256 = '1359fc1d2c4400716467742d795b54e5586d78dee51dec78ec2a4afae27d06e1';
const readJson = (file: string) => JSON.parse(readFileSync(path.join(DATA_DIR, file), 'utf8'));
const rawBank = readJson(BANK_FILE) as Record<string, unknown> & { questions: Array<Record<string, unknown>> };
const overridesResult = parseReviewOverrides(readJson('review-overrides.json'));
if (!overridesResult.ok) throw new Error(overridesResult.error);
const overrides: ReviewOverrides = overridesResult.value;

const jsonQuestion = rawBank.questions[0];
const adminQuestion = {
  externalId: 'ADMIN-1A2B3C4D',
  category: 'learning',
  ageGroup: '10-12',
  text: { uz: 'Darsda savol berish senga osonmi?', ru: 'Легко ли тебе задавать вопросы на уроке?' },
  answerType: 'likert_5',
  options: [1, 2, 3, 4, 5].map((value) => ({ value, label: { uz: `V${value}` } })),
  scoring: { method: 'simple_sum', min: 1, max: 5 },
};

describe('kelajak bank — haqiqiy JSON', () => {
  const parsed = parseKelajakBank(rawBank, overrides);
  const byId = new Map(parsed.valid.map((q) => [q.externalId, q]));

  it('fayl o\'zgartirilmagan (sha256)', () => {
    const sha = createHash('sha256').update(readFileSync(path.join(DATA_DIR, BANK_FILE))).digest('hex');
    expect(sha).toBe(BANK_SHA256);
  });

  it('278/278 savol valid, dublikat va ogohlantirish yo\'q (yaxlitlik tekshiruvlari ham)', () => {
    expect(parsed.read).toBe(278);
    expect(parsed.valid).toHaveLength(278);
    expect(parsed.invalid).toEqual([]);
    expect(parsed.duplicates).toEqual([]);
    expect(parsed.warnings).toEqual([]);
  });

  it('overrides: 8 nofaol (sababi review_note), 7 teskari, 3 izohli faol', () => {
    const inactive = parsed.valid.filter((q) => !q.active).map((q) => q.externalId).sort();
    expect(inactive).toEqual(Object.keys(overrides.inactive).sort());
    expect(byId.get('PARVOZ-Q061')?.reviewNote).toBe(overrides.inactive['PARVOZ-Q061']);
    expect(parsed.valid.filter((q) => q.reverse).map((q) => q.externalId)).toEqual([...overrides.reverse]);
    for (const id of ['PARVOZ-Q050', 'PARVOZ-Q210', 'PARVOZ-Q211']) {
      expect(byId.get(id)).toMatchObject({ active: true, reviewNote: overrides.reviewNotes[id] });
    }
    expect(parsed.valid.filter((q) => q.reviewNote !== null)).toHaveLength(11);
  });

  it('scoring teglari: 17 xavfsizlik bilimi (signal), 15 Career Lab RIASEC; kalitlar tartibi saqlanadi', () => {
    const knowledge = parsed.valid.filter((q) => q.scoring?.signal === 'knowledge');
    expect(knowledge.map((q) => q.externalId)).toEqual([...overrides.knowledge]);
    expect(knowledge.every((q) => q.category === 'safety')).toBe(true);
    const coded = parsed.valid.filter((q) => q.scoring?.riasec !== undefined);
    expect(coded).toHaveLength(15);
    expect(coded.every((q) => q.category === 'career_lab')).toBe(true);
    expect(Object.keys(byId.get('PARVOZ-Q131')!.scoring!)).toEqual(['method', 'direction', 'note', 'signal']);
    expect(byId.get('PARVOZ-Q194')!.scoring).toEqual({
      method: 'reflection_rating',
      dimension: 'career_lab_enjoyment',
      min: 1,
      max: 5,
      riasec: 'R',
    });
    // Holat savoli — teg yo'q (standart `distress`).
    expect(byId.get('PARVOZ-Q127')!.scoring).not.toHaveProperty('signal');
  });

  it('required qoidasi: career_lab_5 (20) va text (12) ixtiyoriy', () => {
    const optional = parsed.valid.filter((q) => !q.required);
    expect(optional).toHaveLength(32);
    expect(new Set(optional.map((q) => q.answerType))).toEqual(new Set(['career_lab_5', 'text']));
  });

  it('matn va variantlar {uz} shaklida; text turida variant va scoring yo\'q', () => {
    const q1 = byId.get('PARVOZ-Q001')!;
    expect(q1.text).toEqual({ uz: jsonQuestion.question_text });
    // review-overrides.json `scaleLabels`: "-mi?" savolga mos o'zbekcha yorliq, qiymat o'zgarmaydi.
    expect(q1.options[3]).toEqual({ value: 4, label: { uz: 'Ha, juda' } });
    expect(byId.get('PARVOZ-Q099')!.options.map((o) => o.label.uz)).toEqual(['Yo‘q', 'Ko‘proq yo‘q', 'Ba’zan', 'Ko‘proq ha', 'Ha']);
    expect(byId.get('PARVOZ-Q193')!.options[4]).toEqual({ value: 5, label: { uz: 'Juda yoqdi' } });
    expect(q1.scoring).toEqual(jsonQuestion.scoring);
    expect(q1.sourceType).toBe('parvoz_original');
    const text = byId.get('PARVOZ-Q247')!;
    expect(text).toMatchObject({ answerType: 'text', options: [], scoring: null, required: false });
  });

  it('overrides\'siz — hammasi faol, teskari yo\'q', () => {
    const plain = parseKelajakBank(rawBank);
    expect(plain.valid.every((q) => q.active && !q.reverse && q.reviewNote === null)).toBe(true);
    // JSON'dagi asl yorliqlar overrides'siz o'zgarmaydi.
    expect(plain.valid[0].options[3]).toEqual({ value: 4, label: { uz: 'Juda yoqadi' } });
  });
});

describe('kelajak bank — yozuv validatsiyasi', () => {
  it('admin formati: uch tilli matn, standart manba, required qoidasi', () => {
    const r = parseKelajakQuestion(adminQuestion);
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    expect(r.value).toMatchObject({
      externalId: 'ADMIN-1A2B3C4D',
      category: 'learning',
      text: { uz: 'Darsda savol berish senga osonmi?', ru: 'Легко ли тебе задавать вопросы на уроке?' },
      required: true,
      reverse: false,
      active: true,
      ...ADMIN_SOURCE,
    });
    const optional = parseKelajakQuestion({ ...adminQuestion, externalId: undefined, required: false });
    expect(optional.ok && optional.value).toMatchObject({ externalId: null, required: false });
  });

  it('admin: matn turi variantsiz', () => {
    const r = parseKelajakQuestion({
      ...adminQuestion,
      category: 'child_voice',
      answerType: 'text',
      options: [],
      scoring: null,
    });
    expect(r.ok && r.value).toMatchObject({ answerType: 'text', required: false, options: [] });
  });

  it('overrides admin yozuviga ham id bo\'yicha qo\'llanadi', () => {
    const r = parseKelajakQuestion(adminQuestion, {
      ...NO_OVERRIDES,
      inactive: { 'ADMIN-1A2B3C4D': 'sabab' },
      reverse: ['ADMIN-1A2B3C4D'],
      knowledge: ['ADMIN-1A2B3C4D'],
    });
    expect(r.ok && r.value).toMatchObject({
      active: false,
      reverse: true,
      reviewNote: 'sabab',
      scoring: { method: 'simple_sum', min: 1, max: 5, signal: 'knowledge' },
    });
  });

  it('scoring oq ro\'yxati: ma\'lum maydonlar qabul qilinadi, nusxa qaytadi', () => {
    const scoring = { method: 'support_signal', direction: 'review_needed', note: 'Signal only.', signal: 'distress' };
    const r = parseKelajakQuestion({ ...adminQuestion, category: 'wellbeing', scoring });
    expect(r.ok && r.value.scoring).toEqual(scoring);
    expect(r.ok && r.value.scoring).not.toBe(scoring);
    const lab = parseKelajakQuestion({
      ...adminQuestion,
      category: 'career_lab',
      answerType: 'career_lab_5',
      scoring: { method: 'reflection_rating', riasec: 'C', min: 1, max: 5 },
    });
    expect(lab.ok && lab.value).toMatchObject({ required: false, scoring: { riasec: 'C' } });
  });

  it('ochiq javobli savol majburiy bo\'lmaydi (aniq required: true — rad etiladi)', () => {
    const base = { ...adminQuestion, category: 'child_voice', answerType: 'text', options: [], scoring: null };
    const r = parseKelajakQuestion({ ...base, required: true });
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toMatch(/required/);
    expect(parseKelajakQuestion({ ...base, required: false }).ok).toBe(true);
  });

  it.each([
    [{ id: 'parvoz q1' }, /externalId/],
    [{ id: 'AB' }, /externalId/],
    [{ category_id: 'astrology' }, /category/],
    [{ age_group: '5-6' }, /ageGroup/],
    [{ answer_type: 'slider' }, /answerType/],
    [{ question_text: '' }, /text\.uz/],
    [{ question_text: 'x'.repeat(501) }, /500/],
    [{ options: [{ value: 1, label: 'a' }] }, /options/],
    [{ options: Array.from({ length: 11 }, (_, i) => ({ value: i, label: `v${i}` })) }, /options/],
    [{ options: [{ value: 1, label: 'a' }, { value: 1, label: 'b' }] }, /takror/],
    [{ options: [{ value: 1.5, label: 'a' }, { value: 2, label: 'b' }] }, /butun/],
    [{ options: [{ value: 1, label: '' }, { value: 2, label: 'b' }] }, /label\.uz/],
    [{ scoring: { method: 'dimension_sum', min: 1, max: 4 } }, /RIASEC/],
    [{ scoring: null }, /RIASEC/],
    [{ scoring: { dimension: 'R', min: 1, max: 5 } }, /scoring\.max/],
    [{ scoring: 'R' }, /scoring/],
    [{ active: 'yes' }, /active/],
    [{ follow_up: 'x'.repeat(501) }, /followUp/],
    [{ source_type: '' }, /sourceType/],
  ])('noto\'g\'ri bank yozuvi: %j', (patch, error) => {
    const r = parseKelajakQuestion({ ...jsonQuestion, ...patch });
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toMatch(error);
  });

  it.each([
    [{ answerType: 'text' }, /text turida variant/],
    [{ answerType: 'text', options: [] }, /scoring/],
    [{ scoring: { method: 'simple_sum', extra: 1 } }, /scoring\.extra: noma'lum/],
    [{ scoring: { method: 'simple_sum', note: { uz: 'ichma-ich' } } }, /scoring\.note/],
    [{ scoring: { method: 'magic' } }, /scoring\.method/],
    [{ scoring: { min: 1.5 } }, /scoring\.min/],
    [{ scoring: { signal: 'panic' } }, /scoring\.signal/],
    [{ scoring: { riasec: 'X' } }, /scoring\.riasec/],
    [{ scoring: { note: 'x'.repeat(201) } }, /scoring\.note/],
    [{ reverse: 1 }, /reverse/],
    [{ required: 'no' }, /required/],
    [{ text: { ru: 'только ru' } }, /text\.uz/],
  ])('noto\'g\'ri admin yozuvi: %j', (patch, error) => {
    const r = parseKelajakQuestion({ ...adminQuestion, ...patch });
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toMatch(error);
  });

  it('obyekt bo\'lmagan yozuv', () => {
    expect(parseKelajakQuestion(null).ok).toBe(false);
    expect(parseKelajakQuestion([jsonQuestion]).ok).toBe(false);
  });
});

describe('kelajak bank — butun fayl', () => {
  const [q1, q2, q3] = rawBank.questions;

  it('fayldagi dublikat: birinchisi olinadi, qolganlari hisobotda', () => {
    const parsed = parseKelajakBank([q1, q2, { ...q1, question_text: 'Boshqa matn?' }]);
    expect(parsed.valid.map((q) => q.externalId)).toEqual(['PARVOZ-Q001', 'PARVOZ-Q002']);
    expect(parsed.valid[0].text.uz).toBe(q1.question_text);
    expect(parsed.duplicates).toEqual([{ externalId: 'PARVOZ-Q001', indexes: [0, 2] }]);
  });

  it('xato yozuvlar ro\'yxati, total_questions va matn dublikati ogohlantirishi', () => {
    const parsed = parseKelajakBank({
      total_questions: 5,
      questions: [q1, { ...q2, age_group: '19-21' }, { ...q3, id: 'PARVOZ-Q999', question_text: q1.question_text, age_group: q1.age_group }],
    });
    expect(parsed.read).toBe(3);
    expect(parsed.invalid).toEqual([{ index: 1, externalId: 'PARVOZ-Q002', error: expect.stringMatching(/ageGroup/) }]);
    expect(parsed.warnings).toEqual([
      expect.stringMatching(/total_questions/),
      expect.stringMatching(/PARVOZ-Q999.*PARVOZ-Q001/),
      expect.stringMatching(/ID ketma-ketligi: PARVOZ-Q002 dan keyin PARVOZ-Q999/),
    ]);
  });

  it('overrides\'dagi yo\'q id — faqat shu bank uchun yozilgan bo\'lsa ogohlantiriladi', () => {
    const partial = parseKelajakBank({ questions: [rawBank.questions[60]] }, overrides);
    expect(partial.warnings.length).toBe(49);
    expect(parseKelajakBank([q1], overrides).warnings).toEqual([]);
  });

  it('yaxlitlik: answer_scales, categories, statistics, scoring va ID ketma-ketligi ogohlantiriladi', () => {
    const questions = rawBank.questions.map((q, i) => {
      if (i === 0) return { ...q, options: (q.options as unknown[]).slice().reverse() };
      if (i === 1) return { ...q, category: 'Boshqa nom' };
      if (i === 2) return { ...q, scoring: undefined, category_id: 'learning', category: 'Fanlar va o‘rganish tajribasi' };
      return q;
    });
    const withGap = [...questions.slice(0, 10), ...questions.slice(11)];
    const warnings = parseKelajakBank({ ...rawBank, questions: withGap, total_questions: 277 }).warnings;
    expect(warnings).toEqual(
      expect.arrayContaining([
        'PARVOZ-Q001: variantlar answer_scales.interest_4 bilan mos emas',
        'PARVOZ-Q002: kategoriya nomi categories bilan mos emas',
        expect.stringMatching(/^categories\.career_interest: e'lon qilingan 60, faylda 58$/),
        expect.stringMatching(/^statistics\.by_category\.learning: e'lon qilingan 24, faylda 25$/),
        expect.stringMatching(/^statistics\.by_age_group\.13-15: e'lon qilingan 69, faylda 68$/),
        'PARVOZ-Q003: scoring yo\'q',
        'ID ketma-ketligi: PARVOZ-Q010 dan keyin PARVOZ-Q012',
      ]),
    );
  });

  it('tuzilma noto\'g\'ri — Error', () => {
    expect(() => parseKelajakBank({ items: [] })).toThrow(/questions/);
    expect(() => parseKelajakBank('[]')).toThrow(/questions/);
  });
});

describe('review overrides', () => {
  it('haqiqiy fayl', () => {
    expect(Object.keys(overrides.inactive)).toHaveLength(8);
    expect(Object.keys(overrides.reviewNotes)).toHaveLength(3);
    expect(overrides.reverse).toHaveLength(7);
    expect(overrides.knowledge).toHaveLength(17);
    expect(Object.keys(overrides.careerLab)).toHaveLength(15);
    expect(parseReviewOverrides({})).toEqual({ ok: true, value: NO_OVERRIDES });
  });

  it.each([
    [null, /obyekt/],
    [{ inactive: ['PARVOZ-Q001'] }, /inactive/],
    [{ reviewNotes: { 'PARVOZ-Q001': '' } }, /reviewNotes/],
    [{ reverse: 'PARVOZ-Q156' }, /reverse/],
    [{ reverse: [156] }, /reverse/],
    [{ knowledge: 'PARVOZ-Q131' }, /knowledge/],
    [{ careerLab: ['PARVOZ-Q194'] }, /careerLab/],
    [{ careerLab: { 'PARVOZ-Q194': 'X' } }, /careerLab\.PARVOZ-Q194/],
  ])('noto\'g\'ri: %j', (raw, error) => {
    const r = parseReviewOverrides(raw);
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toMatch(error);
  });
});
