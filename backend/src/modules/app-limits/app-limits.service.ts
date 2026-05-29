import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
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
  ) {}

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

    try {
      const limit = await this.prisma.appLimit.create({
        data: {
          childId,
          packageName: dto.packageName,
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

      return serialize(limit);
    } catch (e: unknown) {
      if (e && typeof e === 'object' && 'code' in e && (e as { code: string }).code === 'P2002') {
        throw new ConflictException(
          `App limit already exists for package: ${dto.packageName}`,
        );
      }
      throw e;
    }
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
