import { maskPhone, phoneTail, realPhone } from './guardian-phone';

describe('guardian phone helpers', () => {
  describe('realPhone', () => {
    it('keeps a real phone and drops placeholders and empty values', () => {
      expect(realPhone('+998901234567')).toBe('+998901234567');
      expect(realPhone('tg:123456789')).toBe('');
      expect(realPhone('')).toBe('');
      expect(realPhone(null)).toBe('');
      expect(realPhone(undefined)).toBe('');
    });
  });

  describe('phoneTail', () => {
    it('is the last 9 digits regardless of formatting or country code', () => {
      expect(phoneTail('+998901234567')).toBe('901234567');
      expect(phoneTail('+998 90 123 45 67')).toBe('901234567');
      expect(phoneTail('90 123 45 67')).toBe('901234567');
      expect(phoneTail('8 (90) 123-45-67')).toBe('901234567');
    });

    it('is null for short numbers, empty values and Telegram placeholders (even with 9+ digits)', () => {
      expect(phoneTail('12345678')).toBeNull();
      expect(phoneTail('')).toBeNull();
      expect(phoneTail(null)).toBeNull();
      expect(phoneTail('tg:123456789012')).toBeNull();
    });
  });

  describe('maskPhone', () => {
    it.each([
      ['+998901234567', '+998 ** *** 45 67'],
      ['+998 90 123 45 67', '+998 ** *** 45 67'],
      ['998 90 123 12 34', '+998 ** *** 12 34'],
    ])('masks the Uzbek number %s as %s', (input, expected) => {
      expect(maskPhone(input)).toBe(expected);
    });

    it('shows only the last four digits of other numbers', () => {
      expect(maskPhone('+79161234567')).toBe('+******* 45 67');
      expect(maskPhone('0161234567')).toBe('****** 45 67');
    });

    it('never leaks more than the last four digits', () => {
      for (const phone of ['+998901234567', '+79161234567', '0161234567']) {
        const masked = maskPhone(phone)!;
        const visibleDigits = masked.replace(/\D/g, '');
        expect(visibleDigits.endsWith('4567')).toBe(true);
        expect(visibleDigits.replace('998', '').length).toBeLessThanOrEqual(4);
      }
    });

    it('is null without a real phone', () => {
      expect(maskPhone(null)).toBeNull();
      expect(maskPhone('')).toBeNull();
      expect(maskPhone('tg:123456789')).toBeNull();
      expect(maskPhone('123')).toBeNull();
    });
  });
});
