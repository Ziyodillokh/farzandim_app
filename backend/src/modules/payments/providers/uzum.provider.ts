import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash } from 'crypto';
import { PrismaService } from '../../../common/database/prisma.service';
import { EnvConfig } from '../../../common/config/env.schema';
import { PaymentsService } from '../payments.service';
import {
  ProviderNotConfiguredError,
  type CheckoutInput,
  type CheckoutResult,
  type PaymentProvider,
  type WebhookRequest,
  type WebhookResponse,
} from './types';

interface UzumCallback {
  serviceId?: string;
  paymentId?: string;
  transactionId?: string;
  amount?: number;
  status?: string;
  signTime?: string;
  signString?: string;
}

/**
 * Uzum Bank provider -- Checkout API + callback.
 *
 * WARNING: The exact webhook signature schema is not yet verified
 * with Uzum merchant cabinet documentation. Until verified, the
 * provider stays disabled (UZUM_VERIFIED = false).
 */
const UZUM_VERIFIED = false;

@Injectable()
export class UzumProvider implements PaymentProvider {
  readonly key = 'uzum' as const;

  private serviceId: string;
  private secretKey: string;
  private apiBase: string;

  constructor(
    private readonly config: ConfigService<EnvConfig, true>,
    private readonly prisma: PrismaService,
    private readonly paymentsService: PaymentsService,
  ) {
    this.serviceId =
      this.config.get('UZUM_MERCHANT_SERVICE_ID', { infer: true }) ?? '';
    this.secretKey =
      this.config.get('UZUM_SECRET_KEY', { infer: true }) ?? '';
    this.apiBase =
      this.config.get('UZUM_API_BASE', { infer: true }) ?? '';
  }

  isConfigured(): boolean {
    return (
      UZUM_VERIFIED &&
      Boolean(this.serviceId && this.secretKey && this.apiBase)
    );
  }

  private sha256(value: string): string {
    return createHash('sha256').update(value).digest('hex');
  }

  private verifySign(cb: UzumCallback): boolean {
    const expected = this.sha256(
      `${cb.paymentId}${cb.amount}${cb.status}${cb.signTime}${this.secretKey}`,
    );
    return expected === (cb.signString ?? '').toLowerCase();
  }

  async createCheckout(input: CheckoutInput): Promise<CheckoutResult> {
    if (!this.isConfigured()) throw new ProviderNotConfiguredError('uzum');
    const url = new URL('/checkout', this.apiBase);
    url.searchParams.set('service_id', this.serviceId);
    url.searchParams.set('amount', String(input.amount));
    url.searchParams.set('order_id', input.paymentId);
    if (input.returnUrl)
      url.searchParams.set('return_url', input.returnUrl);
    return { provider: 'uzum', checkoutUrl: url.toString() };
  }

  async handleWebhook(req: WebhookRequest): Promise<WebhookResponse> {
    const cb = (req.body ?? {}) as UzumCallback;

    if (typeof cb.paymentId !== 'string') {
      return {
        status: 400,
        body: { status: 'ERROR', message: 'paymentId missing' },
      };
    }
    if (!this.verifySign(cb)) {
      return {
        status: 400,
        body: { status: 'ERROR', message: 'Signature invalid' },
      };
    }

    const payment = await this.prisma.payment.findUnique({
      where: { id: cb.paymentId },
    });
    if (!payment || payment.method !== 'uzum') {
      return {
        status: 404,
        body: { status: 'ERROR', message: 'Order not found' },
      };
    }
    if (typeof cb.amount === 'number' && cb.amount !== payment.amount) {
      return {
        status: 400,
        body: { status: 'ERROR', message: 'Amount mismatch' },
      };
    }

    const status = (cb.status ?? '').toUpperCase();
    const resolution = {
      externalId: cb.transactionId ?? null,
      providerData: { uzum: { ...cb } },
    };

    if (status === 'PAID' || status === 'SUCCESS') {
      await this.paymentsService.markPaymentSuccess(payment.id, resolution);
      return { status: 200, body: { status: 'OK' } };
    }
    if (status === 'CANCELLED' || status === 'REFUNDED') {
      await this.paymentsService.markPaymentCancelled(payment.id, {
        ...resolution,
        notes: 'Uzum cancel',
      });
      return { status: 200, body: { status: 'OK' } };
    }

    await this.paymentsService.markPaymentFailed(payment.id, {
      ...resolution,
      notes: `Uzum status: ${status}`,
    });
    return { status: 200, body: { status: 'OK' } };
  }
}
