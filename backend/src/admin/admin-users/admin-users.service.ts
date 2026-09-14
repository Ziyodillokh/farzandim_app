import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  activeSubscriptionWhere,
  hasActiveSubscription,
} from '../../common/subscription/active-subscription';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { EnvConfig } from '../../common/config/env.schema';
import { FcmService } from '../../common/fcm/fcm.service';
import { AdminAuditService } from '../../common/audit/admin-audit.service';
import { tr } from '../../common/i18n/notification-i18n';
import { GrantSubscriptionDto } from './dto/grant-subscription.dto';

/** Audit yozuvi uchun so'rov konteksti (ip + user-agent). */
export interface AdminReqCtx {
  ip?: string;
  headers?: Record<string, string | string[] | undefined>;
}

/** Tarif darajasi — sovg'a hech qachon pastroq tarifga TUSHIRMAYDI. */
const TIER_RANK: Record<string, number> = {
  free: 0,
  basic: 1,
  standard: 2,
  premium: 3,
};
const DAY_MS = 24 * 60 * 60 * 1000;

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
  private readonly logger = new Logger(AdminUsersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService<EnvConfig, true>,
    private readonly fcm: FcmService,
    private readonly audit: AdminAuditService,
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
      // ⚠️ `expiresAt` SHART: busiz muddati tugagan obuna ham "faol"
      // ko'rinardi va panel bola ilovasidagi haqiqatga zid javob berardi.
      parentWhere.subscriptions = hasActiveSubscription(
        paidPlan,
        paidPlan ? { plan: { entitlementTier: planFilter } } : undefined,
      );
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
                where: activeSubscriptionWhere(),
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
          select: {
            id: true,
            name: true,
            age: true,
            familyCode: true,
            isConnected: true,
            lastSeenAt: true,
            photoPath: true,
          },
        },
        // Faol obuna (bitta) — "Batafsil" panelida tarif + muddat + trial.
        subscriptions: {
          where: activeSubscriptionWhere(),
          include: {
            plan: { select: { id: true, name: true, entitlementTier: true } },
          },
          orderBy: { expiresAt: 'desc' },
          take: 1,
        },
        _count: { select: { payments: true } },
      },
    });
    if (!user) throw new NotFoundException('User not found');
    const sub = user.subscriptions[0] ?? null;
    return {
      id: user.id,
      kind: 'parent',
      role: user.role,
      name: user.name?.trim() || '—',
      phone: user.phone,
      email: user.email,
      telegramId: user.telegramId,
      avatarUrl: user.avatarUrl,
      language: user.language,
      status: user.isActive ? 'active' : 'blocked',
      trialUsed: user.trialUsed,
      lastActivityAt: user.updatedAt.toISOString(),
      createdAt: user.createdAt.toISOString(),
      subscription: sub
        ? {
            id: sub.id,
            planId: sub.plan?.id ?? null,
            planName: sub.plan?.name ?? '—',
            tier: sub.plan?.entitlementTier ?? 'free',
            isTrial: sub.isTrial,
            startedAt: sub.startedAt?.toISOString() ?? null,
            expiresAt: sub.expiresAt?.toISOString() ?? null,
          }
        : null,
      paymentsCount: user._count.payments,
      children: user.childrenAsParent.map((c) => ({
        id: c.id,
        name: c.name,
        age: c.age,
        familyCode: c.familyCode,
        isConnected: c.isConnected,
        lastSeenAt: c.lastSeenAt?.toISOString() ?? null,
        avatarUrl: c.photoPath ? this.childAvatarUrl(c.id) : null,
      })),
      childrenCount: user.childrenAsParent.length,
    };
  }

  /**
   * Admin sovg'asi — ota-onaga tanlangan tarifni `days` kun BEPUL beradi.
   *
   * Qoidalar:
   *  - Faol obuna YO'Q bo'lsa: yangi ACTIVE obuna (isTrial=true, hozirdan
   *    N kun). Cron (TrialService) tugashiga 2 kun qolganda eslatadi.
   *  - Faol obuna BOR bo'lsa: muddat N kunga UZAYADI (tugash sanasidan
   *    boshlab), tarif faqat YUQORIROQ darajaga o'zgaradi — pullik Premium
   *    mijozga Standart sovg'a qilinsa tarifi tushmaydi, faqat muddat uzayadi.
   *    Pullik obunaning `isTrial=false` belgisi saqlanadi (aks holda unga
   *    "demo tugadi" push'i ketardi).
   *  - `User.trialUsed` TEGILMAYDI — bu ro'yxatdan o'tish trial'i uchun.
   */
  async grantSubscription(
    id: string,
    dto: GrantSubscriptionDto,
    staff: { sub: string; email?: string },
    req: AdminReqCtx,
  ) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: { id: true, role: true, name: true },
    });
    if (!user) throw new NotFoundException('User not found');
    if (user.role !== 'PARENT') {
      throw new BadRequestException('Obuna faqat ota-ona akkauntiga beriladi');
    }

    const plan = await this.prisma.plan.findUnique({ where: { id: dto.planId } });
    if (!plan || !plan.isActive) {
      throw new BadRequestException('Tarif topilmadi yoki faol emas');
    }
    if (plan.entitlementTier === 'free') {
      throw new BadRequestException("Bepul tarifni sovg'a qilib bo'lmaydi");
    }

    const now = new Date();
    const existing = await this.prisma.subscription.findFirst({
      where: { userId: id, ...activeSubscriptionWhere(now) },
      include: { plan: { select: { name: true, entitlementTier: true } } },
      orderBy: { expiresAt: 'desc' },
    });

    let subscriptionId: string;
    let expiresAt: Date;
    // Amaldagi tarif nomi — pastroq tarif sovg'a qilinsa eski (yuqori) qoladi.
    let effectivePlanName = plan.name;

    if (existing) {
      if (existing.expiresAt === null) {
        // Muddatsiz (lifetime) obuna — uzaytirishning ma'nosi yo'q.
        throw new BadRequestException('Foydalanuvchida muddatsiz obuna bor');
      }
      const base = existing.expiresAt > now ? existing.expiresAt : now;
      expiresAt = new Date(base.getTime() + dto.days * DAY_MS);
      const currentRank =
        TIER_RANK[existing.plan?.entitlementTier ?? 'free'] ?? 0;
      const giftRank = TIER_RANK[plan.entitlementTier] ?? 0;
      const upgrade = giftRank > currentRank;
      if (!upgrade && existing.plan) effectivePlanName = existing.plan.name;
      const updated = await this.prisma.subscription.update({
        where: { id: existing.id },
        data: {
          planId: upgrade ? plan.id : existing.planId,
          status: 'ACTIVE',
          expiresAt,
          // Yangi tugash sanasi — eslatmalar qayta yuborilsin.
          trialReminderSentAt: null,
          trialEndedNotifiedAt: null,
        },
      });
      subscriptionId = updated.id;
    } else {
      expiresAt = new Date(now.getTime() + dto.days * DAY_MS);
      const created = await this.prisma.subscription.create({
        data: {
          userId: id,
          planId: plan.id,
          status: 'ACTIVE',
          startedAt: now,
          expiresAt,
          isTrial: true,
        },
      });
      subscriptionId = created.id;
    }

    void this.audit.log(req, {
      action: 'user.grant_subscription',
      moderatorId: staff.sub,
      email: staff.email,
      resourceType: 'user',
      resourceId: id,
      details: {
        planId: plan.id,
        planName: plan.name,
        effectivePlanName,
        days: dto.days,
        extended: Boolean(existing),
        expiresAt: expiresAt.toISOString(),
        note: dto.note ?? null,
      },
    });

    // Push (best-effort) — ilovada "Sizga N kunlik Premium sovg'a qilindi".
    try {
      const lang = await this.fcm.getUserLang(id);
      await this.fcm.sendPushToUser(id, {
        title: tr(lang, 'giftSubscription.title'),
        body: tr(lang, 'giftSubscription.body', {
          plan: effectivePlanName,
          days: dto.days,
        }),
        data: { type: 'giftSubscription', relatedRoute: '/premium' },
      });
    } catch (err) {
      this.logger.warn(`gift push failed (user=${id}): ${err}`);
    }

    return {
      ok: true,
      subscriptionId,
      planName: effectivePlanName,
      expiresAt: expiresAt.toISOString(),
      extended: Boolean(existing),
    };
  }

  /**
   * Ogohlantirish — foydalanuvchiga push yuboradi. `id` ota-ona (User.id)
   * yoki bola (Child.id) bo'lishi mumkin (ro'yxat ikkalasini aralash beradi):
   * bola uchun push uning qurilma akkauntiga (childUser) + in-app inbox satri.
   */
  async warnUser(
    id: string,
    message: string,
    staff: { sub: string; email?: string },
    req: AdminReqCtx,
  ) {
    const text = message.trim();
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: { id: true, role: true },
    });

    let delivered = 0;
    let target: 'parent' | 'child';

    if (user) {
      target = 'parent';
      const lang = await this.fcm.getUserLang(user.id);
      const r = await this.fcm.sendPushToUser(user.id, {
        title: tr(lang, 'adminWarning.title'),
        body: text,
        data: { type: 'adminWarning' },
      });
      delivered = r.sent;
    } else {
      const child = await this.prisma.child.findUnique({
        where: { id },
        select: { id: true, childUserId: true },
      });
      if (!child) throw new NotFoundException('User not found');
      target = 'child';
      const lang = child.childUserId
        ? await this.fcm.getUserLang(child.childUserId)
        : 'uz';
      const title = tr(lang, 'adminWarning.title');
      // In-app inbox (bola ilovasi bildirishnomalar ro'yxati).
      await this.prisma.notification.create({
        data: { childId: child.id, type: 'SYSTEM', title, body: text },
      });
      if (child.childUserId) {
        const r = await this.fcm.sendPushToUser(child.childUserId, {
          title,
          body: text,
          data: { type: 'adminWarning' },
        });
        delivered = r.sent;
      }
    }

    void this.audit.log(req, {
      action: 'user.warn',
      moderatorId: staff.sub,
      email: staff.email,
      resourceType: target === 'parent' ? 'user' : 'child',
      resourceId: id,
      details: { message: text, delivered },
    });

    return { ok: true, target, delivered };
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

  /**
   * Foydalanuvchini VA UNGA TEGISHLI BARCHA MA'LUMOTNI serverdan butunlay
   * o'chiradi (qaytarib bo'lmaydi).
   *
   * Bitta `user.delete` yetarli — schema'dagi FK'lar `onDelete: Cascade`
   * bo'lgani uchun DB darajasida kaskad o'chadi:
   *   - bolalar (parentId) → ularning app-usage / app-limit / location /
   *     geo-zone / schedule / routine / notification / sos-alert /
   *     gamification (ChildProfile, XpEvent, ChildStepDaily) / olympiad
   *     attempt / installed-apps;
   *   - ovozli + video xabarlar (sender/receiver), foto so'rovlari;
   *   - FCM tokenlar, sessiyalar, session-access so'rovlari;
   *   - to'lov / obuna yozuvlari.
   * Bola-qurilma sifatida ulangan boshqa oilaning `Child.childUserId` esa
   * `onDelete: SetNull` bilan faqat uziladi (o'sha bola ota-onasida qoladi).
   */
  async deleteUser(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: { id: true, name: true, role: true, phone: true, email: true },
    });
    if (!user) throw new NotFoundException('User not found');
    try {
      await this.prisma.user.delete({ where: { id } });
      return { ok: true, deletedId: id };
    } catch (err: any) {
      if (err?.code === 'P2025')
        throw new NotFoundException('User not found');
      throw err;
    }
  }
}
