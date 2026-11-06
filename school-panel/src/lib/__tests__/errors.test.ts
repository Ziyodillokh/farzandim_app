import { describe, expect, it } from 'vitest';

import { ServiceError } from '@/data/contracts';
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
    // Tarjimasi yo'q kod — kod bo'yicha umumiy kalit.
    expect(errorKey(new ServiceError('CONFLICT', 'x', 'REQUEST_CLOSED'))).toBe('errors.CONFLICT');
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
