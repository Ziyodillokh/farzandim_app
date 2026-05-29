// Uzum Bank provayderi — Checkout API + callback.
//
// ⚠️ ESLATMA: Uzum Bank merchant protokolining aniq endpoint'lari, maydon
// nomlari va imzo algoritmi merchant cabinet hujjati bilan TASDIQLANISHI kerak.
// Quyidagi implementatsiya boshqa provayderlar (Payme/Click) bilan bir xil
// tuzilmaga ega — kalitlar kelganda faqat field-mapping va imzo formulasini
// moslab qo'yish kifoya. Mantiq (Payment topish, success/failed/cancel) tayyor.
//
// Kutilayotgan callback (JSON):
//   { serviceId, paymentId, transactionId, amount, status, signTime, signString }
//   status ∈ PAID | FAILED | CANCELLED
//   signString = sha256(paymentId + amount + status + signTime + UZUM_SECRET_KEY)

import { createHash } from 'crypto';
import { env } from '../../../config/env';
import { prisma } from '../../prisma';
import {
  markPaymentSuccess,
  markPaymentFailed,
  markPaymentCancelled,
} from '../service';
import {
  ProviderNotConfiguredError,
  type CheckoutInput,
  type CheckoutResult,
  type PaymentProvider,
  type WebhookRequest,
  type WebhookResponse,
} from '../types';

interface UzumCallback {
  serviceId?: string;
  paymentId?: string;
  transactionId?: string;
  amount?: number;
  status?: string;
  signTime?: string;
  signString?: string;
}

// H4 — Uzum webhook imzo sxemasi (verifySign) merchant cabinet hujjati bilan
// hali TASDIQLANMAGAN (taxminiy formula). Tasdiqlanmaguncha provayder o'chiq:
// env kalitlar bo'lsa ham checkout va webhook faollashmaydi. Sxema rasman
// tasdiqlangач — UZUM_VERIFIED ni true ga o'zgartiring.
const UZUM_VERIFIED: boolean = false;

function isConfigured(): boolean {
  return (
    UZUM_VERIFIED &&
    Boolean(env.UZUM_MERCHANT_SERVICE_ID && env.UZUM_SECRET_KEY && env.UZUM_API_BASE)
  );
}

function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

/** Callback imzosini tekshiradi. */
function verifySign(cb: UzumCallback): boolean {
  const expected = sha256(
    `${cb.paymentId}${cb.amount}${cb.status}${cb.signTime}${env.UZUM_SECRET_KEY}`,
  );
  return expected === (cb.signString ?? '').toLowerCase();
}

function ok(body: unknown): WebhookResponse {
  return { status: 200, body };
}

export const uzumProvider: PaymentProvider = {
  key: 'uzum',

  isConfigured,

  async createCheckout(input: CheckoutInput): Promise<CheckoutResult> {
    if (!isConfigured()) throw new ProviderNotConfiguredError('uzum');
    // Uzum hosted checkout sahifasiga yo'naltirish. Aniq path/parametrlar
    // merchant hujjati bilan tasdiqlanishi kerak.
    const url = new URL('/checkout', env.UZUM_API_BASE);
    url.searchParams.set('service_id', env.UZUM_MERCHANT_SERVICE_ID ?? '');
    url.searchParams.set('amount', String(input.amount));
    url.searchParams.set('order_id', input.paymentId);
    if (input.returnUrl) url.searchParams.set('return_url', input.returnUrl);
    return { provider: 'uzum', checkoutUrl: url.toString() };
  },

  async handleWebhook(req: WebhookRequest): Promise<WebhookResponse> {
    const cb = (req.body ?? {}) as UzumCallback;

    if (typeof cb.paymentId !== 'string') {
      return { status: 400, body: { status: 'ERROR', message: 'paymentId yo\'q' } };
    }
    if (!verifySign(cb)) {
      return { status: 400, body: { status: 'ERROR', message: 'Imzo xato' } };
    }

    const payment = await prisma.payment.findUnique({ where: { id: cb.paymentId } });
    if (!payment || payment.method !== 'uzum') {
      return { status: 404, body: { status: 'ERROR', message: 'Buyurtma topilmadi' } };
    }
    if (typeof cb.amount === 'number' && cb.amount !== payment.amount) {
      return { status: 400, body: { status: 'ERROR', message: 'Noto\'g\'ri summa' } };
    }

    const status = (cb.status ?? '').toUpperCase();
    const resolution = {
      externalId: cb.transactionId ?? null,
      providerData: { uzum: { ...cb } },
    };

    if (status === 'PAID' || status === 'SUCCESS') {
      await markPaymentSuccess(payment.id, resolution);
      return ok({ status: 'OK' });
    }
    if (status === 'CANCELLED' || status === 'REFUNDED') {
      await markPaymentCancelled(payment.id, {
        ...resolution,
        notes: 'Uzum cancel',
      });
      return ok({ status: 'OK' });
    }
    // FAILED yoki noma'lum holat
    await markPaymentFailed(payment.id, {
      ...resolution,
      notes: `Uzum status: ${status}`,
    });
    return ok({ status: 'OK' });
  },
};
