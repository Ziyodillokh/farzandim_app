// Payme provayderi — Merchant API (JSON-RPC 2.0).
// Hujjat: https://developer.help.paycom.uz/
//
// Payme bizning webhook'imizga quyidagi metodlar bilan murojaat qiladi:
//   CheckPerformTransaction, CreateTransaction, PerformTransaction,
//   CancelTransaction, CheckTransaction, GetStatement.
// Auth: HTTP Basic — login "Paycom", parol = PAYME_MERCHANT_KEY.
// Summa Payme tomonda tiyin'da (1 so'm = 100 tiyin).

import { Prisma, type Payment } from '@prisma/client';
import { timingSafeEqual } from 'crypto';
import { env } from '../../../config/env';
import { prisma } from '../../prisma';
import { markPaymentSuccess, markPaymentCancelled } from '../service';
import {
  ProviderNotConfiguredError,
  type CheckoutInput,
  type CheckoutResult,
  type PaymentProvider,
  type WebhookRequest,
  type WebhookResponse,
} from '../types';

const TIYIN = 100;
const PAYME_TIMEOUT_MS = 12 * 60 * 60 * 1000; // 12 soat — Payme tranzaksiya muddati

// Payme transaction state'lari
const STATE_CREATED = 1;
const STATE_PERFORMED = 2;
const STATE_CANCELLED = -1; // state CREATED da bekor qilindi
const STATE_CANCELLED_AFTER = -2; // state PERFORMED dan keyin bekor (refund)

// Payme JSON-RPC xato kodlari
const ERR = {
  INVALID_AMOUNT: -31001,
  TRANSACTION_NOT_FOUND: -31003,
  CANT_PERFORM: -31008,
  ORDER_NOT_FOUND: -31050,
  ORDER_UNAVAILABLE: -31051,
  AUTH_FAILED: -32504,
  METHOD_NOT_FOUND: -32601,
  PARSE_ERROR: -32700,
} as const;

interface PaymeState {
  transactionId: string;
  state: number;
  createTime: number;
  performTime: number;
  cancelTime: number;
  reason: number | null;
}

interface PaymeParams {
  id?: string;
  time?: number;
  amount?: number;
  account?: Record<string, unknown>;
  reason?: number;
  from?: number;
  to?: number;
}

function isConfigured(): boolean {
  return Boolean(env.PAYME_MERCHANT_ID && env.PAYME_MERCHANT_KEY);
}

function readState(providerData: Prisma.JsonValue | null): PaymeState | null {
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
    body: { error: { code, message: localized(message), data }, id: id ?? null },
  };
}

function rpcResult(id: unknown, result: unknown): WebhookResponse {
  return { status: 200, body: { result, id: id ?? null } };
}

/** Doimiy-vaqtli string solishtirish — timing side-channel'ni oldini oladi. */
export function timingSafeEqualStr(a: string, b: string): boolean {
  const ab = Buffer.from(a, 'utf8');
  const bb = Buffer.from(b, 'utf8');
  if (ab.length !== bb.length) return false;
  return timingSafeEqual(ab, bb);
}

/** HTTP Basic auth tekshiruvi — parol PAYME_MERCHANT_KEY ga teng bo'lishi kerak. */
function checkAuth(headers: Record<string, string | undefined>): boolean {
  const header = headers['authorization'] ?? headers['Authorization'];
  if (!header || !header.startsWith('Basic ')) return false;
  if (!env.PAYME_MERCHANT_KEY) return false;
  try {
    const decoded = Buffer.from(header.slice(6), 'base64').toString('utf8');
    const sep = decoded.indexOf(':');
    const password = sep >= 0 ? decoded.slice(sep + 1) : '';
    return password.length > 0 && timingSafeEqualStr(password, env.PAYME_MERCHANT_KEY);
  } catch {
    return false;
  }
}

/** account.payment_id orqali Payment topish. */
async function findOrderPayment(
  account: Record<string, unknown> | undefined,
): Promise<Payment | null> {
  const paymentId = account?.['payment_id'];
  if (typeof paymentId !== 'string') return null;
  return prisma.payment.findUnique({ where: { id: paymentId } });
}

/** Payme tranzaksiya ID'si orqali Payment topish. */
async function findByTransaction(txnId: string | undefined): Promise<Payment | null> {
  if (typeof txnId !== 'string') return null;
  return prisma.payment.findFirst({ where: { externalId: txnId, method: 'payme' } });
}

