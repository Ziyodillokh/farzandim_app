import {
  normalizePlanRequired,
  normalizeXpReward,
  PLAN_REQUIRED_VALUES,
} from './content-meta.utils';

/**
 * Multipart yuklash DTO'dan o'tmaydi — `meta` oddiy `any`. Bu testlar
 * o'sha teshikni yopadi.
 *
 * Fon: `planRequired` ga `PLAN_RANK` bilmaydigan qiymat (masalan `basic`)
 * tushsa, kontent HECH KIMGA ko'rinmaydi — hatto eng qimmat tarifdagi
 * foydalanuvchiga ham — chunki `planRequired IN allowedPlans(...)` filtri
 * hech qachon mos kelmaydi. Admin panelda esa u "tasdiqlangan" bo'lib
 * turadi, ya'ni xato ko'rinmaydi.
 */
describe('Kontent metadatasini xavfsizlashtirish', () => {
  describe('normalizePlanRequired', () => {
    it.each(PLAN_REQUIRED_VALUES)("'%s' o'zgarishsiz qoladi", (v) => {
      expect(normalizePlanRequired(v)).toBe(v);
    });

    it("'basic' → 'free' (PLAN_RANK uni bilmaydi)", () => {
      // Repo'ning O'Z seed skripti shu qiymatni yozardi.
      expect(normalizePlanRequired('basic')).toBe('free');
    });

    it('katta harf va bo\'shliq tozalanadi', () => {
      expect(normalizePlanRequired('  PREMIUM ')).toBe('premium');
      expect(normalizePlanRequired('Standard')).toBe('standard');
    });

    it.each([undefined, null, '', 42, {}, [], 'bepul', 'gold'])(
      '%p → free',
      (v) => expect(normalizePlanRequired(v)).toBe('free'),
    );
  });

  describe('normalizeXpReward', () => {
    it('to\'g\'ri son o\'tadi', () => {
      expect(normalizeXpReward(120)).toBe(120);
      expect(normalizeXpReward('75')).toBe(75);
    });

    it('nol ruxsat etiladi', () => {
      expect(normalizeXpReward(0)).toBe(0);
    });

    it('manfiy va buzuq qiymat standartga tushadi', () => {
      expect(normalizeXpReward(-5)).toBe(50);
      expect(normalizeXpReward('abc')).toBe(50);
      expect(normalizeXpReward(undefined)).toBe(50);
      expect(normalizeXpReward(Infinity)).toBe(50);
    });

    it('kasr son butunlashtiriladi', () => {
      expect(normalizeXpReward(10.9)).toBe(10);
    });
  });
});
