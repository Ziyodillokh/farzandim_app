import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { staffAuthGuard } from '../../middleware/staff-auth';
import { requirePermission } from '../../middleware/require-permission';
import {
  ENTITLEMENT_TIERS,
  PAYMENT_METHODS,
  PLAN_PERIODS,
  PROMOCODE_STATUSES,
  sanitizeFeatures,
} from '../../lib/plan-feature-catalog';

// ─── Plans ─────────────────────────────────────────────────────────

const PlanCreate = z.object({
  name: z.string().trim().min(1).max(80),
  slug: z.string().trim().min(1).max(64).regex(/^[a-z0-9-]+$/, 'lowercase, digits and hyphens only'),
  description: z.string().trim().max(2000).optional().nullable(),
  priceUzs: z.coerce.number().int().min(0).default(0),
  period: z.enum(PLAN_PERIODS).default('monthly'),
  entitlementTier: z.enum(ENTITLEMENT_TIERS).default('standard'),
  badge: z.string().trim().max(40).optional().nullable(),
  features: z.array(z.string()).optional(),
  isActive: z.boolean().optional(),
  sortOrder: z.coerce.number().int().optional(),
});

const PlanUpdate = z.object({
  name: z.string().trim().min(1).max(80).optional(),
  description: z.union([z.string().trim().max(2000), z.null()]).optional(),
  priceUzs: z.coerce.number().int().min(0).optional(),
  period: z.enum(PLAN_PERIODS).optional(),
  entitlementTier: z.enum(ENTITLEMENT_TIERS).optional(),
  badge: z.union([z.string().trim().max(40), z.null()]).optional(),
  features: z.array(z.string()).optional(),
  isActive: z.boolean().optional(),
  sortOrder: z.coerce.number().int().optional(),
  // slug is intentionally immutable after creation
});

function planRow(p: {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  priceUzs: number;
  period: string;
  entitlementTier: string;
  badge: string | null;
  features: string[];
  isActive: boolean;
  sortOrder: number;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: p.id,
    slug: p.slug,
    name: p.name,
    description: p.description,
    priceUzs: p.priceUzs,
    period: p.period,
    entitlementTier: p.entitlementTier,
    badge: p.badge,
    features: p.features,
    isActive: p.isActive,
    sortOrder: p.sortOrder,
    createdAt: p.createdAt.toISOString(),
    updatedAt: p.updatedAt.toISOString(),
  };
}

// ─── Promocodes ────────────────────────────────────────────────────

const PromocodeCreate = z.object({
  code: z.string().trim().min(2).max(40).transform((v) => v.toUpperCase()),
  discountPct: z.coerce.number().int().min(1).max(100),
  usageLimit: z.coerce.number().int().min(0).default(0),
  expiresAt: z.union([z.string().datetime(), z.null()]).optional(),
  status: z.enum(PROMOCODE_STATUSES).optional(),
  planId: z.union([z.string().uuid(), z.null()]).optional(),
});

const PromocodeUpdate = z.object({
  code: z.string().trim().min(2).max(40).optional().transform((v) => v?.toUpperCase()),
  discountPct: z.coerce.number().int().min(1).max(100).optional(),
  usageLimit: z.coerce.number().int().min(0).optional(),
  expiresAt: z.union([z.string().datetime(), z.null()]).optional(),
  status: z.enum(PROMOCODE_STATUSES).optional(),
  planId: z.union([z.string().uuid(), z.null()]).optional(),
});

function promocodeRow(m: {
  id: string;
  code: string;
  discountPct: number;
  usageLimit: number;
  usedCount: number;
  expiresAt: Date | null;
  status: string;
  planId: string | null;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: m.id,
    code: m.code,
    discountPct: m.discountPct,
    usageLimit: m.usageLimit,
    usedCount: m.usedCount,
    expiresAt: m.expiresAt?.toISOString() ?? null,
    status: m.status,
    planId: m.planId,
    createdAt: m.createdAt.toISOString(),
    updatedAt: m.updatedAt.toISOString(),
  };
}

// ─── Payments ──────────────────────────────────────────────────────

