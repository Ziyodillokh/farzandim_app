import { describe, expect, it } from 'vitest';

import type { Subject } from '@/data/reference/domains';
import { type ChoiceInput, classifySubjects, ENGAGE_MARGIN, isUntaughtChoice, median, PRIORITY_MARGIN } from './subject-signal';

const s = (key: Subject, share: number | null, mastery: number | null): ChoiceInput => ({ key, share, mastery });

/**
 * Mediana: tanlov 40%, o'zlashtirish 66% (9 fan). Chegaralar: ko'p tanlanadigan
 * fan uchun 0,5 p.p., kam tanlanadigan uchun 3 p.p. — qat'iy "ko'proq past".
 */
const BASE: ChoiceInput[] = [
  s('MATH', 60, 66 - PRIORITY_MARGIN),
  s('NATIVE', 55, 65.4),
  s('BIOLOGY', 50, 70),
  s('GEOGRAPHY', 45, 71),
  s('ENGLISH', 40, 66),
  s('INFORMATICS', 35, 72),
  s('PHYSICS', 30, 73),
  s('RUSSIAN', 20, 66 - ENGAGE_MARGIN),
  s('HISTORY', 10, 62.9),
];

const signals = (rows: ReturnType<typeof classifySubjects>['rows']) => Object.fromEntries(rows.map((r) => [r.key, r.signal]));

describe('median', () => {
  it("toq va juft uzunlik; bo'sh — null; kirish massivi o'zgarmaydi", () => {
    const values = [3, 1, 2];
    expect(median(values)).toBe(2);
    expect(values).toEqual([3, 1, 2]);
    expect(median([4, 1, 3, 2])).toBe(2.5);
    expect(median([])).toBeNull();
  });
});

describe('classifySubjects', () => {
  it('medianalar: tanlov va o\'zlashtirish', () => {
    const { medianShare, medianMastery } = classifySubjects(BASE);
    expect(medianShare).toBe(40);
    expect(medianMastery).toBe(66);
  });

  it(`"resurs ustuvorligi": ko'p tanlanadi va medianadan ${PRIORITY_MARGIN} p.p. dan ko'proq past (chegaraning o'zi — signal emas)`, () => {
    const sig = signals(classifySubjects(BASE).rows);
    expect(sig.MATH).toBeNull(); // aynan 0,5 p.p. past
    expect(sig.NATIVE).toBe('priority'); // 0,6 p.p. past
    expect(sig.ENGLISH).toBeNull();
  });

  it(`"qiziqtirish kerak": kam tanlanadi va medianadan ${ENGAGE_MARGIN} p.p. dan ko'proq past (chegaraning o'zi — signal emas)`, () => {
    const sig = signals(classifySubjects(BASE).rows);
    expect(sig.RUSSIAN).toBeNull(); // aynan 3 p.p. past
    expect(sig.HISTORY).toBe('engage'); // 3,1 p.p. past
    expect(Object.values(sig).filter(Boolean)).toHaveLength(2);
  });

  it("tanlov bo'yicha kamayish tartibi; teng ulush — bir xil o'rin; kirish o'zgarmaydi", () => {
    const input = [s('MATH', 20, 60), s('NATIVE', 40, 61), s('ENGLISH', 20, 62)];
    const { rows } = classifySubjects(input);
    expect(rows.map((r) => [r.key, r.rank])).toEqual([
      ['NATIVE', 1],
      ['MATH', 2],
      ['ENGLISH', 2],
    ]);
    expect(input.map((r) => r.key)).toEqual(['MATH', 'NATIVE', 'ENGLISH']);
  });

  it("o'qitilmaydigan fan (tanlov 0, natija yo'q) — ro'yxatda ham, medianada ham yo'q", () => {
    const { rows, untaught, medianShare, medianMastery } = classifySubjects([...BASE, s('CHEMISTRY', 0, null)]);
    expect(untaught).toEqual(['CHEMISTRY']);
    expect(rows.some((r) => r.key === 'CHEMISTRY')).toBe(false);
    expect(medianShare).toBe(40);
    expect(medianMastery).toBe(66);
  });

  it("tanlovi 0, lekin natijasi bor fan — o'qitiladi (ro'yxatda qoladi)", () => {
    const row = s('CHEMISTRY', 0, 64);
    expect(isUntaughtChoice(row)).toBe(false);
    expect(classifySubjects([row]).untaught).toEqual([]);
  });

  it("ulushi yashirilgan fan (share: null) o'qitilmaydigan emas: oxirida, o'rinsiz va signalsiz, medianaga kirmaydi", () => {
    const hidden = s('CHEMISTRY', null, null);
    expect(isUntaughtChoice(hidden)).toBe(false);
    const { rows, untaught, medianShare } = classifySubjects([hidden, ...BASE]);
    expect(untaught).toEqual([]);
    expect(rows.at(-1)).toMatchObject({ key: 'CHEMISTRY', rank: null, signal: null });
    expect(medianShare).toBe(40);
  });

  it("natijasi yo'q fan — signal yo'q; bo'sh ro'yxat — bo'sh natija", () => {
    expect(signals(classifySubjects([...BASE, s('CHEMISTRY', 70, null)]).rows).CHEMISTRY).toBeNull();
    expect(classifySubjects([])).toEqual({ rows: [], untaught: [], medianShare: null, medianMastery: null });
  });
});
