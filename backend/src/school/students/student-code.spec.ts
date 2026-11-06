import { isStudentCode, randomStudentCode, STUDENT_CODE_LENGTH, STUDENT_CODE_TTL_MS, stripCodeSeparators } from './student-code';

// Servis `node:crypto` dan nomli import qiladi (CJS: chaqiruv paytida xossa o'qiladi) — haqiqiy modul ustida spy.
const nodeCrypto = jest.requireActual('node:crypto') as { randomInt: (max: number) => number };

describe('student code helpers', () => {
  afterEach(() => jest.restoreAllMocks());

  it('has a 24 hour lifetime and 6 digits', () => {
    expect(STUDENT_CODE_TTL_MS).toBe(24 * 3_600_000);
    expect(STUDENT_CODE_LENGTH).toBe(6);
  });

  it('generates 6-digit codes', () => {
    for (let i = 0; i < 200; i += 1) expect(randomStudentCode()).toMatch(/^\d{6}$/);
  });

  it('keeps leading zeros', () => {
    jest.spyOn(nodeCrypto, 'randomInt').mockReturnValueOnce(0).mockReturnValueOnce(5).mockReturnValueOnce(48213).mockReturnValueOnce(999_999);

    expect([randomStudentCode(), randomStudentCode(), randomStudentCode(), randomStudentCode()]).toEqual(['000000', '000005', '048213', '999999']);
  });

  it('draws from the full 10^6 space', () => {
    const spy = jest.spyOn(nodeCrypto, 'randomInt');

    randomStudentCode();

    expect(spy).toHaveBeenCalledWith(1_000_000);
  });

  it('recognizes exactly six digits', () => {
    expect(['123456', '000001'].every(isStudentCode)).toBe(true);
    expect(['12345', '1234567', 'ABCDEFGH', '12 456', '１２３４５６', ''].some(isStudentCode)).toBe(false);
  });

  it('strips spaces and dashes only', () => {
    expect(stripCodeSeparators(' 048-213 ')).toBe('048213');
    expect(stripCodeSeparators('04 82\t13')).toBe('048213');
    expect(stripCodeSeparators('AB_12')).toBe('AB_12');
  });
});
