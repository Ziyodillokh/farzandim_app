import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { staffAuthGuard } from '../../middleware/staff-auth';
import { requirePermission } from '../../middleware/require-permission';
import { CONTENT_KINDS } from '../../lib/content-helpers';

const ListQuery = z.object({
  kind: z.enum(CONTENT_KINDS).optional(),
});

const CreateBody = z.object({
  kind: z.enum(CONTENT_KINDS),
  slug: z.string().trim().min(1).max(64).regex(/^[a-z0-9-]+$/, 'lowercase, digits, hyphens'),
  name: z.string().trim().min(1).max(80),
  sortOrder: z.coerce.number().int().optional(),
});

function rowOf(c: {
  id: string;
  kind: string;
  slug: string;
  name: string;
  sortOrder: number;
}) {
  return { id: c.id, kind: c.kind, slug: c.slug, name: c.name, sortOrder: c.sortOrder };
}

export const adminCategoriesRoutes: FastifyPluginAsync = async (fastify) => {
  // Sprint 6 — RBAC: modul autentifikatsiyadan o'tadi.
  // C5 fix: ko'rish view_content/edit_content, yozish faqat edit_content.
  fastify.addHook('preHandler', staffAuthGuard);
  const canRead = requirePermission('view_content', 'edit_content');
  const canWrite = requirePermission('edit_content');

  fastify.get('/', { preHandler: canRead }, async (request, reply) => {
    const parsed = ListQuery.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid query', details: parsed.error.flatten() });
    }
    const where: Prisma.ContentCategoryWhereInput = {};
    if (parsed.data.kind) where.kind = parsed.data.kind;
    const rows = await prisma.contentCategory.findMany({
      where,
      orderBy: [{ kind: 'asc' }, { sortOrder: 'asc' }, { name: 'asc' }],
    });
    return reply.send(rows.map(rowOf));
  });

  fastify.post('/', { preHandler: canWrite }, async (request, reply) => {
    const parsed = CreateBody.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid body', details: parsed.error.flatten() });
    }
    const data = parsed.data;
    try {
      const created = await prisma.contentCategory.create({
        data: { kind: data.kind, slug: data.slug, name: data.name, sortOrder: data.sortOrder ?? 0 },
      });
      return reply.code(201).send(rowOf(created));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2002') {
        return reply.code(409).send({ error: 'Category with this kind+slug already exists' });
      }
      throw err;
    }
  });

  fastify.delete('/:id', { preHandler: canWrite }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      await prisma.contentCategory.delete({ where: { id } });
      return reply.code(204).send();
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Category not found' });
      }
      throw err;
    }
  });
};
