import { deviceStateOf, DEVICE_OFFLINE_AFTER_MS } from '../common/device-state';
import { duplicateKey, normalizeClassName, parseImportRows, toIsoDate } from './student-import';

describe('student import', () => {
  it.each([
    ['7-A', '7-A'],
    ['7a', '7-A'],
    [' 7 - a ', '7-A'],
    ['11B', '11-B'],
    ['10-А', '10-А'],
  ])('sinf nomi %s → %s', (input, expected) => {
    expect(normalizeClassName(input)).toBe(expected);
  });

  it.each([
    ['2013-05-14', '2013-05-14'],
    ['14.05.2013', '2013-05-14'],
    ['4/5/2013', '2013-05-04'],
    ['2013-02-30', null],
    ['31.04.2013', null],
    ['', null],
    ['2013/05/14', null],
  ])('sana %s → %s', (input, expected) => {
    expect(toIsoDate(input)).toBe(expected);
  });

  it('takror kaliti — katta-kichik harf va apostrof farqsiz', () => {
    const a = duplicateKey({ lastName: "To'xtayev", firstName: 'Ali', birthDate: '2013-01-01' });
    const b = duplicateKey({ lastName: 'TOʻXTAYEV', firstName: 'ali', birthDate: '2013-01-01' });
    expect(a).toBe(b);
  });

  it('bo\'sh qatorlar hisobga olinmaydi, qator raqami 1 dan', () => {
    const classes = new Map([['7-A', 'c1']]);
    const { candidates, skipped } = parseImportRows(
      [[''], ['Ali', 'Vali', '', '7a', 'F', '01.02.2014'], ['X', 'Y', '', '8-A', 'M', '2014-01-01']],
      classes,
      new Set(),
    );
    expect(candidates).toEqual([
      { row: 2, data: expect.objectContaining({ lastName: 'Ali', classId: 'c1', gender: 'FEMALE', birthDate: '2014-02-01', device: 'NONE' }) },
    ]);
    expect(skipped).toEqual([{ row: 3, reason: 'class:8-A' }]);
  });
});

describe('device state', () => {
  const now = new Date('2026-10-20T08:00:00Z');
  const student = { id: 's1', device: 'ANDROID' as const };
  const child = { pairedAt: now, lastSeenAt: now, accessibilityEnabled: true, screenTimePermission: null };

  it('bog\'lanmagan: telefoni yo\'q → NO_PHONE, bor → NO_PERMISSION', () => {
    expect(deviceStateOf({ id: 's1', device: 'NONE' }, null, now)).toEqual({ studentId: 's1', status: 'NO_PHONE', lastSeenAt: null });
    expect(deviceStateOf(student, null, now).status).toBe('NO_PERMISSION');
  });

  it('ruxsat o\'chiq → NO_PERMISSION; jim → OFFLINE; aks holda APPLIED', () => {
    expect(deviceStateOf(student, { ...child, accessibilityEnabled: false }, now).status).toBe('NO_PERMISSION');
    expect(deviceStateOf(student, { ...child, screenTimePermission: false }, now).status).toBe('NO_PERMISSION');
    expect(deviceStateOf(student, { ...child, pairedAt: null }, now).status).toBe('NO_PERMISSION');
    const silent = new Date(now.getTime() - DEVICE_OFFLINE_AFTER_MS - 1);
    expect(deviceStateOf(student, { ...child, lastSeenAt: silent }, now).status).toBe('OFFLINE');
    expect(deviceStateOf(student, { ...child, lastSeenAt: null }, now).status).toBe('OFFLINE');
    expect(deviceStateOf(student, child, now)).toEqual({ studentId: 's1', status: 'APPLIED', lastSeenAt: now.toISOString() });
  });
});
