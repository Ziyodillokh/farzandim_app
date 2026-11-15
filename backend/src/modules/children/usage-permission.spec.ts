import { reliableUsagePermission } from './usage-permission';

describe('reliableUsagePermission', () => {
  it("1.0.19 va eskiroq versiyadan kelgan false e'tiborsiz qoldiriladi", () => {
    expect(reliableUsagePermission(false, '1.0.19')).toBeUndefined();
    expect(reliableUsagePermission(false, '1.0.9')).toBeUndefined();
    expect(reliableUsagePermission(false, '0.9.30')).toBeUndefined();
  });

  it('versiyasi noma\'lum yoki tushunarsiz bo\'lsa false ham e\'tiborsiz', () => {
    expect(reliableUsagePermission(false, null)).toBeUndefined();
    expect(reliableUsagePermission(false, undefined)).toBeUndefined();
    expect(reliableUsagePermission(false, 'beta')).toBeUndefined();
  });

  it('1.0.20 va yangiroq versiyadan kelgan false saqlanadi', () => {
    expect(reliableUsagePermission(false, '1.0.20')).toBe(false);
    expect(reliableUsagePermission(false, '1.0.21+21')).toBe(false);
    expect(reliableUsagePermission(false, '1.1')).toBe(false);
    expect(reliableUsagePermission(false, '2.0.0')).toBe(false);
  });

  it('true va kelmagan qiymat har qanday versiyada o\'zgarmaydi', () => {
    expect(reliableUsagePermission(true, '1.0.19')).toBe(true);
    expect(reliableUsagePermission(true, null)).toBe(true);
    expect(reliableUsagePermission(undefined, '1.0.19')).toBeUndefined();
  });
});
