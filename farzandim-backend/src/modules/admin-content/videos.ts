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
  VIDEO_LEVELS,
} from '../../lib/content-helpers';
import { BUCKETS, uploadFile, getDownloadUrl, deleteFile } from '../../lib/minio';
import {
  ALLOWED_VIDEO_MIMES,
  ALLOWED_IMAGE_MIMES,
} from '../../lib/admin-content-upload';
import { extractVideoThumbnail } from '../../lib/video-thumbnail';
import { logAudit } from '../../lib/audit-log';

const MAX_VIDEO_BYTES = 90 * 1024 * 1024; // 90 MB (server bodyLimit 100MB)
const MAX_THUMBNAIL_BYTES = 5 * 1024 * 1024;

const ListQuery = PaginationQuery.extend({
  q: z.string().trim().optional(),
  status: z.string().trim().optional(),
  categoryId: z.string().trim().optional(),
  planRequired: z.string().trim().optional(),
  level: z.string().trim().optional(),
  ageFrom: z.coerce.number().int().optional(),
  ageTo: z.coerce.number().int().optional(),
});

const CreateBody = z.object({
  title: z.string().trim().min(1).max(200),
  url: z.string().url(),
  thumbnail: z.union([z.string().url(), z.null()]).optional(),
  description: z.union([z.string().trim().max(4000), z.null()]).optional(),
  durationSec: z.coerce.number().int().min(0).optional(),
  ageFrom: z.coerce.number().int().min(0).max(25).default(0),
  ageTo: z.coerce.number().int().min(0).max(25).default(18),
  categoryId: z.union([z.string().uuid(), z.null()]).optional(),
  planRequired: z.enum(PLAN_REQUIRED).default('free'),
  level: z.enum(VIDEO_LEVELS).optional(),
  status: z.enum(CONTENT_STATUSES).default('hidden'),
  featured: z.boolean().optional(),
});

// Upload metadata — url MinIO'dan keladi, shu sababli optional.
const UploadMetadata = CreateBody.extend({
  url: z.string().url().optional(),
});

const UpdateBody = z.object({
  title: z.string().trim().min(1).max(200).optional(),
  description: z.union([z.string().trim().max(4000), z.null()]).optional(),
  thumbnail: z.union([z.string().url(), z.null()]).optional(),
  durationSec: z.coerce.number().int().min(0).optional(),
  ageFrom: z.coerce.number().int().min(0).max(25).optional(),
  ageTo: z.coerce.number().int().min(0).max(25).optional(),
  categoryId: z.union([z.string().uuid(), z.null()]).optional(),
  planRequired: z.enum(PLAN_REQUIRED).optional(),
  level: z.union([z.enum(VIDEO_LEVELS), z.null()]).optional(),
  status: z.enum(CONTENT_STATUSES).optional(),
  featured: z.boolean().optional(),
});

function rowOf(v: {
  id: string;
  title: string;
  description: string | null;
  url: string;
  thumbnail: string | null;
  durationSec: number | null;
  ageFrom: number;
  ageTo: number;
  categoryId: string | null;
  category: string | null;
  planRequired: string;
  level: string | null;
  status: string;
  featured: boolean;
  views: number;
  likes: number;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: v.id,
    title: v.title,
    description: v.description,
    url: v.url,
    thumbnail: v.thumbnail,
    durationSec: v.durationSec,
    ageFrom: v.ageFrom,
    ageTo: v.ageTo,
    categoryId: v.categoryId,
    category: v.category,
    planRequired: v.planRequired,
    level: v.level,
    status: v.status,
    featured: v.featured,
    views: v.views,
    likes: v.likes,
    createdAt: v.createdAt.toISOString(),
    updatedAt: v.updatedAt.toISOString(),
  };
}

