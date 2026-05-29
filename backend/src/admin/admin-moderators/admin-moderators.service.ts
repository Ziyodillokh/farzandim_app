import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { AdminAuditService } from '../../common/audit/admin-audit.service';
import { hashPassword } from '../admin-auth/helpers/password';
import { CreateModeratorDto } from './dto/create-moderator.dto';
import { UpdateModeratorDto } from './dto/update-moderator.dto';
import { ROLE_PRESETS, sanitizePermissions } from './constants/permissions';

interface RequestMeta {
  ip?: string;
  headers?: Record<string, string | string[] | undefined>;
}

@Injectable()
export class AdminModeratorsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AdminAuditService,
  ) {}

  private rowOf(m: {
    id: string;
    name: string;
    email: string;
    phone: string | null;
    moderatorRoleKey: string;
    permissions: string[];
    status: string;
    lastActivityAt: Date | null;
    createdAt: Date;
  }) {
    return {
      id: m.id,
      name: m.name,
      email: m.email,
      phone: m.phone,
      moderatorRoleKey: m.moderatorRoleKey,
      permissions: m.permissions,
      status: m.status,
      lastActivityAt: m.lastActivityAt?.toISOString() ?? null,
      createdAt: m.createdAt.toISOString(),
    };
  }

  async list(query: {
    q?: string;
    role?: string;
    status?: string;
    page: number;
    limit: number;
  }) {
    const { q, role, status, page, limit } = query;
    const where: Prisma.ModeratorWhereInput = {};
    if (role) where.moderatorRoleKey = role;
    if (status === 'active' || status === 'blocked') where.status = status;
    if (q && q.length > 0) {
      where.OR = [
        { name: { contains: q, mode: 'insensitive' } },
        { email: { contains: q, mode: 'insensitive' } },
        { phone: { contains: q, mode: 'insensitive' } },
      ];
    }

    const [total, rows] = await Promise.all([
      this.prisma.moderator.count({ where }),
      this.prisma.moderator.findMany({
        where,
        orderBy: [
          { status: 'asc' },
          { lastActivityAt: 'desc' },
          { createdAt: 'desc' },
        ],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    return {
      items: rows.map((r) => this.rowOf(r)),
      page,
      totalPages: Math.max(1, Math.ceil(total / limit)),
      total,
      limit,
    };
  }

  async findOne(id: string) {
    const m = await this.prisma.moderator.findUnique({ where: { id } });
    if (!m) throw new NotFoundException('Moderator not found');
    return this.rowOf(m);
  }

  async create(
    dto: CreateModeratorDto,
    staffId: string,
    staffEmail: string,
    req: RequestMeta,
  ) {
    const existing = await this.prisma.moderator.findUnique({
      where: { email: dto.email },
    });
    if (existing) {
      throw new ConflictException('Moderator with this email already exists');
    }

    const explicit = sanitizePermissions(dto.permissions ?? []);
    const permissions =
      explicit.length > 0
        ? explicit
        : sanitizePermissions([
            ...(ROLE_PRESETS[dto.moderatorRoleKey] ?? []),
          ]);

    const created = await this.prisma.moderator.create({
      data: {
        name: dto.name,
        email: dto.email,
        phone: dto.phone?.trim() || null,
        moderatorRoleKey: dto.moderatorRoleKey,
        permissions,
        passwordHash: await hashPassword(dto.password),
        status: 'active',
      },
    });

    void this.audit.log(req, {
      action: 'moderator.create',
      moderatorId: staffId,
      email: staffEmail,
      resourceType: 'moderator',
      resourceId: created.id,
      details: { targetEmail: created.email, role: created.moderatorRoleKey },
    });

    return this.rowOf(created);
  }

  async update(
    id: string,
    dto: UpdateModeratorDto,
    staffId: string,
    staffEmail: string,
    req: RequestMeta,
  ) {
    const updates: Prisma.ModeratorUpdateInput = {};
    if (dto.name !== undefined) updates.name = dto.name;
    if (dto.phone !== undefined) updates.phone = dto.phone?.trim() || null;
    if (dto.moderatorRoleKey !== undefined)
      updates.moderatorRoleKey = dto.moderatorRoleKey;
    if (dto.permissions !== undefined)
      updates.permissions = sanitizePermissions(dto.permissions);
    if (dto.password !== undefined)
      updates.passwordHash = await hashPassword(dto.password);

    try {
      const updated = await this.prisma.moderator.update({
        where: { id },
        data: updates,
      });

      void this.audit.log(req, {
        action: 'moderator.update',
        moderatorId: staffId,
        email: staffEmail,
        resourceType: 'moderator',
        resourceId: id,
        details: {
          targetEmail: updated.email,
          fields: Object.keys(updates),
        },
      });

      return this.rowOf(updated);
    } catch (err: any) {
      if (err?.code === 'P2025')
        throw new NotFoundException('Moderator not found');
      throw err;
    }
  }

  async block(
    id: string,
    staffId: string,
    staffEmail: string,
    req: RequestMeta,
  ) {
    try {
      const m = await this.prisma.moderator.update({
        where: { id },
        data: { status: 'blocked' },
      });

      void this.audit.log(req, {
        action: 'moderator.block',
        moderatorId: staffId,
        email: staffEmail,
        resourceType: 'moderator',
        resourceId: id,
        details: { targetEmail: m.email },
      });

      return this.rowOf(m);
    } catch (err: any) {
      if (err?.code === 'P2025')
        throw new NotFoundException('Moderator not found');
      throw err;
    }
  }

  async unblock(
    id: string,
    staffId: string,
    staffEmail: string,
    req: RequestMeta,
  ) {
    try {
      const m = await this.prisma.moderator.update({
        where: { id },
        data: { status: 'active' },
      });

      void this.audit.log(req, {
        action: 'moderator.unblock',
        moderatorId: staffId,
        email: staffEmail,
        resourceType: 'moderator',
        resourceId: id,
        details: { targetEmail: m.email },
      });

      return this.rowOf(m);
    } catch (err: any) {
      if (err?.code === 'P2025')
        throw new NotFoundException('Moderator not found');
      throw err;
    }
  }

  async remove(
    id: string,
    staffId: string,
    staffEmail: string,
    req: RequestMeta,
  ) {
    try {
      const target = await this.prisma.moderator.findUnique({
        where: { id },
        select: { email: true },
      });
      await this.prisma.moderator.delete({ where: { id } });

      void this.audit.log(req, {
        action: 'moderator.delete',
        moderatorId: staffId,
        email: staffEmail,
        resourceType: 'moderator',
        resourceId: id,
        details: { targetEmail: target?.email ?? null },
      });

      return { ok: true };
    } catch (err: any) {
      if (err?.code === 'P2025')
        throw new NotFoundException('Moderator not found');
      throw err;
    }
  }

  async resetPassword(
    id: string,
    newPassword: string,
    staffId: string,
    staffEmail: string,
    req: RequestMeta,
  ) {
    try {
      const m = await this.prisma.moderator.update({
        where: { id },
        data: { passwordHash: await hashPassword(newPassword) },
      });

      void this.audit.log(req, {
        action: 'moderator.reset_password',
        moderatorId: staffId,
        email: staffEmail,
        resourceType: 'moderator',
        resourceId: id,
        details: { targetEmail: m.email },
      });

      return { ok: true };
    } catch (err: any) {
      if (err?.code === 'P2025')
        throw new NotFoundException('Moderator not found');
      throw err;
    }
  }
}
