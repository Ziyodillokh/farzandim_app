import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { BatchUpsertUsageDto } from './dto/batch-upsert-usage.dto';
import { ListAppUsageDto } from './dto/list-app-usage.dto';

@Injectable()
export class AppUsageService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  private async validateChildAccess(childId: string, userId: string) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }
    return child;
  }

  async batchUpsert(
    childId: string,
    userId: string,
    dto: BatchUpsertUsageDto,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    await this.validateChildAccess(childId, userId);

    const ops = dto.entries.map((entry) => {
      const dateObj = new Date(`${entry.date}T00:00:00.000Z`);
      return this.prisma.appUsage.upsert({
        where: {
          childId_packageName_date: {
            childId,
            packageName: entry.packageName,
            date: dateObj,
          },
        },
        update: {
          foregroundMs: BigInt(entry.foregroundMs),
          lastUsedAt: entry.lastUsedAt
            ? new Date(entry.lastUsedAt)
            : undefined,
          openCount: entry.openCount,
        },
        create: {
          childId,
          packageName: entry.packageName,
          date: dateObj,
          foregroundMs: BigInt(entry.foregroundMs),
          lastUsedAt: entry.lastUsedAt
            ? new Date(entry.lastUsedAt)
            : undefined,
          openCount: entry.openCount,
        },
      });
    });

    await this.prisma.$transaction(ops);

    await this.audit.log(
      userId,
      'app_usage',
      'BATCH_UPSERT',
      childId,
      { count: dto.entries.length },
      request,
    );

    return { ok: true, upserted: dto.entries.length };
  }

  async list(childId: string, userId: string, query: ListAppUsageDto) {
    await this.validateChildAccess(childId, userId);

    const { from, to, packageName, limit } = query;

    const usage = await this.prisma.appUsage.findMany({
      where: {
        childId,
        ...(packageName && { packageName }),
        ...(from || to
          ? {
              date: {
                ...(from && { gte: new Date(`${from}T00:00:00.000Z`) }),
                ...(to && { lte: new Date(`${to}T00:00:00.000Z`) }),
              },
            }
          : {}),
      },
      orderBy: [{ date: 'desc' }, { foregroundMs: 'desc' }],
      take: limit,
    });

    // BigInt -> number for JSON serialization
    const serialized = usage.map((u) => ({
      ...u,
      foregroundMs: Number(u.foregroundMs),
    }));

    return { usage: serialized, count: serialized.length };
  }

  async weekly(childId: string, userId: string) {
    await this.validateChildAccess(childId, userId);

    const today = new Date();
    const dayKeys: string[] = [];
    for (let i = 6; i >= 0; i -= 1) {
      const d = new Date(
        Date.UTC(
          today.getUTCFullYear(),
          today.getUTCMonth(),
          today.getUTCDate() - i,
        ),
      );
      dayKeys.push(d.toISOString().slice(0, 10));
    }
    const fromDate = new Date(`${dayKeys[0]}T00:00:00.000Z`);

    const rows = await this.prisma.appUsage.findMany({
      where: { childId, date: { gte: fromDate } },
      select: { date: true, foregroundMs: true },
    });

    const totalsByDay = new Map<string, number>();
    for (const key of dayKeys) totalsByDay.set(key, 0);
    for (const row of rows) {
      const key = row.date.toISOString().slice(0, 10);
      if (totalsByDay.has(key)) {
        totalsByDay.set(
          key,
          (totalsByDay.get(key) ?? 0) + Number(row.foregroundMs),
        );
      }
    }

    const days = dayKeys.map((date) => {
      const totalMs = totalsByDay.get(date) ?? 0;
      return { date, totalMs, totalMinutes: Math.round(totalMs / 60000) };
    });
    const weekTotalMs = days.reduce((sum, d) => sum + d.totalMs, 0);

    return {
      days,
      weekTotalMs,
      weekTotalMinutes: Math.round(weekTotalMs / 60000),
    };
  }
}
