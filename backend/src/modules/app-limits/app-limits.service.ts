import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { FcmService } from '../../common/fcm/fcm.service';
import { CreateAppLimitDto } from './dto/create-app-limit.dto';
import { UpdateAppLimitDto } from './dto/update-app-limit.dto';
import {
  APP_CATEGORIES,
  categoryLabel,
  classifyPackage,
} from '../installed-apps/app-category.util';

const MAX_DAY_MS = 24 * 60 * 60 * 1000; // 86_400_000
const MAX_WEEK_MS = 7 * MAX_DAY_MS;

function parseBigInt(value: number | string | undefined | null): bigint | undefined | null {
  if (value === undefined) return undefined;
  if (value === null) return null;
  return typeof value === 'string' ? BigInt(value) : BigInt(value);
}

function serialize(limit: {
  id: string;
  childId: string;
  packageName: string;
  dailyLimitMs: bigint;
  weeklyLimitMs: bigint | null;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    ...limit,
    dailyLimitMs: Number(limit.dailyLimitMs),
    weeklyLimitMs:
      limit.weeklyLimitMs === null ? null : Number(limit.weeklyLimitMs),
  };
}

function validateLimits(
  dailyMs: bigint,
  weeklyMs?: bigint | null,
): string | null {
  if (dailyMs < 0n || dailyMs > BigInt(MAX_DAY_MS)) {
    return `dailyLimitMs must be 0..${MAX_DAY_MS} (1 day)`;
  }
  if (weeklyMs !== undefined && weeklyMs !== null) {
    if (weeklyMs < 0n || weeklyMs > BigInt(MAX_WEEK_MS)) {
      return `weeklyLimitMs must be 0..${MAX_WEEK_MS} (1 week)`;
    }
    if (weeklyMs < dailyMs) {
      return 'weeklyLimitMs cannot be less than dailyLimitMs';
    }
  }
  return null;
}

