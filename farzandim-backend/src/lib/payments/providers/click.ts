// Click provayderi — Merchant SHOP API (prepare / complete callback).
// Hujjat: https://docs.click.uz/
//
// Click bizning webhook'imizga ikki bosqichda murojaat qiladi:
//   action=0 (Prepare)  — to'lovni tayyorlash, buyurtmani tekshirish
//   action=1 (Complete) — to'lovni yakunlash
// So'rov application/x-www-form-urlencoded ko'rinishida keladi.
// Imzo: md5(maydonlar + CLICK_SECRET_KEY).

import { createHash } from 'crypto';
import { env } from '../../../config/env';
import { prisma } from '../../prisma';
import { markPaymentSuccess, markPaymentFailed } from '../service';
import {
  ProviderNotConfiguredError,
  type CheckoutInput,
  type CheckoutResult,
  type PaymentProvider,
  type WebhookRequest,
  type WebhookResponse,
} from '../types';

// Click javob (error) kodlari
const OK = 0;
const ERR_SIGN = -1;
const ERR_AMOUNT = -2;
const ERR_ACTION = -3;
const ERR_ALREADY_PAID = -4;
const ERR_ORDER_NOT_FOUND = -5;
const ERR_TRANSACTION_NOT_FOUND = -6;
const ERR_CANCELLED = -9;

function isConfigured(): boolean {
  return Boolean(
    env.CLICK_SERVICE_ID && env.CLICK_SECRET_KEY && env.CLICK_MERCHANT_ID,
  );
}

/** Body obyekt yoki xom urlencoded string'dan maydonlarni ajratadi. */
function toFields(body: unknown, rawBody: string): Record<string, string> {
  if (body && typeof body === 'object' && !Array.isArray(body)) {
    const obj = body as Record<string, unknown>;
    if (Object.keys(obj).length > 0) {
      const out: Record<string, string> = {};
      for (const [k, v] of Object.entries(obj)) out[k] = v == null ? '' : String(v);
      return out;
    }
  }
  const out: Record<string, string> = {};
  for (const [k, v] of new URLSearchParams(rawBody).entries()) out[k] = v;
  return out;
}

function md5(value: string): string {
  return createHash('md5').update(value).digest('hex');
}

/** Prepare bosqichi imzosi. */
function prepareSign(f: Record<string, string>): string {
  return md5(
    f.click_trans_id +
      f.service_id +
      env.CLICK_SECRET_KEY +
      f.merchant_trans_id +
      f.amount +
      f.action +
      f.sign_time,
  );
}

/** Complete bosqichi imzosi (merchant_prepare_id qo'shiladi). */
function completeSign(f: Record<string, string>): string {
  return md5(
    f.click_trans_id +
      f.service_id +
      env.CLICK_SECRET_KEY +
      f.merchant_trans_id +
      f.merchant_prepare_id +
      f.amount +
      f.action +
      f.sign_time,
  );
}

function clickResponse(
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

async function handlePrepare(f: Record<string, string>): Promise<WebhookResponse> {
  if (prepareSign(f) !== (f.sign_string ?? '').toLowerCase()) {
    return clickResponse(f, ERR_SIGN, 'Imzo tekshiruvi muvaffaqiyatsiz');
  }
  const payment = await prisma.payment.findUnique({
    where: { id: f.merchant_trans_id },
  });
  if (!payment || payment.method !== 'click') {
    return clickResponse(f, ERR_ORDER_NOT_FOUND, 'Buyurtma topilmadi');
  }
  if (Math.round(parseFloat(f.amount)) !== payment.amount) {
    return clickResponse(f, ERR_AMOUNT, "Noto'g'ri summa");
  }
  if (payment.status === 'success') {
    return clickResponse(f, ERR_ALREADY_PAID, "Buyurtma allaqachon to'langan");
  }

  await prisma.payment.update({
    where: { id: payment.id },
    data: {
      status: 'pending',
      externalId: f.click_trans_id,
      providerData: { click: { clickTransId: f.click_trans_id, stage: 'prepared' } },
    },
  });
  return clickResponse(f, OK, 'Success', { merchant_prepare_id: payment.id });
}

async function handleComplete(f: Record<string, string>): Promise<WebhookResponse> {
  if (completeSign(f) !== (f.sign_string ?? '').toLowerCase()) {
    return clickResponse(f, ERR_SIGN, 'Imzo tekshiruvi muvaffaqiyatsiz');
  }
  const payment = await prisma.payment.findUnique({
    where: { id: f.merchant_trans_id },
  });
  if (!payment || payment.method !== 'click') {
    return clickResponse(f, ERR_ORDER_NOT_FOUND, 'Buyurtma topilmadi');
  }
  if (f.merchant_prepare_id !== payment.id) {
    return clickResponse(f, ERR_TRANSACTION_NOT_FOUND, 'Tranzaksiya topilmadi');
  }

  // Click tomonida to'lov bekor qilingan/xato bo'lsa — error < 0.
  const clickError = parseInt(f.error ?? '0', 10);
  if (clickError < 0) {
    await markPaymentFailed(payment.id, {
      externalId: f.click_trans_id,
      providerData: { click: { ...f } },
      notes: `Click error ${clickError}: ${f.error_note ?? ''}`,
    });
    return clickResponse(f, ERR_CANCELLED, 'Tranzaksiya bekor qilindi');
  }
  if (Math.round(parseFloat(f.amount)) !== payment.amount) {
    return clickResponse(f, ERR_AMOUNT, "Noto'g'ri summa");
  }
  if (payment.status === 'success') {
    // Idempotent — qayta complete.
    return clickResponse(f, OK, 'Success', { merchant_confirm_id: payment.id });
  }

  await markPaymentSuccess(payment.id, {
    externalId: f.click_trans_id,
    providerData: { click: { ...f, stage: 'completed' } },
  });
  return clickResponse(f, OK, 'Success', { merchant_confirm_id: payment.id });
}

export const clickProvider: PaymentProvider = {
  key: 'click',

  isConfigured,

  async createCheckout(input: CheckoutInput): Promise<CheckoutResult> {
    if (!isConfigured()) throw new ProviderNotConfiguredError('click');
    const url = new URL(env.CLICK_CHECKOUT_URL);
    url.searchParams.set('service_id', env.CLICK_SERVICE_ID ?? '');
    url.searchParams.set('merchant_id', env.CLICK_MERCHANT_ID ?? '');
    url.searchParams.set('amount', String(input.amount));
    url.searchParams.set('transaction_param', input.paymentId);
    if (input.returnUrl) url.searchParams.set('return_url', input.returnUrl);
    return { provider: 'click', checkoutUrl: url.toString() };
  },

  async handleWebhook(req: WebhookRequest): Promise<WebhookResponse> {
    const f = toFields(req.body, req.rawBody);
    if (f.action === '0') return handlePrepare(f);
    if (f.action === '1') return handleComplete(f);
    return clickResponse(f, ERR_ACTION, 'Action topilmadi');
  },
};
