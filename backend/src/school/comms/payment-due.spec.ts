import { daysUntil, formatPaymentDate, isPaymentDue, paymentDueLine } from './payment-due';

describe("to'lov muddati", () => {
  it('kunlar farqi: oldin musbat, o\'sha kuni 0, o\'tgach manfiy (oy va yil chegarasida ham)', () => {
    expect(daysUntil('2026-11-20', '2026-11-25')).toBe(5);
    expect(daysUntil('2026-11-25', '2026-11-25')).toBe(0);
    expect(daysUntil('2026-11-28', '2026-11-25')).toBe(-3);
    expect(daysUntil('2026-12-30', '2027-01-02')).toBe(3);
  });

  it('eslatma oynasi: 5 kun qolganidan boshlab, to\'lanmaguncha', () => {
    expect(isPaymentDue('2026-11-19', '2026-11-25')).toBe(false);
    expect(isPaymentDue('2026-11-20', '2026-11-25')).toBe(true);
    expect(isPaymentDue('2026-12-20', '2026-11-25')).toBe(true);
  });

  it('qator: qoldi / bugun / o\'tib ketgan — «qarz» so\'zisiz', () => {
    expect(paymentDueLine('uz', '2026-11-22', '2026-11-25')).toBe("To'lovga 3 kun qoldi (25.11.2026).");
    expect(paymentDueLine('uz', '2026-11-25', '2026-11-25')).toBe("Bugun to'lov kuni (25.11.2026).");
    expect(paymentDueLine('uz', '2026-11-28', '2026-11-25')).toBe("To'lov sanasi 25.11.2026 da o'tib ketgan.");
    expect(paymentDueLine('ru', '2026-11-28', '2026-11-25')).toBe('Срок оплаты прошёл 25.11.2026.');
    expect(formatPaymentDate('2027-01-02')).toBe('02.01.2027');
    for (const lang of ['uz', 'ru', 'en'] as const) expect(paymentDueLine(lang, '2026-11-28', '2026-11-25')).not.toMatch(/qarz|долг|debt/i);
  });
});
