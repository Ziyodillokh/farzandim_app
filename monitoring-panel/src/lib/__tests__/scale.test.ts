import { describe, expect, it } from 'vitest';

import { csvMetricHeader, csvNumber } from '../csv';
import { niceScale } from '../scale';

describe('niceScale', () => {
  it('foiz o\'qi 100 dan oshmaydi, ma\'lumot ichida qoladi', () => {
    for (const values of [[94, 99], [98.7, 99.4], [96.2, 97.4, 95.7], [90, 99.9]]) {
      const s = niceScale(values, { minSpan: 4, ceil: 100 });
      expect(s).not.toBeNull();
      expect(s!.domain[1]).toBeLessThanOrEqual(100);
      expect(s!.domain[0]).toBeLessThanOrEqual(Math.min(...values));
      expect(s!.domain[1]).toBeGreaterThanOrEqual(Math.max(...values));
    }
  });

  it('`zero` — o\'q 0 dan boshlanadi, belgilar teng qadamli', () => {
    const s = niceScale([5, 20], { zero: true })!;
    expect(s.domain[0]).toBe(0);
    const steps = s.ticks.slice(1).map((t, i) => t - s.ticks[i]!);
    expect(new Set(steps.map((x) => x.toFixed(6))).size).toBe(1);
  });

  it('qiymat yo\'q — null', () => {
    expect(niceScale([null, null])).toBeNull();
  });
});

describe('csv yordamchilari', () => {
  it('son: vergul, oddiy minus, kasr xonasi', () => {
    expect(csvNumber(-0.25, 1)).toBe('-0,3');
    expect(csvNumber(460922)).toBe('460922');
    expect(csvNumber(Number.NaN)).toBe('');
  });

  it('sarlavha birlik bilan', () => {
    expect(csvMetricHeader('screenTime', 'Ekran vaqti', 'daq')).toBe('Ekran vaqti, daq');
    expect(csvMetricHeader('wellbeing', 'Farovonlik', 'daq')).toBe('Farovonlik');
  });
});
