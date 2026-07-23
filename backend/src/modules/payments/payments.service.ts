import { Injectable } from '@nestjs/common';
import { Prisma, type Payment } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';

const DAY_MS = 24 * 60 * 60 * 1000;

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

export interface PaymentResolution {
  externalId?: string | null;
  providerData?: unknown;
  notes?: string;
}

@Injectable()
export class PaymentsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Activate or extend subscription after successful payment.
   */
  private async activateSubscriptionTx(
    tx: Prisma.TransactionClient,
    payment: Payment,
  ): Promise<string | null> {
    if (!payment.userId || !payment.planId) return null;

    const plan = await tx.plan.findUnique({ where: { id: payment.planId } });
    if (!plan) return null;

    // Muddat: to'lov summasi oylik narxning ~10 barobari bo'lsa — YILLIK sotib
    // olingan (365 kun); aks holda plan.period bo'yicha (oylik=30). Shu tarzda
    // OYLIK plan tanlab yillik sotib olsa ham obuna muddati to'g'ri bo'ladi.
    const isYearlyPurchase =
      plan.priceUzs > 0 && payment.amount >= plan.priceUzs * 10;
    const days = isYearlyPurchase ? 365 : periodDurationDays(plan.period);
    if (days <= 0) return null;

    const now = new Date();
    const existing = await tx.subscription.findFirst({
      where: { userId: payment.userId, status: 'ACTIVE' },
      orderBy: { expiresAt: 'desc' },
    });

    const base =
      existing?.expiresAt && existing.expiresAt > now
        ? existing.expiresAt
        : now;
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

  /**
   * Mark payment as successful and activate subscription. Idempotent.
   */
  async markPaymentSuccess(
    paymentId: string,
    opts: PaymentResolution = {},
  ): Promise<Payment> {
    return this.prisma.$transaction(async (tx) => {
      const payment = await tx.payment.findUnique({
        where: { id: paymentId },
      });
      if (!payment) throw new Error(`Payment ${paymentId} not found`);
      if (payment.status === 'success') return payment;

      const subscriptionId = await this.activateSubscriptionTx(tx, payment);

      return tx.payment.update({
        where: { id: paymentId },
        data: {
          status: 'success',
          paidAt: new Date(),
          subscriptionId: subscriptionId ?? undefined,
          ...(opts.externalId !== undefined
            ? { externalId: opts.externalId }
            : {}),
          ...(opts.providerData !== undefined
            ? {
                providerData:
                  opts.providerData as Prisma.InputJsonValue,
              }
            : {}),
          ...(opts.notes !== undefined ? { notes: opts.notes } : {}),
        },
      });
    });
  }

  /**
   * Mark payment as failed. Does not revert 'success' payments.
   */
  async markPaymentFailed(
    paymentId: string,
    opts: PaymentResolution = {},
  ): Promise<Payment> {
    const payment = await this.prisma.payment.findUnique({
      where: { id: paymentId },
    });
    if (!payment) throw new Error(`Payment ${paymentId} not found`);
    if (payment.status === 'success') return payment;

    return this.prisma.payment.update({
      where: { id: paymentId },
      data: {
        status: 'failed',
        ...(opts.externalId !== undefined
          ? { externalId: opts.externalId }
          : {}),
        ...(opts.providerData !== undefined
          ? {
              providerData:
                opts.providerData as Prisma.InputJsonValue,
            }
          : {}),
        ...(opts.notes !== undefined ? { notes: opts.notes } : {}),
      },
    });
  }

  /**
   * Cancel payment and its associated subscription. Idempotent.
   */
  async markPaymentCancelled(
    paymentId: string,
    opts: PaymentResolution = {},
  ): Promise<Payment> {
    return this.prisma.$transaction(async (tx) => {
      const payment = await tx.payment.findUnique({
        where: { id: paymentId },
      });
      if (!payment) throw new Error(`Payment ${paymentId} not found`);
      if (payment.status === 'cancelled') return payment;

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
            ? {
                providerData:
                  opts.providerData as Prisma.InputJsonValue,
              }
            : {}),
          ...(opts.notes !== undefined ? { notes: opts.notes } : {}),
        },
      });
    });
  }

  /**
   * Get active subscription for a user (with plan).
   */
  async getActiveSubscription(userId: string) {
    return this.prisma.subscription.findFirst({
      where: {
        userId,
        status: 'ACTIVE',
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
      },
      orderBy: { expiresAt: 'desc' },
      include: { plan: true },
    });
  }
}
