import { describe, expect, it } from 'vitest';

import { csvNumber, gap, pctScale } from './num';

describe('pctScale (foiz o\'qi)', () => {
  it('100% dan oshmaydi, qiymatlar o\'q ichida (98,7–99,4 → [96; 100])', () => {
    const s = pctScale([98.7, 99.4]);
    expect(s).not.toBeNull();
    expect(s!.domain).toEqual([96, 100]);
  });

  it.each([[[94, 99]], [[99.9, 100]], [[100, 100]], [[63.6, 76.9, 67.2]], [[0.4, 1.2]], [[41.2, 53.6]]])('chegaralar va qamrov: %j', (values) => {
    const s = pctScale(values)!;
    expect(s.domain[0]).toBeGreaterThanOrEqual(0);
    expect(s.domain[1]).toBeLessThanOrEqual(100);
    expect(s.domain[0]).toBeLessThanOrEqual(Math.min(...values));
    expect(s.domain[1]).toBeGreaterThanOrEqual(Math.max(...values));
  });

  it("qadamlar butun va teng (o'qda \"67,5%\" kabi belgilar yo'q), 5 ta belgi", () => {
    for (const values of [[65.5, 69], [62.7, 70.7, 67.2], [41.2, 53.6], [70, 70]]) {
      const { ticks } = pctScale(values)!;
      expect(ticks).toHaveLength(5);
      expect(ticks.every((t) => Number.isInteger(t))).toBe(true);
      const steps = new Set(ticks.slice(1).map((t, i) => t - ticks[i]!));
      expect(steps.size).toBe(1);
    }
  });

  it("kichik o'zgarish bo'rttirilmaydi: oraliq kamida 4 p.p.", () => {
    const s = pctScale([70.2, 70.4])!;
    expect(s.domain[1] - s.domain[0]).toBeGreaterThanOrEqual(4);
  });

  it("null/undefined e'tiborsiz; qiymat yo'q — null", () => {
    expect(pctScale([null, undefined])).toBeNull();
    expect(pctScale([])).toBeNull();
    expect(pctScale([null, 50, undefined])).not.toBeNull();
  });
});

describe('gap', () => {
  it('bir kasr xonasi bilan; biri yo\'q — null', () => {
    expect(gap(70.26, 68.1)).toBe(2.2);
    expect(gap(60, 63.5)).toBe(-3.5);
    expect(gap(null, 1)).toBeNull();
    expect(gap(1, undefined)).toBeNull();
  });
});

describe('csvNumber', () => {
  it("standart — 1 kasr xonasi, o'nlik vergul; yo'q qiymat — bo'sh", () => {
    expect(csvNumber(67.25)).toBe('67,3');
    expect(csvNumber(100, 0)).toBe('100');
    expect(csvNumber(null)).toBe('');
  });
});
