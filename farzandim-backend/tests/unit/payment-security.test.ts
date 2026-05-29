import { describe, expect, test } from 'vitest';
import { uzumProvider } from '../../src/lib/payments/providers/uzum';
import { timingSafeEqualStr } from '../../src/lib/payments/providers/payme';

describe('Uzum provider (H4)', () => {
  test('isConfigured — imzo sxemasi tasdiqlanmagani uchun har doim false', () => {
    // UZUM_VERIFIED=false bo'lguncha provayder o'chiq — taxminiy imzo
    // formulasi bilan webhook faollashmaydi.
    expect(uzumProvider.isConfigured()).toBe(false);
  });
});

describe('timingSafeEqualStr — Payme Basic-auth doimiy-vaqtli solishtirish (H5)', () => {
  test('bir xil satrlar — true', () => {
    expect(timingSafeEqualStr('merchant-key-abc', 'merchant-key-abc')).toBe(true);
  });

  test('bitta belgi farqi — false', () => {
    expect(timingSafeEqualStr('merchant-key-abc', 'merchant-key-abd')).toBe(false);
  });

  test('uzunlik farqi — false (xato tashlamaydi)', () => {
    expect(timingSafeEqualStr('short', 'much-longer-string')).toBe(false);
  });

  test("bo'sh satrlar", () => {
    expect(timingSafeEqualStr('', '')).toBe(true);
    expect(timingSafeEqualStr('', 'x')).toBe(false);
  });
});
