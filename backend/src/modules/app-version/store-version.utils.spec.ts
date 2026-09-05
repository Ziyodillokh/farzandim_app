import {
  appStoreIdFromUrl,
  compareVersions,
  isValidVersion,
  parseAppStoreVersion,
  parsePlayVersion,
  shouldAccept,
} from './store-version.utils';

/**
 * Do'kon versiyasini avtomatik aniqlash — XAVFSIZLIK testlari.
 *
 * Bu yerdagi asosiy savol: noto'g'ri qiymat manifestga TUSHIB QOLADIMI?
 * Chunki uning narxi allaqachon ikki marta to'langan:
 *   • 2026-08-26 — `latest` deploy raqamiga (1.0.513) aylanib, hamma
 *     foydalanuvchiga SOXTA "yangilanish bor" ko'rsatildi;
 *   • 2026-09-05 — iOS 1.0.1 chiqqach manifest 1.0.0 da qolib, haqiqiy
 *     yangilanish YASHIRINDI.
 * Shuning uchun quyida ataylab buzuq javoblar beriladi.
 */
describe('Do\'kon versiyasini aniqlash', () => {
  describe('isValidVersion — faqat ishonchli shakl', () => {
    it.each(['1.0', '1.0.1', '10.20.30', '1.0.513'])(
      "'%s' qabul qilinadi",
      (v) => expect(isValidVersion(v)).toBe(true),
    );

    it.each([
      '',
      'v1.0.0',
      '1',
      '1.0.0-beta',
      'Varies with device', // Play shu matnni qaytarishi mumkin
      'Zavisit ot ustroystva',
      '1.0.0.0.0',
      'null',
    ])("'%s' RAD ETILADI", (v) => expect(isValidVersion(v)).toBe(false));

    it('null va undefined rad etiladi', () => {
      expect(isValidVersion(null)).toBe(false);
      expect(isValidVersion(undefined)).toBe(false);
    });
  });

  describe('compareVersions — raqamli, leksik emas', () => {
    it('1.0.10 > 1.0.9 (matn sifatida teskari bo\'lardi)', () => {
      expect(compareVersions('1.0.10', '1.0.9')).toBe(1);
    });
    it('1.0 va 1.0.0 teng', () => {
      expect(compareVersions('1.0', '1.0.0')).toBe(0);
    });
    it('1.0.3 < 1.0.4', () => {
      expect(compareVersions('1.0.3', '1.0.4')).toBe(-1);
    });
  });

  describe('shouldAccept — eng muhim qoida', () => {
    it("yangi versiya qabul qilinadi", () => {
      expect(shouldAccept('1.0.4', '1.0.3')).toBe(true);
    });

    it('bir xil versiya qabul qilinadi (zararsiz)', () => {
      expect(shouldAccept('1.0.3', '1.0.3')).toBe(true);
    });

    it('PASTGA TUSHIRISH rad etiladi', () => {
      // Do'kon sahifasi vaqtincha noto'g'ri o'qilsa, foydalanuvchiga
      // mavjud bo'lmagan "yangilanish" ko'rsatilmasin.
      expect(shouldAccept('1.0.2', '1.0.4')).toBe(false);
    });

    it("buzuq qiymat hech qachon qabul qilinmaydi", () => {
      expect(shouldAccept('Varies with device', '1.0.3')).toBe(false);
      expect(shouldAccept(null, '1.0.3')).toBe(false);
      expect(shouldAccept('', '1.0.3')).toBe(false);
    });

    it("ma'lum qiymat yo'q bo'lsa yaroqli versiya qabul qilinadi", () => {
      expect(shouldAccept('1.0.7', null)).toBe(true);
    });
  });

  describe('parseAppStoreVersion — iTunes JSON', () => {
    it("haqiqiy javobdan versiyani oladi", () => {
      const body = JSON.stringify({
        resultCount: 1,
        results: [{ version: '1.0.1', trackName: 'Parvoz Parents' }],
      });
      expect(parseAppStoreVersion(body)).toBe('1.0.1');
    });

    it("ilova topilmasa null (resultCount 0)", () => {
      expect(parseAppStoreVersion('{"resultCount":0,"results":[]}')).toBeNull();
    });

    it('buzuq JSON null qaytaradi, tashlamaydi', () => {
      expect(parseAppStoreVersion('<html>404</html>')).toBeNull();
    });

    it("versiya buzuq bo'lsa null", () => {
      const body = JSON.stringify({
        resultCount: 1,
        results: [{ version: 'beta' }],
      });
      expect(parseAppStoreVersion(body)).toBeNull();
    });
  });

  describe('parsePlayVersion — HTML (mo\'rt, shuning uchun himoyalangan)', () => {
    it("joriy tuzilishdan oladi", () => {
      expect(parsePlayVersion('x[[["1.0.4"]],[[y')).toBe('1.0.4');
    });

    it('schema.org naqshidan oladi', () => {
      expect(parsePlayVersion('{"softwareVersion": "2.3.1"}')).toBe('2.3.1');
    });

    it("hech narsa mos kelmasa null — ESKI QIYMAT SAQLANADI", () => {
      // Google sahifa tuzilishini o'zgartirgan holat. Bu null bo'lishi
      // SHART: taxmin qilib yozish soxta bildirishnomaga olib keladi.
      expect(parsePlayVersion('<html><body>Nothing here</body></html>'))
        .toBeNull();
    });

    it("bo'sh sahifa null", () => {
      expect(parsePlayVersion('')).toBeNull();
    });

    it("'Varies with device' qabul qilinmaydi", () => {
      expect(
        parsePlayVersion('<div>Current Version Varies with device</div>'),
      ).toBeNull();
    });
  });

  describe('appStoreIdFromUrl', () => {
    it('haqiqiy havoladan ID', () => {
      expect(appStoreIdFromUrl('https://apps.apple.com/app/id6798972223'))
        .toBe('6798972223');
    });
    it('mamlakat kodli havoladan ham', () => {
      expect(
        appStoreIdFromUrl(
          'https://apps.apple.com/uz/app/parvoz-parents/id6798972223?uo=4',
        ),
      ).toBe('6798972223');
    });
    it('ID yo\'q bo\'lsa null', () => {
      expect(appStoreIdFromUrl('https://apps.apple.com/app/parvoz')).toBeNull();
    });
  });
});
