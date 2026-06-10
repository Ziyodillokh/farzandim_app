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

    return { limits: limits.map(serialize), count: limits.length };
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

    return { ok: true };
  }
}
