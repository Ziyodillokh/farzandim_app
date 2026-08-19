import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import { timingSafeEqual } from 'crypto';
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

const TIYIN = 100;
const PAYME_TIMEOUT_MS = 12 * 60 * 60 * 1000; // 12 hours

const STATE_CREATED = 1;
const STATE_PERFORMED = 2;
const STATE_CANCELLED = -1;
const STATE_CANCELLED_AFTER = -2;

const ERR = {
  INVALID_AMOUNT: -31001,
  TRANSACTION_NOT_FOUND: -31003,
  CANT_PERFORM: -31008,
  ORDER_NOT_FOUND: -31050,
  ORDER_UNAVAILABLE: -31051,
  AUTH_FAILED: -32504,
  METHOD_NOT_FOUND: -32601,
  INVALID_REQUEST: -32600,
  PARSE_ERROR: -32700,
  /** SetFiscalData: chek (Payme tranzaksiyasi) topilmadi. */
  FISCAL_RECEIPT_NOT_FOUND: -32001,
  /** SetFiscalData: parametrlar noto'g'ri. */
  INVALID_PARAMS: -32602,
} as const;

interface PaymeState {
  transactionId: string;
  state: number;
  createTime: number;
  performTime: number;
  cancelTime: number;
  reason: number | null;
  /**
   * Payme `SetFiscalData` orqali kelgan soliq cheki ma'lumotlari (ixtiyoriy
   * metod; kassada fiskalizatsiya yoqilgan bo'lsa to'lov/bekordan keyin
   * keladi). PERFORM va CANCEL alohida cheklar — alohida saqlanadi.
   */
  fiscal?: {
    perform_data?: Record<string, unknown>;
    cancel_data?: Record<string, unknown>;
  };
}

interface PaymeParams {
  id?: string;
  time?: number;
  amount?: number;
  account?: Record<string, unknown>;
  reason?: number;
  from?: number;
  to?: number;
  /** SetFiscalData: 'PERFORM' | 'CANCEL'. */
  type?: string;
  /** SetFiscalData: ОФД chek ma'lumotlari. */
  fiscal_data?: Record<string, unknown>;
}

function readState(
  providerData: Prisma.JsonValue | null,
): PaymeState | null {
  if (
    providerData &&
    typeof providerData === 'object' &&
    !Array.isArray(providerData) &&
    'payme' in providerData
  ) {
    return (providerData as unknown as { payme: PaymeState }).payme;
  }
  return null;
}

function stateJson(state: PaymeState): Prisma.InputJsonValue {
  return { payme: { ...state } } as Prisma.InputJsonValue;
}

function localized(text: string) {
  return { ru: text, uz: text, en: text };
}

function rpcError(
  id: unknown,
  code: number,
  message: string,
  data?: string,
): WebhookResponse {
  return {
    status: 200,
    body: {
      error: { code, message: localized(message), data },
      id: id ?? null,
    },
  };
}

function rpcResult(id: unknown, result: unknown): WebhookResponse {
  return { status: 200, body: { result, id: id ?? null } };
}

function timingSafeEqualStr(a: string, b: string): boolean {
  const ab = Buffer.from(a, 'utf8');
  const bb = Buffer.from(b, 'utf8');
  if (ab.length !== bb.length) return false;
  return timingSafeEqual(ab, bb);
}

@Injectable()
export class PaymeProvider implements PaymentProvider {
  readonly key = 'payme' as const;

  private merchantId: string;
  private merchantKey: string;
  private checkoutUrl: string;
  /**
   * Payme kassasida sozlangan "account" maydoni nomi (checkout'da `ac.<nom>`,
   * webhook'da `params.account.<nom>`). Kassa Payme hodimi tomonidan
   * yaratiladi va maydon nomi `payment_id` bo'lmasligi mumkin (`order_id`
   * kabi) — shuning uchun env orqali sozlanadi, kod o'zgarmaydi.
   */
  private accountField: string;
  private fiscalMxik: string;
  private fiscalPackageCode: string;
  private fiscalVatPercent: number;

