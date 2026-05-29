export type PaymentProviderKey = 'payme' | 'click' | 'uzum';

export const PAYMENT_PROVIDER_KEYS: readonly PaymentProviderKey[] = [
  'payme',
  'click',
  'uzum',
];

export function isPaymentProviderKey(
  value: unknown,
): value is PaymentProviderKey {
  return (
    typeof value === 'string' &&
    (PAYMENT_PROVIDER_KEYS as readonly string[]).includes(value)
  );
}

/** Checkout input (provider-agnostic). */
export interface CheckoutInput {
  paymentId: string;
  amount: number;
  planName: string;
  returnUrl?: string;
}

export interface CheckoutResult {
  provider: PaymentProviderKey;
  checkoutUrl: string;
  meta?: Record<string, unknown>;
}

/** Provider webhook request -- framework-agnostic. */
export interface WebhookRequest {
  body: unknown;
  rawBody: string;
  headers: Record<string, string | undefined>;
  query: Record<string, unknown>;
}

export interface WebhookResponse {
  status: number;
  body: unknown;
}

export interface PaymentProvider {
  readonly key: PaymentProviderKey;
  isConfigured(): boolean;
  createCheckout(input: CheckoutInput): Promise<CheckoutResult>;
  handleWebhook(req: WebhookRequest): Promise<WebhookResponse>;
}

export class ProviderNotConfiguredError extends Error {
  constructor(public readonly providerKey: PaymentProviderKey) {
    super(`Payment provider "${providerKey}" is not configured (.env keys missing)`);
    this.name = 'ProviderNotConfiguredError';
  }
}
