import { FastifyPluginAsync } from 'fastify';
import multipart from '@fastify/multipart';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { randomUUID } from 'crypto';
import { prisma } from '../../lib/prisma';
import { staffAuthGuard } from '../../middleware/staff-auth';
import { requirePermission } from '../../middleware/require-permission';
import {
  BulkActionBody,
  CONTENT_STATUSES,
  paginated,
  PLAN_REQUIRED,
  PaginationQuery,
} from '../../lib/content-helpers';
import { BUCKETS, uploadFile, getDownloadUrl, deleteFile } from '../../lib/minio';
import {
  ALLOWED_AUDIO_MIMES,
  ALLOWED_IMAGE_MIMES,
} from '../../lib/admin-content-upload';

const MAX_AUDIO_BYTES = 90 * 1024 * 1024; // 90 MB
const MAX_THUMBNAIL_BYTES = 5 * 1024 * 1024;

const ListQuery = PaginationQuery.extend({
  q: z.string().trim().optional(),
  status: z.string().trim().optional(),
  categoryId: z.string().trim().optional(),
  planRequired: z.string().trim().optional(),
  ageFrom: z.coerce.number().int().optional(),
  ageTo: z.coerce.number().int().optional(),
});

const CreateBody = z.object({
  title: z.string().trim().min(1).max(200),
  author: z.string().trim().min(1).max(150),
  audioUrl: z.string().url(),
  thumbnail: z.union([z.string().url(), z.null()]).optional(),
  description: z.union([z.string().trim().max(4000), z.null()]).optional(),
  durationSec: z.coerce.number().int().min(0).optional(),
  partsCount: z.coerce.number().int().min(1).default(1),
  ageFrom: z.coerce.number().int().min(0).max(25).default(0),
  ageTo: z.coerce.number().int().min(0).max(25).default(18),
  categoryId: z.union([z.string().uuid(), z.null()]).optional(),
  planRequired: z.enum(PLAN_REQUIRED).default('free'),
  status: z.enum(CONTENT_STATUSES).default('hidden'),
});

// Upload metadata — audioUrl MinIO'dan keladi, shu sababli optional.
const UploadMetadata = CreateBody.extend({
  audioUrl: z.string().url().optional(),
});

const UpdateBody = CreateBody.partial().omit({ audioUrl: true }).extend({
  audioUrl: z.string().url().optional(),
});

function rowOf(a: {
  id: string;
  title: string;
  author: string;
  description: string | null;
  audioUrl: string;
  thumbnail: string | null;
  durationSec: number | null;
  partsCount: number;
  ageFrom: number;
  ageTo: number;
  categoryId: string | null;
  category: string | null;
  planRequired: string;
  status: string;
  listens: number;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: a.id,
    title: a.title,
    author: a.author,
    description: a.description,
    audioUrl: a.audioUrl,
    thumbnail: a.thumbnail,
    durationSec: a.durationSec,
    partsCount: a.partsCount,
    ageFrom: a.ageFrom,
    ageTo: a.ageTo,
    categoryId: a.categoryId,
    category: a.category,
    planRequired: a.planRequired,
    status: a.status,
    listens: a.listens,
    createdAt: a.createdAt.toISOString(),
    updatedAt: a.updatedAt.toISOString(),
  };
}

