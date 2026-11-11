import { generateTempPassword, TEMP_PASSWORD_LENGTH } from './temp-password';

describe('generateTempPassword', () => {
  it('12 belgi, faqat o\'qilishi oson belgilar', () => {
    for (let i = 0; i < 200; i++) {
      const password = generateTempPassword();
      expect(password).toHaveLength(TEMP_PASSWORD_LENGTH);
      expect(password).toMatch(/^[a-km-np-zA-HJ-NP-Z2-9]+$/);
    }
  });

  it('har chaqiruvda boshqa', () => {
    const seen = new Set(Array.from({ length: 50 }, () => generateTempPassword()));
    expect(seen.size).toBe(50);
  });
});
