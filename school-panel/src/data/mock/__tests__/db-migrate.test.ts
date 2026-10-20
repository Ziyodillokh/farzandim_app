import { describe, expect, it } from 'vitest';

import { createFreshSnapshot, migrate } from '../db';
import { CLOSED_WEEKS } from '../seed/learning';

const weeksOf = (db: ReturnType<typeof createFreshSnapshot>) => new Set(db.tables.activity.map((a) => a.weekStart)).size;

describe('demo bazasi migratsiyasi', () => {
  it('Growth faolligi: avvalgi 6 haftalik baza 6 yakunlangan + joriy haftaga qayta quriladi', () => {
    const fresh = createFreshSnapshot(new Date(2026, 9, 14, 10));
    expect(weeksOf(fresh)).toBe(CLOSED_WEEKS + 1);
    const oldest = [...new Set(fresh.tables.activity.map((a) => a.weekStart))].sort()[0];
    const legacy = { ...fresh, tables: { ...fresh.tables, activity: fresh.tables.activity.filter((a) => a.weekStart !== oldest) } };
    const migrated = migrate(legacy);
    expect(weeksOf(migrated)).toBe(CLOSED_WEEKS + 1);
    expect(migrated.tables.activity).toEqual(fresh.tables.activity);
  });

  it('yangi baza o\'zgarmaydi (idempotent)', () => {
    const fresh = createFreshSnapshot(new Date(2026, 9, 14, 10));
    expect(migrate(fresh)).toBe(fresh);
  });
});