@Injectable()
export class AppLimitsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly realtime: RealtimeGateway,
    private readonly fcm: FcmService,
  ) {}

  /** ms → "2 soat" / "30 daqiqa" / "2 soat 15 daqiqa". */
  private formatDuration(ms: number): string {
    const min = Math.round(ms / 60000);
    if (min < 60) return `${min} daqiqa`;
    const h = Math.floor(min / 60);
    const m = min % 60;
    return m === 0 ? `${h} soat` : `${h} soat ${m} daqiqa`;
  }

  /**
   * Cheklov o'zgartirilganda akkauntning BOSHQA qurilmalariga (bir xil
   * ota-ona hisobida 2-qurilma — masalan ona telefoni) push yuboradi.
   * `sendPushToUser` user'ning barcha qurilma tokenlariga boradi; xato
   * bo'lsa asosiy oqim buzilmaydi (fire-and-forget + try/catch).
   */
  private async notifyOtherDevices(
    child: { id: string; parentId: string },
    packageName: string,
    dailyLimitMs: bigint,
    isActive: boolean,
  ): Promise<void> {
    try {
      const installed = await this.prisma.installedApp.findFirst({
        where: { childId: child.id, packageName },
        select: { appName: true },
      });
      const appLabel = installed?.appName ?? packageName;
      const ms = Number(dailyLimitMs);
      const limitText = !isActive
        ? "o'chirildi"
        : ms <= 0
          ? 'cheksiz qilindi'
          : `${this.formatDuration(ms)} qilindi`;
      await this.fcm.sendPushToUser(child.parentId, {
        title: "Cheklov o'zgartirildi",
        body: `${appLabel}: kunlik ${limitText}`,
        data: {
          type: 'app_limit',
          childId: child.id,
          packageName,
        },
      });
    } catch {
      // push xatosi cheklov saqlanishiga ta'sir qilmaydi
    }
  }

  /**
   * Bola qurilmasiga "darhol qayta sync qil" silent data-push (#15). WS faqat
   * foreground'da ishlaydi; bu fon/yopiq holatda ham blokni bir necha
   * soniyada kuchga kiritadi (RestrictionsSyncService darhol sync qiladi).
   * childUserId yo'q yoki push xatosi — jim (limit baribir DB'da saqlangan,
   * 30s davriy sync baribir oladi).
   */
  private async pushChildResync(child: {
    childUserId: string | null;
  }): Promise<void> {
    if (!child.childUserId) return;
    try {
      await this.fcm.sendPushToUser(child.childUserId, {
        title: '',
        body: '',
        dataOnly: true,
        data: { type: 'restrictions_sync' },
      });
    } catch {
      /* push xatosi limitга ta'sir qilmaydi */
    }
  }

  async findOne(id: string, userId: string) {
    const limit = await this.prisma.appLimit.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!limit) throw new NotFoundException('App limit not found');
    if (limit.child.parentId !== userId && limit.child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const { child: _omit, ...rest } = limit;
    return serialize(rest);
  }

  async list(childId: string, userId: string, isActiveFilter?: string) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const limits = await this.prisma.appLimit.findMany({
      where: {
        childId,
        ...(isActiveFilter !== undefined && {
          isActive: isActiveFilter === 'true',
        }),
      },
      orderBy: { packageName: 'asc' },
    });

    const serialized = limits.map(serialize);

    // BOLA qurilmasi so'raganда — amal qilayotgan "qo'shimcha vaqt" grant'larini
    // kunlik limitga qo'shamiz (vaqtincha). Ota-ona ko'rinishi o'zgarmaydi
    // (u sozlangan asl limitni ko'radi). Bloklangan (dailyLimitMs=0) ilova
    // grant tufayli vaqtli limitga aylanadi → grant tugaguncha ochiladi.
    const isChild = child.childUserId === userId;
    let effective = serialized;
    if (isChild) {
      // 1) Kategoriya bloklari → bloklangan kategoriyadagi o'rnatilgan
      //    ilovalarni sintetik blok (dailyLimitMs=0) sifatida qo'shamiz (#14).
      effective = await this.applyCategoryBlocks(childId, effective);
      // 2) Unlock grant daqiqalari → mos paket limitiga qo'shiladi (grant
      //    kategoriya blokidan ustun: bloklangan ilova vaqtincha ochiladi).
      effective = await this.applyActiveGrants(childId, effective);
    }

    return { limits: effective, count: effective.length };
  }

  /**
   * Bloklangan kategoriyalardagi o'rnatilgan ilovalarni sintetik blok
   * (dailyLimitMs=0) sifatida qaytaradi (#14). Allaqachon aniq limit/blok
   * bo'lgan paketlarga tegmaydi. DINAMIK — yangi o'rnatilgan ilova ham
   * keyingi sync'da avtomatik qamrab olinadi.
   */
  private async applyCategoryBlocks(
    childId: string,
    limits: ReturnType<typeof serialize>[],
  ): Promise<ReturnType<typeof serialize>[]> {
    const blocks = await this.prisma.categoryBlock.findMany({
      where: { childId },
      select: { category: true },
    });
    if (blocks.length === 0) return limits;
    const blockedCats = new Set(blocks.map((b) => b.category));

    const apps = await this.prisma.installedApp.findMany({
      where: { childId },
      select: { packageName: true, category: true },
    });
    const existing = new Set(limits.map((l) => l.packageName));
    const now = new Date();
    const out = [...limits];
    for (const app of apps) {
      if (existing.has(app.packageName)) continue;
      // Saqlangan kategoriya bo'lmasa (eski yozuv) — paketdan klassifikatsiya.
      const cat = app.category ?? classifyPackage(app.packageName);
      if (!blockedCats.has(cat)) continue;
      existing.add(app.packageName);
      out.push({
        id: `cat:${app.packageName}`,
        childId,
        packageName: app.packageName,
        dailyLimitMs: 0,
        weeklyLimitMs: null,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      });
    }
    return out;
  }

  /**
   * APPROVED + hali tugamagan APP grant'larini mos paket limitiga qo'shadi.
   * Limit yozuvi bo'lmagan (faqat grant berilgan) paket uchun sintetik vaqtli
   * limit qo'shadi. Kunlik shiftdan oshmaydi (MAX_DAY_MS).
   */
  private async applyActiveGrants(
    childId: string,
    limits: ReturnType<typeof serialize>[],
  ): Promise<ReturnType<typeof serialize>[]> {
    const now = new Date();
    const grants = await this.prisma.unlockRequest.findMany({
      where: {
        childId,
        kind: 'APP',
        status: 'APPROVED',
        expiresAt: { gt: now },
        packageName: { not: null },
      },
      select: { packageName: true, grantedMinutes: true },
    });
    if (grants.length === 0) return limits;

    // Paket bo'yicha jami grant ms (bir paketga bir nechta grant bo'lsa qo'shiladi).
    const bonusMs = new Map<string, number>();
    for (const g of grants) {
      if (!g.packageName || !g.grantedMinutes) continue;
      bonusMs.set(
        g.packageName,
        (bonusMs.get(g.packageName) ?? 0) + g.grantedMinutes * 60_000,
      );
    }

    const out = limits.map((l) => {
      const bonus = bonusMs.get(l.packageName);
      if (!bonus) return l;
      bonusMs.delete(l.packageName);
      return {
        ...l,
        dailyLimitMs: Math.min(MAX_DAY_MS, l.dailyLimitMs + bonus),
      };
    });

    // Limit yozuvi yo'q, lekin grant bor paketlar — sintetik vaqtli limit.
    for (const [packageName, bonus] of bonusMs) {
      out.push({
        id: `grant:${packageName}`,
        childId,
        packageName,
        dailyLimitMs: Math.min(MAX_DAY_MS, bonus),
        weeklyLimitMs: null,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      });
    }
    return out;
  }

  async create(
    childId: string,
    userId: string,
    dto: CreateAppLimitDto,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId) {
      throw new ForbiddenException('Only parent can create app limits');
    }

    const dailyLimitMs = parseBigInt(dto.dailyLimitMs)!;
    const weeklyLimitMs = parseBigInt(dto.weeklyLimitMs) ?? null;

    const err = validateLimits(dailyLimitMs, weeklyLimitMs);
    if (err) throw new BadRequestException(err);

    // Idempotent upsert — (childId, packageName) unique. Cheklov allaqachon
    // mavjud bo'lsa yangilaymiz (409 Conflict bermaymiz). Mobil klient
    // ba'zan GET muvaffaqiyatsiz bo'lganda noto'g'ri POST qiladi — bu
    // doim xavfsiz ishlashini kafolatlaydi.
    const limit = await this.prisma.appLimit.upsert({
      where: {
        childId_packageName: { childId, packageName: dto.packageName },
      },
      create: {
        childId,
        packageName: dto.packageName,
        dailyLimitMs,
        weeklyLimitMs,
        isActive: dto.isActive ?? true,
      },
      update: {
        dailyLimitMs,
        weeklyLimitMs,
        isActive: dto.isActive ?? true,
      },
    });

    await this.audit.log(
      userId,
      'app_limit',
      'CREATE',
      limit.id,
      { packageName: limit.packageName },
      request,
    );
    this.realtime.emitToChild(childId, 'app_limit:created', serialize(limit));
    void this.notifyOtherDevices(
      child,
      limit.packageName,
      limit.dailyLimitMs,
      limit.isActive,
    );
    void this.pushChildResync(child);

    return serialize(limit);
  }

  async update(
    id: string,
    userId: string,
    dto: UpdateAppLimitDto,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const limit = await this.prisma.appLimit.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!limit) throw new NotFoundException('App limit not found');
    if (limit.child.parentId !== userId) {
      throw new ForbiddenException('Only parent can update');
    }

    const nextDaily =
      dto.dailyLimitMs !== undefined
        ? parseBigInt(dto.dailyLimitMs)!
        : limit.dailyLimitMs;
    const nextWeekly =
      dto.weeklyLimitMs === undefined
        ? limit.weeklyLimitMs
        : parseBigInt(dto.weeklyLimitMs) ?? null;

    const err = validateLimits(nextDaily, nextWeekly);
    if (err) throw new BadRequestException(err);

    const updated = await this.prisma.appLimit.update({
      where: { id },
      data: {
        ...(dto.dailyLimitMs !== undefined && {
          dailyLimitMs: parseBigInt(dto.dailyLimitMs)!,
        }),
        ...(dto.weeklyLimitMs !== undefined && {
          weeklyLimitMs: parseBigInt(dto.weeklyLimitMs) ?? null,
        }),
        ...(dto.isActive !== undefined && { isActive: dto.isActive }),
      },
    });

    await this.audit.log(userId, 'app_limit', 'UPDATE', id, dto as object, request);
    this.realtime.emitToChild(
      updated.childId,
      'app_limit:updated',
      serialize(updated),
    );
    void this.notifyOtherDevices(
      limit.child,
      updated.packageName,
      updated.dailyLimitMs,
      updated.isActive,
    );
    void this.pushChildResync(limit.child);

    return serialize(updated);
  }

  async remove(
    id: string,
    userId: string,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const limit = await this.prisma.appLimit.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!limit) throw new NotFoundException('App limit not found');
    if (limit.child.parentId !== userId) {
      throw new ForbiddenException('Only parent can delete');
    }

    const childIdForEmit = limit.childId;
    await this.prisma.appLimit.delete({ where: { id } });
    await this.audit.log(
      userId,
      'app_limit',
      'DELETE',
      id,
      { packageName: limit.packageName },
      request,
    );
    this.realtime.emitToChild(childIdForEmit, 'app_limit:deleted', { id });
    void this.pushChildResync(limit.child);

    return { ok: true };
  }

  /* ------------------------------------------------------------------ */
  /*  #15 — POST /children/:childId/app-limits/block-now                 */
  /* ------------------------------------------------------------------ */

  /**
   * Darhol bloklash — ilovani to'liq blok (dailyLimitMs=0) qiladi va bolaga
   * silent resync push yuboradi (fon'da ham ~bir necha soniyada kuchga kiradi,
   * davriy sync kutilmaydi). Ota-ona uchun.
   */
  async blockNow(
    childId: string,
    userId: string,
    packageName: string,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId) {
      throw new ForbiddenException('Only parent can block');
    }

    const limit = await this.prisma.appLimit.upsert({
      where: { childId_packageName: { childId, packageName } },
      create: { childId, packageName, dailyLimitMs: 0n, isActive: true },
      update: { dailyLimitMs: 0n, isActive: true },
    });

    await this.audit.log(
      userId,
      'app_limit',
      'BLOCK_NOW',
      limit.id,
      { packageName },
      request,
    );
    this.realtime.emitToChild(childId, 'app_limit:updated', serialize(limit));
    void this.pushChildResync(child);

    return serialize(limit);
  }

  /* ------------------------------------------------------------------ */
  /*  #14 — Kategoriya bloklash                                          */
  /* ------------------------------------------------------------------ */

  /** Bola/ota-ona: kategoriyalar holati (ilova soni + bloklanganmi). */
  async listCategories(childId: string, userId: string) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const [apps, blocks] = await Promise.all([
      this.prisma.installedApp.findMany({
        where: { childId, isSystem: false },
        select: { packageName: true, category: true },
      }),
      this.prisma.categoryBlock.findMany({
        where: { childId },
        select: { category: true },
      }),
    ]);
    const blocked = new Set(blocks.map((b) => b.category));
    const counts = new Map<string, number>();
    for (const a of apps) {
      const cat = a.category ?? classifyPackage(a.packageName);
      counts.set(cat, (counts.get(cat) ?? 0) + 1);
    }

    return {
      categories: APP_CATEGORIES.map((category) => ({
        category,
        label: categoryLabel(category),
        appCount: counts.get(category) ?? 0,
        blocked: blocked.has(category),
      })),
    };
  }

  /** Ota-ona: kategoriyani bloklaydi yoki blokdan chiqaradi. */
  async toggleCategory(
    childId: string,
    userId: string,
    category: string,
    block: boolean,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId) {
      throw new ForbiddenException('Only parent can block categories');
    }

    if (block) {
      await this.prisma.categoryBlock.upsert({
        where: { childId_category: { childId, category } },
        create: { childId, category },
        update: {},
      });
    } else {
      await this.prisma.categoryBlock
        .delete({ where: { childId_category: { childId, category } } })
        .catch(() => {
          /* allaqachon yo'q — idempotent */
        });
    }

    await this.audit.log(
      userId,
      'category_block',
      block ? 'BLOCK' : 'UNBLOCK',
      childId,
      { category },
      request,
    );
    // Bola limit ro'yxati (augmentatsiya) o'zgardi → darhol sync.
    this.realtime.emitToChild(childId, 'app_limit:updated', { category, block });
    void this.pushChildResync(child);

    return this.listCategories(childId, userId);
  }
}
