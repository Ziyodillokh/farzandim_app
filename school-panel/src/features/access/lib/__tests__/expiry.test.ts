import { describe, expect, it } from 'vitest';

import { REVEAL_MINUTES, REVEAL_TTL_MS, REVEAL_WARN_MS, revealExpiry } from '../expiry';

describe('revealExpiry', () => {
  const START = 1_000_000;
  const deadline = START + REVEAL_TTL_MS;

  it('muddat 5 daqiqa, ogohlantirish — oxirgi 20 soniya (WCAG 2.2.1)', () => {
    expect(REVEAL_TTL_MS).toBe(300_000);
    expect(REVEAL_MINUTES).toBe(5);
    expect(REVEAL_WARN_MS).toBeGreaterThanOrEqual(20_000);
  });

  it('boshida va ogohlantirishgacha — ochiq, soniya yo\'q', () => {
    expect(revealExpiry(deadline, START)).toEqual({ expired: false, secondsLeft: null });
    expect(revealExpiry(deadline, deadline - REVEAL_WARN_MS - 1)).toEqual({ expired: false, secondsLeft: null });
  });

  it('oxirgi 20 soniyada — qolgan soniya (yuqoriga yaxlitlanadi)', () => {
    expect(revealExpiry(deadline, deadline - REVEAL_WARN_MS)).toEqual({ expired: false, secondsLeft: 20 });
    expect(revealExpiry(deadline, deadline - 15_000)).toEqual({ expired: false, secondsLeft: 15 });
    expect(revealExpiry(deadline, deadline - 14_001)).toEqual({ expired: false, secondsLeft: 15 });
    expect(revealExpiry(deadline, deadline - 1)).toEqual({ expired: false, secondsLeft: 1 });
  });

  it('muddat o\'tgan yoki aynan hozir — expired', () => {
    expect(revealExpiry(deadline, deadline)).toEqual({ expired: true });
    expect(revealExpiry(deadline, deadline + 60_000)).toEqual({ expired: true });
  });

  it('uzaytirish — yangi muddat bilan hisob qaytadan boshlanadi', () => {
    const later = deadline - 10_000;
    expect(revealExpiry(deadline, later)).toMatchObject({ secondsLeft: 10 });
    const extended = later + REVEAL_TTL_MS;
    expect(revealExpiry(extended, later)).toEqual({ expired: false, secondsLeft: null });
  });
});
