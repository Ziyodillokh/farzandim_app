import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';

@Injectable()
export class AdminAuditLogService {
  constructor(private readonly prisma: PrismaService) {}

  private rowOf(log: {
    id: string;
    moderatorId: string | null;
    email: string | null;
    action: string;
    resourceType: string | null;
    resourceId: string | null;
    status: string;
    ipAddress: string | null;
    userAgent: string | null;
    details: Prisma.JsonValue | null;
    createdAt: Date;
  }) {
    return {
      id: log.id,
      moderatorId: log.moderatorId,
      email: log.email,
      action: log.action,
      resourceType: log.resourceType,
      resourceId: log.resourceId,
      status: log.status,
      ipAddress: log.ipAddress,
      userAgent: log.userAgent,
      details: log.details,
      createdAt: log.createdAt.toISOString(),
    };
  }

  async list(query: {
    page: number;
    limit: number;
    moderatorId?: string;
    action?: string;
    resourceType?: string;
    resourceId?: string;
    status?: string;
    from?: string;
    to?: string;
  }) {
    const {
      page,
      limit,
      moderatorId,
      action,
      resourceType,
      resourceId,
      status,
      from,
      to,
    } = query;

    const where: Prisma.ModeratorAuditLogWhereInput = {};
    if (moderatorId) where.moderatorId = moderatorId;
    if (action) where.action = { contains: action, mode: 'insensitive' };
    if (resourceType) where.resourceType = resourceType;
    if (resourceId) where.resourceId = resourceId;
    if (status) where.status = status;
    if (from || to) {
      where.createdAt = {};
      if (from) where.createdAt.gte = new Date(from);
      if (to) where.createdAt.lte = new Date(to);
    }

    const [total, rows] = await Promise.all([
      this.prisma.moderatorAuditLog.count({ where }),
      this.prisma.moderatorAuditLog.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    return {
      items: rows.map((r) => this.rowOf(r)),
      pagination: {
        page,
        totalPages: Math.max(1, Math.ceil(total / limit)),
        total,
        limit,
      },
    };
  }

  async getActions(): Promise<{ actions: string[] }> {
    const rows = await this.prisma.$queryRaw<Array<{ action: string }>>`
      SELECT DISTINCT action FROM moderator_audit_logs ORDER BY action
    `;
    return { actions: rows.map((r) => r.action) };
  }
}
