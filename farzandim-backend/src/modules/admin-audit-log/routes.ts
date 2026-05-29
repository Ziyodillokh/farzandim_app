import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { staffAuthGuard } from '../../middleware/staff-auth';
import { requirePermission } from '../../middleware/require-permission';

// Sprint 5.x — Audit log read API.
//
// Admin actions allaqachon `audit_logs` jadval'iga yoziladi (lib/audit-log.ts).
// Bu modul shu yozuvlarni filter + paginate qilib qaytaradi.

const ListQuery = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  moderatorId: z.string().trim().optional(),
  action: z.string().trim().optional(),
  resourceType: z.string().trim().optional(),
  resourceId: z.string().trim().optional(),
  status: z.string().trim().optional(),
  // Sana oralig'i (ISO date)
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

function rowOf(log: {
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

export const adminAuditLogRoutes: FastifyPluginAsync = async (fastify) => {
  // Sprint 6 — RBAC: butun modul auth + permission tekshiruvidan o'tadi.
  fastify.addHook('preHandler', staffAuthGuard);
  fastify.addHook('preHandler', requirePermission('view_analytics'));

  /**
   * GET /api/admin/audit-log
   * Filter + paginate. Eng yangilari birinchi.
   */
  fastify.get('/', { preHandler: staffAuthGuard }, async (request, reply) => {
    const parsed = ListQuery.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid query', details: parsed.error.flatten() });
    }
    const { page, limit, moderatorId, action, resourceType, resourceId, status, from, to } = parsed.data;

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
      prisma.moderatorAuditLog.count({ where }),
      prisma.moderatorAuditLog.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    return reply.send({
      items: rows.map(rowOf),
      pagination: {
        page,
        totalPages: Math.max(1, Math.ceil(total / limit)),
        total,
        limit,
      },
    });
  });

  /**
   * GET /api/admin/audit-log/actions
   * Distinct action ro'yxati (filter dropdown uchun).
   */
  fastify.get('/actions', { preHandler: staffAuthGuard }, async (_request, reply) => {
    const rows = await prisma.$queryRaw<Array<{ action: string }>>`
      SELECT DISTINCT action FROM moderator_audit_logs ORDER BY action
    `;
    return reply.send({ actions: rows.map((r) => r.action) });
  });
};
