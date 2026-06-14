import { Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { EnvConfig } from '../../common/config/env.schema';

export interface RowJson {
  id: string;
  kind: 'parent' | 'child';
  name: string;
  email: string | null;
  phone: string | null;
  role: 'PARENT' | 'CHILD';
  status: 'active' | 'blocked';
  plan: string;
  planLabel: string;
  lastActivityAt: string | null;
  /** Ko'rsatish uchun avatar URL. Parent — OAuth (Telegram/Google) tashqi
   *  URL; bola — MinIO'dagi fotosi @Public proxy orqali. Yo'q bo'lsa null
   *  (UI initsiallarni ko'rsatadi). */
  avatarUrl: string | null;
}

@Injectable()
export class AdminUsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService<EnvConfig, true>,
  ) {}

  // Bola fotosi @Public proxy orqali (signed MinIO URL brauzerga yetmaydi).
  // PUBLIC_BASE_URL — deploy domeni (admin shu domenda ishlaydi).
  private childAvatarUrl(childId: string): string {
    const base = this.config.get('PUBLIC_BASE_URL', { infer: true });
    return `${base}/api/children/${childId}/avatar/image`;
  }

  private parentRow(u: {
    id: string;
    name: string | null;
    email: string | null;
    phone: string | null;
    isActive: boolean;
    updatedAt: Date;
    avatarUrl?: string | null;
    subscriptions?: { plan: { name: string; entitlementTier: string } | null }[];
  }): RowJson {
    const sub = u.subscriptions?.[0];
    return {
      id: u.id,
      kind: 'parent',
      name: u.name?.trim() || '—',
      email: u.email,
      phone: u.phone,
      role: 'PARENT',
      status: u.isActive ? 'active' : 'blocked',
      plan: sub?.plan?.entitlementTier ?? 'free',
      planLabel: sub?.plan?.name ?? 'Free',
      lastActivityAt: u.updatedAt.toISOString(),
      avatarUrl: u.avatarUrl ?? null,
    };
  }

  private childRow(c: {
    id: string;
    name: string;
    lastSeenAt: Date | null;
    updatedAt: Date;
    photoPath?: string | null;
    childUser?: { phone: string | null; email: string | null } | null;
  }): RowJson {
    return {
      id: c.id,
      kind: 'child',
      name: c.name,
      email: c.childUser?.email ?? null,
      phone: c.childUser?.phone ?? null,
      role: 'CHILD',
      status: 'active',
      plan: 'free',
      planLabel: 'Free',
      lastActivityAt: (c.lastSeenAt ?? c.updatedAt).toISOString(),
      avatarUrl: c.photoPath ? this.childAvatarUrl(c.id) : null,
    };
  }

  async list(query: {
    q?: string;
    role?: string;
    status?: string;
    plan?: string;
    page: number;
    limit: number;
  }) {
    const { q, role, status, plan, page, limit } = query;
    const kindFilter =
      role === 'parent' || role === 'PARENT'
        ? 'parent'
        : role === 'child' || role === 'CHILD'
          ? 'child'
          : null;
    const planFilter = plan && plan.length > 0 ? plan : null;
    // Bolalarda obuna yo'q (doimo free) — pulli tarif tanlansa ularni chiqarmaymiz.
    const paidPlan = planFilter !== null && planFilter !== 'free';

    const parentWhere: Prisma.UserWhereInput = { role: 'PARENT' };
    if (status === 'active') parentWhere.isActive = true;
    if (status === 'blocked') parentWhere.isActive = false;
    if (q && q.length > 0) {
      parentWhere.OR = [
        { name: { contains: q, mode: 'insensitive' } },
        { phone: { contains: q, mode: 'insensitive' } },
        { email: { contains: q, mode: 'insensitive' } },
      ];
    }
    if (planFilter) {
      parentWhere.subscriptions = paidPlan
        ? { some: { status: 'ACTIVE', plan: { entitlementTier: planFilter } } }
        : { none: { status: 'ACTIVE' } }; // free — faol obuna yo'q
    }

    const childWhere: Prisma.ChildWhereInput = {};
    if (q && q.length > 0) {
      childWhere.OR = [
        { name: { contains: q, mode: 'insensitive' } },
        { childUser: { phone: { contains: q, mode: 'insensitive' } } },
        { childUser: { email: { contains: q, mode: 'insensitive' } } },
      ];
    }

    const childAllowed =
      kindFilter !== 'parent' && status !== 'blocked' && !paidPlan;
    const parentAllowed = kindFilter !== 'child';

    const [parentTotal, childTotal] = await Promise.all([
      parentAllowed
        ? this.prisma.user.count({ where: parentWhere })
        : 0,
      childAllowed
        ? this.prisma.child.count({ where: childWhere })
        : 0,
    ]);

    const total = parentTotal + childTotal;
    const totalPages = Math.max(1, Math.ceil(total / limit));
    const skip = (page - 1) * limit;
    const fetchCount = skip + limit;

    const [parentRows, childRows] = await Promise.all([
      parentAllowed
        ? this.prisma.user.findMany({
            where: parentWhere,
            include: {
              subscriptions: {
                where: { status: 'ACTIVE' },
                include: { plan: { select: { name: true, entitlementTier: true } } },
                orderBy: { createdAt: 'desc' },
                take: 1,
              },
            },
            orderBy: { updatedAt: 'desc' },
            take: fetchCount,
          })
        : [],
      childAllowed
        ? this.prisma.child.findMany({
            where: childWhere,
            include: { childUser: { select: { phone: true, email: true } } },
            orderBy: [{ lastSeenAt: 'desc' }, { updatedAt: 'desc' }],
            take: fetchCount,
          })
        : [],
    ]);

    const combined: RowJson[] = [
      ...parentRows.map((r) => this.parentRow(r)),
      ...childRows.map((r) => this.childRow(r)),
    ]
      .sort((a, b) => {
        if (!a.lastActivityAt) return 1;
        if (!b.lastActivityAt) return -1;
        return b.lastActivityAt.localeCompare(a.lastActivityAt);
      })
      .slice(skip, skip + limit);

    return {
      items: combined,
      pagination: { page, totalPages, total, limit },
    };
  }

  async findOne(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      include: {
        childrenAsParent: {
          select: { id: true, name: true, age: true, familyCode: true },
        },
      },
    });
    if (!user) throw new NotFoundException('User not found');
    return {
      id: user.id,
      kind: 'parent',
      role: user.role,
      name: user.name?.trim() || '—',
      phone: user.phone,
      telegramId: user.telegramId,
      avatarUrl: user.avatarUrl,
      language: user.language,
      status: user.isActive ? 'active' : 'blocked',
      lastActivityAt: user.updatedAt.toISOString(),
      createdAt: user.createdAt.toISOString(),
      children: user.childrenAsParent,
      childrenCount: user.childrenAsParent.length,
    };
  }

  async findChildProfile(id: string) {
    const child = await this.prisma.child.findUnique({
      where: { id },
      include: {
        childUser: {
          select: { phone: true, telegramId: true, isActive: true },
        },
        parent: { select: { id: true, name: true, phone: true } },
        profile: true,
        xpEvents: { orderBy: { createdAt: 'desc' }, take: 10 },
      },
    });
    if (!child) throw new NotFoundException('Child profile not found');
    return {
      id: child.id,
      kind: 'child' as const,
      name: child.name,
      age: child.age,
      gender: child.gender,
      region: child.region,
      photoPath: child.photoPath,
      familyCode: child.familyCode,
      isConnected: child.isConnected,
      lastSeenAt: child.lastSeenAt?.toISOString() ?? null,
      pairedAt: child.pairedAt?.toISOString() ?? null,
      device: {
        model: child.deviceModel,
        androidVersion: child.androidVersion,
        appVersion: child.appVersion,
        batteryLevel: child.batteryLevel,
        isCharging: child.isCharging,
        wifiName: child.wifiName,
      },
      phone: child.childUser?.phone ?? null,
      parent: child.parent,
      // Bola onboarding'da tanlagan qiziqishlar (chip'lar bilan ko'rsatiladi).
      // `as any` — Prisma client `interests` qatorini regen qilmaguncha
      // (`npx prisma generate`) TypeScript ko'rmaydi. Migratsiyadan keyin
      // tabiiy ravishda type to'g'ri tushadi.
      interests: ((child as any).interests as string[]) ?? [],
      profile: child.profile
        ? {
            xp: child.profile.xp,
            level: child.profile.level,
            status: child.profile.status,
            streakDays: child.profile.streakDays,
            donBalance: child.profile.donBalance,
          }
        : null,
      recentXpEvents: child.xpEvents.map((e) => ({
        id: e.id,
        type: e.type,
        xpDelta: e.xpDelta,
        donDelta: e.donDelta,
        createdAt: e.createdAt.toISOString(),
      })),
      createdAt: child.createdAt.toISOString(),
    };
  }

  async blockUser(id: string) {
    try {
      await this.prisma.user.update({
        where: { id },
        data: { isActive: false },
      });
      return { ok: true, status: 'blocked' };
    } catch (err: any) {
      if (err?.code === 'P2025')
        throw new NotFoundException('User not found');
      throw err;
    }
  }

  async unblockUser(id: string) {
    try {
      await this.prisma.user.update({
        where: { id },
        data: { isActive: true },
      });
      return { ok: true, status: 'active' };
    } catch (err: any) {
      if (err?.code === 'P2025')
        throw new NotFoundException('User not found');
      throw err;
    }
  }
}
