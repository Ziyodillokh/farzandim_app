import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

import { generateSeed } from '@/data/mock/seed';
import { assignAllPortraits, assignPortrait, inferStaffGender, PINNED_PORTRAITS, PORTRAIT_POOL, portraitUrl, shortName, staffAvatarSrc } from '../staff-avatar';

const staff = generateSeed(20261012, new Date('2026-10-12T10:00:00')).staff;

describe('xodim portretlari', () => {
  it('jins otasining ismi qo\'shimchasidan aniqlanadi', () => {
    expect(inferStaffGender('Yusupova Nodira Azimovna')).toBe('FEMALE');
    expect(inferStaffGender('Toshmatov Sardor Akmalovich')).toBe('MALE');
    expect(inferStaffGender('Karimova Aziza')).toBe('FEMALE');
    expect(inferStaffGender("Aliyev Javohir Bobur o'g'li")).toBe('MALE');
  });

  it('har seed xodimiga jinsiga mos, takrorlanmas portret', () => {
    const keys = staff.map((s) => s.portrait);
    expect(keys.every(Boolean)).toBe(true);
    expect(new Set(keys).size).toBe(keys.length);
    for (const s of staff) expect(s.portrait?.[0]).toBe(inferStaffGender(s.fullName) === 'FEMALE' ? 'f' : 'm');
  });

  it('demo hisoblarga biriktirilgan portretlar', () => {
    for (const [id, key] of Object.entries(PINNED_PORTRAITS)) expect(staff.find((s) => s.id === id)?.portrait).toBe(key);
  });

  it('pul seed\'dagi har jins uchun yetarli va barcha fayllar mavjud', () => {
    const female = staff.filter((s) => inferStaffGender(s.fullName) === 'FEMALE').length;
    expect(female).toBeLessThanOrEqual(PORTRAIT_POOL.FEMALE);
    expect(staff.length - female).toBeLessThanOrEqual(PORTRAIT_POOL.MALE);
    for (const [g, n] of [['f', PORTRAIT_POOL.FEMALE], ['m', PORTRAIT_POOL.MALE]] as const) {
      for (let i = 1; i <= n; i++) {
        expect(existsSync(join(process.cwd(), 'public/avatars', `${g}-${String(i).padStart(2, '0')}.svg`))).toBe(true);
      }
    }
  });

  it('yangi xodim eng kam ishlatilgan portretni oladi; migratsiya mavjudlarini saqlaydi', () => {
    const next = assignPortrait(staff, 'Qodirova Zarina Anvarovna');
    expect(next.startsWith('f-')).toBe(true);
    expect(staff.some((s) => s.portrait === next)).toBe(false);
    const stripped = staff.map((s) => ({ ...s, portrait: undefined }));
    expect(assignAllPortraits(stripped).map((s) => s.portrait)).toEqual(staff.map((s) => s.portrait));
  });

  it('rasm → portret → null; yo\'l basePath bilan va xavfsiz', () => {
    expect(staffAvatarSrc({ photo: 'data:image/png;base64,AAA', portrait: 'f-01' })).toBe('data:image/png;base64,AAA');
    expect(staffAvatarSrc({ portrait: 'f-01' })).toMatch(/\/avatars\/f-01\.svg$/);
    expect(portraitUrl('../x')).toBeNull();
    expect(staffAvatarSrc({})).toBeNull();
    expect(shortName('Yusupova Nodira Azimovna')).toBe('Nodira Yusupova');
  });
});
