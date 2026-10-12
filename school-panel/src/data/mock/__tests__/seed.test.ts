import { describe, expect, it } from 'vitest';

import { hashString } from '@/lib/rng';
import { generateSeed } from '../seed';
import { FIXED_STAFF } from '../seed/people';

const NOW = new Date(2026, 9, 12, 9, 30);

describe('generateSeed', () => {
  const tables = generateSeed(20261012, NOW);

  it('har safar bir xil ma\'lumot beradi (deterministik)', () => {
    const again = generateSeed(20261012, NOW);
    expect(hashString(JSON.stringify(again))).toBe(hashString(JSON.stringify(tables)));
  });

  it('22 sinf, 24–28 o\'quvchidan, har sinfda sinf rahbari', () => {
    expect(tables.classes).toHaveLength(22);
    for (const cls of tables.classes) {
      const size = tables.students.filter((s) => s.classId === cls.id).length;
      expect(size).toBeGreaterThanOrEqual(24);
      expect(size).toBeLessThanOrEqual(28);
      expect(tables.staff.some((s) => s.id === cls.homeroomStaffId && s.classIds.includes(cls.id))).toBe(true);
    }
  });

  it('demo hisob xodimlari mavjud, 7-A sinf rahbari to\'g\'ri', () => {
    for (const id of Object.values(FIXED_STAFF)) expect(tables.staff.some((s) => s.id === id)).toBe(true);
    expect(tables.classes.find((c) => c.id === 'cls-7a')?.homeroomStaffId).toBe(FIXED_STAFF.homeroom7a);
  });

  it('o\'quvchi kodlari noyob, telefonlar +998 formatida', () => {
    const codes = new Set(tables.students.map((s) => s.studentCode));
    expect(codes.size).toBe(tables.students.length);
    for (const g of tables.guardians) expect(g.phone).toMatch(/^\+998 \d{2} \d{3} \d{2} \d{2}$/);
  });

  it('har o\'quvchida kamida bitta ota-ona bor va u mavjud', () => {
    const ids = new Set(tables.guardians.map((g) => g.id));
    for (const s of tables.students) {
      expect(s.guardianIds.length).toBeGreaterThan(0);
      for (const g of s.guardianIds) expect(ids.has(g)).toBe(true);
    }
  });

  it('localStorage uchun hajm 3 MB dan kichik', () => {
    const bytes = new TextEncoder().encode(JSON.stringify(tables)).length;
    expect(bytes).toBeLessThan(3 * 1024 * 1024);
  });
});