  constructor(
    private readonly config: ConfigService<EnvConfig, true>,
    private readonly prisma: PrismaService,
    private readonly paymentsService: PaymentsService,
  ) {
    this.merchantId = this.config.get('PAYME_MERCHANT_ID', { infer: true }) ?? '';
    this.merchantKey = this.config.get('PAYME_MERCHANT_KEY', { infer: true }) ?? '';
    this.checkoutUrl = this.config.get('PAYME_CHECKOUT_URL', { infer: true }) ?? 'https://checkout.paycom.uz';
    this.accountField =
      this.config.get('PAYME_ACCOUNT_FIELD', { infer: true }) ?? 'payment_id';
    this.fiscalMxik = this.config.get('PAYME_FISCAL_MXIK', { infer: true }) ?? '';
    this.fiscalPackageCode =
      this.config.get('PAYME_FISCAL_PACKAGE_CODE', { infer: true }) ?? '';
    this.fiscalVatPercent =
      this.config.get('PAYME_FISCAL_VAT_PERCENT', { infer: true }) ?? 0;
  }

  /**
   * Soliq cheki uchun `detail` obyekti (Payme fiskalizatsiya talabi).
   *
   * MXIK/package_code sozlanmagan bo'lsa `undefined` qaytaradi — ya'ni
   * `detail` javobga UMUMAN qo'shilmaydi. Bu ataylab: noto'g'ri/bo'sh kod
   * bilan chek yuborilgandan ko'ra, chek yuborilmagani yaxshiroq (soliq
   * tomonda xato yozuv paydo bo'lmasin).
   *
   * `price` — TIYINDA (Payme shunday kutadi), `count` — 1 (bitta obuna).
   */
  private fiscalDetail(title: string, amountTiyin: number) {
    if (!this.fiscalMxik || !this.fiscalPackageCode) return undefined;
    return {
      receipt_type: 0,
      items: [
        {
          title,
          price: amountTiyin,
          count: 1,
          code: this.fiscalMxik,
          package_code: this.fiscalPackageCode,
          vat_percent: this.fiscalVatPercent,
        },
      ],
    };
  }

  isConfigured(): boolean {
    return Boolean(this.merchantId && this.merchantKey);
  }

  private checkAuth(
    headers: Record<string, string | undefined>,
  ): boolean {
    const header = headers['authorization'] ?? headers['Authorization'];
    if (!header || !header.startsWith('Basic ')) return false;
    if (!this.merchantKey) return false;
    try {
      const decoded = Buffer.from(header.slice(6), 'base64').toString('utf8');
      const sep = decoded.indexOf(':');
      const password = sep >= 0 ? decoded.slice(sep + 1) : '';
      return (
        password.length > 0 && timingSafeEqualStr(password, this.merchantKey)
      );
    } catch {
      return false;
    }
  }

  private async findOrderPayment(account?: Record<string, unknown>) {
    const paymentId = account?.[this.accountField];
    if (typeof paymentId !== 'string') return null;
    return this.prisma.payment.findUnique({ where: { id: paymentId } });
  }

  private async findByTransaction(txnId?: string) {
    if (typeof txnId !== 'string') return null;
    return this.prisma.payment.findFirst({
      where: { externalId: txnId, method: 'payme' },
    });
  }

  async createCheckout(input: CheckoutInput): Promise<CheckoutResult> {
    if (!this.isConfigured()) throw new ProviderNotConfiguredError('payme');
    const parts = [
      `m=${this.merchantId}`,
      `ac.${this.accountField}=${input.paymentId}`,
      `a=${input.amount * TIYIN}`,
    ];
    if (input.returnUrl) parts.push(`c=${input.returnUrl}`);
    const encoded = Buffer.from(parts.join(';'), 'utf8').toString('base64');
    return {
      provider: 'payme',
      checkoutUrl: `${this.checkoutUrl}/${encoded}`,
    };
  }

