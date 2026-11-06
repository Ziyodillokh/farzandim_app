import { describe, expect, it } from 'vitest';

import { ServiceError } from '@/data/contracts';
import { errorKey, formErrorKey } from '../errors';

describe('errorKey', () => {
  it('VALIDATION `maydon: errors.form.kalit` — forma kaliti', () => {
    expect(errorKey(new ServiceError('VALIDATION', 'workEnd: errors.form.endBeforeStart'))).toBe('errors.form.endBeforeStart');
  });

  it('panelda tarjimasi yo\'q forma kaliti — umumiy VALIDATION xabari (xom kalit ko\'rinmaydi)', () => {
    expect(errorKey(new ServiceError('VALIDATION', 'workEnd: errors.form.yangiTekshiruv'))).toBe('errors.VALIDATION');
    expect(formErrorKey('errors.form.yangiTekshiruv')).toBe('errors.VALIDATION');
  });

  it('boshqa kodlar — kod bo\'yicha kalit; ServiceError bo\'lmasa UNKNOWN', () => {
    expect(errorKey(new ServiceError('CONFLICT', 'REQUEST_CLOSED'))).toBe('errors.CONFLICT');
    expect(errorKey(new Error('x'))).toBe('errors.UNKNOWN');
  });
});
