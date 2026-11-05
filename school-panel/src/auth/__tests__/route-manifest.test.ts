import { describe, expect, it } from 'vitest';

import { PERMISSIONS, roleHas, ROLES } from '../permissions';
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

describe('dars jadvali', () => {
  it('sahifa Maktab guruhida, School Mode bo\'limidan keyin; ko\'rish — classes.view', () => {
    const school = ROUTES.filter((r) => r.group === 'school').map((r) => r.path);
    expect(school.indexOf('/timetable')).toBe(school.indexOf('/school-mode') + 1);
    expect(findRoute('/timetable')?.perm).toBe('classes.view');
  });

  it('tahrirlash (timetable.manage): direktor, admin, sinf rahbari; o\'qituvchi faqat ko\'radi', () => {
    expect(PERMISSIONS).toContain('timetable.manage');
    const editors = Object.values(ROLES).filter((r) => r.permissions.includes('timetable.manage')).map((r) => r.key).sort();
    expect(editors).toEqual(['ADMIN', 'DIRECTOR', 'HOMEROOM']);
    expect(roleHas('TEACHER', 'classes.view')).toBe(true);
    expect(roleHas('TEACHER', 'timetable.manage')).toBe(false);
  });
});