  async handleWebhook(req: WebhookRequest): Promise<WebhookResponse> {
    const body = req.body as {
      method?: unknown;
      params?: unknown;
      id?: unknown;
    };
    const id = body?.id;

    if (!this.checkAuth(req.headers)) {
      return rpcError(id, ERR.AUTH_FAILED, 'Authorization failed');
    }
    // -32600: RPC so'rovda majburiy maydon (`method`) yo'q (Payme "Общие
    // ошибки"); -32700 faqat JSON o'zi buzilgan holat uchun (uni Fastify
    // bizgacha 400 bilan qaytaradi).
    if (!body || typeof body !== 'object') {
      return rpcError(id, ERR.PARSE_ERROR, 'Parse error');
    }
    if (typeof body.method !== 'string') {
      return rpcError(id, ERR.INVALID_REQUEST, 'Invalid request');
    }
    const params = (body.params ?? {}) as PaymeParams;

    switch (body.method) {
      case 'CheckPerformTransaction':
        return this.checkPerformTransaction(id, params);
      case 'CreateTransaction':
        return this.createTransaction(id, params);
      case 'PerformTransaction':
        return this.performTransaction(id, params);
      case 'CancelTransaction':
        return this.cancelTransaction(id, params);
      case 'CheckTransaction':
        return this.checkTransaction(id, params);
      case 'GetStatement':
        return this.getStatement(id, params);
      case 'SetFiscalData':
        return this.setFiscalData(id, params);
      default:
        return rpcError(id, ERR.METHOD_NOT_FOUND, 'Method not found');
    }
  }

  private async checkPerformTransaction(
    id: unknown,
    params: PaymeParams,
  ): Promise<WebhookResponse> {
    const payment = await this.findOrderPayment(params.account);
    if (!payment || payment.method !== 'payme') {
      return rpcError(id, ERR.ORDER_NOT_FOUND, 'Order not found', this.accountField);
    }
    if (payment.status === 'success') {
      return rpcError(id, ERR.ORDER_UNAVAILABLE, 'Order already paid', this.accountField);
    }
    // Bekor qilingan / yiqilgan buyurtma (Payme tranzaksiyasi -1/-2 yoki
    // checkout yaratilmagan) qayta to'lanmaydi — ilova har urinishda YANGI
    // payment_id yaratadi. Faqat `pending` buyurtma to'lanishi mumkin.
    if (payment.status !== 'pending') {
      return rpcError(id, ERR.ORDER_UNAVAILABLE, 'Order unavailable', this.accountField);
    }
    // Buyurtmada allaqachon FAOL (state=1) tranzaksiya bor — Payme sandbox
    // «В процессе» holati: "другая транзакция заняла этот счет" →
    // -31050..-31099 kutiladi (allow:true EMAS). Bir martalik buyurtma
    // faqat bitta tranzaksiya bilan to'lanadi.
    const active = readState(payment.providerData);
    if (active && active.state === STATE_CREATED) {
      return rpcError(
        id,
        ERR.ORDER_UNAVAILABLE,
        'Another transaction open for this order',
        this.accountField,
      );
    }
    if (params.amount !== payment.amount * TIYIN) {
      return rpcError(id, ERR.INVALID_AMOUNT, 'Invalid amount');
    }
    // Fiskalizatsiya: chek soliq oborotida ko'rinishi uchun `detail` kerak
    // (Payme talabi). MXIK sozlanmagan bo'lsa qo'shilmaydi.
    const detail = this.fiscalDetail(
      payment.planName ?? 'Parvoz obuna',
      payment.amount * TIYIN,
    );
    return rpcResult(id, detail ? { allow: true, detail } : { allow: true });
  }

