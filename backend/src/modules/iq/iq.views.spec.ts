import { normStats } from './domain/scoring';
import { domainScores, scoreSession } from './iq.views';

describe("IQ natija: tur bo'yicha", () => {
  it("aralash forma — har tur uchun to'g'ri / jami, bank tartibida", () => {
    const kinds = ['FIGURAL', 'NUMERIC', 'FIGURAL', 'LOGIC', 'VERBAL', 'NUMERIC'] as const;
    expect(domainScores([1, 0, 1, 1, 0, 1], kinds)).toEqual([
      { kind: 'FIGURAL', right: 2, total: 2 },
      { kind: 'NUMERIC', right: 1, total: 2 },
      { kind: 'VERBAL', right: 0, total: 1 },
      { kind: 'LOGIC', right: 1, total: 1 },
    ]);
  });

  it("bitta turli (rasmli A/B) forma — domains yo'q", () => {
    expect(domainScores([1, 0], ['FIGURAL', 'FIGURAL'])).toBeUndefined();
    const result = scoreSession(
      { normGroup: '9', completedAt: new Date('2026-10-22T08:00:00Z') },
      { correct: 1, total: 2, responses: [1, 0] },
      [-1, 0],
      normStats(null),
      ['FIGURAL', 'FIGURAL'],
    );
    expect(result).not.toHaveProperty('domains');
    const mixed = scoreSession(
      { normGroup: '9', completedAt: new Date('2026-10-22T08:00:00Z') },
      { correct: 1, total: 2, responses: [1, 0] },
      [-1, 0],
      normStats(null),
      ['FIGURAL', 'VERBAL'],
    );
    expect(mixed.domains).toEqual([
      { kind: 'FIGURAL', right: 1, total: 1 },
      { kind: 'VERBAL', right: 0, total: 1 },
    ]);
  });
});
