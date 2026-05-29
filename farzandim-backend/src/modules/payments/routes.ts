// To'lov moduli (Sprint 6 — P0 monetizatsiya).
//
// Consumer endpoint'lar (JWT auth):
//   GET  /api/payments/plans     — tariflar + sozlangan provayderlar
//   GET  /api/payments/me        — joriy obuna + to'lov tarixi
//   POST /api/payments/checkout  — to'lov boshlash (pending Payment + checkout URL)
//
// Provayder webhook'lari (JWT yo'q — provayder imzo bilan tekshiriladi):
//   POST /api/payments/webhook/payme
//   POST /api/payments/webhook/click
//   POST /api/payments/webhook/uzum

import { FastifyPluginAsync, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { prisma } from '../../lib/prisma';
import { authGuard } from '../../middleware/auth';
import { paymentWebhookIps } from '../../config/env';
import {
  getActiveSubscription,
  getAvailableProviderKeys,
  getProvider,
  isProviderAvailable,
  type PaymentProvider,
  type WebhookRequest,
} from '../../lib/payments';

const checkoutSchema = z.object({
  planId: z.string().min(1),
  provider: z.enum(['payme', 'click', 'uzum']),
});

/** Provayder webhook'ini bajaradi va javobni qaytaradi. */
async function runWebhook(
  provider: PaymentProvider,
  request: FastifyRequest,
  reply: FastifyReply,
): Promise<void> {
  // H4 — provayder sozlanmagan/tasdiqlanmagan bo'lsa webhook umuman ishlamaydi
  // (taxminiy imzo formulasi ishga tushmasin — Uzum hozir shu holatda).
  if (!provider.isConfigured()) {
    reply.code(404).send({ error: 'Provider not available' });
    return;
  }
  const webhookReq: WebhookRequest = {
    body: request.body,
    rawBody:
      typeof request.body === 'string'
        ? request.body
        : JSON.stringify(request.body ?? ''),
    headers: request.headers as Record<string, string | undefined>,
    query: (request.query ?? {}) as Record<string, unknown>,
  };
  try {
    const result = await provider.handleWebhook(webhookReq);
    reply.code(result.status).send(result.body);
  } catch (err) {
    request.log.error({ err }, `payments webhook ${provider.key} xato`);
    reply.code(500).send({ error: 'Webhook processing failed' });
  }
}

/**
 * H5 — webhook IP allowlist. `PAYMENT_WEBHOOK_IPS` to'ldirilgan bo'lsa faqat
 * o'sha IP'lardan kelgan webhook'lar qabul qilinadi; bo'sh bo'lsa o'tkazadi
 * (imzo tekshiruvi baribir himoya qiladi). Nginx orqasidamiz — real IP
 * `X-Forwarded-For` ning birinchi qiymatidan olinadi.
 */
async function webhookIpGuard(
  request: FastifyRequest,
  reply: FastifyReply,
): Promise<void> {
  if (paymentWebhookIps.length === 0) return;
  const fwd = request.headers['x-forwarded-for'];
  const clientIp =
    (typeof fwd === 'string' ? fwd.split(',')[0]?.trim() : undefined) ?? request.ip;
  if (!paymentWebhookIps.includes(clientIp)) {
    request.log.warn({ clientIp }, 'webhook ruxsat etilmagan IP — rad etildi');
    reply.code(403).send({ error: 'Forbidden' });
    return;
  }
}

export const paymentRoutes: FastifyPluginAsync = async (fastify) => {
  // Click callback'i application/x-www-form-urlencoded ko'rinishida keladi —
  // bu plugin doirasida parser ro'yxatdan o'tkaziladi (boshqa modullarga ta'sir yo'q).
  fastify.addContentTypeParser(
    'application/x-www-form-urlencoded',
    { parseAs: 'string' },
    (_req, body, done) => {
      try {
        const obj: Record<string, string> = {};
        for (const [k, v] of new URLSearchParams(body as string)) obj[k] = v;
        done(null, obj);
      } catch (err) {
        done(err as Error, undefined);
      }
    },
  );

  // GET /api/payments/plans — tariflar ro'yxati + sozlangan provayderlar
  fastify.get('/plans', { preHandler: authGuard }, async (_request, reply) => {
    const plans = await prisma.plan.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
    });
    return reply.send({
      plans: plans.map((p) => ({
        id: p.id,
        slug: p.slug,
        name: p.name,
        description: p.description,
        priceUzs: p.priceUzs,
        period: p.period,
        entitlementTier: p.entitlementTier,
        badge: p.badge,
        features: p.features,
      })),
      availableProviders: getAvailableProviderKeys(),
    });
  });

  // GET /api/payments/me — joriy obuna + oxirgi 20 to'lov
  fastify.get('/me', { preHandler: authGuard }, async (request, reply) => {
    const userId = request.user!.userId;
    const [subscription, payments] = await Promise.all([
      getActiveSubscription(userId),
      prisma.payment.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
    ]);
    return reply.send({
      subscription: subscription
        ? {
            id: subscription.id,
            status: subscription.status,
            planName: subscription.plan?.name ?? null,
            entitlementTier: subscription.plan?.entitlementTier ?? 'free',
            startedAt: subscription.startedAt?.toISOString() ?? null,
            expiresAt: subscription.expiresAt?.toISOString() ?? null,
          }
        : null,
      payments: payments.map((p) => ({
        id: p.id,
        planName: p.planName,
        amount: p.amount,
        method: p.method,
        status: p.status,
        createdAt: p.createdAt.toISOString(),
        paidAt: p.paidAt?.toISOString() ?? null,
      })),
    });
  });

  // POST /api/payments/checkout — to'lov boshlash
  fastify.post('/checkout', { preHandler: authGuard }, async (request, reply) => {
    const userId = request.user!.userId;
    const parsed = checkoutSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply
        .code(400)
        .send({ error: 'Invalid body', details: parsed.error.flatten() });
    }
    const { planId, provider } = parsed.data;

    if (!isProviderAvailable(provider)) {
      return reply.code(503).send({
        error: `To'lov provayderi "${provider}" hozircha mavjud emas`,
      });
    }

    const plan = await prisma.plan.findUnique({ where: { id: planId } });
    if (!plan || !plan.isActive) {
      return reply.code(404).send({ error: 'Tarif topilmadi' });
    }
    if (plan.priceUzs <= 0) {
      return reply.code(400).send({ error: "Bepul tarif uchun to'lov kerak emas" });
    }

    const payment = await prisma.payment.create({
      data: {
        userId,
        planId: plan.id,
        planName: plan.name,
        amount: plan.priceUzs,
        method: provider,
        status: 'pending',
      },
    });

    try {
      const checkout = await getProvider(provider).createCheckout({
        paymentId: payment.id,
        amount: payment.amount,
        planName: plan.name,
      });
      return reply.send({
        paymentId: payment.id,
        provider: checkout.provider,
        checkoutUrl: checkout.checkoutUrl,
      });
    } catch (err) {
      request.log.error({ err }, 'checkout yaratish muvaffaqiyatsiz');
      await prisma.payment.update({
        where: { id: payment.id },
        data: { status: 'failed', notes: 'Checkout creation failed' },
      });
      return reply.code(502).send({ error: "To'lov sahifasini ochib bo'lmadi" });
    }
  });

  // Provayder webhook'lari — JWT yo'q, provayder imzosi bilan tekshiriladi.
  fastify.post('/webhook/payme', { preHandler: webhookIpGuard }, (request, reply) =>
    runWebhook(getProvider('payme'), request, reply),
  );
  fastify.post('/webhook/click', { preHandler: webhookIpGuard }, (request, reply) =>
    runWebhook(getProvider('click'), request, reply),
  );
  fastify.post('/webhook/uzum', { preHandler: webhookIpGuard }, (request, reply) =>
    runWebhook(getProvider('uzum'), request, reply),
  );
};
