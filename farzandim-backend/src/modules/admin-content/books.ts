import { FastifyPluginAsync } from 'fastify';
import multipart from '@fastify/multipart';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { randomUUID } from 'crypto';
import { prisma } from '../../lib/prisma';
import { staffAuthGuard } from '../../middleware/staff-auth';
import { requirePermission } from '../../middleware/require-permission';
import { CONTENT_STATUSES, paginated, PLAN_REQUIRED, PaginationQuery } from '../../lib/content-helpers';
import { BUCKETS, uploadFile, getDownloadUrl, deleteFile } from '../../lib/minio';
import { ALLOWED_PDF_MIMES, ALLOWED_IMAGE_MIMES } from '../../lib/admin-content-upload';

const MAX_PDF_BYTES = 50 * 1024 * 1024; // 50 MB
const MAX_COVER_BYTES = 5 * 1024 * 1024;

const ListQuery = PaginationQuery.extend({
  q: z.string().trim().optional(),
  status: z.string().trim().optional(),
  category: z.string().trim().optional(),
  planRequired: z.string().trim().optional(),
  ageFrom: z.coerce.number().int().optional(),
  ageTo: z.coerce.number().int().optional(),
});

const CreateBody = z.object({
  title: z.string().trim().min(1).max(200),
  author: z.string().trim().min(1).max(150),
  description: z.union([z.string().trim().max(4000), z.null()]).optional(),
  pdfUrl: z.union([z.string().url(), z.null()]).optional(),
  coverUrl: z.union([z.string().url(), z.null()]).optional(),
  pages: z.coerce.number().int().min(0).default(0),
  ageFrom: z.coerce.number().int().min(0).max(25).default(0),
  ageTo: z.coerce.number().int().min(0).max(25).default(18),
  category: z.string().trim().default('school'),
  planRequired: z.enum(PLAN_REQUIRED).default('free'),
  status: z.enum(CONTENT_STATUSES).default('hidden'),
});

const UpdateBody = CreateBody.partial();

// Upload metadata — pdfUrl/coverUrl MinIO'dan keladi, optional.
const UploadMetadata = CreateBody.extend({
  pdfUrl: z.union([z.string().url(), z.null()]).optional(),
  coverUrl: z.union([z.string().url(), z.null()]).optional(),
});

function rowOf(b: {
  id: string;
  title: string;
  author: string;
  description: string | null;
  pdfUrl: string | null;
  coverUrl: string | null;
  pages: number;
  ageFrom: number;
  ageTo: number;
  category: string;
  categoryId: string | null;
  planRequired: string;
  status: string;
  reads: number;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: b.id,
    title: b.title,
    author: b.author,
    description: b.description,
    pdfUrl: b.pdfUrl,
    coverUrl: b.coverUrl,
    pages: b.pages,
    ageFrom: b.ageFrom,
    ageTo: b.ageTo,
    category: b.category,
    categoryId: b.categoryId,
    planRequired: b.planRequired,
    status: b.status,
    reads: b.reads,
    createdAt: b.createdAt.toISOString(),
    updatedAt: b.updatedAt.toISOString(),
  };
}

