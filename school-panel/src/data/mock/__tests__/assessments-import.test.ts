import { beforeEach, describe, expect, it } from 'vitest';

import { PSYCH_LIMITS } from '@/data/schemas/assessments';
import { getTables } from '../db';
import { assessmentsService as svc } from '../services/assessments';
import { sampleInput } from './assessments-fixtures';
import { freshDb, loginAs } from './helpers';

const HEADER = 'studentCode;test;date;raw';

function envelope(test: unknown, extra: Record<string, unknown> = {}): string {
  return JSON.stringify({ format: 'parvoz.psych-test', formatVersion: 1, test, ...extra });
}

function code(classId = 'cls-7a', index = 0): string {
  const s = getTables().students.filter((x) => x.classId === classId)[index];
  if (!s) throw new Error(classId);
  return s.studentCode;
}

describe('JSON test importi', () => {
  beforeEach(() => {
    freshDb();
    loginAs('PSYCHOLOGIST');
  });

  it('eksport → import: IMPORTED qoralama', async () => {
    const json = await svc.exportTest('tpl-attention');
    expect(JSON.parse(json)).toMatchObject({ format: 'parvoz.psych-test', formatVersion: 1 });
    const imported = await svc.importTest(json);
    expect(imported).toMatchObject({ source: 'IMPORTED', status: 'DRAFT', version: 1, basedOn: null });
    expect(imported.items).toHaveLength(14);
  });

  it.each([
    ['buzilgan JSON', '{"format": '],
    ['massiv', '[]'],
    ['noto\'g\'ri format', JSON.stringify({ format: 'other', formatVersion: 1, test: sampleInput() })],
    ['noma\'lum versiya', JSON.stringify({ format: 'parvoz.psych-test', formatVersion: 2, test: sampleInput() })],
    ['konvertda ortiqcha maydon', envelope(sampleInput(), { hack: true })],
    ['testda ortiqcha maydon', envelope({ ...sampleInput(), id: 'x' })],
    ['savolda ortiqcha maydon', envelope(sampleInput({ items: [{ ...sampleInput().items[0], extra: 1 } as never] }))],
    ['noma\'lum shkala', envelope(sampleInput({ items: [{ ...sampleInput().items[0], scale: 'nope' } as never] }))],
    ['to\'g\'ri javob variantlarda yo\'q', envelope(sampleInput({ items: [{ ...sampleInput().items[0], correct: 'z' } as never] }))],
    ['variant kalitlari takrorlangan', envelope(sampleInput({ items: [{ ...sampleInput().items[0], options: [{ key: 'a', text: { uz: 'x', ru: 'x' } }, { key: 'a', text: { uz: 'y', ru: 'y' } }] } as never] }))],
    ['sd = 0', envelope(sampleInput({ norms: { total: [{ band: 'A7_8', mean: 1, sd: 0 }] } }))],
    ['me\'yor — noma\'lum shkala', envelope(sampleInput({ norms: { other: [{ band: 'A7_8', mean: 1, sd: 1 }] } }))],
    ['matn 300 belgidan uzun', envelope(sampleInput({ description: { uz: 'x'.repeat(301), ru: 'x' } }))],
    ['8 tadan ortiq shkala', envelope(sampleInput({ scales: Array.from({ length: 9 }, (_, i) => ({ ...sampleInput().scales[0], key: `s${i}` })) as never }))],
    ['60 tadan ortiq savol', envelope(sampleInput({ items: Array.from({ length: 61 }, (_, i) => ({ ...sampleInput().items[0], id: `q${i}` })) as never }))],
    ['8 tadan ortiq variant', envelope(sampleInput({ items: [{ ...sampleInput().items[0], options: Array.from({ length: 9 }, (_, i) => ({ key: `o${i}`, text: { uz: 'x', ru: 'x' } })) } as never] }))],
    ['noto\'g\'ri kalit', envelope(sampleInput({ scales: [{ ...sampleInput().scales[0], key: '1bad' }] as never }))],
  ])('%s → VALIDATION', async (_name, json) => {
    await expect(svc.importTest(json)).rejects.toMatchObject({ code: 'VALIDATION' });
  });

  it('__proto__ kaliti rad etiladi va prototip buzilmaydi', async () => {
    const json = envelope(sampleInput()).replace('"norms":{', '"norms":{"__proto__":[{"band":"A7_8","mean":1,"sd":1}],');
    expect(json).toContain('__proto__');
    await expect(svc.importTest(json)).rejects.toMatchObject({ code: 'VALIDATION' });
    expect(({} as Record<string, unknown>).band).toBeUndefined();
  });

  it('200 KB dan katta fayl rad etiladi', async () => {
    const big = envelope(sampleInput(), { exportedAt: '' }).replace('"exportedAt":""', `"exportedAt":"${' '.repeat(PSYCH_LIMITS.jsonBytes)}"`);
    await expect(svc.importTest(big)).rejects.toMatchObject({ code: 'VALIDATION', message: expect.stringContaining('jsonTooLarge') });
  });
});

