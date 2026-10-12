import { describe, expect, it } from 'vitest';

import { roleHas } from '../permissions';
import { findRoute } from '../route-manifest';

describe('findRoute', () => {
  it('ichki sahifa o\'z ruxsati bilan tekshiriladi (ota sahifaniki emas)', () => {
    expect(findRoute('/attendance/corrections')?.perm).toBe('attendance.correct');
    expect(findRoute('/attendance/corrections/')?.perm).toBe('attendance.correct');
    expect(roleHas('DUTY', findRoute('/attendance/corrections')?.perm ?? 'dashboard.view')).toBe(false);
  });

  it('tafsilot sahifasi eng uzun mos yo\'lni oladi', () => {
    expect(findRoute('/care/requests/view')?.perm).toBe('care.individual');
    expect(findRoute('/attendance')?.perm).toBe('attendance.view');
  });

  it('noma\'lum yo\'l — undefined', () => {
    expect(findRoute('/yoq-sahifa')).toBeUndefined();
  });
});