export const adminBooksRoutes: FastifyPluginAsync = async (fastify) => {
  // Sprint 6 — RBAC: modul autentifikatsiyadan o'tadi.
  // C5 fix: o'qish/yozish ruxsatlari ajratilgan — view_content faqat ko'rish uchun.
  fastify.addHook('preHandler', staffAuthGuard);
  const canView = requirePermission(
    'view_content', 'approve_content', 'reject_content', 'edit_content', 'delete_content',
  );
  const canEdit = requirePermission('edit_content');
  const canApprove = requirePermission('approve_content');
  const canReject = requirePermission('reject_content');
  const canDelete = requirePermission('delete_content');

  await fastify.register(multipart, {
    limits: { fileSize: MAX_PDF_BYTES, files: 2 },
  });

  // Sprint 5.6d — real MinIO multipart upload
  //
  // POST /admin/books/upload
  // FormData:
  //   pdfFile:    PDF file (application/pdf) — max 50 MB
  //   coverFile?: cover image (jpg/png/webp/gif) — max 5 MB
  //   metadata:   JSON {title, author, description?, pages, ageFrom, ageTo,
  //                     category, planRequired, status}
  fastify.post('/upload', { preHandler: canEdit }, async (request, reply) => {
    if (!request.isMultipart()) {
      return reply.code(400).send({ error: 'multipart/form-data required' });
    }

    let pdfBuf: Buffer | null = null;
    let pdfFilename = 'book.pdf';
    let pdfMime = 'application/pdf';
    let coverBuf: Buffer | null = null;
    let coverFilename = 'cover.jpg';
    let coverMime = 'image/jpeg';
    let metadataStr: string | null = null;

    try {
      for await (const part of request.parts()) {
        if (part.type === 'file') {
          const buf = await part.toBuffer();
          if (part.fieldname === 'pdfFile') {
            if (buf.length > MAX_PDF_BYTES) {
              return reply.code(413).send({ error: 'PDF too large', max: MAX_PDF_BYTES });
            }
            if (!ALLOWED_PDF_MIMES.includes(part.mimetype)) {
              return reply.code(415).send({ error: 'Unsupported PDF format', mimetype: part.mimetype });
            }
            pdfBuf = buf;
            pdfFilename = part.filename;
            pdfMime = part.mimetype;
          } else if (part.fieldname === 'coverFile') {
            if (buf.length > MAX_COVER_BYTES) {
              return reply.code(413).send({ error: 'Cover too large', max: MAX_COVER_BYTES });
            }
            if (!ALLOWED_IMAGE_MIMES.includes(part.mimetype)) {
              return reply.code(415).send({ error: 'Unsupported image format', mimetype: part.mimetype });
            }
            coverBuf = buf;
            coverFilename = part.filename;
            coverMime = part.mimetype;
          }
        } else if (part.fieldname === 'metadata') {
          metadataStr = String((part as { value: unknown }).value ?? '');
        }
      }
    } catch (err) {
      fastify.log.error({ err }, 'admin-books/upload: parts iteration failed');
      return reply.code(400).send({ error: 'Failed to parse multipart' });
    }

    if (!pdfBuf) return reply.code(400).send({ error: 'pdfFile field required' });
    if (!metadataStr) return reply.code(400).send({ error: 'metadata field required' });

    let metaRaw: unknown;
    try {
      metaRaw = JSON.parse(metadataStr);
    } catch {
      return reply.code(400).send({ error: 'Invalid metadata JSON' });
    }
    const metaParsed = UploadMetadata.safeParse(metaRaw);
    if (!metaParsed.success) {
      return reply.code(400).send({ error: 'Invalid metadata', details: metaParsed.error.flatten() });
    }
    const meta = metaParsed.data;

    const id = randomUUID();
    const pdfExt = pdfFilename.includes('.') ? '.' + pdfFilename.split('.').pop() : '.pdf';
    const pdfKey = `books/${id}${pdfExt}`;
    try {
      await uploadFile(BUCKETS.contentBooks, pdfKey, pdfBuf, pdfMime);
    } catch (err) {
      fastify.log.error({ err }, 'admin-books/upload: PDF MinIO upload failed');
      return reply.code(500).send({ error: 'PDF storage upload failed' });
    }
    // 6-kunlik signed URL display fallback (consumer endpoint har request'da re-sign).
    const pdfUrl = await getDownloadUrl(BUCKETS.contentBooks, pdfKey, 6 * 86_400);

    let coverUrl: string | null = null;
    let coverStorageKey: string | null = null;
    if (coverBuf) {
      const coverExt = coverFilename.includes('.') ? '.' + coverFilename.split('.').pop() : '.jpg';
      const coverKey = `covers/${id}${coverExt}`;
      try {
        await uploadFile(BUCKETS.contentThumbnails, coverKey, coverBuf, coverMime);
        coverUrl = await getDownloadUrl(BUCKETS.contentThumbnails, coverKey, 6 * 86_400);
        coverStorageKey = coverKey;
      } catch (err) {
        fastify.log.warn({ err }, 'admin-books/upload: cover upload failed (continuing)');
      }
    }

    const created = await prisma.book.create({
      data: {
        title: meta.title,
        author: meta.author,
        description: meta.description ?? null,
        pdfUrl,
        coverUrl: coverUrl ?? meta.coverUrl ?? null,
        storageKey: pdfKey,
        thumbStorageKey: coverStorageKey,
        pages: meta.pages,
        ageFrom: meta.ageFrom,
        ageTo: meta.ageTo,
        category: meta.category,
        planRequired: meta.planRequired,
        status: meta.status,
      },
    });

    return reply.code(201).send({
      ...rowOf(created),
      storage: { pdfKey, bucket: BUCKETS.contentBooks, sizeBytes: pdfBuf.length },
    });
  });

  fastify.get('/', { preHandler: canView }, async (request, reply) => {
    const parsed = ListQuery.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid query', details: parsed.error.flatten() });
    }
    const { page, limit, q, status, category, planRequired, ageFrom, ageTo } = parsed.data;
    const where: Prisma.BookWhereInput = {};
    if (status && (CONTENT_STATUSES as readonly string[]).includes(status)) where.status = status;
    if (category) where.category = category;
    if (planRequired && (PLAN_REQUIRED as readonly string[]).includes(planRequired)) where.planRequired = planRequired;
    if (ageFrom !== undefined) where.ageTo = { gte: ageFrom };
    if (ageTo !== undefined) where.ageFrom = { lte: ageTo };
    if (q && q.trim().length > 0) {
      where.OR = [
        { title: { contains: q.trim(), mode: 'insensitive' } },
        { author: { contains: q.trim(), mode: 'insensitive' } },
      ];
    }
    const [total, rows] = await Promise.all([
      prisma.book.count({ where }),
      prisma.book.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return reply.send(paginated(rows.map(rowOf), page, limit, total));
  });

  fastify.post('/create', { preHandler: canEdit }, async (request, reply) => {
    const parsed = CreateBody.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid body', details: parsed.error.flatten() });
    }
    const data = parsed.data;
    const created = await prisma.book.create({
      data: {
        title: data.title,
        author: data.author,
        description: data.description ?? null,
        pdfUrl: data.pdfUrl ?? null,
        coverUrl: data.coverUrl ?? null,
        pages: data.pages,
        ageFrom: data.ageFrom,
        ageTo: data.ageTo,
        category: data.category,
        planRequired: data.planRequired,
        status: data.status,
      },
    });
    return reply.code(201).send(rowOf(created));
  });

  fastify.patch('/:id', { preHandler: canEdit }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const parsed = UpdateBody.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid body', details: parsed.error.flatten() });
    }
    const data = parsed.data;
    const updates: Prisma.BookUpdateInput = {};
    if (data.title !== undefined) updates.title = data.title;
    if (data.author !== undefined) updates.author = data.author;
    if (data.description !== undefined) updates.description = data.description ?? null;
    if (data.pdfUrl !== undefined) updates.pdfUrl = data.pdfUrl ?? null;
    if (data.coverUrl !== undefined) updates.coverUrl = data.coverUrl ?? null;
    if (data.pages !== undefined) updates.pages = data.pages;
    if (data.ageFrom !== undefined) updates.ageFrom = data.ageFrom;
    if (data.ageTo !== undefined) updates.ageTo = data.ageTo;
    if (data.category !== undefined) updates.category = data.category;
    if (data.planRequired !== undefined) updates.planRequired = data.planRequired;
    if (data.status !== undefined) updates.status = data.status;
    try {
      const updated = await prisma.book.update({ where: { id }, data: updates });
      return reply.send(rowOf(updated));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') return reply.code(404).send({ error: 'Book not found' });
      throw err;
    }
  });

  fastify.patch('/:id/approve', { preHandler: canApprove }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      const updated = await prisma.book.update({ where: { id }, data: { status: 'approved' } });
      return reply.send(rowOf(updated));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') return reply.code(404).send({ error: 'Book not found' });
      throw err;
    }
  });

  fastify.patch('/:id/reject', { preHandler: canReject }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      const updated = await prisma.book.update({ where: { id }, data: { status: 'rejected' } });
      return reply.send(rowOf(updated));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') return reply.code(404).send({ error: 'Book not found' });
      throw err;
    }
  });

  fastify.delete('/:id', { preHandler: canDelete }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      const existing = await prisma.book.findUnique({
        where: { id },
        select: { storageKey: true, thumbStorageKey: true },
      });
      if (!existing) {
        return reply.code(404).send({ error: 'Book not found' });
      }
      await prisma.book.delete({ where: { id } });
      await Promise.allSettled([
        existing.storageKey ? deleteFile(BUCKETS.contentBooks, existing.storageKey) : Promise.resolve(),
        existing.thumbStorageKey ? deleteFile(BUCKETS.contentThumbnails, existing.thumbStorageKey) : Promise.resolve(),
      ]);
      return reply.code(204).send();
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') return reply.code(404).send({ error: 'Book not found' });
      throw err;
    }
  });
};
