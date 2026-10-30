import { describe, expect, it } from 'vitest';

import type { Iq } from '@/data/contracts';
import { IQ_DISPLAY_BANDS, type IqDisplayBand } from '@/data/reference/domains';
import { bandShare, hasAreaBands, hasBandData, IQ_BANDS_ASC, IQ_NORM_SHARE, maxNormDeviation, modalBand, NORM_CLOSE_PP, normVerdict } from './iq-norm';

type Shares = Record<IqDisplayBand, number>;

const bands = (shares: Shares): Iq['bands'] => IQ_DISPLAY_BANDS.map((key) => ({ key, share: shares[key], delta: null }));
const ZERO: Shares = { VERY_HIGH: 0, HIGH: 0, ABOVE_AVERAGE: 0, AVERAGE: 0, BELOW_AVERAGE: 0, GROWTH_ZONE: 0 };
/** Normadan faqat bitta darajada `diff` p.p. farq (qolgani — aynan norma). */
const offNorm = (band: IqDisplayBand, diff: number): Iq['bands'] => bands({ ...IQ_NORM_SHARE, [band]: IQ_NORM_SHARE[band] + diff });

describe('norma', () => {
  it("normal taqsimot ulushlari ~100%; o'sish tartibi — teskari", () => {
    const total = IQ_DISPLAY_BANDS.reduce((sum, b) => sum + IQ_NORM_SHARE[b], 0);
    expect(total).toBeCloseTo(99.9, 1);
    expect(IQ_BANDS_ASC[0]).toBe('GROWTH_ZONE');
    expect(IQ_BANDS_ASC.at(-1)).toBe('VERY_HIGH');
  });
});

describe('taqsimot bor-yo\'qligi', () => {
  it("hamma ulush 0 yoki bo'sh ro'yxat — ma'lumot yo'q", () => {
    expect(hasBandData(bands(ZERO))).toBe(false);
    expect(hasBandData([])).toBe(false);
    expect(hasBandData(bands({ ...ZERO, AVERAGE: 0.1 }))).toBe(true);
  });

  it("bo'linma taqsimoti: null yoki hamma 0 — yo'q", () => {
    expect(hasAreaBands(null)).toBe(false);
    expect(hasAreaBands(ZERO)).toBe(false);
    expect(hasAreaBands({ ...ZERO, HIGH: 4 })).toBe(true);
  });

  it("ulush topilmasa — 0", () => {
    expect(bandShare([], 'HIGH')).toBe(0);
  });
});

describe('maxNormDeviation', () => {
  it('hamma ulush 0 — null (normadan "−49,5 p.p." deb chiqmaydi)', () => {
    expect(maxNormDeviation(bands(ZERO))).toBeNull();
  });

  it("eng katta mutlaq og'ish — darajasi va ishorasi bilan, bir kasr xonasi", () => {
    expect(maxNormDeviation(offNorm('GROWTH_ZONE', -3.04))).toEqual({ band: 'GROWTH_ZONE', diff: -3 });
    expect(maxNormDeviation(offNorm('HIGH', 2.5))).toEqual({ band: 'HIGH', diff: 2.5 });
  });
});

describe('normVerdict', () => {
  it(`farq ${NORM_CLOSE_PP} p.p. dan kichik — "normaga yaqin"`, () => {
    expect(normVerdict(offNorm('AVERAGE', NORM_CLOSE_PP - 0.1))).toMatchObject({ kind: 'close', band: 'AVERAGE' });
    expect(normVerdict(bands(IQ_NORM_SHARE))).toMatchObject({ kind: 'close', diff: 0 });
  });

  it(`chegaraning o'zi (${NORM_CLOSE_PP} p.p.) va undan katta — "normadan uzoq"`, () => {
    expect(normVerdict(offNorm('AVERAGE', NORM_CLOSE_PP))).toMatchObject({ kind: 'far', band: 'AVERAGE', diff: NORM_CLOSE_PP });
    expect(normVerdict(offNorm('GROWTH_ZONE', -NORM_CLOSE_PP))).toMatchObject({ kind: 'far', diff: -NORM_CLOSE_PP });
  });

  it("taqsimot yo'q — xulosa yo'q", () => {
    expect(normVerdict(bands(ZERO))).toBeNull();
  });
});

describe('modalBand', () => {
  it("eng katta ulushli daraja; hamma 0 — null", () => {
    expect(modalBand(bands({ ...ZERO, ABOVE_AVERAGE: 30, AVERAGE: 45 }))?.key).toBe('AVERAGE');
    expect(modalBand(bands(ZERO))).toBeNull();
  });
});
