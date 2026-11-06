import { describe, expect, it } from 'vitest';

import { LOGIN_PATTERN } from '@/data/schemas/access';
import type { MockInviteCode } from '../access-tables';
import {
  activeInviteOf,
  generateInviteCodeDigits,
  generateTemporaryPassword,
  isActiveInvite,
  recipientRoles,
  TEMP_PASSWORD_ALPHABET,
  TEMP_PASSWORD_LENGTH,
  suggestLogin,
  toAsciiSlug,
  toInviteCodeView,
  uniqueInviteCode,
} from '../access-model';

const NOW = Date.parse('2026-10-12T10:00:00');
const invite = (patch: Partial<MockInviteCode> = {}): MockInviteCode => ({
  id: 'inv-1',
  studentId: 'stu-1',
  code: '012345',
  createdAt: '2026-10-12T09:00:00',
  expiresAt: '2026-10-13T09:00:00',
  studentUsedAt: null,
  parentUsedAt: null,
  closedAt: null,
  createdByStaffId: 'stf-admin',
  ...patch,
});

describe('vaqtinchalik parol', () => {
  it('8 belgi, faqat o\'xshash belgilarsiz alifbo (i, l, o, 0, 1 yo\'q)', () => {
    expect(TEMP_PASSWORD_ALPHABET).toBe('abcdefghjkmnpqrstuvwxyz23456789');
    for (let i = 0; i < 300; i++) {
      const password = generateTemporaryPassword();
      expect(password).toHaveLength(TEMP_PASSWORD_LENGTH);
      expect([...password].every((ch) => TEMP_PASSWORD_ALPHABET.includes(ch))).toBe(true);
    }
  });

  it('har safar boshqa (kripto-tasodifiy)', () => {
    const seen = new Set(Array.from({ length: 60 }, generateTemporaryPassword));
    expect(seen.size).toBe(60);
  });
});

describe('6 xonali kod', () => {
  it('doim 6 raqam; bosh nollar saqlanadi', () => {
    const codes = Array.from({ length: 3000 }, generateInviteCodeDigits);
    expect(codes.every((c) => /^\d{6}$/.test(c))).toBe(true);
    expect(codes.some((c) => c.startsWith('0'))).toBe(true);
  });

  it('faol kodlar orasida takrorlanmaydi; yopilgan yoki muddati o\'tgan kod raqamlari qayta ishlatilishi mumkin', () => {
    const active = Array.from({ length: 50 }, (_, i) => invite({ id: `a${i}`, code: String(i).padStart(6, '0') }));
    for (let i = 0; i < 100; i++) expect(active.some((a) => a.code === uniqueInviteCode(active, NOW))).toBe(false);
  });
});

describe('faol kod', () => {
  it('yopilmagan va muddati o\'tmagan', () => {
    expect(isActiveInvite(invite(), NOW)).toBe(true);
    expect(isActiveInvite(invite({ closedAt: '2026-10-12T09:30:00' }), NOW)).toBe(false);
    expect(isActiveInvite(invite({ expiresAt: '2026-10-12T09:59:59' }), NOW)).toBe(false);
    expect(isActiveInvite(invite({ expiresAt: '2026-10-12T10:00:00' }), NOW)).toBe(false);
  });

  it('o\'quvchining eng yangi faol kodi', () => {
    const older = invite({ id: 'old', createdAt: '2026-10-12T08:00:00', code: '111111' });
    const newer = invite({ id: 'new', createdAt: '2026-10-12T09:30:00', code: '222222' });
    const other = invite({ id: 'other', studentId: 'stu-2', createdAt: '2026-10-12T09:45:00', code: '333333' });
    expect(activeInviteOf([older, newer, other], 'stu-1', NOW)?.id).toBe('new');
    expect(activeInviteOf([invite({ closedAt: '2026-10-12T09:50:00' })], 'stu-1', NOW)).toBeNull();
    expect(activeInviteOf([], 'stu-1', NOW)).toBeNull();
  });

  it('ko\'rinish: o\'rin holati vaqt bilan', () => {
    expect(toInviteCodeView(invite({ studentUsedAt: '2026-10-12T09:10:00' }))).toEqual({
      code: '012345',
      expiresAt: '2026-10-13T09:00:00',
      student: { used: true, usedAt: '2026-10-12T09:10:00' },
      parent: { used: false, usedAt: null },
    });
  });
});