export const adminAudiobooksRoutes: FastifyPluginAsync = async (fastify) => {
  // Sprint 6 — RBAC: modul autentifikatsiyadan o'tadi.
  // C5 fix: o'qish/yozish ruxsatlari ajratilgan — view_content faqat ko'rish uchun.
  fastify.addHook('preHandler', staffAuthGuard);
  const canView = requirePermission(
    'view_content', 'upload_audiobooks', 'edit_audiobooks', 'delete_audiobooks', 'approve_audiobooks',
  );
  const canManage = requirePermission('upload_audiobooks', 'edit_audiobooks');
  const canApprove = requirePermission('approve_audiobooks');
  const canDelete = requirePermission('delete_audiobooks');

  await fastify.register(multipart, {
    limits: { fileSize: MAX_AUDIO_BYTES, files: 2 },
  });

  fastify.get('/', { preHandler: canView }, async (request, reply) => {
    const parsed = ListQuery.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid query', details: parsed.error.flatten() });
    }
    const { page, limit, q, status, categoryId, planRequired, ageFrom, ageTo } = parsed.data;
    const where: Prisma.AudiobookWhereInput = {};
    if (status && (CONTENT_STATUSES as readonly string[]).includes(status)) where.status = status;
    if (categoryId) where.categoryId = categoryId;
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
      prisma.audiobook.count({ where }),
      prisma.audiobook.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return reply.send(paginated(rows.map(rowOf), page, limit, total));
  });

  // Sprint 5.6b — real MinIO multipart upload
  //
  // POST /admin/audiobooks/upload
  // FormData:
  //   audioFile:       main audio (m4a/mp3/aac/...) — max 90 MB
  //   thumbnailFile?:  cover image — max 5 MB
  //   metadata:        JSON {title, author, description?, durationSec?,
  //                          partsCount, ageFrom, ageTo, categoryId?,
  //                          planRequired, status}
  fastify.post('/upload', { preHandler: canManage }, async (request, reply) => {
    if (!request.isMultipart()) {
      return reply.code(400).send({ error: 'multipart/form-data required' });
    }

    let audioBuf: Buffer | null = null;
    let audioFilename = 'upload.m4a';
    let audioMime = 'audio/mp4';
    let thumbBuf: Buffer | null = null;
    let thumbFilename = 'thumb.jpg';
    let thumbMime = 'image/jpeg';
    let metadataStr: string | null = null;

    try {
      for await (const part of request.parts()) {
        if (part.type === 'file') {
          const buf = await part.toBuffer();
          if (part.fieldname === 'audioFile') {
            if (buf.length > MAX_AUDIO_BYTES) {
              return reply.code(413).send({ error: 'Audio too large', max: MAX_AUDIO_BYTES });
            }
            if (!ALLOWED_AUDIO_MIMES.includes(part.mimetype)) {
              return reply.code(415).send({ error: 'Unsupported audio format', mimetype: part.mimetype });
            }
            audioBuf = buf;
            audioFilename = part.filename;
            audioMime = part.mimetype;
          } else if (part.fieldname === 'thumbnailFile') {
            if (buf.length > MAX_THUMBNAIL_BYTES) {
              return reply.code(413).send({ error: 'Thumbnail too large', max: MAX_THUMBNAIL_BYTES });
            }
            if (!ALLOWED_IMAGE_MIMES.includes(part.mimetype)) {
              return reply.code(415).send({ error: 'Unsupported image format', mimetype: part.mimetype });
            }
            thumbBuf = buf;
            thumbFilename = part.filename;
            thumbMime = part.mimetype;
          }
        } else if (part.fieldname === 'metadata') {
          metadataStr = String((part as { value: unknown }).value ?? '');
        }
      }
    } catch (err) {
      fastify.log.error({ err }, 'admin-audiobooks/upload: parts iteration failed');
      return reply.code(400).send({ error: 'Failed to parse multipart' });
    }

    if (!audioBuf) return reply.code(400).send({ error: 'audioFile field required' });
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
    const audioExt = audioFilename.includes('.') ? '.' + audioFilename.split('.').pop() : '.m4a';
    const audioKey = `audio/${id}${audioExt}`;
    try {
      await uploadFile(BUCKETS.contentAudio, audioKey, audioBuf, audioMime);
    } catch (err) {
      fastify.log.error({ err }, 'admin-audiobooks/upload: audio MinIO upload failed');
      return reply.code(500).send({ error: 'Audio storage upload failed' });
    }
    // 6-kunlik signed URL (AWS SigV4 maks 7 kun). Re-sign uchun sprint 5.6c'ga
    // Audiobook.storageKey columni kerak.
    const audioUrl = await getDownloadUrl(BUCKETS.contentAudio, audioKey, 6 * 86_400);

    let thumbnailUrl: string | null = null;
    let thumbStorageKey: string | null = null;
    if (thumbBuf) {
      const thumbExt = thumbFilename.includes('.') ? '.' + thumbFilename.split('.').pop() : '.jpg';
      const thumbKey = `thumbnails/${id}${thumbExt}`;
      try {
        await uploadFile(BUCKETS.contentThumbnails, thumbKey, thumbBuf, thumbMime);
        thumbnailUrl = await getDownloadUrl(BUCKETS.contentThumbnails, thumbKey, 6 * 86_400);
        thumbStorageKey = thumbKey;
      } catch (err) {
        fastify.log.warn({ err }, 'admin-audiobooks/upload: thumbnail upload failed (continuing)');
      }
    }

    // Sprint 5.6c — storageKey saqlanadi, consumer re-sign uchun.
    const created = await prisma.audiobook.create({
      data: {
        title: meta.title,
        author: meta.author,
        description: meta.description ?? null,
        audioUrl,
        thumbnail: thumbnailUrl ?? meta.thumbnail ?? null,
        storageKey: audioKey,
        thumbStorageKey,
        durationSec: meta.durationSec ?? null,
        partsCount: meta.partsCount,
        ageFrom: meta.ageFrom,
        ageTo: meta.ageTo,
        categoryId: meta.categoryId ?? null,
        planRequired: meta.planRequired,
        status: meta.status,
      },
    });

    return reply.code(201).send({
      ...rowOf(created),
      storage: { audioKey, bucket: BUCKETS.contentAudio, sizeBytes: audioBuf.length },
    });
  });

  fastify.post('/', { preHandler: canManage }, async (request, reply) => {
    const parsed = CreateBody.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid body', details: parsed.error.flatten() });
    }
    const data = parsed.data;
    const created = await prisma.audiobook.create({
      data: {
        title: data.title,
        author: data.author,
        description: data.description ?? null,
        audioUrl: data.audioUrl,
        thumbnail: data.thumbnail ?? null,
        durationSec: data.durationSec ?? null,
        partsCount: data.partsCount,
        ageFrom: data.ageFrom,
        ageTo: data.ageTo,
        categoryId: data.categoryId ?? null,
        planRequired: data.planRequired,
        status: data.status,
      },
    });
    return reply.code(201).send(rowOf(created));
  });

  fastify.patch('/:id', { preHandler: canManage }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const parsed = UpdateBody.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid body', details: parsed.error.flatten() });
    }
    const data = parsed.data;
    const updates: Prisma.AudiobookUpdateInput = {};
    if (data.title !== undefined) updates.title = data.title;
    if (data.author !== undefined) updates.author = data.author;
    if (data.description !== undefined) updates.description = data.description ?? null;
    if (data.audioUrl !== undefined) updates.audioUrl = data.audioUrl;
    if (data.thumbnail !== undefined) updates.thumbnail = data.thumbnail ?? null;
    if (data.durationSec !== undefined) updates.durationSec = data.durationSec;
    if (data.partsCount !== undefined) updates.partsCount = data.partsCount;
    if (data.ageFrom !== undefined) updates.ageFrom = data.ageFrom;
    if (data.ageTo !== undefined) updates.ageTo = data.ageTo;
    if (data.categoryId !== undefined) updates.categoryId = data.categoryId ?? null;
    if (data.planRequired !== undefined) updates.planRequired = data.planRequired;
    if (data.status !== undefined) updates.status = data.status;
    try {
      const updated = await prisma.audiobook.update({ where: { id }, data: updates });
      return reply.send(rowOf(updated));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Audiobook not found' });
      }
      throw err;
    }
  });

  fastify.patch('/:id/approve', { preHandler: canApprove }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      const updated = await prisma.audiobook.update({ where: { id }, data: { status: 'approved' } });
      return reply.send(rowOf(updated));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') return reply.code(404).send({ error: 'Audiobook not found' });
      throw err;
    }
  });

  fastify.patch('/:id/reject', { preHandler: canApprove }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      const updated = await prisma.audiobook.update({ where: { id }, data: { status: 'rejected' } });
      return reply.send(rowOf(updated));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') return reply.code(404).send({ error: 'Audiobook not found' });
      throw err;
    }
  });

  fastify.delete('/:id', { preHandler: canDelete }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      const existing = await prisma.audiobook.findUnique({
        where: { id },
        select: { storageKey: true, thumbStorageKey: true },
      });
      if (!existing) {
        return reply.code(404).send({ error: 'Audiobook not found' });
      }
      await prisma.audiobook.delete({ where: { id } });
      await Promise.allSettled([
        existing.storageKey ? deleteFile(BUCKETS.contentAudio, existing.storageKey) : Promise.resolve(),
        existing.thumbStorageKey ? deleteFile(BUCKETS.contentThumbnails, existing.thumbStorageKey) : Promise.resolve(),
      ]);
      return reply.code(204).send();
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') return reply.code(404).send({ error: 'Audiobook not found' });
      throw err;
    }
  });

  fastify.post('/bulk', { preHandler: canDelete }, async (request, reply) => {
    const parsed = BulkActionBody.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid body', details: parsed.error.flatten() });
    }
    const { ids, action } = parsed.data;
    let updated = 0;
    let deleted = 0;
    if (action === 'approve' || action === 'reject' || action === 'hide') {
      const target = action === 'approve' ? 'approved' : action === 'reject' ? 'rejected' : 'hidden';
      const r = await prisma.audiobook.updateMany({ where: { id: { in: ids } }, data: { status: target } });
      updated = r.count;
    } else if (action === 'delete') {
      const rows = await prisma.audiobook.findMany({
        where: { id: { in: ids } },
        select: { storageKey: true, thumbStorageKey: true },
      });
      const r = await prisma.audiobook.deleteMany({ where: { id: { in: ids } } });
      deleted = r.count;
      await Promise.allSettled(
        rows.flatMap((row) => [
          row.storageKey ? deleteFile(BUCKETS.contentAudio, row.storageKey) : Promise.resolve(),
          row.thumbStorageKey ? deleteFile(BUCKETS.contentThumbnails, row.thumbStorageKey) : Promise.resolve(),
        ]),
      );
    }
    return reply.send({ ok: true, updated, deleted });
  });
};
