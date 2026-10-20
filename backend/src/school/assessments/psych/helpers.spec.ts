// Backend yordamchilari: CSV o'qish, prototip himoyasi, kanonik JSON,
// meros xossalar me'yor sifatida o'qilmasligi.

import { canonicalJson } from './catalog';
import { parseCsv } from './csv';
import { findUnsafeJson, MAX_JSON_DEPTH } from './safe-json';
import { normFor } from './scoring';

describe('parseCsv (panel bilan bir xil)', () => {
  it('`;` ajratuvchi, BOM, CRLF, qo\'shtirnoqlar va bo\'sh qatorlar', () => {
    const text = '﻿studentCode;test;date;raw\r\nP-1;"Qog\'oz; test";2026-10-01;5\r\n\r\n;;;\nP-2;"a ""b""";01.10.2026;7';
    expect(parseCsv(text)).toEqual([
      ['studentCode', 'test', 'date', 'raw'],
      ['P-1', 'Qog\'oz; test', '2026-10-01', '5'],
      ['P-2', 'a "b"', '01.10.2026', '7'],
    ]);
  });

  it('`,` ajratuvchi — birinchi qatorda vergul ko\'p bo\'lsa', () => {
    expect(parseCsv('a,b,c\n1,2,3')).toEqual([
      ['a', 'b', 'c'],
      ['1', '2', '3'],
    ]);
  });
});

describe('findUnsafeJson', () => {
  it('`__proto__` / `constructor` / `prototype` istalgan chuqurlikda topiladi', () => {
    expect(findUnsafeJson(JSON.parse('{"test":{"norms":{"__proto__":[1]}}}'))).toEqual({ path: ['test', 'norms', '__proto__'], reason: 'key' });
    expect(findUnsafeJson({ items: [{ options: [{ constructor: 1 }] }] })).toEqual({ path: ['items', 0, 'options', 0, 'constructor'], reason: 'key' });
    expect(findUnsafeJson({ a: { prototype: {} } })?.reason).toBe('key');
    expect(findUnsafeJson({ title: { uz: '__proto__' }, items: [] })).toBeNull();
    expect(({} as Record<string, unknown>).band).toBeUndefined();
  });

  it('juda chuqur tuzilma rad etiladi (stek to\'lmaydi)', () => {
    const deep = JSON.parse(`${'['.repeat(5000)}1${']'.repeat(5000)}`) as unknown;
    expect(findUnsafeJson(deep)?.reason).toBe('depth');
    let ok: unknown = 1;
    for (let i = 0; i < MAX_JSON_DEPTH; i++) ok = [ok];
    expect(findUnsafeJson(ok)).toBeNull();
  });
});

describe('canonicalJson', () => {
  it('kalit tartibiga bog\'liq emas (JSONB)', () => {
    expect(canonicalJson({ b: 1, a: [{ y: 2, x: 1 }] })).toBe(canonicalJson({ a: [{ x: 1, y: 2 }], b: 1 }));
    expect(canonicalJson([1, 2])).not.toBe(canonicalJson([2, 1]));
  });
});

describe('normFor — faqat o\'z kalitlari', () => {
  it('meros xossa (constructor, toString) me\'yor sifatida o\'qilmaydi', () => {
    expect(normFor({}, 'constructor', 'A11_12')).toBeNull();
    expect(normFor({}, 'toString', 'A11_12')).toBeNull();
    expect(normFor({ total: [{ band: 'A9_10', mean: 1, sd: 1 }] }, 'total', 'A11_12')?.band).toBe('A9_10');
  });
});
