import { describe, expect, it } from 'vitest';

import { csvHeader, csvNumber, csvStamp } from './csv';

describe('csvNumber', () => {
  it('uses a decimal comma and no grouping', () => {
    expect(csvNumber(9.2)).toBe('9,2');
    expect(csvNumber(460922)).toBe('460922');
  });

  it('uses the typographic minus so the formula guard does not prefix an apostrophe', () => {
    expect(csvNumber(-0.3)).toBe('−0,3');
  });

  it('leaves missing values empty', () => {
    expect(csvNumber(null)).toBe('');
    expect(csvNumber(undefined)).toBe('');
    expect(csvNumber(Number.NaN)).toBe('');
  });
});

describe('csvStamp', () => {
  it('formats a local date', () => {
    expect(csvStamp(new Date(2026, 9, 3))).toBe('2026-10-03');
  });
});

describe('csvHeader', () => {
  it('adds the unit to the header', () => {
    expect(csvHeader('bullying', 'Bulling signali', 'daq')).toBe('Bulling signali, %');
    expect(csvHeader('screenTime', 'Ekran vaqti', 'daq')).toBe('Ekran vaqti, daq');
    expect(csvHeader('wellbeing', 'Farovonlik', 'daq')).toBe('Farovonlik');
  });
});
