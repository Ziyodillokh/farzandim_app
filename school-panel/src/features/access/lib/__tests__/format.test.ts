import { describe, expect, it } from 'vitest';

import { groupCode, plainCode, remainingUntil, spokenCode } from '../format';

describe('groupCode', () => {
  it('6 raqam — 3+3; bosh nollar saqlanadi', () => {
    expect(groupCode('123456')).toBe('123 456');
    expect(groupCode('004217')).toBe('004 217');
  });

  it('boshqa uzunlik/format — o\'zgarishsiz', () => {
    expect(groupCode('12345')).toBe('12345');
    expect(groupCode('ABCD2345')).toBe('ABCD2345');
    expect(groupCode('')).toBe('');
  });
});

describe('spokenCode / plainCode', () => {
  it('ekran o\'qish dasturi uchun raqamlar alohida; nusxalash uchun bo\'shliqsiz', () => {
    expect(spokenCode('123456')).toBe('1 2 3, 4 5 6');
    expect(spokenCode('AB12')).toBe('A B 1 2');
    expect(plainCode('123 456')).toBe('123456');
    expect(plainCode('123456')).toBe('123456');
  });
});

describe('remainingUntil', () => {
  const NOW = Date.parse('2026-10-12T10:00:00');

  it('soat va daqiqa (butun daqiqa, pastga)', () => {
    expect(remainingUntil('2026-10-13T10:00:00', NOW)).toEqual({ expired: false, hours: 24, minutes: 0 });
    expect(remainingUntil('2026-10-13T09:15:30', NOW)).toEqual({ expired: false, hours: 23, minutes: 15 });
    expect(remainingUntil('2026-10-12T10:45:00', NOW)).toEqual({ expired: false, hours: 0, minutes: 45 });
  });

  it('1 daqiqadan kam — 0 soat 0 daqiqa (hali o\'tmagan)', () => {
    expect(remainingUntil('2026-10-12T10:00:40', NOW)).toEqual({ expired: false, hours: 0, minutes: 0 });
  });

  it('o\'tib ketgan, aynan hozir yoki noto\'g\'ri sana — expired', () => {
    expect(remainingUntil('2026-10-12T10:00:00', NOW)).toEqual({ expired: true });
    expect(remainingUntil('2026-10-12T09:59:59', NOW)).toEqual({ expired: true });
    expect(remainingUntil('yaroqsiz', NOW)).toEqual({ expired: true });
  });
});
