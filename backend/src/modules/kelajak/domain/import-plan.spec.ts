import { parseImportArgs } from '../../../../scripts/kelajak/import-bank';
import { KELAJAK_OVERRIDES_FILE } from '../../../../scripts/kelajak/build-bank-migration';
import { KelajakQuestionData, ParsedBank } from './bank';
import {
  ExistingKelajakQuestion,
  formatImportReport,
  planKelajakImport,
  stableJson,
} from './import-plan';

const question = (externalId: string | null, patch: Partial<KelajakQuestionData> = {}): KelajakQuestionData => ({
  externalId,
  category: 'learning',
  ageGroup: '10-12',
  text: { uz: `Savol ${externalId}?` },
  answerType: 'likert_5',
  options: [1, 2, 3, 4, 5].map((value) => ({ value, label: { uz: `V${value}` } })),
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
  ...patch,
});

/** Bazadagi ko'rinish: JSON ustunlari kalitlari boshqa tartibda (JSONB). */
const existing = (
  q: KelajakQuestionData,
  answerCount = 0,
  adminEdited = false,
  id = `db-${q.externalId}`,
): ExistingKelajakQuestion => ({
  ...q,
  scoring: q.scoring && Object.fromEntries(Object.entries(q.scoring).reverse()),
  id,
  externalId: q.externalId!,
  answerCount,
  adminEdited,
});

