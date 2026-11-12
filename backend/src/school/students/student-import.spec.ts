import { deviceStateOf, DEVICE_OFFLINE_AFTER_MS } from '../common/device-state';
import { duplicateKey, normalizeClassName, parseImportRows, parseRelation, toIsoDate } from './student-import';

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

describe('student import — ota-onalar', () => {
  const classes = new Map([['7-A', 'c1']]);
  const base = ['Karimov', 'Aziz', '', '7-A', 'M', '2013-05-14'];

  it.each([
    ['Ona', 'MOTHER'],
    ['onasi', 'MOTHER'],
    ['Мать', 'MOTHER'],
    ['OTA', 'FATHER'],
    ['папа', 'FATHER'],
    ['Buvisi', 'GRANDPARENT'],
    ['дедушка', 'GRANDPARENT'],
    ['amaki', 'OTHER'],
    ['', 'OTHER'],
  ])('kimligi %s → %s', (input, expected) => {
    expect(parseRelation(input)).toBe(expected);
  });

  it('eski 8 ustunli fayl: bitta ota-ona, kimligi «Boshqa»', () => {
    const { candidates } = parseImportRows([[...base, 'Karimova Malika', '+998 90 123 45 67']], classes, new Set());

    expect(candidates[0]?.data.guardians).toEqual([{ fullName: 'Karimova Malika', phone: '+998 90 123 45 67', relation: 'OTHER' }]);
  });

  it('kimligi va ikkinchi ota-ona ustunlari', () => {
    const { candidates } = parseImportRows(
      [[...base, 'Karimova Malika', '+998901234567', 'ona', 'Karimov Akmal', '+998 93 765 43 21', 'ota']],
      classes,
      new Set(),
    );

    expect(candidates[0]?.data.guardians).toEqual([
      { fullName: 'Karimova Malika', phone: '+998 90 123 45 67', relation: 'MOTHER' },
      { fullName: 'Karimov Akmal', phone: '+998 93 765 43 21', relation: 'FATHER' },
    ]);
  });

  it('ismi yoki telefoni yo\'q ota-ona e\'tiborga olinmaydi; ikki ota-onaga bir telefon — qator o\'tkaziladi', () => {
    const { candidates, skipped } = parseImportRows(
      [
        [...base, 'Karimova Malika', '', 'ona'],
        ['Rasulova', 'Madina', '', '7-A', 'F', '2015-09-02', 'Rasulov Bobur', '+998 93 765 43 21', 'ota', 'Rasulova Dilnoza', '+998937654321', 'ona'],
      ],
      classes,
      new Set(),
    );

    expect(candidates[0]?.data.guardians).toEqual([]);
    expect(skipped).toEqual([{ row: 2, reason: 'guardians.1.phone: errors.form.duplicatePhone' }]);
  });
});

describe('device state', () => {
  const now = new Date('2026-10-20T08:00:00Z');
  const student = { id: 's1', device: 'ANDROID' as const };
  const android = { pairedAt: now, lastSeenAt: now, androidVersion: 'Android 14', usagePermission: true, overlayPermission: true, screenTimePermission: null };
  const iphone = { pairedAt: now, lastSeenAt: now, androidVersion: 'iOS 17.5', usagePermission: null, overlayPermission: null, screenTimePermission: true };

  it('bog\'lanmagan: telefoni yo\'q → NO_PHONE, bor → NO_PERMISSION', () => {
    expect(deviceStateOf({ id: 's1', device: 'NONE' }, null, now)).toEqual({ studentId: 's1', status: 'NO_PHONE', lastSeenAt: null });
    expect(deviceStateOf(student, null, now).status).toBe('NO_PERMISSION');
  });

  it('Android: foydalanish ma\'lumotlari yoki ustida ko\'rsatish o\'chiq → NO_PERMISSION (Accessibility shart emas)', () => {
    expect(deviceStateOf(student, android, now).status).toBe('APPLIED');
    expect(deviceStateOf(student, { ...android, usagePermission: false }, now).status).toBe('NO_PERMISSION');
    expect(deviceStateOf(student, { ...android, overlayPermission: false }, now).status).toBe('NO_PERMISSION');
    // Eski ilova overlay holatini yubormaydi — noma'lum, ruxsat yo'q deb hisoblanmaydi.
    expect(deviceStateOf(student, { ...android, overlayPermission: null }, now).status).toBe('APPLIED');
  });

  it('iOS: Ekran vaqti o\'chiq → NO_PERMISSION', () => {
    expect(deviceStateOf(student, iphone, now).status).toBe('APPLIED');
    expect(deviceStateOf(student, { ...iphone, screenTimePermission: false }, now).status).toBe('NO_PERMISSION');
  });

  it('bog\'lanmagan ilova → NO_PERMISSION; jim → OFFLINE; aks holda APPLIED', () => {
    expect(deviceStateOf(student, { ...android, pairedAt: null }, now).status).toBe('NO_PERMISSION');
    const silent = new Date(now.getTime() - DEVICE_OFFLINE_AFTER_MS - 1);
    expect(deviceStateOf(student, { ...android, lastSeenAt: silent }, now).status).toBe('OFFLINE');
    expect(deviceStateOf(student, { ...android, lastSeenAt: null }, now).status).toBe('OFFLINE');
    expect(deviceStateOf(student, android, now)).toEqual({ studentId: 's1', status: 'APPLIED', lastSeenAt: now.toISOString() });
  });
});
