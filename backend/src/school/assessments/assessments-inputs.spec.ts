// Tayinlash vaqtlari: panel `datetime-local` (Toshkent) va zonali ISO qiymatlar.

import { assignInputSchema, toInstant } from './assessments-inputs.schemas';

describe('toInstant', () => {
  it('zonasiz qiymat — Toshkent devor soati; zonali — shu lahza', () => {
    expect(toInstant('2026-10-12T08:00').toISOString()).toBe('2026-10-12T03:00:00.000Z');
    expect(toInstant('2026-10-12T08:00:30').toISOString()).toBe('2026-10-12T03:00:30.000Z');
    expect(toInstant('2026-10-12T08:00:30.5').toISOString()).toBe('2026-10-12T03:00:30.500Z');
    expect(toInstant('2026-10-12T08:00Z').toISOString()).toBe('2026-10-12T08:00:00.000Z');
    expect(toInstant('2026-10-12T08:00:00+05:00').toISOString()).toBe('2026-10-12T03:00:00.000Z');
  });

  it('mavjud bo\'lmagan sana / vaqt — Invalid Date', () => {
    for (const v of ['2026-02-31T08:00', '2026-10-12T25:00', '2026-13-01T08:00', '12.10.2026 08:00']) {
      expect(Number.isNaN(toInstant(v).getTime())).toBe(true);
    }
  });

  it('sxema: noto\'g\'ri sana va teskari oyna xabarlari', () => {
    const base = { testId: 'tpl-logic', target: { kind: 'GRADES', grades: [7] }, consent: true };
    const bad = assignInputSchema.safeParse({ ...base, opensAt: '2026-02-31T08:00', closesAt: '2026-03-05T08:00' });
    expect(bad.error?.issues[0]).toMatchObject({ path: ['opensAt'], message: 'errors.form.invalidDate' });
    const reversed = assignInputSchema.safeParse({ ...base, opensAt: '2026-10-12T08:00', closesAt: '2026-10-12T07:59' });
    expect(reversed.error?.issues[0]).toMatchObject({ path: ['closesAt'], message: 'errors.form.endBeforeStart' });
    expect(assignInputSchema.safeParse({ ...base, opensAt: '2026-10-12T08:00', closesAt: '2026-10-19T18:00' }).success).toBe(true);
  });
});
