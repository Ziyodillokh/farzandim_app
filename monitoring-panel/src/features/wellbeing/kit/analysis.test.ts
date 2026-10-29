import { describe, expect, it } from 'vitest';

import { distinctExtremeGrades, extremeAllBy, extremeBy, extremeGrades, gradeRangeKeys, meanOf, niceScale, niceStep, oneIn } from './analysis';

describe('meanOf', () => {
  it('ignores null and non-finite values', () => {
    expect(meanOf([2, null, 4, undefined, Number.NaN])).toBe(3);
  });

  it('returns null when nothing is valid', () => {
    expect(meanOf([null, undefined])).toBeNull();
  });
});

describe('extremeGrades', () => {
  const bullying = [
    { grade: 1, value: 7.2 },
    { grade: 5, value: 9.2 },
    { grade: 6, value: 13.2 },
    { grade: 7, value: 13.2 },
    { grade: 8, value: 13.2 },
    { grade: 9, value: 10.2 },
  ];

  it('groups the consecutive grades that share the maximum', () => {
    expect(extremeGrades(bullying, 'max')).toEqual({ from: 6, to: 8, value: 13.2 });
  });

  it('returns a single grade for a unique minimum', () => {
    expect(extremeGrades(bullying, 'min')).toEqual({ from: 1, to: 1, value: 7.2 });
  });

  it('stops the run at a gap in grades', () => {
    const gapped = [
      { grade: 2, value: 5 },
      { grade: 4, value: 5 },
    ];
    expect(extremeGrades(gapped, 'max')).toEqual({ from: 2, to: 2, value: 5 });
  });

  it('returns null when every value is missing', () => {
    expect(extremeGrades([{ grade: 1, value: null }], 'max')).toBeNull();
  });
});

describe('distinctExtremeGrades', () => {
  it('keeps an extreme that stands out from other grades', () => {
    expect(distinctExtremeGrades([{ grade: 9, value: 96.5 }, { grade: 10, value: 95.4 }, { grade: 11, value: 95.4 }], 'min')).toEqual({ from: 10, to: 11, value: 95.4 });
  });

  it('drops the extreme when every graded value is equal', () => {
    expect(distinctExtremeGrades([{ grade: 1, value: null }, { grade: 10, value: 68 }, { grade: 11, value: 68 }], 'min')).toBeNull();
  });
});

describe('gradeRangeKeys', () => {
  it('lists every grade in the range as a key', () => {
    expect([...gradeRangeKeys({ from: 6, to: 8 })]).toEqual(['6', '7', '8']);
  });

  it('is empty without a range', () => {
    expect(gradeRangeKeys(null).size).toBe(0);
  });
});

describe('extremeBy', () => {
  const days = [
    { day: 1, value: 95.9 },
    { day: 6, value: 95.1 },
    { day: 3, value: null },
  ];

  it('finds the lowest item and skips nulls', () => {
    expect(extremeBy(days, (d) => d.value, 'min')).toEqual({ day: 6, value: 95.1 });
  });

  it('finds the highest item', () => {
    expect(extremeBy(days, (d) => d.value, 'max')).toEqual({ day: 1, value: 95.9 });
  });

  it('returns null for an empty list', () => {
    expect(extremeBy([], () => 1, 'max')).toBeNull();
  });
});

describe('extremeAllBy', () => {
  const types = [
    { type: 'STATE', value: 96.6 },
    { type: 'PRIVATE', value: 97.7 },
    { type: 'SPECIAL', value: 96.6 },
    { type: 'OTHER', value: null },
  ];

  it('returns every item that ties for the extreme', () => {
    expect(extremeAllBy(types, (x) => x.value, 'min')).toEqual({ items: [types[0], types[2]], value: 96.6 });
  });

  it('returns a single winner when there is no tie', () => {
    expect(extremeAllBy(types, (x) => x.value, 'max')?.items.map((x) => x.type)).toEqual(['PRIVATE']);
  });

  it('returns null when nothing has a value', () => {
    expect(extremeAllBy([{ value: null }], (x) => x.value, 'max')).toBeNull();
  });
});

describe('niceStep', () => {
  it('rounds up to 1, 2, 2.5 or 5 times a power of ten', () => {
    expect(niceStep(0.75)).toBe(1);
    expect(niceStep(1.5)).toBe(2);
    expect(niceStep(2.2)).toBe(2.5);
    expect(niceStep(12)).toBe(20);
    expect(niceStep(0.03)).toBe(0.05);
  });

  it('skips fractional steps for integer metrics', () => {
    expect(niceStep(2.25, true)).toBe(5);
    expect(niceStep(0.4, true)).toBe(1);
  });

  it('falls back to 1 for invalid input', () => {
    expect(niceStep(0)).toBe(1);
    expect(niceStep(Number.NaN)).toBe(1);
  });
});

describe('niceScale', () => {
  const evenlySpaced = (ticks: number[]) => ticks.every((t, i) => i === 0 || Math.abs(t - ticks[i - 1]! - (ticks[1]! - ticks[0]!)) < 1e-9);

  it('keeps close attendance rates readable without exaggerating them', () => {
    const scale = niceScale([95.1, 96.6, 96.5], { minSpan: 4 })!;
    expect(scale.domain[0]).toBeLessThanOrEqual(93);
    expect(scale.domain[1]).toBeGreaterThanOrEqual(96.6);
    expect(scale.ticks).toHaveLength(5);
    expect(evenlySpaced(scale.ticks)).toBe(true);
  });

  it('produces integer ticks for an index trend', () => {
    const scale = niceScale([67, 70, 69], { minSpan: 6, integer: true })!;
    expect(scale.ticks.every(Number.isInteger)).toBe(true);
    expect(scale.domain[0]).toBeLessThanOrEqual(67);
    expect(scale.domain[1]).toBeGreaterThanOrEqual(70);
  });

  it('starts at zero for shares', () => {
    const scale = niceScale([7.2, 13.2], { zero: true })!;
    expect(scale.domain[0]).toBe(0);
    expect(scale.domain[1]).toBeGreaterThanOrEqual(13.2);
  });

  it('never goes below the floor', () => {
    expect(niceScale([0.4, 1.2], { minSpan: 5 })!.domain[0]).toBe(0);
  });

  it('handles identical values', () => {
    const scale = niceScale([70, 70])!;
    expect(scale.domain[0]).toBeLessThan(70);
    expect(scale.domain[1]).toBeGreaterThan(70);
  });

  it('returns null without data', () => {
    expect(niceScale([null])).toBeNull();
  });
});

describe('oneIn', () => {
  it('turns a share into "one in N"', () => {
    expect(oneIn(25.7)).toBe(4);
    expect(oneIn(9.8)).toBe(10);
  });

  it('is null for tiny or invalid shares', () => {
    expect(oneIn(0.5)).toBeNull();
    expect(oneIn(null)).toBeNull();
    expect(oneIn(140)).toBeNull();
  });
});
