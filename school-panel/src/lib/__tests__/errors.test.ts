import { describe, expect, it } from 'vitest';

import { ServiceError } from '@/data/contracts';
import { translate } from '@/i18n/translate';
import { errorDetail, errorKey, formErrorKey } from '../errors';

describe('errorKey', () => {
  it('VALIDATION `maydon: errors.form.kalit` — forma kaliti', () => {
    expect(errorKey(new ServiceError('VALIDATION', 'workEnd: errors.form.endBeforeStart'))).toBe('errors.form.endBeforeStart');
  });

  it('panelda tarjimasi yo\'q forma kaliti — umumiy VALIDATION xabari (xom kalit ko\'rinmaydi)', () => {
    expect(errorKey(new ServiceError('VALIDATION', 'workEnd: errors.form.yangiTekshiruv'))).toBe('errors.VALIDATION');
    expect(formErrorKey('errors.form.yangiTekshiruv')).toBe('errors.VALIDATION');
  });

  it('backend\'ning aniq kodi (detail) tarjimasi bo\'lsa — umumiy CONFLICT o\'rniga aynan shu xabar', () => {
    expect(errorKey(new ServiceError('CONFLICT', 'NOT_LINKED', 'NOT_LINKED'))).toBe('errors.detail.NOT_LINKED');
    expect(errorKey(new ServiceError('CONFLICT', 'LOGIN_TAKEN', 'LOGIN_TAKEN'))).toBe('errors.detail.LOGIN_TAKEN');
    // Ulanish/tiklash so'rovi allaqachon hal qilingan: «yozuv mavjud» o'rniga aniq xabar (backend kodlari ham shular).
    expect(errorKey(new ServiceError('CONFLICT', 'already resolved', 'ALREADY_RESOLVED'))).toBe('errors.detail.ALREADY_RESOLVED');
    expect(errorKey(new ServiceError('NOT_FOUND', 'x', 'REQUEST_NOT_FOUND'))).toBe('errors.detail.REQUEST_NOT_FOUND');
    // Tarjimasi yo'q kod — kod bo'yicha umumiy kalit.
    expect(errorKey(new ServiceError('CONFLICT', 'x', 'REQUEST_CLOSED'))).toBe('errors.CONFLICT');
  });

  it('K1/K2 kodlari (STUDENT_ARCHIVED, REQUEST_STALE, STUDENT_LINKED_ELSEWHERE, ALREADY_ENROLLED): aniq matn, ikkala tilda', () => {
    for (const detail of ['STUDENT_ARCHIVED', 'REQUEST_STALE', 'STUDENT_LINKED_ELSEWHERE', 'ALREADY_ENROLLED']) {
      const key = errorKey(new ServiceError('CONFLICT', 'x', detail));
      expect(key).toBe(`errors.detail.${detail}`);
      expect(translate('uz', key)).not.toBe(key);
      expect(translate('uz', key)).not.toMatch(/[А-Яа-я]/);
      expect(translate('ru', key)).toMatch(/[А-Яа-я]/);
    }
  });

  it('umumiy 404 (`NOT_FOUND` kodi har bir maktab xatosida) o\'z umumiy matnini saqlaydi — "detail" bilan bosib ketilmaydi', () => {
    expect(errorKey(new ServiceError('NOT_FOUND', 'stu-1', 'NOT_FOUND'))).toBe('errors.NOT_FOUND');
    expect(errorKey(new ServiceError('FORBIDDEN', 'class c1', 'FORBIDDEN'))).toBe('errors.FORBIDDEN');
  });

  it('errorDetail: faqat ServiceError.detail', () => {
    expect(errorDetail(new ServiceError('CONFLICT', 'x', 'NOT_LINKED'))).toBe('NOT_LINKED');
    expect(errorDetail(new ServiceError('CONFLICT', 'x'))).toBeNull();
    expect(errorDetail(new Error('NOT_LINKED'))).toBeNull();
    expect(errorDetail(null)).toBeNull();
  });

  it('boshqa kodlar — kod bo\'yicha kalit; ServiceError bo\'lmasa UNKNOWN', () => {
    expect(errorKey(new ServiceError('CONFLICT', 'REQUEST_CLOSED'))).toBe('errors.CONFLICT');
    expect(errorKey(new Error('x'))).toBe('errors.UNKNOWN');
  });
});
