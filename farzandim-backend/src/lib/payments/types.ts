// To'lov provayderlari — provayder-agnostik tip va interfeyslar (Sprint 6).
//
// Har bir provayder (Payme/Click/Uzum) o'zining protokolini to'liq inkapsulyatsiya
// qiladi. Routes qatlami faqat shu interfeysni biladi — provayderga xos JSON-RPC
// yoki prepare/complete mantig'i bilan ishlamaydi.

export type PaymentProviderKey = 'payme' | 'click' | 'uzum';

export const PAYMENT_PROVIDER_KEYS: readonly PaymentProviderKey[] = [
  'payme',
  'click',
  'uzum',
];

export function isPaymentProviderKey(value: unknown): value is PaymentProviderKey {
  return (
    typeof value === 'string' &&
    (PAYMENT_PROVIDER_KEYS as readonly string[]).includes(value)
  );
}

/** Checkout boshlash uchun kerakli ma'lumot (provayder-agnostik). */
export interface CheckoutInput {
  /** Bizning Payment.id — provayderga buyurtma ID sifatida uzatiladi. */
  paymentId: string;
  /** To'lov summasi — UZS so'm. */
  amount: number;
  /** Tarif nomi (provayder checkout sahifasida ko'rsatish uchun). */
  planName: string;
  /** To'lovdan keyin foydalanuvchi qaytadigan sahifa. */
  returnUrl?: string;
}

export interface CheckoutResult {
  provider: PaymentProviderKey;
  /** Foydalanuvchi yo'naltiriladigan to'lov sahifasi URL'i. */
  checkoutUrl: string;
  /** Provayderga xos qo'shimcha ma'lumot (ixtiyoriy). */
  meta?: Record<string, unknown>;
}

/** Provayder webhook'iga kelgan so'rov — framework-agnostik (test qilsa bo'ladi). */
export interface WebhookRequest {
  body: unknown;
  /** Xom request body (imzo tekshiruvi uchun). */
  rawBody: string;
  headers: Record<string, string | undefined>;
  query: Record<string, unknown>;
}

/** Provayderga qaytariladigan javob (HTTP status + body). */
export interface WebhookResponse {
  status: number;
  body: unknown;
}

export interface PaymentProvider {
  readonly key: PaymentProviderKey;
  /** .env'da kerakli kalitlar bor-yo'qligi. false bo'lsa provayder o'chiq. */
  isConfigured(): boolean;
  /**
   * Checkout URL yaratadi.
   * @throws ProviderNotConfiguredError — isConfigured() false bo'lsa.
   */
  createCheckout(input: CheckoutInput): Promise<CheckoutResult>;
  /** Provayder callback protokolini to'liq boshqaradi. */
  handleWebhook(req: WebhookRequest): Promise<WebhookResponse>;
}

/** Provayder sozlanmaganda (kalitlar yo'q) tashlanadi. */
export class ProviderNotConfiguredError extends Error {
  constructor(public readonly providerKey: PaymentProviderKey) {
    super(`To'lov provayderi "${providerKey}" sozlanmagan (.env kalitlari yo'q)`);
    this.name = 'ProviderNotConfiguredError';
  }
}