  private async createTransaction(
    id: unknown,
    params: PaymeParams,
  ): Promise<WebhookResponse> {
    const payment = await this.findOrderPayment(params.account);
    if (!payment || payment.method !== 'payme') {
      return rpcError(id, ERR.ORDER_NOT_FOUND, 'Order not found', this.accountField);
    }
    if (params.amount !== payment.amount * TIYIN) {
      return rpcError(id, ERR.INVALID_AMOUNT, 'Invalid amount');
    }

    const existing = readState(payment.providerData);
    if (existing) {
      if (existing.transactionId === params.id) {
        // Takroriy CreateTransaction (Payme retry) — idempotent javob.
        // Lekin faqat hali FAOL (state=1) tranzaksiya qaytariladi:
        //   • allaqachon bajarilgan/bekor qilingan → -31008;
        //   • 12 soatdan oshgan → timeout bilan bekor (state=-1, reason=4)
        //     va -31008 (Payme spetsifikatsiyasi + sandbox testi).
        if (existing.state !== STATE_CREATED) {
          return rpcError(id, ERR.CANT_PERFORM, 'Transaction is not active');
        }
        if (Date.now() - existing.createTime > PAYME_TIMEOUT_MS) {
          const timedOut: PaymeState = {
            ...existing,
            state: STATE_CANCELLED,
            cancelTime: Date.now(),
            reason: 4,
          };
          await this.prisma.payment.update({
            where: { id: payment.id },
            data: { status: 'failed', providerData: stateJson(timedOut) },
          });
          return rpcError(id, ERR.CANT_PERFORM, 'Transaction timed out');
        }
        return rpcResult(id, {
          create_time: existing.createTime,
          transaction: payment.id,
          state: existing.state,
        });
      }
      return rpcError(
        id,
        ERR.ORDER_UNAVAILABLE,
        'Another transaction open for this order',
        this.accountField,
      );
    }
    if (payment.status === 'success') {
      return rpcError(id, ERR.ORDER_UNAVAILABLE, 'Order already paid', this.accountField);
    }
    if (payment.status !== 'pending') {
      return rpcError(id, ERR.ORDER_UNAVAILABLE, 'Order unavailable', this.accountField);
    }

    const now = Date.now();
    const state: PaymeState = {
      transactionId: params.id ?? '',
      state: STATE_CREATED,
      createTime: now,
      performTime: 0,
      cancelTime: 0,
      reason: null,
    };
    await this.prisma.payment.update({
      where: { id: payment.id },
      data: {
        status: 'pending',
        externalId: params.id,
        providerData: stateJson(state),
      },
    });
    return rpcResult(id, {
      create_time: now,
      transaction: payment.id,
      state: STATE_CREATED,
    });
  }