function paymentRow(p: {
  id: string;
  userId: string | null;
  planId: string | null;
  planName: string | null;
  amount: number;
  method: string;
  status: string;
  externalId: string | null;
  notes: string | null;
  createdAt: Date;
  user?: { id: string; name: string | null; phone: string | null } | null;
  plan?: { id: string; name: string; slug: string } | null;
}) {
  return {
    id: p.id,
    user: p.user ? { id: p.user.id, name: p.user.name ?? '—', phone: p.user.phone } : null,
    catalogPlan: p.plan ? { id: p.plan.id, name: p.plan.name, slug: p.plan.slug } : null,
    plan: p.planName ?? p.plan?.name ?? null,
    amount: p.amount,
    method: p.method,
    status: p.status,
    externalId: p.externalId,
    notes: p.notes,
    createdAt: p.createdAt.toISOString(),
  };
}

// ─── Routes ────────────────────────────────────────────────────────

export const adminMonetizationRoutes: FastifyPluginAsync = async (fastify) => {
  // Sprint 6 — RBAC: butun modul autentifikatsiyadan o'tadi.
  // C5 fix: o'qish va yozish ruxsatlari ajratilgan — view_payments faqat
  // ko'rish uchun, yozish (plan/promokod CRUD) manage_monetization talab qiladi.
  fastify.addHook('preHandler', staffAuthGuard);
  const canRead = requirePermission('manage_monetization', 'view_payments');
  const canWrite = requirePermission('manage_monetization');

  // PLANS ----------------------------------------------------------

  fastify.get('/plans', { preHandler: canRead }, async (_request, reply) => {
    const rows = await prisma.plan.findMany({
      orderBy: [{ sortOrder: 'asc' }, { priceUzs: 'asc' }, { createdAt: 'asc' }],
    });
    return reply.send(rows.map(planRow));
  });

  fastify.post('/plans', { preHandler: canWrite }, async (request, reply) => {
    const parsed = PlanCreate.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid plan payload', details: parsed.error.flatten() });
    }
    const data = parsed.data;
    const exists = await prisma.plan.findUnique({ where: { slug: data.slug } });
    if (exists) {
      return reply.code(409).send({ error: 'Plan with this slug already exists' });
    }
    const created = await prisma.plan.create({
      data: {
        slug: data.slug,
        name: data.name,
        description: data.description ?? null,
        priceUzs: data.priceUzs,
        period: data.period,
        entitlementTier: data.entitlementTier,
        badge: data.badge ?? null,
        features: sanitizeFeatures(data.features ?? []),
        isActive: data.isActive ?? true,
        sortOrder: data.sortOrder ?? 0,
      },
    });
    return reply.code(201).send(planRow(created));
  });

  fastify.patch('/plans/:id', { preHandler: canWrite }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const parsed = PlanUpdate.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid plan payload', details: parsed.error.flatten() });
    }
    const data = parsed.data;
    const updates: Prisma.PlanUpdateInput = {};
    if (data.name !== undefined) updates.name = data.name;
    if (data.description !== undefined) updates.description = data.description;
    if (data.priceUzs !== undefined) updates.priceUzs = data.priceUzs;
    if (data.period !== undefined) updates.period = data.period;
    if (data.entitlementTier !== undefined) updates.entitlementTier = data.entitlementTier;
    if (data.badge !== undefined) updates.badge = data.badge;
    if (data.features !== undefined) updates.features = sanitizeFeatures(data.features);
    if (data.isActive !== undefined) updates.isActive = data.isActive;
    if (data.sortOrder !== undefined) updates.sortOrder = data.sortOrder;
    try {
      const updated = await prisma.plan.update({ where: { id }, data: updates });
      return reply.send(planRow(updated));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Plan not found' });
      }
      throw err;
    }
  });

  fastify.delete('/plans/:id', { preHandler: canWrite }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const plan = await prisma.plan.findUnique({
      where: { id },
      include: { _count: { select: { payments: true, promocodes: true } } },
    });
    if (!plan) return reply.code(404).send({ error: 'Plan not found' });

    if (plan._count.payments > 0 || plan._count.promocodes > 0) {
      const deactivated = await prisma.plan.update({
        where: { id },
        data: { isActive: false },
      });
      return reply.send({ ...planRow(deactivated), soft: true });
    }

    await prisma.plan.delete({ where: { id } });
    return reply.send({ ...planRow(plan), soft: false });
  });

  // PROMOCODES -----------------------------------------------------

  fastify.get('/promocodes', { preHandler: canRead }, async (request, reply) => {
    const q = (request.query as { q?: string; planId?: string; status?: string }) ?? {};
    const where: Prisma.PromocodeWhereInput = {};
    if (q.planId) where.planId = q.planId;
    if (q.status === 'active' || q.status === 'inactive' || q.status === 'archived') {
      where.status = q.status;
    }
    if (q.q && q.q.trim().length > 0) {
      where.code = { contains: q.q.trim(), mode: 'insensitive' };
    }
    const rows = await prisma.promocode.findMany({
      where,
      orderBy: [{ status: 'asc' }, { createdAt: 'desc' }],
    });
    return reply.send(rows.map(promocodeRow));
  });

  fastify.post('/promocodes', { preHandler: canWrite }, async (request, reply) => {
    const parsed = PromocodeCreate.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid promocode payload', details: parsed.error.flatten() });
    }
    const data = parsed.data;
    const exists = await prisma.promocode.findUnique({ where: { code: data.code } });
    if (exists) {
      return reply.code(409).send({ error: 'Promocode with this code already exists' });
    }
    const created = await prisma.promocode.create({
      data: {
        code: data.code,
        discountPct: data.discountPct,
        usageLimit: data.usageLimit,
        expiresAt: data.expiresAt ? new Date(data.expiresAt) : null,
        status: data.status ?? 'active',
        planId: data.planId ?? null,
      },
    });
    return reply.code(201).send(promocodeRow(created));
  });

  fastify.patch('/promocodes/:id', { preHandler: canWrite }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const parsed = PromocodeUpdate.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid promocode payload', details: parsed.error.flatten() });
    }
    const data = parsed.data;
    const updates: Prisma.PromocodeUpdateInput = {};
    if (data.code !== undefined) updates.code = data.code;
    if (data.discountPct !== undefined) updates.discountPct = data.discountPct;
    if (data.usageLimit !== undefined) updates.usageLimit = data.usageLimit;
    if (data.expiresAt !== undefined) updates.expiresAt = data.expiresAt ? new Date(data.expiresAt) : null;
    if (data.status !== undefined) updates.status = data.status;
    if (data.planId !== undefined) {
      updates.plan = data.planId ? { connect: { id: data.planId } } : { disconnect: true };
    }
    try {
      const updated = await prisma.promocode.update({ where: { id }, data: updates });
      return reply.send(promocodeRow(updated));
    } catch (err: unknown) {
      const code = (err as { code?: string }).code;
      if (code === 'P2025') return reply.code(404).send({ error: 'Promocode not found' });
      if (code === 'P2002') return reply.code(409).send({ error: 'Promocode with this code already exists' });
      throw err;
    }
  });

  fastify.delete('/promocodes/:id', { preHandler: canWrite }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      await prisma.promocode.delete({ where: { id } });
      return reply.code(204).send();
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Promocode not found' });
      }
      throw err;
    }
  });

  // PAYMENTS (read-only) -------------------------------------------

  fastify.get('/payments', { preHandler: canRead }, async (request, reply) => {
    const q = (request.query as { q?: string; planId?: string; method?: string }) ?? {};
    const where: Prisma.PaymentWhereInput = {};
    if (q.planId) where.planId = q.planId;
    if (q.method && (PAYMENT_METHODS as readonly string[]).includes(q.method)) {
      where.method = q.method;
    }
    if (q.q && q.q.trim().length > 0) {
      const term = q.q.trim();
      where.OR = [
        { externalId: { contains: term, mode: 'insensitive' } },
        { planName: { contains: term, mode: 'insensitive' } },
        { user: { name: { contains: term, mode: 'insensitive' } } },
        { user: { phone: { contains: term, mode: 'insensitive' } } },
      ];
    }
    const rows = await prisma.payment.findMany({
      where,
      include: {
        user: { select: { id: true, name: true, phone: true } },
        plan: { select: { id: true, name: true, slug: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
    return reply.send(rows.map(paymentRow));
  });
};