describe('toAsciiSlug', () => {
  it('apostrof va diakritika olib tashlanadi; kirill lotinga', () => {
    expect(toAsciiSlug("G'ayrat")).toBe('gayrat');
    expect(toAsciiSlug('Oʻktam')).toBe('oktam');
    expect(toAsciiSlug('Zoé')).toBe('zoe');
    expect(toAsciiSlug('Ўктам')).toBe('oktam');
    expect(toAsciiSlug('Айнур')).toBe('aynur');
    expect(toAsciiSlug('  ')).toBe('');
  });
});

describe('suggestLogin', () => {
  const aziza = { firstName: 'Aziza', lastName: 'Karimova' };

  it('ism + "." + familiya bosh harfi + 2 raqam; format kontraktga mos', () => {
    const login = suggestLogin(aziza, new Set(), 'stu-1');
    expect(login).toMatch(/^aziza\.k\d{2}$/);
    expect(LOGIN_PATTERN.test(login)).toBe(true);
  });

  it('bir xil tuz — bir xil taklif; band bo\'lsa boshqa raqamlar', () => {
    const first = suggestLogin(aziza, new Set(), 'stu-1');
    expect(suggestLogin(aziza, new Set(), 'stu-1')).toBe(first);
    const second = suggestLogin(aziza, new Set([first]), 'stu-1');
    expect(second).not.toBe(first);
    expect(second).toMatch(/^aziza\.k\d{2}$/);
  });

  it('ism ishlatib bo\'lmasa yoki raqamlar tugasa — parvoz + 4 raqam (band bo\'lmagan)', () => {
    expect(suggestLogin({ firstName: '...', lastName: 'Karimova' }, new Set(), 's')).toMatch(/^parvoz\d{4}$/);
    const all = new Set(Array.from({ length: 100 }, (_, n) => `aziza.k${String(n).padStart(2, '0')}`));
    const fallback = suggestLogin(aziza, all, 'stu-1');
    expect(fallback).toMatch(/^parvoz\d{4}$/);
    expect(all.has(fallback)).toBe(false);
  });

  it('uzun ism qisqartiriladi va format buzilmaydi', () => {
    const login = suggestLogin({ firstName: 'Muhammadyusufbekzodakattaism', lastName: 'Rahimov' }, new Set(), 's');
    expect(LOGIN_PATTERN.test(login)).toBe(true);
    expect(login.length).toBeLessThanOrEqual(24);
  });
});

describe('recipientRoles: bildirishnoma faqat uni hal qila oladigan xodimga', () => {
  it('kontrakt qabul qiluvchilari ∩ amal ruxsati: tiklash (`students.manage`) — faqat admin; ulanish (`guardians.link`) — sinf rahbari + admin', () => {
    expect(recipientRoles('CHILD_RECOVERY_REQUEST')).toEqual(['ADMIN']);
    expect(recipientRoles('LINK_REVIEW')).toEqual(['HOMEROOM', 'ADMIN']);
    expect(recipientRoles('LINK_CORRECTION')).toEqual(['HOMEROOM', 'ADMIN']);
  });

  it('sinf rahbariga `students.manage` berilsa — tiklash so\'rovi unga ham keladi; ruxsati olinsa — hech kimga', () => {
    const granted = (role: string, permission: string) => role === 'HOMEROOM' || (role === 'ADMIN' && permission !== 'none');
    expect(recipientRoles('CHILD_RECOVERY_REQUEST', granted)).toEqual(['HOMEROOM', 'ADMIN']);
    expect(recipientRoles('LINK_REVIEW', () => false)).toEqual([]);
  });
});
