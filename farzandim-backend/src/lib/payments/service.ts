// To'lov lifecycle + obuna aktivlashtirish — provayder-agnostik biznes mantiq.
//
// Har bir provayder (Payme/Click/Uzum) webhook'ida muvaffaqiyat/xato/bekor
// holatida shu funksiyalarni chaqiradi. Provayderga xos protokol bu yerda yo'q.

import { Prisma, type Payment } from '@prisma/client';
import { prisma } from '../prisma';

const DAY_MS = 24 * 60 * 60 * 1000;

/** Plan.period → obuna muddati (kun). 'free' → 0 (obuna kerak emas). */
function periodDurationDays(period: string): number {
  switch (period) {
    case 'yearly':
      return 365;
    case 'monthly':
      return 30;
    default:
      return 0;
  }
}

/**
 * To'lov tegishli obunani aktivlashtiradi yoki muddatini uzaytiradi.
 * Aktiv obuna bor bo'lsa — yangi muddat uning tugash sanasi ustiga qo'shiladi.
 *
 * @returns Subscription.id yoki null (free plan / anonim to'lov).
 */
async function activateSubscriptionTx(
  tx: Prisma.TransactionClient,
  payment: Payment,
): Promise<string | null> {
  if (!payment.userId || !payment.planId) return null;

  const plan = await tx.plan.findUnique({ where: { id: payment.planId } });
  if (!plan) return null;

  const days = periodDurationDays(plan.period);
  if (days <= 0) return null; // free plan — obuna kerak emas

  const now = new Date();
  const existing = await tx.subscription.findFirst({
    where: { userId: payment.userId, status: 'ACTIVE' },
    orderBy: { expiresAt: 'desc' },
  });

  // Aktiv obuna muddati hali tugamagan bo'lsa — yangi muddat ustiga qo'shiladi.
  const base =
    existing?.expiresAt && existing.expiresAt > now ? existing.expiresAt : now;
  const expiresAt = new Date(base.getTime() + days * DAY_MS);

  if (existing) {
    const updated = await tx.subscription.update({
      where: { id: existing.id },
      data: { planId: plan.id, status: 'ACTIVE', expiresAt },
    });
    return updated.id;
  }

  const created = await tx.subscription.create({
    data: {
      userId: payment.userId,
      planId: plan.id,
      status: 'ACTIVE',
      startedAt: now,
      expiresAt,
    },
  });
  return created.id;
}

/** Provayder webhook'idan kelgan natija ma'lumotlari. */
export interface PaymentResolution {
  /** Provayder tranzaksiya ID'si. */
  externalId?: string | null;
  /** Provayder callback'idan kelgan xom payload (audit uchun). */
  providerData?: unknown;
  /** Erkin izoh (masalan, bekor qilish sababi). */
  notes?: string;
}

/**
 * To'lovni muvaffaqiyatli deb belgilaydi va obunani aktivlashtiradi.
 * Idempotent — Payment allaqachon 'success' bo'lsa hech narsa o'zgartirmaydi.
 */
export async function markPaymentSuccess(
  paymentId: string,
  opts: PaymentResolution = {},
): Promise<Payment> {
  return prisma.$transaction(async (tx) => {
    const payment = await tx.payment.findUnique({ where: { id: paymentId } });
    if (!payment) throw new Error(`Payment ${paymentId} topilmadi`);
    if (payment.status === 'success') return payment; // idempotent

    const subscriptionId = await activateSubscriptionTx(tx, payment);

    return tx.payment.update({
      where: { id: paymentId },
      data: {
        status: 'success',
        paidAt: new Date(),
        subscriptionId: subscriptionId ?? undefined,
        ...(opts.externalId !== undefined ? { externalId: opts.externalId } : {}),
        ...(opts.providerData !== undefined
          ? { providerData: opts.providerData as Prisma.InputJsonValue }
          : {}),
        ...(opts.notes !== undefined ? { notes: opts.notes } : {}),
      },
    });
  });
}

/**
 * To'lovni muvaffaqiyatsiz deb belgilaydi.
 * 'success' holatdagi to'lovni qaytarib o'zgartirmaydi.
 */
export async function markPaymentFailed(
  paymentId: string,
  opts: PaymentResolution = {},
): Promise<Payment> {
  const payment = await prisma.payment.findUnique({ where: { id: paymentId } });
  if (!payment) throw new Error(`Payment ${paymentId} topilmadi`);
  if (payment.status === 'success') return payment;

  return prisma.payment.update({
    where: { id: paymentId },
    data: {
      status: 'failed',
      ...(opts.externalId !== undefined ? { externalId: opts.externalId } : {}),
      ...(opts.providerData !== undefined
        ? { providerData: opts.providerData as Prisma.InputJsonValue }
        : {}),
      ...(opts.notes !== undefined ? { notes: opts.notes } : {}),
    },
  });
}

/**
 * To'lovni bekor qiladi (provayder CancelTransaction / refund).
 * To'lov obunani aktivlashtirган bo'lsa — obuna ham CANCELLED holatiga o'tadi.
 * Idempotent.
 */
export async function markPaymentCancelled(
  paymentId: string,
  opts: PaymentResolution = {},
): Promise<Payment> {
  return prisma.$transaction(async (tx) => {
    const payment = await tx.payment.findUnique({ where: { id: paymentId } });
    if (!payment) throw new Error(`Payment ${paymentId} topilmadi`);
    if (payment.status === 'cancelled') return payment;

    // To'lov obuna aktivlashtirган bo'lsa — uni bekor qilamiz (refund holati).
    if (payment.subscriptionId) {
      await tx.subscription.update({
        where: { id: payment.subscriptionId },
        data: { status: 'CANCELLED', cancelledAt: new Date() },
      });
    }

    return tx.payment.update({
      where: { id: paymentId },
      data: {
        status: 'cancelled',
        ...(opts.providerData !== undefined
          ? { providerData: opts.providerData as Prisma.InputJsonValue }
          : {}),
        ...(opts.notes !== undefined ? { notes: opts.notes } : {}),
      },
    });
  });
}

/**
 * Foydalanuvchining aktiv (muddati tugamagan) obunasi, plan bilan birga.
 * consumer-content plan-gating shu funksiyadan foydalanadi.
 */
export async function getActiveSubscription(userId: string) {
  return prisma.subscription.findFirst({
    where: {
      userId,
      status: 'ACTIVE',
      OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
    },
    orderBy: { expiresAt: 'desc' },
    include: { plan: true },
  });
}
