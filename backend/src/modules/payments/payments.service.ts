import { Injectable, Logger} from '@nestjs/common';
import { Prisma, type Payment } from '@prisma/client';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../common/database/prisma.service';

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Tarif davri → kun soni. `null` = MUDDATSIZ (lifetime).
 *
 * ⚠️ 2026-09-05'da topilgan xato: `lifetime` bu yerda 0 qaytarardi va
 * `if (days <= 0) return null` obunani UMUMAN yaratmasdi — lekin to'lov
 * `success` deb belgilanardi. Ya'ni mijoz pul to'lab hech narsa olmasdi
 * va bu hech qayerda iz qoldirmasdi. `lifetime` tarif yaratish
 * CreatePlanDto'da ruxsat etilgan (PLAN_PERIODS), ya'ni bu nazariy emas.
 *
 * O'qish tomoni muddatsizlikni ALLAQACHON qo'llab-quvvatlaydi:
 * `expiresAt: null` → `{ OR: [{ expiresAt: null }, { gt: now }] }` bo'yicha
 * har doim faol. Shuning uchun to'g'ri yechim — 0 emas, `null`.
 *
 * `undefined` = tanilmagan davr (xato).
 */
function periodDurationDays(period: string): number | null | undefined {
  switch (period) {
    case 'yearly':
      return 365;
    case 'monthly':
      return 30;
    case 'lifetime':
      return null; // muddatsiz
    default:
      return undefined; // tanilmadi
  }
}

export interface PaymentResolution {
  externalId?: string | null;
  providerData?: unknown;
  notes?: string;
}

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Muddati o'tgan obunalarni EXPIRED ga o'tkazadi (har soat).
   *
   * ⚠️ NEGA KERAK: ilgari hech narsa obunani EXPIRED qilmasdi — muddati
   * tugagan yozuv `status='ACTIVE'` bo'lib qolaverardi. Iste'molchi API
   * `expiresAt` ni ham tekshirgani uchun to'g'ri ishlardi, admin panel esa
   * faqat statusga qarardi va foydalanuvchini "obunachi" deb ko'rsatardi.
   * Ikki ko'rinish bir-biriga zid bo'lib, "to'ladi-yu kontent yo'q"
   * shikoyatini tekshirib bo'lmasdi.
   *
   * Endi shart bitta joyda (`activeSubscriptionWhere`) va bu cron holatni
   * ham haqiqatga keltiradi — ikkalasi qayta ajralib ketmaydi.
   *
   * `expiresAt: null` (lifetime) TEGILMAYDI.
   */
  @Cron('0 10 * * * *', { name: 'subscriptions-expire' })
  async expireOverdueSubscriptions(): Promise<void> {
    const res = await this.prisma.subscription.updateMany({
      where: { status: 'ACTIVE', expiresAt: { not: null, lt: new Date() } },
      data: { status: 'EXPIRED' },
    });
    if (res.count > 0) {
      this.logger.log(`${res.count} ta obuna muddati tugadi → EXPIRED`);
    }
  }

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
    if (days === undefined) {
      // Tanilmagan davr — obuna berolmaymiz. JIM O'TMAYMIZ: mijoz pul
      // to'lagan, buni albatta ko'rish kerak.
      this.logger.error(
        `To'lov ${payment.id}: '${plan.period}' davri tanilmadi — ` +
          `obuna YARATILMADI (plan ${plan.id}, user ${payment.userId})`,
      );
      return null;
    }

    const now = new Date();
    const existing = await tx.subscription.findFirst({
      where: { userId: payment.userId, status: 'ACTIVE' },
      orderBy: { expiresAt: 'desc' },
    });

    const base =
      existing?.expiresAt && existing.expiresAt > now
        ? existing.expiresAt
        : now;
    // days === null → lifetime: muddat qo'yilmaydi (abadiy faol).
    const expiresAt = days === null ? null : new Date(base.getTime() + days * DAY_MS);

    if (existing) {
      const updated = await tx.subscription.update({
        where: { id: existing.id },
        // To'lov qilindi — bu endi PULLIK obuna (trial emas), shuning uchun
        // trial belgisi tozalanadi (aks holda "trial tugayapti" push ketardi).
        data: {
          planId: plan.id,
          status: 'ACTIVE',
          expiresAt,
          isTrial: false,
          trialReminderSentAt: null,
          trialEndedNotifiedAt: null,
        },
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

      // ⚠️ To'lov o'tdi, lekin obuna berilmadi. Ilgari bu HECH QANDAY iz
      // qoldirmasdi: to'lov 'success', subscriptionId bo'sh — mijoz pul
      // to'lab hech narsa olmagan va buni bilishning yo'li yo'q edi.
      if (!subscriptionId && payment.planId) {
        this.logger.error(
          `To'lov ${payment.id} MUVAFFAQIYATLI, lekin OBUNA YARATILMADI ` +
            `(user ${payment.userId}, plan ${payment.planId}, ` +
            `summa ${payment.amount}). Qo'lda tekshirish kerak.`,
        );
      }

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
