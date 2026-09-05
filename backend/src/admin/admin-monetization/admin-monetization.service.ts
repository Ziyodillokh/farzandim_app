import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { CreatePlanDto } from './dto/create-plan.dto';
import { UpdatePlanDto } from './dto/update-plan.dto';
import { CreatePromocodeDto } from './dto/create-promocode.dto';
import { UpdatePromocodeDto } from './dto/update-promocode.dto';

@Injectable()
export class AdminMonetizationService {
  constructor(private readonly prisma: PrismaService) {}

  // ─── Plans ─────────────────────────────────────────────────────

  private planRow(p: any) {
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

  async listPlans() {
    const rows = await this.prisma.plan.findMany({
      orderBy: [{ sortOrder: 'asc' }, { priceUzs: 'asc' }, { createdAt: 'asc' }],
    });
    return rows.map((r) => this.planRow(r));
  }

  async createPlan(dto: CreatePlanDto) {
    const exists = await this.prisma.plan.findUnique({
      where: { slug: dto.slug },
    });
    if (exists) {
      throw new ConflictException('Plan with this slug already exists');
    }
    const created = await this.prisma.plan.create({
      data: {
        slug: dto.slug,
        name: dto.name,
        description: dto.description ?? null,
        priceUzs: dto.priceUzs,
        period: dto.period,
        entitlementTier: dto.entitlementTier,
        badge: dto.badge ?? null,
        features: dto.features ?? [],
        isActive: dto.isActive ?? true,
        sortOrder: dto.sortOrder ?? 0,
      },
    });
    return this.planRow(created);
  }

  async updatePlan(id: string, dto: UpdatePlanDto) {
    const updates: Prisma.PlanUpdateInput = {};
    if (dto.name !== undefined) updates.name = dto.name;
    if (dto.description !== undefined) updates.description = dto.description;
    if (dto.priceUzs !== undefined) updates.priceUzs = dto.priceUzs;
    if (dto.period !== undefined) updates.period = dto.period;
    if (dto.entitlementTier !== undefined)
      updates.entitlementTier = dto.entitlementTier;
    if (dto.badge !== undefined) updates.badge = dto.badge;
    if (dto.features !== undefined) updates.features = dto.features;
    if (dto.isActive !== undefined) updates.isActive = dto.isActive;
    if (dto.sortOrder !== undefined) updates.sortOrder = dto.sortOrder;
    try {
      const updated = await this.prisma.plan.update({
        where: { id },
        data: updates,
      });
      return this.planRow(updated);
    } catch (err: any) {
      if (err?.code === 'P2025')
        throw new NotFoundException('Plan not found');
      throw err;
    }
  }

  async deletePlan(id: string) {
    const plan = await this.prisma.plan.findUnique({
      where: { id },
      include: {
        // ⚠️ `subscriptions` SHART: Subscription.plan `onDelete: SetNull`
        // bilan bog'langan, ya'ni tarifni o'chirish obunachilarning
        // planId sini NULL qiladi. Keyin loadChildContext plan topolmay
        // ularni 'free' deb hisoblaydi — TO'LAGAN mijoz butun pullik
        // kontentdan jimgina ayriladi. (2026-09-05 auditi)
        _count: {
          select: { payments: true, promocodes: true, subscriptions: true },
        },
      },
    });
    if (!plan) throw new NotFoundException('Plan not found');

    // If plan has FK references, do a soft delete (deactivate) instead.
    if (
      plan._count.payments > 0 ||
      plan._count.promocodes > 0 ||
      plan._count.subscriptions > 0
    ) {
      const deactivated = await this.prisma.plan.update({
        where: { id },
        data: { isActive: false },
      });
      return { ...this.planRow(deactivated), soft: true };
    }

    await this.prisma.plan.delete({ where: { id } });
    return { ...this.planRow(plan), soft: false };
  }

  // ─── Promocodes ────────────────────────────────────────────────

  private promocodeRow(m: any) {
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

  async listPromocodes(query: { q?: string; planId?: string; status?: string }) {
    const where: Prisma.PromocodeWhereInput = {};
    if (query.planId) where.planId = query.planId;
    if (
      query.status === 'active' ||
      query.status === 'inactive' ||
      query.status === 'archived'
    ) {
      where.status = query.status;
    }
    if (query.q && query.q.trim().length > 0) {
      where.code = { contains: query.q.trim(), mode: 'insensitive' };
    }
    const rows = await this.prisma.promocode.findMany({
      where,
      orderBy: [{ status: 'asc' }, { createdAt: 'desc' }],
    });
    return rows.map((r) => this.promocodeRow(r));
  }

  async createPromocode(dto: CreatePromocodeDto) {
    const exists = await this.prisma.promocode.findUnique({
      where: { code: dto.code },
    });
    if (exists) {
      throw new ConflictException('Promocode with this code already exists');
    }
    const created = await this.prisma.promocode.create({
      data: {
        code: dto.code,
        discountPct: dto.discountPct,
        usageLimit: dto.usageLimit ?? 0,
        expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : null,
        status: dto.status ?? 'active',
        planId: dto.planId ?? null,
      },
    });
    return this.promocodeRow(created);
  }

  async updatePromocode(id: string, dto: UpdatePromocodeDto) {
    const updates: Prisma.PromocodeUpdateInput = {};
    if (dto.code !== undefined) updates.code = dto.code;
    if (dto.discountPct !== undefined) updates.discountPct = dto.discountPct;
    if (dto.usageLimit !== undefined) updates.usageLimit = dto.usageLimit;
    if (dto.expiresAt !== undefined)
      updates.expiresAt = dto.expiresAt ? new Date(dto.expiresAt) : null;
    if (dto.status !== undefined) updates.status = dto.status;
    if (dto.planId !== undefined) {
      updates.plan = dto.planId
        ? { connect: { id: dto.planId } }
        : { disconnect: true };
    }
    try {
      const updated = await this.prisma.promocode.update({
        where: { id },
        data: updates,
      });
      return this.promocodeRow(updated);
    } catch (err: any) {
      if (err?.code === 'P2025')
        throw new NotFoundException('Promocode not found');
      if (err?.code === 'P2002')
        throw new ConflictException('Promocode with this code already exists');
      throw err;
    }
  }

  async deletePromocode(id: string) {
    try {
      await this.prisma.promocode.delete({ where: { id } });
      return { ok: true };
    } catch (err: any) {
      if (err?.code === 'P2025')
        throw new NotFoundException('Promocode not found');
      throw err;
    }
  }

  // ─── Payments ──────────────────────────────────────────────────

  private paymentRow(p: any) {
    return {
      id: p.id,
      user: p.user
        ? { id: p.user.id, name: p.user.name ?? '—', phone: p.user.phone }
        : null,
      catalogPlan: p.plan
        ? { id: p.plan.id, name: p.plan.name, slug: p.plan.slug }
        : null,
      plan: p.planName ?? p.plan?.name ?? null,
      amount: p.amount,
      method: p.method,
      status: p.status,
      externalId: p.externalId,
      notes: p.notes,
      createdAt: p.createdAt.toISOString(),
    };
  }

  async listPayments(query: { q?: string; planId?: string; method?: string; status?: string }) {
    const where: Prisma.PaymentWhereInput = {};
    if (query.planId) where.planId = query.planId;
    if (query.method) where.method = query.method;
    if (query.status) where.status = query.status;
    if (query.q && query.q.trim().length > 0) {
      const term = query.q.trim();
      where.OR = [
        { externalId: { contains: term, mode: 'insensitive' } },
        { planName: { contains: term, mode: 'insensitive' } },
        { user: { name: { contains: term, mode: 'insensitive' } } },
        { user: { phone: { contains: term, mode: 'insensitive' } } },
      ];
    }
    const rows = await this.prisma.payment.findMany({
      where,
      include: {
        user: { select: { id: true, name: true, phone: true } },
        plan: { select: { id: true, name: true, slug: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
    return rows.map((r) => this.paymentRow(r));
  }

  // ─── Subscriptions (placeholder) ───────────────────────────────

  async listSubscriptions(query: { status?: string; page?: number; limit?: number }) {
    // Subscription model to be added later; return empty for now
    return {
      items: [],
      pagination: {
        page: query.page ?? 1,
        totalPages: 1,
        total: 0,
        limit: query.limit ?? 20,
      },
    };
  }
}
