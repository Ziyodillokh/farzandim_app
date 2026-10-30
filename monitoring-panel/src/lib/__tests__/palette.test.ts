import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';

import { describe, expect, it } from 'vitest';

import { buildScale, scaleIndex } from '../color-scale';
import { csvDecimal, escapeCsvCell } from '../csv';

const SRC = resolve(__dirname, '../..');

function files(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return name === '__tests__' ? [] : files(path);
    return /\.(tsx?|css)$/.test(name) ? [path] : [];
  });
}

describe('dizayn qoidalari', () => {
  it('binafsha ranglar ishlatilmaydi (purple / violet / fuchsia)', () => {
    const offenders = files(SRC).filter((f) => /\b(purple|violet|fuchsia)-\d{2,3}\b/.test(readFileSync(f, 'utf8')));
    expect(offenders).toEqual([]);
  });

  it('kvantil shkala: reyting bo\'yicha 5 guruh, "kam — yaxshi" teskari', () => {
    const values = [10, 20, 30, 40, 50];
    const up = buildScale(values, 'up', 30);
    expect(values.map((v) => scaleIndex(v, up))).toEqual([0, 1, 2, 3, 4]);
    const down = buildScale(values, 'down', 30);
    expect(values.map((v) => scaleIndex(v, down))).toEqual([4, 3, 2, 1, 0]);
  });

  it('CSV raqamlari: o\'nlik vergul, bo\'sh qiymat — bo\'sh katak', () => {
    expect(csvDecimal(67.25, 1)).toBe('67,3');
    expect(csvDecimal(null, 1)).toBeNull();
  });

  it('CSV formula himoyasi: formula bloklanadi, manfiy son esa son bo\'lib qoladi', () => {
    expect(escapeCsvCell('=SUM(A1:A2)')).toBe("'=SUM(A1:A2)");
    expect(escapeCsvCell('-cmd')).toBe("'-cmd");
    expect(escapeCsvCell('@x')).toBe("'@x");
    expect(escapeCsvCell('-0,3')).toBe('-0,3');
    expect(escapeCsvCell(-12)).toBe('-12');
    expect(escapeCsvCell('a;b')).toBe('"a;b"');
  });
});
