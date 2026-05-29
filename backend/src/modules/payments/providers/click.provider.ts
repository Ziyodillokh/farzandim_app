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

const OK = 0;
const ERR_SIGN = -1;
const ERR_AMOUNT = -2;
const ERR_ACTION = -3;
const ERR_ALREADY_PAID = -4;
const ERR_ORDER_NOT_FOUND = -5;
const ERR_TRANSACTION_NOT_FOUND = -6;
const ERR_CANCELLED = -9;

@Injectable()
export class ClickProvider implements PaymentProvider {
  readonly key = 'click' as const;

  private serviceId: string;
  private secretKey: string;
  private merchantId: string;
  private checkoutUrl: string;

  constructor(
    private readonly config: ConfigService<EnvConfig, true>,
    private readonly prisma: PrismaService,
    private readonly paymentsService: PaymentsService,
  ) {
    this.serviceId = this.config.get('CLICK_SERVICE_ID', { infer: true }) ?? '';
    this.secretKey = this.config.get('CLICK_SECRET_KEY', { infer: true }) ?? '';
    this.merchantId = this.config.get('CLICK_MERCHANT_ID', { infer: true }) ?? '';
    this.checkoutUrl =
      this.config.get('CLICK_CHECKOUT_URL', { infer: true }) ??
      'https://my.click.uz/services/pay';
  }

  isConfigured(): boolean {
    return Boolean(this.serviceId && this.secretKey && this.merchantId);
  }

  private md5(value: string): string {
    return createHash('md5').update(value).digest('hex');
  }

  private toFields(
    body: unknown,
    rawBody: string,
  ): Record<string, string> {
    if (body && typeof body === 'object' && !Array.isArray(body)) {
      const obj = body as Record<string, unknown>;
      if (Object.keys(obj).length > 0) {
        const out: Record<string, string> = {};
        for (const [k, v] of Object.entries(obj))
          out[k] = v == null ? '' : String(v);
        return out;
      }
    }
    const out: Record<string, string> = {};
    for (const [k, v] of new URLSearchParams(rawBody).entries()) out[k] = v;
    return out;
  }

  private prepareSign(f: Record<string, string>): string {
    return this.md5(
      f.click_trans_id +
        f.service_id +
        this.secretKey +
        f.merchant_trans_id +
        f.amount +
        f.action +
        f.sign_time,
    );
  }

  private completeSign(f: Record<string, string>): string {
    return this.md5(
      f.click_trans_id +
        f.service_id +
        this.secretKey +
        f.merchant_trans_id +
        f.merchant_prepare_id +
        f.amount +
        f.action +
        f.sign_time,
    );
  }

  private clickResponse(
    f: Record<string, string>,
    error: number,
    errorNote: string,
    extra: Record<string, unknown> = {},
  ): WebhookResponse {
    return {
      status: 200,
      body: {
        click_trans_id: f.click_trans_id,
        merchant_trans_id: f.merchant_trans_id,
        ...extra,
        error,
        error_note: errorNote,
      },
    };
  }

  async createCheckout(input: CheckoutInput): Promise<CheckoutResult> {
    if (!this.isConfigured()) throw new ProviderNotConfiguredError('click');
    const url = new URL(this.checkoutUrl);
    url.searchParams.set('service_id', this.serviceId);
    url.searchParams.set('merchant_id', this.merchantId);
    url.searchParams.set('amount', String(input.amount));
    url.searchParams.set('transaction_param', input.paymentId);
    if (input.returnUrl)
      url.searchParams.set('return_url', input.returnUrl);
    return { provider: 'click', checkoutUrl: url.toString() };
  }

  async handleWebhook(req: WebhookRequest): Promise<WebhookResponse> {
    const f = this.toFields(req.body, req.rawBody);
    if (f.action === '0') return this.handlePrepare(f);
    if (f.action === '1') return this.handleComplete(f);
    return this.clickResponse(f, ERR_ACTION, 'Action not found');
  }

  private async handlePrepare(
    f: Record<string, string>,
  ): Promise<WebhookResponse> {
    if (
      this.prepareSign(f) !== (f.sign_string ?? '').toLowerCase()
    ) {
      return this.clickResponse(f, ERR_SIGN, 'Signature verification failed');
    }
    const payment = await this.prisma.payment.findUnique({
      where: { id: f.merchant_trans_id },
    });
    if (!payment || payment.method !== 'click') {
      return this.clickResponse(f, ERR_ORDER_NOT_FOUND, 'Order not found');
    }
    if (Math.round(parseFloat(f.amount)) !== payment.amount) {
      return this.clickResponse(f, ERR_AMOUNT, 'Invalid amount');
    }
    if (payment.status === 'success') {
      return this.clickResponse(f, ERR_ALREADY_PAID, 'Order already paid');
    }

    await this.prisma.payment.update({
      where: { id: payment.id },
      data: {
        status: 'pending',
        externalId: f.click_trans_id,
        providerData: {
          click: { clickTransId: f.click_trans_id, stage: 'prepared' },
        },
      },
    });
    return this.clickResponse(f, OK, 'Success', {
      merchant_prepare_id: payment.id,
    });
  }

  private async handleComplete(
    f: Record<string, string>,
  ): Promise<WebhookResponse> {
    if (
      this.completeSign(f) !== (f.sign_string ?? '').toLowerCase()
    ) {
      return this.clickResponse(f, ERR_SIGN, 'Signature verification failed');
    }
    const payment = await this.prisma.payment.findUnique({
      where: { id: f.merchant_trans_id },
    });
    if (!payment || payment.method !== 'click') {
      return this.clickResponse(f, ERR_ORDER_NOT_FOUND, 'Order not found');
    }
    if (f.merchant_prepare_id !== payment.id) {
      return this.clickResponse(
        f,
        ERR_TRANSACTION_NOT_FOUND,
        'Transaction not found',
      );
    }

    const clickError = parseInt(f.error ?? '0', 10);
    if (clickError < 0) {
      await this.paymentsService.markPaymentFailed(payment.id, {
        externalId: f.click_trans_id,
        providerData: { click: { ...f } },
        notes: `Click error ${clickError}: ${f.error_note ?? ''}`,
      });
      return this.clickResponse(f, ERR_CANCELLED, 'Transaction cancelled');
    }
    if (Math.round(parseFloat(f.amount)) !== payment.amount) {
      return this.clickResponse(f, ERR_AMOUNT, 'Invalid amount');
    }
    if (payment.status === 'success') {
      return this.clickResponse(f, OK, 'Success', {
        merchant_confirm_id: payment.id,
      });
    }

    await this.paymentsService.markPaymentSuccess(payment.id, {
      externalId: f.click_trans_id,
      providerData: { click: { ...f, stage: 'completed' } },
    });
    return this.clickResponse(f, OK, 'Success', {
      merchant_confirm_id: payment.id,
    });
  }
}
