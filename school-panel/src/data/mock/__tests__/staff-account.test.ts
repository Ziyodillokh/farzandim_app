import { describe, expect, it } from 'vitest';

import { type RoleKey, ServiceError } from '@/data/contracts';
import { toServiceError } from '@/data/http/client';
import { accountMenu, staffErrorKey } from '@/features/staff/account';

const SELF = 'stf-director';
const row = (id: string, role: RoleKey, username: string | null = 'login') => ({ id, role, username });

describe('xodim: panel hisobi amallari (haqiqiy rejim menyusi)', () => {
  it('o\'z qatorida panel hisobi nofaol (izoh bilan), o\'chirish yo\'q — server ham 409 \'self\' qaytaradi', () => {
    expect(accountMenu(row(SELF, 'DIRECTOR'), SELF)).toEqual({ canSet: false, canRemove: false, note: 'self' });
    expect(accountMenu(row(SELF, 'DIRECTOR', null), SELF)).toEqual({ canSet: false, canRemove: false, note: 'self' });
  });

  it('boshqa xodim: hisob berish mumkin; o\'chirish — faqat hisobi bo\'lsa', () => {
    expect(accountMenu(row('stf-admin', 'ADMIN'), SELF)).toEqual({ canSet: true, canRemove: true, note: null });
    expect(accountMenu(row('stf-x', 'TEACHER', null), SELF)).toEqual({ canSet: true, canRemove: false, note: null });
  });

  it('himoyalangan rol (psixolog): hisobni operator beradi', () => {
    expect(accountMenu(row('stf-psychologist', 'PSYCHOLOGIST', null), SELF)).toMatchObject({ canSet: false, note: 'protected' });
  });

  it('sessiya yo\'q (selfId null) — hech bir qator "o\'zi" emas', () => {
    expect(accountMenu(row(SELF, 'DIRECTOR'), null)).toMatchObject({ canSet: true, note: null });
  });
});

describe('xodim: xato xabarlari', () => {
  it('409 \'username\' — band login haqida aniq xabar; boshqa 409 — umumiy', () => {
    expect(staffErrorKey(toServiceError(409, { code: 'CONFLICT', message: 'username' }))).toBe('staff.account.usernameTaken');
    expect(staffErrorKey(toServiceError(409, { code: 'CONFLICT', message: 'self' }))).toBe('staff.errors.conflict');
    expect(staffErrorKey(new ServiceError('CONFLICT', 'demo'))).toBe('staff.errors.conflict');
  });

  it('409 bo\'lmagan xatolar — umumiy xarita (errorKey)', () => {
    expect(staffErrorKey(new ServiceError('FORBIDDEN', 'staff.manage'))).toBe('errors.FORBIDDEN');
    expect(staffErrorKey(new ServiceError('VALIDATION', 'username: errors.form.invalid'))).toBe('errors.form.invalid');
    expect(staffErrorKey(new Error('boom'))).toBe('errors.UNKNOWN');
  });
});
