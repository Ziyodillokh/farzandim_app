import { isValidCardNumber, randomCardNumber, verhoeffDigit } from './card-number';

describe('karta raqami', () => {
  it('Verhoeff tekshiruv raqami ma\'lum misollarda to\'g\'ri', () => {
    expect(verhoeffDigit('236')).toBe(3);
    expect(verhoeffDigit('482109375')).toBe(3);
    expect(isValidCardNumber('4821093753')).toBe(true);
  });

  it('bitta xato raqam va qo\'shni raqamlar almashishi ushlanadi', () => {
    expect(isValidCardNumber('4821093754')).toBe(false);
    expect(isValidCardNumber('4821093853')).toBe(false);
    expect(isValidCardNumber('4812093753')).toBe(false);
  });

  it('format: 10 xona, boshida nol yo\'q', () => {
    expect(isValidCardNumber('0821093753')).toBe(false);
    expect(isValidCardNumber('482109375')).toBe(false);
    expect(isValidCardNumber('K-000001')).toBe(false);
  });

  it('tasodifiy raqam doim to\'g\'ri formatda (chegaraviy qiymatlar bilan)', () => {
    expect(randomCardNumber((min) => min)).toBe(`100000000${verhoeffDigit('100000000')}`);
    expect(randomCardNumber((_, max) => max - 1)).toBe(`999999999${verhoeffDigit('999999999')}`);
    for (let i = 0; i < 200; i += 1) expect(isValidCardNumber(randomCardNumber())).toBe(true);
  });
});