  private async performTransaction(
    id: unknown,
    params: PaymeParams,
  ): Promise<WebhookResponse> {
    const payment = await this.findByTransaction(params.id);
    const state = payment ? readState(payment.providerData) : null;
    if (!payment || !state) {
      return rpcError(id, ERR.TRANSACTION_NOT_FOUND, 'Transaction not found');
    }

    if (state.state === STATE_PERFORMED) {
      return rpcResult(id, {
        transaction: payment.id,
        perform_time: state.performTime,
        state: STATE_PERFORMED,
      });
    }
    if (state.state !== STATE_CREATED) {
      return rpcError(id, ERR.CANT_PERFORM, 'Cannot perform transaction');
    }
    if (Date.now() - state.createTime > PAYME_TIMEOUT_MS) {
      const timedOut: PaymeState = {
        ...state,
        state: STATE_CANCELLED,
        cancelTime: Date.now(),
        reason: 4,
      };
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: { status: 'failed', providerData: stateJson(timedOut) },
      });
      return rpcError(id, ERR.CANT_PERFORM, 'Transaction timed out');
    }

    const now = Date.now();
    const performed: PaymeState = {
      ...state,
      state: STATE_PERFORMED,
      performTime: now,
    };
    await this.paymentsService.markPaymentSuccess(payment.id, {
      externalId: state.transactionId,
      providerData: { payme: performed },
    });
    return rpcResult(id, {
      transaction: payment.id,
      perform_time: now,
      state: STATE_PERFORMED,
    });
  }

  private async cancelTransaction(
    id: unknown,
    params: PaymeParams,
  ): Promise<WebhookResponse> {
    const payment = await this.findByTransaction(params.id);
    const state = payment ? readState(payment.providerData) : null;
    if (!payment || !state) {
      return rpcError(id, ERR.TRANSACTION_NOT_FOUND, 'Transaction not found');
    }

    if (
      state.state === STATE_CANCELLED ||
      state.state === STATE_CANCELLED_AFTER
    ) {
      return rpcResult(id, {
        transaction: payment.id,
        cancel_time: state.cancelTime,
        state: state.state,
      });
    }

    const now = Date.now();
    const reason =
      typeof params.reason === 'number' ? params.reason : null;

    if (state.state === STATE_PERFORMED) {
      const cancelled: PaymeState = {
        ...state,
        state: STATE_CANCELLED_AFTER,
        cancelTime: now,
        reason,
      };
      await this.paymentsService.markPaymentCancelled(payment.id, {
        providerData: { payme: cancelled },
        notes: `Payme cancel (reason=${reason})`,
      });
      return rpcResult(id, {
        transaction: payment.id,
        cancel_time: now,
        state: STATE_CANCELLED_AFTER,
      });
    }

    const cancelled: PaymeState = {
      ...state,
      state: STATE_CANCELLED,
      cancelTime: now,
      reason,
    };
    await this.prisma.payment.update({
      where: { id: payment.id },
      data: { status: 'cancelled', providerData: stateJson(cancelled) },
    });
    return rpcResult(id, {
      transaction: payment.id,
      cancel_time: now,
      state: STATE_CANCELLED,
    });
  }

  private async checkTransaction(
    id: unknown,
    params: PaymeParams,
  ): Promise<WebhookResponse> {
    const payment = await this.findByTransaction(params.id);
    const state = payment ? readState(payment.providerData) : null;
    if (!payment || !state) {
      return rpcError(id, ERR.TRANSACTION_NOT_FOUND, 'Transaction not found');
    }
    return rpcResult(id, {
      create_time: state.createTime,
      perform_time: state.performTime,
      cancel_time: state.cancelTime,
      transaction: payment.id,
      state: state.state,
      reason: state.reason,
    });
  }

  /**
   * SetFiscalData — Payme ОФД'da chek ro'yxatdan o'tgach fiskal ma'lumotni
   * yuboradi (`type`: PERFORM | CANCEL). Ixtiyoriy metod, lekin kassada
   * fiskalizatsiya yoqilgan bo'lsa har to'lovdan keyin keladi — -32601
   * qaytarish Payme tomonida xato sifatida ko'rinadi. Ma'lumot
   * `providerData.payme.fiscal.{perform_data|cancel_data}` ga saqlanadi
   * (PERFORM va CANCEL — ikki alohida fiskal chek, hujjat talabi).
   */
  private async setFiscalData(
    id: unknown,
    params: PaymeParams,
  ): Promise<WebhookResponse> {
    const type = params.type;
    if (
      (type !== 'PERFORM' && type !== 'CANCEL') ||
      !params.fiscal_data ||
      typeof params.fiscal_data !== 'object'
    ) {
      return rpcError(id, ERR.INVALID_PARAMS, 'Invalid params: type/fiscal_data');
    }
    const payment = await this.findByTransaction(params.id);
    const state = payment ? readState(payment.providerData) : null;
    if (!payment || !state) {
      return rpcError(id, ERR.FISCAL_RECEIPT_NOT_FOUND, 'Receipt not found');
    }
    const updated: PaymeState = {
      ...state,
      fiscal: {
        ...(state.fiscal ?? {}),
        ...(type === 'PERFORM'
          ? { perform_data: params.fiscal_data }
          : { cancel_data: params.fiscal_data }),
      },
    };
    await this.prisma.payment.update({
      where: { id: payment.id },
      data: { providerData: stateJson(updated) },
    });
    return rpcResult(id, { success: true });
  }

  private async getStatement(
    id: unknown,
    params: PaymeParams,
  ): Promise<WebhookResponse> {
    const from = typeof params.from === 'number' ? params.from : 0;
    const to = typeof params.to === 'number' ? params.to : Date.now();

    // Payme `from..to` oralig'ini TRANZAKSIYA yaratilgan vaqt (create_time)
    // bo'yicha kutadi. Payment.createdAt esa checkout ochilgan vaqt — u har
    // doim create_time'dan OLDIN, shuning uchun DB'da faqat yuqori chegara
    // (createdAt <= to) bilan toraytirib, aniq filtrni state.createTime
    // bo'yicha qilamiz (aks holda from≈create_time bo'lsa yozuv tushib
    // qolardi).
    const rows = await this.prisma.payment.findMany({
      where: {
        method: 'payme',
        externalId: { not: null },
        createdAt: { lte: new Date(to) },
      },
    });
    const transactions = rows.flatMap((p) => {
      const state = readState(p.providerData);
      if (!state) return [];
      if (state.createTime < from || state.createTime > to) return [];
      return [
        {
          id: state.transactionId,
          time: state.createTime,
          amount: p.amount * TIYIN,
          account: { [this.accountField]: p.id },
          create_time: state.createTime,
          perform_time: state.performTime,
          cancel_time: state.cancelTime,
          transaction: p.id,
          state: state.state,
          reason: state.reason,
        },
      ];
    });
    transactions.sort((a, b) => a.time - b.time);
    return rpcResult(id, { transactions });
  }
}
