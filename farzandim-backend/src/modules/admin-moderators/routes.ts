import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { hashPassword } from '../admin-auth/password';
import { staffAuthGuard } from '../../middleware/staff-auth';
import { requirePermission } from '../../middleware/require-permission';
import { ADMIN_ROLE_PRESETS, sanitizePermissions } from '../../lib/admin-permissions';
import { logAudit } from '../../lib/audit-log';

const ROLE_KEYS = ['super_admin', 'finance', 'content_maker', 'support', 'custom'] as const;
const RoleKey = z.enum(ROLE_KEYS);

const ListQuery = z.object({
  q: z.string().trim().optional(),
  role: z.string().trim().optional(),
  status: z.string().trim().optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

const CreateBody = z.object({
  name: z.string().trim().min(1).max(120),
  email: z.string().trim().toLowerCase().email().max(180),
  phone: z.union([z.string().trim().min(4).max(40), z.null()]).optional(),
  moderatorRoleKey: RoleKey,
  permissions: z.array(z.string()).optional(),
  password: z.string().min(8).max(120),
});

const UpdateBody = z.object({
  name: z.string().trim().min(1).max(120).optional(),
  phone: z.union([z.string().trim().max(40), z.null()]).optional(),
  moderatorRoleKey: RoleKey.optional(),
  permissions: z.array(z.string()).optional(),
  password: z.string().min(8).max(120).optional(),
});

function rowOf(m: {
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

export const adminModeratorsRoutes: FastifyPluginAsync = async (fastify) => {
  // Sprint 6 — RBAC: moderatorlarni boshqarish faqat super_admin uchun
  // (permission katalogida moderator-boshqaruv kaliti yo'q).
  fastify.addHook('preHandler', staffAuthGuard);
  fastify.addHook('preHandler', requirePermission());

  fastify.get('/', { preHandler: staffAuthGuard }, async (request, reply) => {
    const parsed = ListQuery.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid query', details: parsed.error.flatten() });
    }
    const { q, role, status, page, limit } = parsed.data;

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
      prisma.moderator.count({ where }),
      prisma.moderator.findMany({
        where,
        orderBy: [{ status: 'asc' }, { lastActivityAt: 'desc' }, { createdAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    const totalPages = Math.max(1, Math.ceil(total / limit));
    return reply.send({
      items: rows.map(rowOf),
      page,
      totalPages,
      total,
      limit,
    });
  });

  fastify.get('/:id', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const m = await prisma.moderator.findUnique({ where: { id } });
    if (!m) return reply.code(404).send({ error: 'Moderator not found' });
    return reply.send(rowOf(m));
  });

  fastify.post('/', { preHandler: staffAuthGuard }, async (request, reply) => {
    const parsed = CreateBody.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid body', details: parsed.error.flatten() });
    }
    const data = parsed.data;
    const existing = await prisma.moderator.findUnique({ where: { email: data.email } });
    if (existing) {
      return reply.code(409).send({ error: 'Moderator with this email already exists' });
    }
    const explicit = sanitizePermissions(data.permissions ?? []);
    const permissions =
      explicit.length > 0 ? explicit : sanitizePermissions(ADMIN_ROLE_PRESETS[data.moderatorRoleKey] ?? []);

    const created = await prisma.moderator.create({
      data: {
        name: data.name,
        email: data.email,
        phone: data.phone?.trim() || null,
        moderatorRoleKey: data.moderatorRoleKey,
        permissions,
        passwordHash: await hashPassword(data.password),
        status: 'active',
      },
    });
    void logAudit(request, {
      action: 'moderator.create',
      moderatorId: request.staff?.sub ?? null,
      email: request.staff?.email ?? null,
      resourceType: 'moderator',
      resourceId: created.id,
      details: { targetEmail: created.email, role: created.moderatorRoleKey },
    });
    return reply.code(201).send(rowOf(created));
  });

  fastify.patch('/:id', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const parsed = UpdateBody.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid body', details: parsed.error.flatten() });
    }
    const data = parsed.data;
    const updates: Prisma.ModeratorUpdateInput = {};
    if (data.name !== undefined) updates.name = data.name;
    if (data.phone !== undefined) updates.phone = data.phone?.trim() || null;
    if (data.moderatorRoleKey !== undefined) updates.moderatorRoleKey = data.moderatorRoleKey;
    if (data.permissions !== undefined) updates.permissions = sanitizePermissions(data.permissions);
    if (data.password !== undefined) updates.passwordHash = await hashPassword(data.password);

    try {
      const updated = await prisma.moderator.update({ where: { id }, data: updates });
      void logAudit(request, {
        action: 'moderator.update',
        moderatorId: request.staff?.sub ?? null,
        email: request.staff?.email ?? null,
        resourceType: 'moderator',
        resourceId: id,
        details: { targetEmail: updated.email, fields: Object.keys(updates) },
      });
      return reply.send(rowOf(updated));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Moderator not found' });
      }
      throw err;
    }
  });

  fastify.post('/:id/block', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      const m = await prisma.moderator.update({ where: { id }, data: { status: 'blocked' } });
      void logAudit(request, {
        action: 'moderator.block',
        moderatorId: request.staff?.sub ?? null,
        email: request.staff?.email ?? null,
        resourceType: 'moderator',
        resourceId: id,
        details: { targetEmail: m.email },
      });
      return reply.send(rowOf(m));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Moderator not found' });
      }
      throw err;
    }
  });

  fastify.post('/:id/unblock', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      const m = await prisma.moderator.update({ where: { id }, data: { status: 'active' } });
      void logAudit(request, {
        action: 'moderator.unblock',
        moderatorId: request.staff?.sub ?? null,
        email: request.staff?.email ?? null,
        resourceType: 'moderator',
        resourceId: id,
        details: { targetEmail: m.email },
      });
      return reply.send(rowOf(m));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Moderator not found' });
      }
      throw err;
    }
  });

  fastify.delete('/:id', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      const target = await prisma.moderator.findUnique({ where: { id }, select: { email: true } });
      await prisma.moderator.delete({ where: { id } });
      void logAudit(request, {
        action: 'moderator.delete',
        moderatorId: request.staff?.sub ?? null,
        email: request.staff?.email ?? null,
        resourceType: 'moderator',
        resourceId: id,
        details: { targetEmail: target?.email ?? null },
      });
      return reply.code(204).send();
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Moderator not found' });
      }
      throw err;
    }
  });
};
