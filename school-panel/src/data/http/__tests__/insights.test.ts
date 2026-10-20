import { describe, expect, it } from 'vitest';

import { academicMonths } from '../services/insights';

describe('academic months', () => {
  it('sentyabrdan joriy oygacha, yangisi birinchi (Toshkent vaqti)', () => {
    expect(academicMonths(new Date('2026-10-20T08:00:00Z'))).toEqual(['2026-10', '2026-09']);
    expect(academicMonths(new Date('2027-02-03T08:00:00Z'))).toEqual(['2027-02', '2027-01', '2026-12', '2026-11', '2026-10', '2026-09']);
    // 31-avgust 20:00 UTC — Toshkentda allaqachon 1-sentyabr.
    expect(academicMonths(new Date('2027-08-31T20:00:00Z'))).toEqual(['2027-09']);
  });
});
