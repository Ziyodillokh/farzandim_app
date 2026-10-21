import { bandFor, eapAbility, normStats, NORMED_N, raschP, scoreAbility, welfordAdd } from './scoring';

const items = (n: number, b = 0) => Array.from({ length: n }, (_, i) => ({ b: b + (i - n / 2) * 0.1 }));
const answer = (bs: Array<{ b: number }>, correct: number) => bs.map((x, i) => ({ ...x, correct: i < correct }));

describe('IQ baholash (docs/IQ-REJA.md §3)', () => {
  it('Rasch: θ = b da ehtimol 0.5', () => {
    expect(raschP(1.2, 1.2)).toBeCloseTo(0.5, 10);
    expect(raschP(2, 0)).toBeGreaterThan(0.85);
  });

  it("EAP: ko'proq to'g'ri javob — yuqoriroq θ; hammasi to'g'ri/noto'g'ri ham chekli", () => {
    const bs = items(20);
    const thetas = [0, 5, 10, 15, 20].map((c) => eapAbility(answer(bs, c)).theta);
    for (let i = 1; i < thetas.length; i++) expect(thetas[i]).toBeGreaterThan(thetas[i - 1]);
    expect(Number.isFinite(thetas[0])).toBe(true);
    expect(thetas[4]).toBeLessThan(5);
    expect(eapAbility(answer(bs, 10)).theta).toBeCloseTo(0, 0);
  });

  it("EAP: savol ko'p bo'lsa standart xato kichikroq", () => {
    expect(eapAbility(answer(items(40), 20)).se).toBeLessThan(eapAbility(answer(items(10), 5)).se);
  });

  it("Welford: o'rtacha va sd oddiy formulaga teng", () => {
    const xs = [0.2, -1.1, 0.7, 1.9, -0.4];
    const row = xs.reduce(welfordAdd, { n: 0, mean: 0, m2: 0 });
    const mean = xs.reduce((a, x) => a + x, 0) / xs.length;
    const sd = Math.sqrt(xs.reduce((a, x) => a + (x - mean) ** 2, 0) / (xs.length - 1));
    expect(normStats(row)).toEqual({
      n: 5,
      mean: expect.closeTo(mean, 10),
      sd: expect.closeTo(sd, 10),
    });
  });

  it("n < 30: dastlabki ma'lumotnoma, PROVISIONAL — IQ raqami va oraliq yo'q", () => {
    const score = scoreAbility({ theta: 1, se: 0.4 }, { n: 12, mean: 5, sd: 0.1 }, { mean: 0, sd: 1 });
    expect(score).toEqual({
      status: 'PROVISIONAL',
      percentile: 84,
      band: 'ABOVE_AVERAGE',
      standardScore: null,
      ci95: null,
    });
  });

  it('30 ≤ n < 300: empirik norma, lekin hali PROVISIONAL', () => {
    const score = scoreAbility({ theta: 0.5, se: 0.4 }, { n: 120, mean: 0.5, sd: 0.8 }, { mean: 0, sd: 1 });
    expect(score).toMatchObject({
      status: 'PROVISIONAL',
      percentile: 50,
      band: 'AVERAGE',
      standardScore: null,
    });
  });

  it('n ≥ 300: NORMED — standart ball 100±15 va 95% oraliq', () => {
    const score = scoreAbility({ theta: 1.6, se: 0.3 }, { n: NORMED_N, mean: 0, sd: 0.8 }, { mean: 0, sd: 1 });
    expect(score.status).toBe('NORMED');
    expect(score.standardScore).toBe(130);
    expect(score.band).toBe('VERY_HIGH');
    expect(score.ci95).toEqual([119, 141]);
  });

  it('standart ball 55..145 bilan cheklanadi', () => {
    const low = scoreAbility({ theta: -9, se: 0.5 }, { n: 500, mean: 0, sd: 1 }, { mean: 0, sd: 1 });
    expect(low.standardScore).toBe(55);
    expect(low.band).toBe('VERY_LOW');
  });

  it.each([
    [130, 'VERY_HIGH'],
    [129, 'HIGH'],
    [110, 'ABOVE_AVERAGE'],
    [109, 'AVERAGE'],
    [90, 'AVERAGE'],
    [89, 'BELOW_AVERAGE'],
    [79, 'LOW'],
    [69, 'VERY_LOW'],
  ])('WISC-V tasnifi: %i → %s', (ss, band) => {
    expect(bandFor(ss)).toBe(band);
  });
});