describe('kelajak import plan', () => {
  it('stableJson: kalitlar tartibidan qat\'i nazar bir xil', () => {
    expect(stableJson({ b: 1, a: [{ y: 2, x: null }] })).toBe(stableJson({ a: [{ x: null, y: 2 }], b: 1 }));
    expect(stableJson(undefined)).toBe('null');
    expect(stableJson({ a: undefined })).toBe('{}');
  });

  it('--update\'siz: yangilari yaratiladi, mavjudlari o\'tkazib yuboriladi', () => {
    const plan = planKelajakImport({
      questions: [question('Q-1'), question('Q-2', { text: { uz: 'Yangi?' } }), question(null)],
      existing: [existing(question('Q-2'))],
      update: false,
    });
    expect(plan.create.map((q) => q.externalId)).toEqual(['Q-1']);
    expect(plan.update).toEqual([]);
    expect(plan.skipped).toEqual([
      { externalId: 'Q-2', reason: 'exists' },
      { externalId: null, reason: 'no_external_id' },
    ]);
  });

  it('--update: faqat o\'zgargan maydonlar; o\'zgarishsizi o\'tkaziladi', () => {
    const plan = planKelajakImport({
      questions: [question('Q-1', { text: { uz: 'Yangi?' }, active: false }), question('Q-2')],
      existing: [existing(question('Q-1')), existing(question('Q-2'))],
      update: true,
    });
    expect(plan.update).toEqual([
      { id: 'db-Q-1', externalId: 'Q-1', fields: ['text', 'active'], changes: { text: { uz: 'Yangi?' }, active: false } },
    ]);
    expect(plan.skipped).toEqual([{ externalId: 'Q-2', reason: 'unchanged' }]);
    expect(plan.locked).toEqual([]);
  });

  it('javob berilgan savol: answerType/options/category/ageGroup/scoring bloklanadi', () => {
    const changed = question('Q-1', {
      answerType: 'frequency_5',
      category: 'school_quality',
      ageGroup: '13-15',
      options: [1, 2, 3, 4].map((value) => ({ value, label: { uz: `F${value}` } })),
      scoring: { method: 'simple_sum', min: 1, max: 4 },
      text: { uz: 'Tuzatilgan matn?' },
    });
    const plan = planKelajakImport({ questions: [changed], existing: [existing(question('Q-1'), 3)], update: true });
    expect(plan.update).toEqual([
      { id: 'db-Q-1', externalId: 'Q-1', fields: ['text'], changes: { text: { uz: 'Tuzatilgan matn?' } } },
    ]);
    expect(plan.locked).toEqual([
      { externalId: 'Q-1', fields: ['category', 'ageGroup', 'answerType', 'options', 'scoring'] },
    ]);
  });

  it('javobsiz savolda tuzilma ham yangilanadi; faqat bloklangan o\'zgarish — o\'zgarishsiz', () => {
    const changed = question('Q-1', { ageGroup: '13-15' });
    const free = planKelajakImport({ questions: [changed], existing: [existing(question('Q-1'))], update: true });
    expect(free.update[0].fields).toEqual(['ageGroup']);
    const used = planKelajakImport({ questions: [changed], existing: [existing(question('Q-1'), 1)], update: true });
    expect(used.update).toEqual([]);
    expect(used.skipped).toEqual([{ externalId: 'Q-1', reason: 'unchanged' }]);
    expect(used.locked).toEqual([{ externalId: 'Q-1', fields: ['ageGroup'] }]);
  });

  it('javob berilgan savolda scoring (RIASEC) va reverse ham o\'zgarmaydi — admin bilan bir xil', () => {
    const base = question('Q-1', { category: 'career_interest', scoring: { method: 'dimension_sum', dimension: 'R', min: 1, max: 5 } });
    const changed = { ...base, scoring: { method: 'dimension_sum', dimension: 'I', min: 1, max: 5 }, reverse: true };
    const plan = planKelajakImport({ questions: [changed], existing: [existing(base, 40)], update: true });
    expect(plan.update).toEqual([]);
    expect(plan.skipped).toEqual([{ externalId: 'Q-1', reason: 'unchanged' }]);
    expect(plan.locked).toEqual([{ externalId: 'Q-1', fields: ['scoring', 'reverse'] }]);
    // Javobsiz savolda — yangilanadi.
    const free = planKelajakImport({ questions: [changed], existing: [existing(base)], update: true });
    expect(free.update[0].fields).toEqual(['scoring', 'reverse']);
  });

  it('admin tahrirlagan savol qayta yozilmaydi (matn, faollik, review izohi); --overwrite-admin-edits bilan — yoziladi', () => {
    // Admin Q061 matnini tuzatib, faollashtirgan; bank fayli eski matn va nofaol holatni beradi.
    const fixed = question('Q-61', { text: { uz: 'Tuzatilgan matn?' }, active: true, reviewNote: null });
    const fromFile = question('Q-61', { active: false, reviewNote: 'Ochiq savol' });
    const plan = planKelajakImport({ questions: [fromFile], existing: [existing(fixed, 12, true)], update: true });
    expect(plan.update).toEqual([]);
    expect(plan.skipped).toEqual([{ externalId: 'Q-61', reason: 'admin_edited' }]);
    expect(plan.adminEdited).toEqual([{ externalId: 'Q-61', fields: ['text', 'reviewNote', 'active'] }]);

    const forced = planKelajakImport({
      questions: [fromFile],
      existing: [existing(fixed, 12, true)],
      update: true,
      overwriteAdminEdits: true,
    });
    expect(forced.update[0].fields).toEqual(['text', 'reviewNote', 'active']);
    expect(forced.adminEdited).toEqual([]);
    // Fayl bilan bir xil admin savoli — oddiy "o'zgarishsiz".
    const same = planKelajakImport({ questions: [fixed], existing: [existing(fixed, 0, true)], update: true });
    expect(same.skipped).toEqual([{ externalId: 'Q-61', reason: 'unchanged' }]);
  });

  it('hisobot: barcha hisoblagichlar va ro\'yxatlar', () => {
    const parsed: ParsedBank = {
      read: 5,
      valid: [question('Q-1'), question('Q-2')],
      invalid: [{ index: 3, externalId: 'Q-4', error: 'ageGroup: noma\'lum (5-6)' }],
      duplicates: [{ externalId: 'Q-1', indexes: [0, 4] }],
      warnings: ['total_questions (6) savollar soniga (5) teng emas'],
    };
    const report = formatImportReport({
      file: 'bank.json',
      parsed,
      dryRun: true,
      plan: {
        create: [{ ...question('Q-1'), externalId: 'Q-1' }],
        update: [{ id: 'x', externalId: 'Q-2', fields: ['text'], changes: { text: { uz: 'a' } } }],
        skipped: [
          { externalId: 'Q-3', reason: 'exists' },
          { externalId: 'Q-5', reason: 'admin_edited' },
        ],
        locked: [{ externalId: 'Q-2', fields: ['options'] }],
        adminEdited: [{ externalId: 'Q-5', fields: ['text'] }],
      },
    });
    expect(report).toContain('bank.json (dry-run');
    for (const line of [
      /O'qildi:\s+5/,
      /Valid:\s+2/,
      /Xato:\s+1/,
      /Fayldagi dublikat:\s+1/,
      /Yaratildi:\s+1/,
      /Yangilandi:\s+1/,
      /O'tkazib yuborildi:\s+2 \(mavjud: 1, o'zgarishsiz: 0, externalId yo'q: 0, admin tahrirlagan: 1\)/,
      /Bloklangan \(javob bor\):\s+1/,
      /Admin tahrirlagan:\s+1/,
      /Q-5: admin tahrirlagan — qayta yozilmadi \(text\); kerak bo'lsa --overwrite-admin-edits/,
      /#3 Q-4: ageGroup/,
      /Q-1: #0, #4/,
      /Q-2: text/,
      /Q-2: options/,
      /total_questions/,
    ]) {
      expect(report).toMatch(line);
    }
  });
});

describe('import CLI parametrlari', () => {
  it('fayl, --update, --dry-run, --overrides, --overwrite-admin-edits', () => {
    expect(parseImportArgs(['bank.json'])).toEqual({
      file: 'bank.json',
      update: false,
      dryRun: false,
      overridesFile: KELAJAK_OVERRIDES_FILE,
      overwriteAdminEdits: false,
    });
    expect(
      parseImportArgs(['--dry-run', 'bank.json', '--update', '--overrides', 'o.json', '--overwrite-admin-edits']),
    ).toEqual({
      file: 'bank.json',
      update: true,
      dryRun: true,
      overridesFile: 'o.json',
      overwriteAdminEdits: true,
    });
  });

  it.each([[[]], [['a.json', 'b.json']], [['a.json', '--force']], [['a.json', '--overrides']]])(
    'noto\'g\'ri: %j',
    (argv) => {
      expect(() => parseImportArgs(argv)).toThrow();
    },
  );
});
