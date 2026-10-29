import { describe, expect, it } from 'vitest';

import type { AreaMatrix, AreaRow, MetricKey, Stat } from '@/data/contracts';
import { areaExcess, columnMeans, findHotspots, rankProblems, sortAreaRows } from './problem-analysis';

const METRICS: readonly MetricKey[] = ['bullying', 'sleep', 'anxiety'];

const stat = (value: number | null, delta: number | null = null): Stat => ({ value, base: null, delta, n: 100 });

function row(id: string, values: Partial<Record<MetricKey, number | null>>): AreaRow {
  return {
    id,
    name: `Area ${id}`,
    official: 1000,
    covered: 800,
    values: Object.fromEntries(Object.entries(values).map(([k, v]) => [k, stat(v ?? null)])),
  };
}

const rows = [
  row('A', { bullying: 10, sleep: 20, anxiety: 15 }),
  row('B', { bullying: 12, sleep: 30, anxiety: 15 }),
  row('C', { bullying: 8, sleep: 25, anxiety: null }),
];

const matrix: AreaMatrix = {
  level: 'REGION',
  metrics: [...METRICS],
  scope: { bullying: stat(10, -0.4), sleep: stat(25.7, 0), anxiety: stat(14.9, 0) },
  rows,
};

describe('columnMeans', () => {
  it('averages each metric over the areas that have a value', () => {
    expect(columnMeans(rows, METRICS)).toEqual({ bullying: 10, sleep: 25, anxiety: 15 });
  });
});

describe('rankProblems', () => {
  it('orders signals by the scope value, most widespread first', () => {
    const ranked = rankProblems(matrix, METRICS);
    expect(ranked.map((r) => r.metric)).toEqual(['sleep', 'anxiety', 'bullying']);
    expect(ranked[0]?.peak).toEqual({ id: 'B', name: 'Area B', value: 30 });
    expect(ranked[2]?.delta).toBe(-0.4);
  });

  it('puts signals without data last', () => {
    const sparse: AreaMatrix = { ...matrix, scope: { ...matrix.scope, sleep: stat(null) } };
    expect(rankProblems(sparse, METRICS).at(-1)?.metric).toBe('sleep');
  });
});

describe('areaExcess', () => {
  it('sums the relative excess and keeps only notable signals', () => {
    const means = columnMeans(rows, METRICS);
    const b = areaExcess(rows[1]!, METRICS, means);
    expect(b.burden).toBeCloseTo(0.2 + 0.2, 6);
    expect(b.signals.map((s) => s.metric)).toEqual(['bullying', 'sleep']);
    expect(b.signals[0]?.diff).toBeCloseTo(2, 6);
  });

  it('ignores values at or below the average', () => {
    const means = columnMeans(rows, METRICS);
    expect(areaExcess(rows[0]!, METRICS, means)).toEqual({ burden: 0, aboveCount: 0, signals: [] });
  });
});

describe('findHotspots', () => {
  it('returns areas with notable excess, highest burden first', () => {
    const hot = findHotspots(matrix, METRICS);
    expect(hot.map((h) => h.id)).toEqual(['B']);
    expect(hot[0]?.aboveCount).toBe(2);
  });

  it('respects the limit', () => {
    expect(findHotspots(matrix, METRICS, 0)).toEqual([]);
  });
});

describe('sortAreaRows', () => {
  it('keeps the official order', () => {
    expect(sortAreaRows(rows, METRICS, 'official').map((r) => r.id)).toEqual(['A', 'B', 'C']);
  });

  it('sorts by a single signal, highest first, nulls last', () => {
    expect(sortAreaRows(rows, METRICS, 'anxiety').map((r) => r.id)).toEqual(['A', 'B', 'C']);
    expect(sortAreaRows(rows, METRICS, 'bullying').map((r) => r.id)).toEqual(['B', 'A', 'C']);
  });

  it('sorts by the combined burden', () => {
    expect(sortAreaRows(rows, METRICS, 'burden')[0]?.id).toBe('B');
  });

  it('does not mutate the input', () => {
    const copy = [...rows];
    sortAreaRows(rows, METRICS, 'bullying');
    expect(rows).toEqual(copy);
  });
});