export const adminVideosRoutes: FastifyPluginAsync = async (fastify) => {
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
    limits: {
      fileSize: MAX_VIDEO_BYTES,
      files: 2, // videoFile + thumbnailFile
    },
  });

  fastify.get('/', { preHandler: canView }, async (request, reply) => {
    const parsed = ListQuery.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid query', details: parsed.error.flatten() });
    }
    const { page, limit, q, status, categoryId, planRequired, level, ageFrom, ageTo } = parsed.data;
    const where: Prisma.VideoWhereInput = {};
    if (status && (CONTENT_STATUSES as readonly string[]).includes(status)) where.status = status;
    if (categoryId) where.categoryId = categoryId;
    if (planRequired && (PLAN_REQUIRED as readonly string[]).includes(planRequired)) {
      where.planRequired = planRequired;
    }
    if (level && (VIDEO_LEVELS as readonly string[]).includes(level)) where.level = level;
    if (ageFrom !== undefined) where.ageTo = { gte: ageFrom };
    if (ageTo !== undefined) where.ageFrom = { lte: ageTo };
    if (q && q.trim().length > 0) {
      where.OR = [
        { title: { contains: q.trim(), mode: 'insensitive' } },
        { description: { contains: q.trim(), mode: 'insensitive' } },
      ];
    }
    const [total, rows] = await Promise.all([
      prisma.video.count({ where }),
      prisma.video.findMany({
        where,
        orderBy: [{ featured: 'desc' }, { createdAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return reply.send(paginated(rows.map(rowOf), page, limit, total));
  });

  // Sprint 5.6b — real MinIO multipart upload
  //
  // POST /admin/videos/upload
  // FormData:
  //   videoFile:      main video (mp4/webm/...) — max 90 MB
  //   thumbnailFile?: cover image (jpg/png/webp) — max 5 MB
  //   metadata:       JSON string {title, description?, durationSec?,
  //                                ageFrom, ageTo, categoryId?, planRequired,
  //                                level?, status, featured?}
  fastify.post('/upload', { preHandler: canEdit }, async (request, reply) => {
    if (!request.isMultipart()) {
      return reply.code(400).send({ error: 'multipart/form-data required' });
    }

    let videoBuf: Buffer | null = null;
    let videoFilename = 'upload.mp4';
    let videoMime = 'video/mp4';
    let thumbBuf: Buffer | null = null;
    let thumbFilename = 'thumb.jpg';
    let thumbMime = 'image/jpeg';
    let metadataStr: string | null = null;

    try {
      for await (const part of request.parts()) {
        if (part.type === 'file') {
          const buf = await part.toBuffer();
          if (part.fieldname === 'videoFile') {
            if (buf.length > MAX_VIDEO_BYTES) {
              return reply.code(413).send({ error: 'Video too large', max: MAX_VIDEO_BYTES });
            }
            if (!ALLOWED_VIDEO_MIMES.includes(part.mimetype)) {
              return reply.code(415).send({ error: 'Unsupported video format', mimetype: part.mimetype });
            }
            videoBuf = buf;
            videoFilename = part.filename;
            videoMime = part.mimetype;
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
      fastify.log.error({ err }, 'admin-videos/upload: parts iteration failed');
      return reply.code(400).send({ error: 'Failed to parse multipart' });
    }

    if (!videoBuf) return reply.code(400).send({ error: 'videoFile field required' });
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

    // Upload video
    const id = randomUUID();
    const videoExt = videoFilename.includes('.') ? '.' + videoFilename.split('.').pop() : '.mp4';
    const videoKey = `videos/${id}${videoExt}`;
    try {
      await uploadFile(BUCKETS.contentVideos, videoKey, videoBuf, videoMime);
    } catch (err) {
      fastify.log.error({ err }, 'admin-videos/upload: video MinIO upload failed');
      return reply.code(500).send({ error: 'Video storage upload failed' });
    }
    // 6-kunlik signed URL — admin preview va keyingi consumer fetch'lar uchun.
    // TODO(5.6c): Video.storageKey columniga path saqlash + consumer route'da
    //             har request'da qayta sign qilish.
    const videoUrl = await getDownloadUrl(BUCKETS.contentVideos, videoKey, 6 * 86_400);

    // Upload thumbnail — explicit (admin yuklagan) yoki video'dan ffmpeg auto-extract.
    let thumbnailUrl: string | null = null;
    let thumbStorageKey: string | null = null;

    // 1) Admin alohida thumbnailFile yuborgan bo'lsa, shuni ishlatamiz.
    if (thumbBuf) {
      const thumbExt = thumbFilename.includes('.') ? '.' + thumbFilename.split('.').pop() : '.jpg';
      const thumbKey = `thumbnails/${id}${thumbExt}`;
      try {
        await uploadFile(BUCKETS.contentThumbnails, thumbKey, thumbBuf, thumbMime);
        thumbnailUrl = await getDownloadUrl(BUCKETS.contentThumbnails, thumbKey, 6 * 86_400);
        thumbStorageKey = thumbKey;
      } catch (err) {
        fastify.log.warn({ err }, 'admin-videos/upload: thumbnail upload failed (continuing)');
      }
    }

    // 2) Sprint 5.6f — agar admin thumbnail bermagan bo'lsa, video'dan
    //    avtomatik ajratib olamiz (ffmpeg 1-sekunddagi kadr).
    if (!thumbStorageKey) {
      try {
        const extracted = await extractVideoThumbnail(videoBuf, videoExt);
        if (extracted) {
          const autoKey = `thumbnails/${id}-auto.jpg`;
          await uploadFile(BUCKETS.contentThumbnails, autoKey, extracted.buffer, extracted.mime);
          thumbnailUrl = await getDownloadUrl(BUCKETS.contentThumbnails, autoKey, 6 * 86_400);
          thumbStorageKey = autoKey;
          fastify.log.info({ videoKey, autoKey, bytes: extracted.buffer.length }, 'admin-videos/upload: auto-thumbnail extracted');
        }
      } catch (err) {
        fastify.log.warn({ err }, 'admin-videos/upload: auto-thumbnail failed (continuing without)');
      }
    }

    // Persist DB row — storageKey saqlanadi (Sprint 5.6c). Consumer endpoint
    // har request'da signed URL'ni qayta sign qiladi. `url` field display
    // fallback bo'lib qoladi.
    const created = await prisma.video.create({
      data: {
        title: meta.title,
        description: meta.description ?? null,
        url: videoUrl,
        thumbnail: thumbnailUrl ?? meta.thumbnail ?? null,
        storageKey: videoKey,
        thumbStorageKey,
        durationSec: meta.durationSec ?? null,
        ageFrom: meta.ageFrom,
        ageTo: meta.ageTo,
        categoryId: meta.categoryId ?? null,
        planRequired: meta.planRequired,
        level: meta.level ?? null,
        status: meta.status,
        featured: meta.featured ?? false,
      },
    });

    return reply.code(201).send({
      ...rowOf(created),
      storage: {
        videoKey,
        bucket: BUCKETS.contentVideos,
        sizeBytes: videoBuf.length,
      },
    });
  });

  fastify.post('/create', { preHandler: canEdit }, async (request, reply) => {
    const parsed = CreateBody.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid body', details: parsed.error.flatten() });
    }
    const data = parsed.data;
    if (data.ageFrom > data.ageTo) {
      return reply.code(400).send({ error: 'ageFrom must be <= ageTo' });
    }
    const created = await prisma.video.create({
      data: {
        title: data.title,
        description: data.description ?? null,
        url: data.url,
        thumbnail: data.thumbnail ?? null,
        durationSec: data.durationSec ?? null,
        ageFrom: data.ageFrom,
        ageTo: data.ageTo,
        categoryId: data.categoryId ?? null,
        planRequired: data.planRequired,
        level: data.level ?? null,
        status: data.status,
        featured: data.featured ?? false,
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
    const updates: Prisma.VideoUpdateInput = {};
    if (data.title !== undefined) updates.title = data.title;
    if (data.description !== undefined) updates.description = data.description ?? null;
    if (data.thumbnail !== undefined) updates.thumbnail = data.thumbnail ?? null;
    if (data.durationSec !== undefined) updates.durationSec = data.durationSec;
    if (data.ageFrom !== undefined) updates.ageFrom = data.ageFrom;
    if (data.ageTo !== undefined) updates.ageTo = data.ageTo;
    if (data.categoryId !== undefined) updates.categoryId = data.categoryId ?? null;
    if (data.planRequired !== undefined) updates.planRequired = data.planRequired;
    if (data.level !== undefined) updates.level = data.level ?? null;
    if (data.status !== undefined) updates.status = data.status;
    if (data.featured !== undefined) updates.featured = data.featured;
    try {
      const updated = await prisma.video.update({ where: { id }, data: updates });
      return reply.send(rowOf(updated));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Video not found' });
      }
      throw err;
    }
  });

  fastify.patch('/:id/approve', { preHandler: canApprove }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      const updated = await prisma.video.update({ where: { id }, data: { status: 'approved' } });
      return reply.send(rowOf(updated));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Video not found' });
      }
      throw err;
    }
  });

  fastify.patch('/:id/reject', { preHandler: canReject }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      const updated = await prisma.video.update({ where: { id }, data: { status: 'rejected' } });
      return reply.send(rowOf(updated));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Video not found' });
      }
      throw err;
    }
  });

  fastify.delete('/:id', { preHandler: canDelete }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      // Avval row'ni topib storage key'larini olamiz — DB delete'dan keyin
      // ulardan foydalanish uchun.
      const existing = await prisma.video.findUnique({
        where: { id },
        select: { storageKey: true, thumbStorageKey: true },
      });
      if (!existing) {
        return reply.code(404).send({ error: 'Video not found' });
      }
      await prisma.video.delete({ where: { id } });
      // MinIO cleanup — silent fail (DB allaqachon o'chirilgan).
      await Promise.allSettled([
        existing.storageKey
          ? deleteFile(BUCKETS.contentVideos, existing.storageKey)
          : Promise.resolve(),
        existing.thumbStorageKey
          ? deleteFile(BUCKETS.contentThumbnails, existing.thumbStorageKey)
          : Promise.resolve(),
      ]);
      void logAudit(request, {
        action: 'video.delete',
        moderatorId: request.staff?.sub ?? null,
        email: request.staff?.email ?? null,
        resourceType: 'video',
        resourceId: id,
      });
      return reply.code(204).send();
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Video not found' });
      }
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
    switch (action) {
      case 'approve': {
        const r = await prisma.video.updateMany({ where: { id: { in: ids } }, data: { status: 'approved' } });
        updated = r.count;
        break;
      }
      case 'reject': {
        const r = await prisma.video.updateMany({ where: { id: { in: ids } }, data: { status: 'rejected' } });
        updated = r.count;
        break;
      }
      case 'hide': {
        const r = await prisma.video.updateMany({ where: { id: { in: ids } }, data: { status: 'hidden' } });
        updated = r.count;
        break;
      }
      case 'feature': {
        const r = await prisma.video.updateMany({ where: { id: { in: ids } }, data: { featured: true } });
        updated = r.count;
        break;
      }
      case 'unfeature': {
        const r = await prisma.video.updateMany({ where: { id: { in: ids } }, data: { featured: false } });
        updated = r.count;
        break;
      }
      case 'delete': {
        // Bulk delete — avval storage keys olamiz, keyin DB + MinIO tozalash.
        const rows = await prisma.video.findMany({
          where: { id: { in: ids } },
          select: { storageKey: true, thumbStorageKey: true },
        });
        const r = await prisma.video.deleteMany({ where: { id: { in: ids } } });
        deleted = r.count;
        await Promise.allSettled(
          rows.flatMap((row) => [
            row.storageKey ? deleteFile(BUCKETS.contentVideos, row.storageKey) : Promise.resolve(),
            row.thumbStorageKey ? deleteFile(BUCKETS.contentThumbnails, row.thumbStorageKey) : Promise.resolve(),
          ]),
        );
        break;
      }
    }
    return reply.send({ ok: true, updated, deleted });
  });
};
