import { describe, expect, it } from 'vitest';

import { buildCards } from '@/data/mock/seed/cards';
import { cardNumberFrom, formatCardNumber, isValidCardNumber, randomCardNumber, verhoeffDigit } from '../card-number';

describe('karta raqami', () => {
  it('Verhoeff: ma\'lum misollar va backend bilan bir xil natija', () => {
    expect(verhoeffDigit('236')).toBe(3);
    expect(cardNumberFrom(482109375)).toBe('4821093753');
    expect(isValidCardNumber('4821093753')).toBe(true);
  });

  it('bitta xato raqam va qo\'shni raqamlar almashishi ushlanadi; boshida nol yo\'q', () => {
    expect(isValidCardNumber('4821093754')).toBe(false);
    expect(isValidCardNumber('4812093753')).toBe(false);
    expect(isValidCardNumber('0821093753')).toBe(false);
    expect(isValidCardNumber('K-000001')).toBe(false);
  });

  it('tasodifiy raqam chegaralarda ham to\'g\'ri', () => {
    expect(isValidCardNumber(randomCardNumber(() => 0))).toBe(true);
    expect(isValidCardNumber(randomCardNumber(() => 0.999_999_999))).toBe(true);
    for (let i = 0; i < 200; i += 1) expect(isValidCardNumber(randomCardNumber())).toBe(true);
  });

  it('ko\'rsatish: 5 + 5, eski raqamlar o\'zgarmaydi', () => {
    expect(formatCardNumber('4821093753')).toBe('48210 93753');
    expect(formatCardNumber('K-000001')).toBe('K-000001');
  });

  it('demo kartalar: hammasi to\'g\'ri va takrorlanmaydi', () => {
    const students = Array.from({ length: 1500 }, (_, i) => ({ id: `s${i}`, archived: false, enrolledAt: '2025-09-01' }));
    const numbers = buildCards(students as never).map((c) => c.number);
    expect(numbers.every(isValidCardNumber)).toBe(true);
    expect(new Set(numbers).size).toBe(numbers.length);
  });
});
