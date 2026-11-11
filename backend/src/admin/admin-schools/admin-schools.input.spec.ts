import { BadRequestException } from '@nestjs/common';
import {
  ADMIN_MANAGED_ROLES,
  addStaffSchema,
  createSchoolSchema,
  listSchoolsSchema,
  parseAdminInput,
  resetPasswordSchema,
} from './admin-schools.input';

const school = (patch: object = {}) => ({
  code: ' Parvoz-14 ',
  name: '14-maktab',
  city: 'Toshkent',
  director: { fullName: 'Karimov Akmal' },
  ...patch,
});

const messageOf = (fn: () => unknown): string => {
  try {
    fn();
  } catch (e) {
    expect(e).toBeInstanceOf(BadRequestException);
    return ((e as BadRequestException).getResponse() as { message: string }).message;
  }
  throw new Error('xato kutilgan edi');
};

describe('admin-schools input', () => {
  it('maktab: kod kichik harfga, direktor logini — «direktor»', () => {
    const data = parseAdminInput(createSchoolSchema, school());
    expect(data).toEqual({
      code: 'parvoz-14',
      name: '14-maktab',
      shortName: undefined,
      city: 'Toshkent',
      director: { fullName: 'Karimov Akmal', username: 'direktor' },
    });
  });

  it('maktab: noto\'g\'ri kod, bo\'sh nom va uzun qisqa nom — maydon bilan xabar', () => {
    expect(messageOf(() => parseAdminInput(createSchoolSchema, school({ code: '14 maktab' })))).toMatch(/^code: /);
    expect(messageOf(() => parseAdminInput(createSchoolSchema, school({ name: '  ' })))).toBe('name: Maktab nomi kiritilmagan');
    expect(messageOf(() => parseAdminInput(createSchoolSchema, school({ shortName: 'x'.repeat(13) })))).toMatch(/^shortName: /);
    expect(messageOf(() => parseAdminInput(createSchoolSchema, school({ city: '' })))).toMatch(/^city: /);
    expect(
      messageOf(() => parseAdminInput(createSchoolSchema, school({ director: { fullName: 'A', username: 'Di' } }))),
    ).toMatch(/^director\.username: /);
    expect(messageOf(() => parseAdminInput(createSchoolSchema, school({ director: undefined })))).toMatch(/^director: /);
    expect(messageOf(() => parseAdminInput(createSchoolSchema, undefined))).toBeTruthy();
  });

  it('xodim: faqat direktor va psixolog', () => {
    expect(ADMIN_MANAGED_ROLES).toEqual(expect.arrayContaining(['DIRECTOR', 'PSYCHOLOGIST']));
    expect(ADMIN_MANAGED_ROLES).not.toContain('TEACHER');
    const ok = parseAdminInput(addStaffSchema, { role: 'PSYCHOLOGIST', fullName: 'Yusupova Malika', username: 'Psixolog' });
    expect(ok).toEqual({ role: 'PSYCHOLOGIST', fullName: 'Yusupova Malika', username: 'psixolog', position: undefined });
    expect(
      messageOf(() => parseAdminInput(addStaffSchema, { role: 'TEACHER', fullName: 'A', username: 'oqituvchi' })),
    ).toMatch(/^role: /);
  });

  it('parolni tiklash: tanasiz — 2FA o\'zgarmaydi', () => {
    expect(parseAdminInput(resetPasswordSchema, undefined)).toEqual({ resetTotp: false });
    expect(parseAdminInput(resetPasswordSchema, { resetTotp: true })).toEqual({ resetTotp: true });
  });

  it('ro\'yxat: sahifa chegaralari', () => {
    expect(parseAdminInput(listSchoolsSchema, {})).toEqual({ q: undefined, page: 1, limit: 20 });
    expect(parseAdminInput(listSchoolsSchema, { q: ' 14 ', page: '2', limit: '50' })).toEqual({ q: '14', page: 2, limit: 50 });
    expect(messageOf(() => parseAdminInput(listSchoolsSchema, { limit: '500' }))).toMatch(/^limit: /);
  });
});