async function checkPerformTransaction(
  id: unknown,
  params: PaymeParams,
): Promise<WebhookResponse> {
  const payment = await findOrderPayment(params.account);
  if (!payment || payment.method !== 'payme') {
    return rpcError(id, ERR.ORDER_NOT_FOUND, 'Buyurtma topilmadi', 'payment_id');
  }
  if (payment.status === 'success') {
    return rpcError(id, ERR.ORDER_UNAVAILABLE, "Buyurtma allaqachon to'langan", 'payment_id');
  }
  if (params.amount !== payment.amount * TIYIN) {
    return rpcError(id, ERR.INVALID_AMOUNT, "Noto'g'ri summa");
  }
  return rpcResult(id, { allow: true });
}

async function createTransaction(
  id: unknown,
  params: PaymeParams,
): Promise<WebhookResponse> {
  const payment = await findOrderPayment(params.account);
  if (!payment || payment.method !== 'payme') {
    return rpcError(id, ERR.ORDER_NOT_FOUND, 'Buyurtma topilmadi', 'payment_id');
  }
  if (params.amount !== payment.amount * TIYIN) {
    return rpcError(id, ERR.INVALID_AMOUNT, "Noto'g'ri summa");
  }

  const existing = readState(payment.providerData);
  if (existing) {
    // Idempotent — bir xil tranzaksiya qayta yuborildi.
    if (existing.transactionId === params.id) {
      return rpcResult(id, {
        create_time: existing.createTime,
        transaction: payment.id,
        state: existing.state,
      });
    }
    return rpcError(
      id,
      ERR.ORDER_UNAVAILABLE,
      'Buyurtma uchun boshqa tranzaksiya ochiq',
      'payment_id',
    );
  }
  if (payment.status === 'success') {
    return rpcError(id, ERR.ORDER_UNAVAILABLE, "Buyurtma allaqachon to'langan", 'payment_id');
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
  await prisma.payment.update({
    where: { id: payment.id },
    data: { status: 'pending', externalId: params.id, providerData: stateJson(state) },
  });
  return rpcResult(id, {
    create_time: now,
    transaction: payment.id,
    state: STATE_CREATED,
  });
}

async function performTransaction(
  id: unknown,
  params: PaymeParams,
): Promise<WebhookResponse> {
  const payment = await findByTransaction(params.id);
  const state = payment ? readState(payment.providerData) : null;
  if (!payment || !state) {
    return rpcError(id, ERR.TRANSACTION_NOT_FOUND, 'Tranzaksiya topilmadi');
  }

  if (state.state === STATE_PERFORMED) {
    return rpcResult(id, {
      transaction: payment.id,
      perform_time: state.performTime,
      state: STATE_PERFORMED,
    });
  }
  if (state.state !== STATE_CREATED) {
    return rpcError(id, ERR.CANT_PERFORM, "Tranzaksiyani bajarib bo'lmaydi");
  }
  // Muddati o'tgan tranzaksiya — bekor qilamiz (Payme reason=4).
  if (Date.now() - state.createTime > PAYME_TIMEOUT_MS) {
    const timedOut: PaymeState = {
      ...state,
      state: STATE_CANCELLED,
      cancelTime: Date.now(),
      reason: 4,
    };
    await prisma.payment.update({
      where: { id: payment.id },
      data: { status: 'failed', providerData: stateJson(timedOut) },
    });
    return rpcError(id, ERR.CANT_PERFORM, 'Tranzaksiya muddati tugadi');
  }

  const now = Date.now();
  const performed: PaymeState = { ...state, state: STATE_PERFORMED, performTime: now };
  await markPaymentSuccess(payment.id, {
    externalId: state.transactionId,
    providerData: { payme: performed },
  });
  return rpcResult(id, {
    transaction: payment.id,
    perform_time: now,
    state: STATE_PERFORMED,
  });
}

async function cancelTransaction(
  id: unknown,
  params: PaymeParams,
): Promise<WebhookResponse> {
  const payment = await findByTransaction(params.id);
  const state = payment ? readState(payment.providerData) : null;
  if (!payment || !state) {
    return rpcError(id, ERR.TRANSACTION_NOT_FOUND, 'Tranzaksiya topilmadi');
  }

  if (state.state === STATE_CANCELLED || state.state === STATE_CANCELLED_AFTER) {
    return rpcResult(id, {
      transaction: payment.id,
      cancel_time: state.cancelTime,
      state: state.state,
    });
  }

  const now = Date.now();
  const reason = typeof params.reason === 'number' ? params.reason : null;

  if (state.state === STATE_PERFORMED) {
    // Perform'dan keyin bekor — refund. Obuna ham bekor qilinadi.
    const cancelled: PaymeState = {
      ...state,
      state: STATE_CANCELLED_AFTER,
      cancelTime: now,
      reason,
    };
    await markPaymentCancelled(payment.id, {
      providerData: { payme: cancelled },
      notes: `Payme cancel (reason=${reason})`,
    });
    return rpcResult(id, {
      transaction: payment.id,
      cancel_time: now,
      state: STATE_CANCELLED_AFTER,
    });
  }

  // state CREATED — hali perform bo'lmagan.
  const cancelled: PaymeState = {
    ...state,
    state: STATE_CANCELLED,
    cancelTime: now,
    reason,
  };
  await prisma.payment.update({
    where: { id: payment.id },
    data: { status: 'cancelled', providerData: stateJson(cancelled) },
  });
  return rpcResult(id, {
    transaction: payment.id,
    cancel_time: now,
    state: STATE_CANCELLED,
  });
}

async function checkTransaction(
  id: unknown,
  params: PaymeParams,
): Promise<WebhookResponse> {
  const payment = await findByTransaction(params.id);
  const state = payment ? readState(payment.providerData) : null;
  if (!payment || !state) {
    return rpcError(id, ERR.TRANSACTION_NOT_FOUND, 'Tranzaksiya topilmadi');
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

async function getStatement(
  id: unknown,
  params: PaymeParams,
): Promise<WebhookResponse> {
  const from = typeof params.from === 'number' ? params.from : 0;
  const to = typeof params.to === 'number' ? params.to : Date.now();
  const rows = await prisma.payment.findMany({
    where: {
      method: 'payme',
      externalId: { not: null },
      createdAt: { gte: new Date(from), lte: new Date(to) },
    },
  });
  const transactions = rows.flatMap((p) => {
    const state = readState(p.providerData);
    if (!state) return [];
    return [
      {
        id: state.transactionId,
        time: state.createTime,
        amount: p.amount * TIYIN,
        account: { payment_id: p.id },
        create_time: state.createTime,
        perform_time: state.performTime,
        cancel_time: state.cancelTime,
        transaction: p.id,
        state: state.state,
        reason: state.reason,
      },
    ];
  });
  return rpcResult(id, { transactions });
}

export const paymeProvider: PaymentProvider = {
  key: 'payme',

  isConfigured,

  async createCheckout(input: CheckoutInput): Promise<CheckoutResult> {
    if (!isConfigured()) throw new ProviderNotConfiguredError('payme');
    // checkout.paycom.uz/<base64(m=...;ac.payment_id=...;a=tiyin)>
    const parts = [
      `m=${env.PAYME_MERCHANT_ID}`,
      `ac.payment_id=${input.paymentId}`,
      `a=${input.amount * TIYIN}`,
    ];
    if (input.returnUrl) parts.push(`c=${input.returnUrl}`);
    const encoded = Buffer.from(parts.join(';'), 'utf8').toString('base64');
    return {
      provider: 'payme',
      checkoutUrl: `${env.PAYME_CHECKOUT_URL}/${encoded}`,
    };
  },

  async handleWebhook(req: WebhookRequest): Promise<WebhookResponse> {
    const body = req.body as { method?: unknown; params?: unknown; id?: unknown };
    const id = body?.id;

    if (!checkAuth(req.headers)) {
      return rpcError(id, ERR.AUTH_FAILED, 'Avtorizatsiya xatosi');
    }
    if (!body || typeof body.method !== 'string') {
      return rpcError(id, ERR.PARSE_ERROR, "Noto'g'ri so'rov");
    }
    const params = (body.params ?? {}) as PaymeParams;

    switch (body.method) {
      case 'CheckPerformTransaction':
        return checkPerformTransaction(id, params);
      case 'CreateTransaction':
        return createTransaction(id, params);
      case 'PerformTransaction':
        return performTransaction(id, params);
      case 'CancelTransaction':
        return cancelTransaction(id, params);
      case 'CheckTransaction':
        return checkTransaction(id, params);
      case 'GetStatement':
        return getStatement(id, params);
      default:
        return rpcError(id, ERR.METHOD_NOT_FOUND, 'Metod topilmadi');
    }
  },
};
