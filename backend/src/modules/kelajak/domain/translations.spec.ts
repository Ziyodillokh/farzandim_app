import { KELAJAK_TRANSLATIONS } from './translations.data';
import { withTranslations } from './translations';

describe('Kelajak tarjimalari', () => {
  it("bank savoliga ruscha va inglizcha qo'shiladi", () => {
    const text = withTranslations({ uz: 'Mantiqiy boshqotirmalarni yechishdan zavqlanasanmi?' });
    expect(text.ru).toBe('Тебе нравится решать логические головоломки?');
    expect(text.en).toBe('Do you enjoy solving logic puzzles?');
  });

  it('javob varianti ham tarjima qilinadi', () => {
    expect(withTranslations({ uz: 'Juda yoqadi' })).toEqual({ uz: 'Juda yoqadi', ru: 'Очень нравится', en: 'Like it a lot' });
  });

  it("bazadagi tarjima ustun; noma'lum matn o'zgarmaydi", () => {
    expect(withTranslations({ uz: 'Yoqadi', ru: 'Admin' }).ru).toBe('Admin');
    expect(withTranslations({ uz: 'Yangi savol' })).toEqual({ uz: 'Yangi savol' });
  });

  it("har bir tarjima to'liq", () => {
    const entries = Object.entries(KELAJAK_TRANSLATIONS);
    expect(entries.length).toBe(292);
    for (const [uz, t] of entries) {
      expect(uz.trim()).toBe(uz);
      expect(t.ru.length).toBeGreaterThan(0);
      expect(t.en.length).toBeGreaterThan(0);
    }
  });
});
