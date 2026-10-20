// JSON test eksport/import (qat'iy sxema, `__proto__` himoyasi, 200 KB) va
// natijalarni CSV'dan import (qator holatlari, tashqi test bir marta, dublikatlar).

import { addDays, tashkentDay } from '../../src/common/time/tashkent';
import { resetDb } from './db';
import { AssessWorld, buildWorld, childApi, publishedAssignment, sampleInput, staffApi } from './school-assessments-fixtures';
import { createTestApp, TestApp } from './test-app';

const HEADER = 'studentCode;test;date;raw';
const envelope = (test: unknown, extra: Record<string, unknown> = {}) => JSON.stringify({ format: 'parvoz.psych-test', formatVersion: 1, test, ...extra });
const firstItem = () => sampleInput().items[0]!;
const dotted = (iso: string) => `${iso.slice(8, 10)}.${iso.slice(5, 7)}.${iso.slice(0, 4)}`;

describe('School assessments — JSON va CSV import', () => {
  let t: TestApp;
  let w: AssessWorld;
  let api: ReturnType<typeof staffApi>;
  const importJson = (json: unknown) => api(w.psych, 'POST', '/tests/import', { json });

  beforeAll(async () => {
    t = await createTestApp();
    api = staffApi(t);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    w = await buildWorld(t);
  });

  afterAll(() => t.close());

  it('eksport → import: IMPORTED qoralama, kalitlar panel tartibida', async () => {
    const env = (await api(w.psych, 'GET', '/tests/tpl-attention/export')).json();
    expect(env).toMatchObject({ format: 'parvoz.psych-test', formatVersion: 1, exportedAt: expect.any(String) });
    const imported = (await importJson(JSON.stringify(env, null, 2))).json();
    expect(imported).toMatchObject({ source: 'IMPORTED', status: 'DRAFT', version: 1, basedOn: null, createdBy: w.psych.staffId });
    expect(imported.items).toHaveLength(14);
    const own = (await api(w.psych, 'GET', `/tests/${imported.id}/export`)).json();
    expect(Object.keys(own.test)).toEqual(['title', 'description', 'instructions', 'kind', 'grades', 'timeLimitMin', 'scales', 'items', 'scoring', 'norms']);
    expect(Object.keys(own.test.items[0])).toEqual(['id', 'type', 'scale', 'text', 'options', 'correct']);
    const audit = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'assessments.test.import' } });
    expect(audit.params).toEqual({ count: 14, title: 'Diqqat va xotira' });
  });

  it.each([
    ['buzilgan JSON', '{"format": ', 'file: assessments.validation.jsonParse'],
    ['massiv', '[]', null],
    ['noto\'g\'ri format', JSON.stringify({ format: 'other', formatVersion: 1, test: sampleInput() }), null],
    ['noma\'lum versiya', JSON.stringify({ format: 'parvoz.psych-test', formatVersion: 2, test: sampleInput() }), null],
    ['konvertda ortiqcha maydon', envelope(sampleInput(), { hack: true }), null],
    ['testda ortiqcha maydon', envelope({ ...sampleInput(), id: 'x' }), null],
    ['savolda ortiqcha maydon', envelope(sampleInput({ items: [{ ...firstItem(), extra: 1 }] })), null],
    ['noma\'lum shkala', envelope(sampleInput({ items: [{ ...firstItem(), scale: 'nope' }] })), 'test.items.0.scale: assessments.validation.unknownScale'],
    ['to\'g\'ri javob variantlarda yo\'q', envelope(sampleInput({ items: [{ ...firstItem(), correct: 'z' }] })), 'test.items.0.correct: assessments.validation.correct'],
    ['variant kalitlari takrorlangan', envelope(sampleInput({ items: [{ ...firstItem(), options: [{ key: 'a', text: { uz: 'x', ru: 'x' } }, { key: 'a', text: { uz: 'y', ru: 'y' } }] }] })), 'test.items.0.options.1.key: assessments.validation.duplicateKey'],
    ['sd = 0', envelope(sampleInput({ norms: { total: [{ band: 'A7_8', mean: 1, sd: 0 }] } })), 'test.norms.total.0.sd: assessments.validation.sd'],
    ['me\'yor — noma\'lum shkala', envelope(sampleInput({ norms: { other: [{ band: 'A7_8', mean: 1, sd: 1 }] } })), 'test.norms.other: assessments.validation.unknownScale'],
    ['matn 300 belgidan uzun', envelope(sampleInput({ description: { uz: 'x'.repeat(301), ru: 'x' } })), 'test.description.uz: errors.form.tooLong'],
    ['8 tadan ortiq shkala', envelope(sampleInput({ scales: Array.from({ length: 9 }, (_, i) => ({ ...sampleInput().scales[0], key: `s${i}` })) })), 'test.scales: errors.form.tooLong'],
    ['60 tadan ortiq savol', envelope(sampleInput({ items: Array.from({ length: 61 }, (_, i) => ({ ...firstItem(), id: `q${i}` })) })), 'test.items: errors.form.tooLong'],
    ['8 tadan ortiq variant', envelope(sampleInput({ items: [{ ...firstItem(), options: Array.from({ length: 9 }, (_, i) => ({ key: `o${i}`, text: { uz: 'x', ru: 'x' } })) }] })), 'test.items.0.options: assessments.validation.options'],
    ['noto\'g\'ri kalit', envelope(sampleInput({ scales: [{ ...sampleInput().scales[0], key: '1bad' }] })), 'test.scales.0.key: assessments.validation.key'],
    ['meros xossa kalit', envelope(sampleInput({ norms: { toString: [{ band: 'A7_8', mean: 1, sd: 1 }] } })), 'test.norms.toString: assessments.validation.key'],
    ['satr emas', 42, 'file: assessments.validation.jsonTooLarge'],
  ])('%s → VALIDATION', async (_name, json, message) => {
    const res = await importJson(json);
    expect(res.json().code).toBe('VALIDATION');
    if (message) expect(res.json().message).toBe(message);
  });

  it('__proto__ / constructor kalitlari rad etiladi, prototip buzilmaydi, hech narsa saqlanmaydi', async () => {
    const json = envelope(sampleInput()).replace('"norms":{', '"norms":{"__proto__":[{"band":"A7_8","mean":1,"sd":1}],');
    expect(json).toContain('__proto__');
    expect((await importJson(json)).json()).toEqual({ statusCode: 400, code: 'VALIDATION', message: 'test.norms.__proto__: assessments.validation.key' });
    const ctor = envelope(sampleInput()).replace('"title":{', '"title":{"constructor":{"prototype":{"band":1}},');
    expect((await importJson(ctor)).json().message).toBe('test.title.constructor: assessments.validation.key');
    expect(({} as Record<string, unknown>).band).toBeUndefined();

    const raw = JSON.stringify(sampleInput()).replace('"norms":{', '"norms":{"__proto__":{"polluted":true},');
    const created = await t.app.inject({
      method: 'POST',
      url: '/api/school/assessments/tests',
      payload: raw,
      headers: { authorization: `Bearer ${w.psych.token}`, 'content-type': 'application/json' },
    });
    expect(created.json().message).toBe('norms.__proto__: assessments.validation.key');
    const norms = await api(w.psych, 'PUT', '/tests/tpl-logic/norms', JSON.parse('{"norms":{"__proto__":{"total":[]}}}'));
    expect(norms.json().message).toBe('__proto__: assessments.validation.key');
    expect(({} as Record<string, unknown>).polluted).toBeUndefined();
    expect(await t.prisma.schoolPsychTest.count()).toBe(0);
  });

  it('200 KB dan katta fayl rad etiladi', async () => {
    const big = envelope(sampleInput(), { exportedAt: '' }).replace('"exportedAt":""', `"exportedAt":"${' '.repeat(200 * 1024)}"`);
    expect((await importJson(big)).json()).toMatchObject({ code: 'VALIDATION', message: 'file: assessments.validation.jsonTooLarge' });
  });

  it.each([
    ['sarlavha noto\'g\'ri', 'code;test;date;raw\nP-1;tpl-logic;2026-10-01;5', 'header: assessments.validation.csvHeader'],
    ['noto\'g\'ri shkala ustuni', `${HEADER};memory\nP-1;tpl-logic;2026-10-01;5;1`, 'header: assessments.validation.csvHeader'],
    ['ma\'lumot yo\'q', `${HEADER}\n`, 'file: assessments.validation.csvEmpty'],
    ['2000 qatordan ko\'p', `${HEADER}\n${'P-1;tpl-logic;2026-10-01;5\n'.repeat(2001)}`, 'file: assessments.validation.csvTooManyRows'],
    ['512 KB dan katta', `${HEADER}\n${'x'.repeat(512 * 1024)}`, 'file: assessments.validation.csvTooLarge'],
  ])('CSV: %s → VALIDATION', async (_name, text, message) => {
    expect((await api(w.psych, 'POST', '/results/csv/preview', { text })).json()).toMatchObject({ code: 'VALIDATION', message });
  });

  it('CSV: har qator — OK / ERROR / DUPLICATE va sabab', async () => {
    const c = w.kids7a[0]!.studentCode;
    const today = tashkentDay();
    const d = (n: number) => addDays(today, -n);
    const text = [
      `${HEADER};scale:memory`,
      `${c};tpl-logic;${d(19)};9;`,
      `${c};tpl-logic;${dotted(d(19))};10;`,
      `P-0000;tpl-logic;${d(19)};9;`,
      `${c};tpl-logic;31.02.2026;9;`,
      `${c};tpl-logic;${addDays(today, 40)};9;`,
      `${c};tpl-logic;${d(1400)};9;`,
      `${c};tpl-logic;${d(18)};17;`,
      `${c};tpl-logic;${d(17)};8.5;`,
      `${c};tpl-logic;${d(16)};abc;`,
      `${c};tpl-attention;${d(19)};5;`,
      `${c};tpl-attention;${d(18)};5;6`,
      `${c};tpl-logic;${d(15)};5;3`,
      `${c};Qog'oz test;${d(30)};87.5;`,
      `${c};Qog'oz test;${d(29)};1001;`,
    ].join('\n');
    const p = (await api(w.psych, 'POST', '/results/csv/preview', { text })).json();
    expect(p.rows.map((r: { line: number; status: string; reason: string | null }) => [r.line, r.status, r.reason])).toEqual([
      [2, 'OK', null],
      [3, 'DUPLICATE', 'DUPLICATE_FILE'],
      [4, 'ERROR', 'STUDENT_NOT_FOUND'],
      [5, 'ERROR', 'BAD_DATE'],
      [6, 'ERROR', 'DATE_RANGE'],
      [7, 'ERROR', 'DATE_RANGE'],
      [8, 'ERROR', 'RAW_RANGE'],
      [9, 'ERROR', 'BAD_RAW'],
      [10, 'ERROR', 'BAD_RAW'],
      [11, 'ERROR', 'MISSING_SCALE'],
      [12, 'OK', null],
      [13, 'ERROR', 'UNKNOWN_SCALE'],
      [14, 'OK', null],
      [15, 'ERROR', 'RAW_RANGE'],
    ]);
    expect(p.counts).toEqual({ OK: 3, ERROR: 10, DUPLICATE: 1 });
    expect(p.newTests).toEqual(['Qog\'oz test']);
    expect(p.rows[10]).toMatchObject({ raw: { attention: 5, memory: 6 }, studentName: 'Alfaov Alfa0', className: '7-A', testTitle: 'Diqqat va xotira' });
    expect(p.rows[12]).toMatchObject({ newExternal: true, testTitle: 'Qog\'oz test', raw: { total: 87.5 } });
    expect(await t.prisma.schoolPsychResult.count()).toBe(0);
  });

  it('CSV: ilovadagi natija bilan bir xil kun — DUPLICATE_EXISTING', async () => {
    const { testId, assignment } = await publishedAssignment(t, w, [w.classes.c7a]);
    await childApi(t)(w.kids7a[0]!, 'POST', `/${assignment.id}/submit`, { answers: { q1: 'a' } });
    const p = (await api(w.psych, 'POST', '/results/csv/preview', { text: `${HEADER}\n${w.kids7a[0]!.studentCode};${testId};${tashkentDay()};3` })).json();
    expect(p.rows[0]).toMatchObject({ status: 'DUPLICATE', reason: 'DUPLICATE_EXISTING' });
  });

  it('CSV import: faqat OK qatorlar, tashqi test bir marta; me\'yor kiritilgach baholanadi', async () => {
    const day = addDays(tashkentDay(), -20);
    const text = [HEADER, `${w.kids7a[0]!.studentCode};Qog'oz test;${day};87`, `${w.kids7a[1]!.studentCode};qog'oz TEST;${day};91`, `P-0000;tpl-logic;${day};9`].join('\r\n');
    const res = (await api(w.psych, 'POST', '/results/csv/import', { text })).json();
    expect(res).toEqual({ created: 2, skipped: [{ line: 4, reason: 'STUDENT_NOT_FOUND' }] });
    const external = await t.prisma.schoolPsychTest.findMany();
    expect(external).toHaveLength(1);
    const tests = (await api(w.psych, 'GET', '/tests?source=EXTERNAL')).json();
    expect(tests).toHaveLength(1);
    expect(tests[0]).toMatchObject({ status: 'PUBLISHED', norms: {}, resultsCount: 2, title: { uz: 'Qog\'oz test', ru: 'Qog\'oz test' } });
    expect(tests[0].scales).toEqual([{ key: 'total', label: { uz: 'Umumiy ball', ru: 'Общий балл' }, domain: 'REASONING', polarity: 'HIGHER_BETTER', display: 'STANDARD' }]);
    expect((await api(w.psych, 'GET', `/tests/${tests[0].id}`)).json().readOnly).toBe(true);

    const again = (await api(w.psych, 'POST', '/results/csv/preview', { text })).json();
    expect(again.rows.slice(0, 2).map((r: { reason: string }) => r.reason)).toEqual(['DUPLICATE_EXISTING', 'DUPLICATE_EXISTING']);
    expect(again.newTests).toEqual([]);

    const results = (await api(w.psych, 'GET', `/tests/${tests[0].id}/results`)).json();
    expect(results).toMatchObject({ needsNorms: true, scaleKey: 'total' });
    expect(results.rows).toHaveLength(2);
    expect(results.rows[0]).toMatchObject({ origin: 'IMPORT', takenAt: new Date(`${day}T09:00:00+05:00`).toISOString(), scales: [{ key: 'total', max: null, standard: null }] });
    expect((await api(w.psych, 'PUT', `/tests/${tests[0].id}/norms`, { norms: { total: [{ band: 'A13_14', mean: 87, sd: 4 }] } })).statusCode).toBe(204);
    const scored = (await api(w.psych, 'GET', `/tests/${tests[0].id}/results`)).json();
    expect(scored.needsNorms).toBe(false);
    expect(scored.rows.map((r: { scales: Array<{ standard: number }> }) => r.scales[0]!.standard).sort()).toEqual([100, 115]);

    const audit = await t.prisma.schoolAuditLog.findMany({ where: { module: 'ASSESSMENTS' }, orderBy: { at: 'asc' } });
    expect(audit.map((a) => [a.action, a.params])).toEqual([
      ['assessments.test.external', { count: 1 }],
      ['assessments.results.import', { count: 2 }],
      ['assessments.norms.update', { title: 'Qog\'oz test' }],
    ]);
    expect(JSON.stringify(audit)).not.toMatch(/Alfa|P-\d/);
  });
});
