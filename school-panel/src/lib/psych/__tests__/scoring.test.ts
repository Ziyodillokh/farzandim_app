import { describe, expect, it } from 'vitest';

import type { PsychTest } from '@/data/contracts';
import {
  type AnswerVector,
  abilityBand,
  ageBandOf,
  ageOn,
  concernBand,
  decodeAnswers,
  domainIndex,
  encodeAnswers,
  likertScore,
  maxRaw,
  minRaw,
  normFor,
  rawScores,
  scoreResult,
  toPercentile,
  toStandard,
  topCodes,
  zScore,
} from '../scoring';
import { previousTerms, termOf } from '../terms';

const L = (s: string) => ({ uz: s, ru: s });
const TEST: Pick<PsychTest, 'items' | 'scales' | 'norms' | 'kind'> = {
  kind: 'CUSTOM',
  scales: [
    { key: 'logic', label: L('l'), domain: 'REASONING', polarity: 'HIGHER_BETTER', display: 'STANDARD' },
    { key: 'worry', label: L('w'), domain: 'EMOTIONAL', polarity: 'HIGHER_CONCERN', display: 'LEVEL' },
    { key: 'R', label: L('r'), domain: null, polarity: 'HIGHER_BETTER', display: 'RAW' },
    { key: 'I', label: L('i'), domain: null, polarity: 'HIGHER_BETTER', display: 'RAW' },
  ],
  items: [
    { id: 'q1', type: 'SINGLE', scale: 'logic', text: L('?'), options: [{ key: 'a', text: L('a') }, { key: 'b', text: L('b') }], correct: 'b' },
    { id: 'q2', type: 'SINGLE', scale: 'logic', text: L('?'), options: [{ key: 'a', text: L('a') }, { key: 'b', text: L('b') }], correct: 'a' },
    { id: 'q3', type: 'LIKERT', scale: 'worry', text: L('?'), reverse: false },
    { id: 'q4', type: 'LIKERT', scale: 'worry', text: L('?'), reverse: true },
    { id: 'q5', type: 'MULTI', text: L('?'), options: [{ key: 'x', text: L('x'), scale: 'R' }, { key: 'y', text: L('y'), scale: 'I' }, { key: 'z', text: L('z'), scale: 'R' }] },
  ],
  norms: { logic: [{ band: 'A11_12', mean: 1, sd: 0.5 }], worry: [{ band: 'A11_12', mean: 5, sd: 1 }] },
};

describe('standart ball va persentil', () => {
  it('z → 100±15, 55..145 oralig\'ida', () => {
    expect(toStandard(0)).toBe(100);
    expect(toStandard(1)).toBe(115);
    expect(toStandard(4)).toBe(145);
    expect(toStandard(-4)).toBe(55);
    expect(zScore(12, { mean: 10, sd: 2 })).toBe(1);
    expect(() => zScore(1, { mean: 0, sd: 0 })).toThrow();
  });
  it('persentil normal taqsimot bo\'yicha, 1..99', () => {
    expect(toPercentile(0)).toBe(50);
    expect(toPercentile(1)).toBe(84);
    expect(toPercentile(-1)).toBe(16);
    expect(toPercentile(2)).toBe(98);
    expect(toPercentile(5)).toBe(99);
    expect(toPercentile(-5)).toBe(1);
  });
  it('bandlar chegaralari', () => {
    expect([69, 70, 84, 85, 114, 115, 129, 130].map(abilityBand)).toEqual(['VERY_LOW', 'LOW', 'LOW', 'AVERAGE', 'AVERAGE', 'HIGH', 'HIGH', 'VERY_HIGH']);
    expect([114, 115, 129, 130].map(concernBand)).toEqual(['TYPICAL', 'WATCH', 'WATCH', 'SUPPORT']);
  });
});

describe('xom ball', () => {
  it('teskari Likert va chegaralar', () => {
    expect(likertScore(1, true)).toBe(5);
    expect(likertScore(5, true)).toBe(1);
    expect(likertScore(3, true)).toBe(3);
    expect(() => likertScore(6, false)).toThrow();
  });
  it('SINGLE, LIKERT (teskari) va MULTI bo\'yicha shkala yig\'indilari', () => {
    expect(rawScores(TEST, ['b', 'b', 4, 2, [0, 2]])).toEqual({ logic: 1, worry: 8, R: 2, I: 0 });
    expect(rawScores(TEST, [null, null, null, null, null])).toEqual({ logic: 0, worry: 0, R: 0, I: 0 });
    expect(maxRaw(TEST, 'logic')).toBe(2);
    expect(maxRaw(TEST, 'worry')).toBe(10);
    expect(minRaw(TEST, 'worry')).toBe(2);
    expect(maxRaw(TEST, 'R')).toBe(2);
  });
  it('javoblar ixcham kodlanadi va qaytariladi', () => {
    const answers: AnswerVector = ['b', null, 4, 2, [0, 2]];
    const code = encodeAnswers(TEST, answers);
    expect(code).toHaveLength(5);
    expect(decodeAnswers(TEST, code)).toEqual(['b', null, 4, 2, [0, 2]]);
  });
  it('kasbiy kod: eng yuqori 3 ta, tenglikda RIASEC tartibi', () => {
    expect(topCodes({ R: 2, I: 5, A: 5, S: 1, E: 0, C: 3 })).toBe('IAC');
    expect(topCodes({})).toBe('RIA');
  });
});

describe('yosh, me\'yor va natija', () => {
  it('yosh va yosh bandi', () => {
    expect(ageOn('2014-10-13', '2026-10-12')).toBe(11);
    expect(ageOn('2014-10-12', '2026-10-12')).toBe(12);
    expect([8, 9, 10, 11, 12, 13, 14, 15].map(ageBandOf)).toEqual(['A7_8', 'A9_10', 'A9_10', 'A11_12', 'A11_12', 'A13_14', 'A13_14', 'A15_17']);
  });
  it('me\'yor: aniq band, bo\'lmasa eng yaqini', () => {
    expect(normFor(TEST.norms, 'logic', 'A11_12')?.mean).toBe(1);
    expect(normFor(TEST.norms, 'logic', 'A15_17')?.band).toBe('A11_12');
    expect(normFor(TEST.norms, 'nope', 'A11_12')).toBeNull();
  });
  it('natija: STANDARD, LEVEL (concern) va RAW shkalalar', () => {
    const r = scoreResult(TEST, { raw: { logic: 2, worry: 7, R: 2, I: 1 }, ageBand: 'A11_12' });
    const logic = r.scales.find((s) => s.key === 'logic');
    const worry = r.scales.find((s) => s.key === 'worry');
    const R = r.scales.find((s) => s.key === 'R');
    expect(logic?.standard).toBe(130);
    expect(logic?.band).toBe('VERY_HIGH');
    expect(worry?.band).toBe('SUPPORT');
    expect(R?.standard).toBeNull();
    expect(domainIndex({ percentile: 84 }, 'HIGHER_CONCERN')).toBe(16);
  });
});

describe('o\'quv choraklari', () => {
  it('chorak, ta\'til va yoz', () => {
    expect(termOf('2026-10-12').key).toBe('2026-27:Q1');
    expect(termOf('2026-11-05').key).toBe('2026-27:Q1');
    expect(termOf('2027-02-01').key).toBe('2026-27:Q3');
    expect(termOf('2026-07-15').key).toBe('2025-26:Q4');
  });
  it('oldingi 3 chorak (eskidan yangiga)', () => {
    expect(previousTerms('2026-10-12', 3).map((t) => t.key)).toEqual(['2025-26:Q2', '2025-26:Q3', '2025-26:Q4']);
  });
});
