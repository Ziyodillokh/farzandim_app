import { describe, expect, it } from 'vitest';

import { roleHas } from '../permissions';
import { findRoute, NAV_GROUP_ORDER, ROUTES } from '../route-manifest';

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

describe('menyu tartibi', () => {
  it("guruhlar: Asosiy → Rivojlanish → Aloqa → Maktab → Boshqaruv; Smart Reminder Xabarlardan oldin", () => {
    expect(NAV_GROUP_ORDER).toEqual(['main', 'wellbeing', 'communication', 'school', 'admin']);
    const top = ROUTES.filter((r) => r.group).map((r) => r.path);
    expect(top.indexOf('/reminders')).toBeLessThan(top.indexOf('/messages'));
    expect(top.slice(1, 5)).toEqual(['/care', '/assessments', '/development', '/learning']);
  });

  it('yangi sahifalar o\'z ruxsati bilan tekshiriladi', () => {
    expect(findRoute('/assessments/view')?.perm).toBe('assessments.manage');
    expect(findRoute('/development')?.perm).toBe('development.view');
  });
});
