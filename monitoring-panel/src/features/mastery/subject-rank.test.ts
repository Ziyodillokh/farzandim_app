import { describe, expect, it } from 'vitest';

import type { SubjectStat } from '@/data/contracts';
import type { Subject } from '@/data/reference/domains';
import { isUntaught, rankSubjects, splitTaught, subjectHighlights } from './subject-rank';

function row(subject: Subject, value: number | null, patch: Partial<SubjectStat> = {}): SubjectStat {
  return { subject, value, base: null, delta: null, n: value === null ? 0 : 120, interest: value === null ? null : 30, success: null, national: null, ...patch };
}

describe('rankSubjects', () => {
  it("bo'sh ro'yxat — bo'sh natija", () => {
    expect(rankSubjects([])).toEqual([]);
  });

  it("qiymatli fan yo'q — hammasi o'rinsiz va belgisiz", () => {
    const ranked = rankSubjects([row('MATH', null, { n: 6 }), row('PHYSICS', null)]);
    expect(ranked.map((r) => [r.rank, r.tag])).toEqual([
      [null, null],
      [null, null],
    ]);
  });

  it("bitta qiymatli fan — 1-o'rin, lekin \"eng yuqori/eng past\" belgisi yo'q", () => {
    const ranked = rankSubjects([row('MATH', null, { n: 6 }), row('NATIVE', 70)]);
    expect(ranked[0]).toMatchObject({ subject: 'NATIVE', rank: 1, tag: null });
    expect(ranked[1]).toMatchObject({ subject: 'MATH', rank: null, tag: null });
  });

  it("kamayish tartibida; qiymatsizlar oxirida; kirish massivi o'zgarmaydi", () => {
    const input = [row('MATH', 60), row('NATIVE', null, { n: 4 }), row('ENGLISH', 75), row('HISTORY', 68)];
    const snapshot = input.map((r) => r.subject);
    const ranked = rankSubjects(input);
    expect(ranked.map((r) => r.subject)).toEqual(['ENGLISH', 'HISTORY', 'MATH', 'NATIVE']);
    expect(ranked.map((r) => r.tag)).toEqual(['top', null, 'bottom', null]);
    expect(input.map((r) => r.subject)).toEqual(snapshot);
  });

  it("teng qiymatlar — bir xil o'rin (1, 1, 3) va ikkalasi ham belgilanadi", () => {
    const ranked = rankSubjects([row('MATH', 70), row('NATIVE', 70), row('ENGLISH', 60), row('HISTORY', 60)]);
    expect(ranked.map((r) => r.rank)).toEqual([1, 1, 3, 3]);
    expect(ranked.map((r) => r.tag)).toEqual(['top', 'top', 'bottom', 'bottom']);
  });

  it("hamma qiymat teng — belgilar yo'q (eng yuqori ham, e'tibor ham emas)", () => {
    const ranked = rankSubjects([row('MATH', 66.3), row('NATIVE', 66.3)]);
    expect(ranked.map((r) => r.rank)).toEqual([1, 1]);
    expect(ranked.every((r) => r.tag === null)).toBe(true);
  });

  it('respublika bilan farq — bir kasr xonasi; respublika yo\'q — null', () => {
    const ranked = rankSubjects([row('MATH', 65.2, { national: 66.1 }), row('NATIVE', 70)]);
    expect(ranked.find((r) => r.subject === 'MATH')?.vsNational).toBe(-0.9);
    expect(ranked.find((r) => r.subject === 'NATIVE')?.vsNational).toBeNull();
  });
});

describe('subjectHighlights', () => {
  it("o'sish yo'q (hamma o'zgarish ≤ 0 yoki null) — eng tez o'sish ko'rsatilmaydi", () => {
    const h = subjectHighlights(rankSubjects([row('MATH', 70, { delta: 0 }), row('NATIVE', 65, { delta: -1.2 }), row('ENGLISH', 60)]));
    expect(h.fastest).toBeUndefined();
    expect(h.strongest?.subject).toBe('MATH');
    expect(h.weakest?.subject).toBe('ENGLISH');
  });

  it("eng tez o'sish — eng katta musbat o'zgarish", () => {
    const h = subjectHighlights(rankSubjects([row('MATH', 70, { delta: 0.4 }), row('NATIVE', 65, { delta: 1.7 })]));
    expect(h.fastest?.subject).toBe('NATIVE');
  });

  it("bitta fan yoki teng natijalar — \"e'tibor talab\" fan yo'q", () => {
    expect(subjectHighlights(rankSubjects([row('MATH', 70)])).weakest).toBeUndefined();
    expect(subjectHighlights(rankSubjects([row('MATH', 70), row('NATIVE', 70)])).weakest).toBeUndefined();
    expect(subjectHighlights([])).toEqual({ strongest: undefined, weakest: undefined, fastest: undefined, lagging: undefined });
  });

  it('respublikadan ortda — faqat salbiy farq, eng kattasi', () => {
    const h = subjectHighlights(rankSubjects([row('MATH', 70, { national: 69 }), row('NATIVE', 65, { national: 66 }), row('ENGLISH', 60, { national: 63.5 })]));
    expect(h.lagging).toMatchObject({ subject: 'ENGLISH', vsNational: -3.5 });
    expect(subjectHighlights(rankSubjects([row('MATH', 70, { national: 69 })])).lagging).toBeUndefined();
  });
});

describe("o'qitilmaydigan fanlar", () => {
  it("bolalar yo'q (n = 0) va tanlov yo'q — o'qitilmaydi", () => {
    expect(isUntaught(row('CHEMISTRY', null, { n: 0, interest: null }))).toBe(true);
    expect(isUntaught(row('CHEMISTRY', null, { n: 0, interest: 0 }))).toBe(true);
  });

  it("K-anonimlik bilan yashirilgan fan (n > 0) o'qitilmaydigan emas — ro'yxatda qoladi", () => {
    const suppressed = row('CHEMISTRY', null, { n: 7, interest: null });
    expect(isUntaught(suppressed)).toBe(false);
    const { taught, untaught } = splitTaught([row('MATH', 70), suppressed, row('PHYSICS', null, { n: 0 })]);
    expect(taught.map((r) => r.subject)).toEqual(['MATH', 'CHEMISTRY']);
    expect(untaught).toEqual(['PHYSICS']);
    expect(rankSubjects(taught).at(-1)).toMatchObject({ subject: 'CHEMISTRY', rank: null, tag: null });
  });
});