describe('Natijalarni CSV\'dan import qilish', () => {
  beforeEach(() => {
    freshDb();
    loginAs('PSYCHOLOGIST');
  });

  it.each([
    ['sarlavha noto\'g\'ri', 'code;test;date;raw\nP-1;tpl-logic;2026-10-01;5'],
    ['noto\'g\'ri shkala ustuni', `${HEADER};memory\nP-1;tpl-logic;2026-10-01;5;1`],
    ['ma\'lumot yo\'q', `${HEADER}\n`],
    ['2000 qatordan ko\'p', `${HEADER}\n${'P-1;tpl-logic;2026-10-01;5\n'.repeat(PSYCH_LIMITS.csvRows + 1)}`],
    ['512 KB dan katta', `${HEADER}\n${'x'.repeat(PSYCH_LIMITS.csvBytes)}`],
  ])('%s → VALIDATION', async (_name, text) => {
    await expect(svc.previewResultsCsv(text)).rejects.toMatchObject({ code: 'VALIDATION' });
  });

  it('har qator: OK / ERROR / DUPLICATE va sabab', async () => {
    const c = code();
    const text = [
      `${HEADER};scale:memory`,
      `${c};tpl-logic;2026-10-01;9;`,
      `${c};tpl-logic;01.10.2026;10;`,
      `P-0000;tpl-logic;2026-10-01;9;`,
      `${c};tpl-logic;31.02.2026;9;`,
      `${c};tpl-logic;2026-12-01;9;`,
      `${c};tpl-logic;2023-01-01;9;`,
      `${c};tpl-logic;2026-10-02;17;`,
      `${c};tpl-logic;2026-10-03;8.5;`,
      `${c};tpl-logic;2026-10-04;abc;`,
      `${c};tpl-attention;2026-10-01;5;`,
      `${c};tpl-attention;2026-10-02;5;6`,
      `${c};tpl-logic;2026-10-05;5;3`,
      `${c};Qog'oz test;2026-09-20;87.5;`,
      `${c};Qog'oz test;2026-09-21;1001;`,
    ].join('\n');
    const p = await svc.previewResultsCsv(text);
    const reasons = p.rows.map((r) => [r.line, r.status, r.reason]);
    expect(reasons).toEqual([
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
    expect(p.rows[10]?.raw).toEqual({ attention: 5, memory: 6 });
  });

  it('mavjud natija bilan bir xil kun — DUPLICATE_EXISTING', async () => {
    const seeded = getTables().psychResults.find((r) => r.assignmentId === 'pa-1');
    const student = getTables().students.find((s) => s.id === seeded?.studentId);
    const text = `${HEADER}\n${student?.studentCode};tpl-logic;${seeded?.takenAt.slice(0, 10)};8`;
    const p = await svc.previewResultsCsv(text);
    expect(p.rows[0]).toMatchObject({ status: 'DUPLICATE', reason: 'DUPLICATE_EXISTING' });
  });

  it('import faqat OK qatorlarni yozadi, tashqi test bir marta yaratiladi', async () => {
    const before = getTables().psychResults.length;
    const text = [HEADER, `${code('cls-7a', 0)};Qog'oz test;2026-09-20;87`, `${code('cls-7a', 1)};qog'oz TEST;2026-09-20;91`, `P-0000;tpl-logic;2026-10-01;9`].join('\r\n');
    const res = await svc.importResultsCsv(text);
    expect(res).toEqual({ created: 2, skipped: [{ line: 4, reason: 'STUDENT_NOT_FOUND' }] });
    const t = getTables();
    expect(t.psychResults.length).toBe(before + 2);
    const external = t.psychTests.filter((x) => x.source === 'EXTERNAL');
    expect(external).toHaveLength(1);
    expect(external[0]).toMatchObject({ status: 'PUBLISHED', norms: {}, scales: [{ key: 'total', display: 'STANDARD', domain: 'REASONING' }] });
    const again = await svc.previewResultsCsv(text);
    expect(again.rows.slice(0, 2).map((r) => r.reason)).toEqual(['DUPLICATE_EXISTING', 'DUPLICATE_EXISTING']);
    expect(again.newTests).toEqual([]);
    const res2 = await svc.resultsByTest(external[0]?.id ?? '');
    expect(res2.rows).toHaveLength(2);
    expect(res2.needsNorms).toBe(true);
  });
});
