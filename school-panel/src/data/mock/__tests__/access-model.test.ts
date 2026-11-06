import { describe, expect, it } from 'vitest';

import { roleHas } from '@/auth/permissions';
import type { Staff } from '@/data/contracts';
import { LOGIN_PATTERN } from '@/data/schemas/access';
import type { MockInviteCode } from '../access-tables';
import {
  accessNotificationId,
  activeInviteOf,
  generateInviteCodeDigits,
  generateTemporaryPassword,
  isActiveInvite,
  notificationAudience,
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
  studentConfirmedAt: null,
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

  it('ko\'rinish (K2 §2): ikkala o\'rin bo\'sh — FREE / FREE', () => {
    expect(toInviteCodeView(invite())).toEqual({
      code: '012345',
      expiresAt: '2026-10-13T09:00:00',
      student: { status: 'FREE', usedAt: null },
      parent: { status: 'FREE', usedAt: null },
    });
  });

  it('o\'quvchi o\'rni uch holatli: kiritilmagan → tekshiruvda (kiritdi, tasdiq yo\'q) → tasdiqlangan', () => {
    expect(toInviteCodeView(invite({ studentUsedAt: '2026-10-12T09:10:00' })).student).toEqual({ status: 'UNDER_REVIEW', usedAt: '2026-10-12T09:10:00' });
    expect(toInviteCodeView(invite({ studentUsedAt: '2026-10-12T09:10:00', studentConfirmedAt: '2026-10-12T09:20:00' })).student).toEqual({
      status: 'CONFIRMED',
      usedAt: '2026-10-12T09:10:00',
    });
  });

  it('ota-ona o\'rni: FREE | USED (vaqt bilan)', () => {
    expect(toInviteCodeView(invite({ parentUsedAt: '2026-10-12T09:15:00' })).parent).toEqual({ status: 'USED', usedAt: '2026-10-12T09:15:00' });
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

describe('accessNotificationId', () => {
  it('so\'rov id\'siga bog\'langan (hal bo\'lganda shu id o\'chiriladi); REVIEW id\'sidagi ":" saqlanadi', () => {
    expect(accessNotificationId('LINK_REVIEW', 'inv-1:chd-1')).toBe('ntf-link-review-inv-1:chd-1');
    expect(accessNotificationId('LINK_CORRECTION', 'lnk-correction-stu-1')).toBe('ntf-link-correction-lnk-correction-stu-1');
    expect(accessNotificationId('CHILD_RECOVERY_REQUEST', 'rec-1')).toBe('ntf-child-recovery-request-rec-1');
  });
});

describe('notificationAudience: bildirishnoma FAOL va ish qila oladigan xodimlarga (backend `staff-recipients.ts`)', () => {
  const person = (id: string, role: Staff['role'], patch: Partial<Staff> = {}): Pick<Staff, 'id' | 'role' | 'active' | 'classIds'> => ({
    id,
    role,
    active: true,
    classIds: role === 'HOMEROOM' || role === 'TEACHER' ? [`cls-${id}`] : [],
    ...patch,
  });
  const staff = [
    person('dir', 'DIRECTOR'),
    person('adm', 'ADMIN'),
    person('hr-a', 'HOMEROOM', { classIds: ['cls-a'] }),
    person('hr-b', 'HOMEROOM', { classIds: ['cls-b'] }),
    person('psy', 'PSYCHOLOGIST'),
    person('duty', 'DUTY'),
    person('teacher', 'TEACHER', { classIds: ['cls-a'] }),
  ];

  it('tiklash so\'rovi (`students.manage`): direktor va administrator; sinf rahbari — yo\'q (unda bu ruxsat yo\'q)', () => {
    expect(notificationAudience(staff, 'CHILD_RECOVERY_REQUEST', 'cls-a')).toEqual({ staffIds: ['dir', 'adm'], roles: ['DIRECTOR', 'ADMIN'] });
  });

  it.each(['LINK_REVIEW', 'LINK_CORRECTION'] as const)('%s (`guardians.link`): direktor, administrator va FAQAT o\'quvchi sinfining sinf rahbari', (kind) => {
    expect(notificationAudience(staff, kind, 'cls-a')).toEqual({ staffIds: ['dir', 'adm', 'hr-a'], roles: ['DIRECTOR', 'ADMIN', 'HOMEROOM'] });
    expect(notificationAudience(staff, kind, 'cls-b')).toEqual({ staffIds: ['dir', 'adm', 'hr-b'], roles: ['DIRECTOR', 'ADMIN', 'HOMEROOM'] });
  });

  it('sinfsiz o\'quvchi: faqat butun maktab doirasidagi rollar (sinf rahbari yo\'q)', () => {
    expect(notificationAudience(staff, 'LINK_REVIEW', null)).toEqual({ staffIds: ['dir', 'adm'], roles: ['DIRECTOR', 'ADMIN'] });
  });

  it('sinf rahbariga `students.manage` berilsa — tiklash so\'rovi unga ham keladi, lekin faqat o\'z sinfi uchun', () => {
    const granted: Parameters<typeof notificationAudience>[3] = (role, permission) =>
      roleHas(role, permission) || (role === 'HOMEROOM' && permission === 'students.manage');
    expect(notificationAudience(staff, 'CHILD_RECOVERY_REQUEST', 'cls-a', granted)).toEqual({
      staffIds: ['dir', 'adm', 'hr-a'],
      roles: ['DIRECTOR', 'ADMIN', 'HOMEROOM'],
    });
  });

  it('faol bo\'lmagan xodim qabul qiluvchi emas (sinf rahbari ish tashlagan — direktor va admin baribir oladi)', () => {
    const inactive = staff.map((s) => (s.id === 'hr-a' ? { ...s, active: false } : s));
    expect(notificationAudience(inactive, 'LINK_REVIEW', 'cls-a')?.staffIds).toEqual(['dir', 'adm']);
  });

  it('hech kim mos kelmasa — maktabning faol direktorlari (ruxsati bo\'lmasa ham); `staffIds` bo\'sh, rol bo\'yicha', () => {
    expect(notificationAudience(staff, 'LINK_REVIEW', 'cls-a', () => false)).toEqual({ staffIds: [], roles: ['DIRECTOR'] });
    const onlyDirector = [person('dir', 'DIRECTOR'), person('hr-a', 'HOMEROOM', { classIds: ['cls-a'] })];
    expect(notificationAudience(onlyDirector, 'LINK_CORRECTION', 'cls-a', (role) => role === 'TEACHER')).toEqual({ staffIds: [], roles: ['DIRECTOR'] });
  });

  it('faol direktor ham yo\'q — bildirishnoma yozilmaydi (`null`)', () => {
    const noDirector = staff.map((s) => (s.role === 'DIRECTOR' ? { ...s, active: false } : s));
    expect(notificationAudience(noDirector, 'LINK_REVIEW', 'cls-a', () => false)).toBeNull();
    expect(notificationAudience([], 'LINK_REVIEW', 'cls-a')).toBeNull();
  });
});
