import { FastifyPluginAsync } from 'fastify';
import multipart from '@fastify/multipart';
import { z } from 'zod';
import { randomUUID } from 'crypto';
import { authGuard } from '../../middleware/auth';
import { prisma } from '../../lib/prisma';
import { BUCKETS, uploadFile, deleteFile, getDownloadUrl } from '../../lib/minio';
import { writeAudit } from '../../lib/audit';
import { emitToUser, emitToChild } from '../../lib/realtime';

// Photo request flow:
//   1. Parent POST /api/children/:childId/photo-requests (message ixtiyoriy)
//      Status: PENDING. Child push xabari oladi.
//   2. Child quyidagilardan birini qiladi:
//      a) POST /api/photo-requests/:id/upload (multipart) — photoPath saqlanadi, status COMPLETED
//      b) PUT /api/photo-requests/:id/decline — status DECLINED
//   3. Parent natijani ko'radi (signed URL orqali photo'ni yuklab oladi).

const ALLOWED_IMAGE_MIMES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
const MAX_IMAGE_SIZE_BYTES = 15 * 1024 * 1024; // 15 MB

const createSchema = z.object({
  message: z.string().max(500).optional(),
});

const listQuerySchema = z.object({
  status: z.enum(['PENDING', 'COMPLETED', 'DECLINED']).optional(),
  limit: z.coerce.number().int().min(1).max(200).default(100),
});

export const photoRequestRoutes: FastifyPluginAsync = async (fastify) => {
  await fastify.register(multipart, {
    limits: {
      fileSize: MAX_IMAGE_SIZE_BYTES,
      files: 1,
    },
  });

  fastify.addHook('preHandler', authGuard);

  /**
   * GET /api/children/:childId/photo-requests
   * Parent yoki child o'ziga tegishlilarni ko'radi.
   */
  fastify.get<{
    Params: { childId: string };
    Querystring: { status?: string; limit?: number };
  }>('/children/:childId/photo-requests', async (request, reply) => {
    const userId = request.user!.userId;
    const { childId } = request.params;

    const child = await prisma.child.findUnique({ where: { id: childId } });
    if (!child) return reply.code(404).send({ error: 'Child not found' });
    if (child.parentId !== userId && child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    const parsed = listQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid query', details: parsed.error.format() });
    }

    const { status, limit } = parsed.data;

    const requests = await prisma.photoRequest.findMany({
      where: { childId, ...(status && { status }) },
      orderBy: { requestedAt: 'desc' },
      take: limit,
    });

    return reply.send({ requests, count: requests.length });
  });

  /**
   * POST /api/children/:childId/photo-requests — parent yaratadi
   */
  fastify.post<{ Params: { childId: string } }>(
    '/children/:childId/photo-requests',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.parentId !== userId) {
        return reply.code(403).send({ error: 'Only parent can request photos' });
      }

      const parsed = createSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
      }

      const photoRequest = await prisma.photoRequest.create({
        data: {
          parentId: userId,
          childId,
          message: parsed.data.message,
        },
      });

      await writeAudit(request, 'photo_request', 'CREATE', photoRequest.id, parsed.data);

      // Child push (FCM lazy)
      // emitToUser orqali real-time bola appga
      if (child.childUserId) {
        emitToUser(child.childUserId, 'photo_request:received', photoRequest);
      }
      emitToChild(childId, 'photo_request:created', photoRequest);

      return reply.code(201).send(photoRequest);
    },
  );

  /**
   * POST /api/photo-requests/:id/upload — child fulfills (multipart image)
   */
  fastify.post<{ Params: { id: string } }>('/photo-requests/:id/upload', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const photoRequest = await prisma.photoRequest.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!photoRequest) return reply.code(404).send({ error: 'Photo request not found' });
    if (photoRequest.child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Only child can upload photo for this request' });
    }
    if (photoRequest.status !== 'PENDING') {
      return reply.code(409).send({ error: 'Request already processed' });
    }

    const data = await request.file();
    if (!data) {
      return reply.code(400).send({ error: 'No file uploaded' });
    }

    if (!ALLOWED_IMAGE_MIMES.includes(data.mimetype)) {
      return reply.code(415).send({ error: 'Unsupported image format', mimetype: data.mimetype });
    }

    const buffer = await data.toBuffer();
    if (buffer.length > MAX_IMAGE_SIZE_BYTES) {
      return reply.code(413).send({ error: 'File too large', max: MAX_IMAGE_SIZE_BYTES });
    }

    const ext = data.filename.split('.').pop() || 'jpg';
    const storagePath = `photo-requests/${photoRequest.childId}/${id}.${ext}`;

    try {
      await uploadFile(BUCKETS.avatars, storagePath, buffer, data.mimetype);
    } catch (err) {
      fastify.log.error(err);
      return reply.code(500).send({ error: 'Storage upload failed' });
    }

    const updated = await prisma.photoRequest.update({
      where: { id },
      data: {
        photoPath: storagePath,
        status: 'COMPLETED',
        completedAt: new Date(),
      },
    });

    await writeAudit(request, 'photo_request', 'UPDATE', id, { status: 'COMPLETED' });
    emitToUser(photoRequest.parentId, 'photo_request:completed', updated);
    emitToChild(photoRequest.childId, 'photo_request:completed', updated);

    return reply.send(updated);
  });

  /**
   * PUT /api/photo-requests/:id/decline — child declines
   */
  fastify.put<{ Params: { id: string } }>(
    '/photo-requests/:id/decline',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { id } = request.params;

      const photoRequest = await prisma.photoRequest.findUnique({
        where: { id },
        include: { child: true },
      });
      if (!photoRequest) return reply.code(404).send({ error: 'Photo request not found' });
      if (photoRequest.child.childUserId !== userId) {
        return reply.code(403).send({ error: 'Only child can decline' });
      }
      if (photoRequest.status !== 'PENDING') {
        return reply.code(409).send({ error: 'Request already processed' });
      }

      const updated = await prisma.photoRequest.update({
        where: { id },
        data: { status: 'DECLINED', declinedAt: new Date() },
      });

      await writeAudit(request, 'photo_request', 'UPDATE', id, { status: 'DECLINED' });
      emitToUser(photoRequest.parentId, 'photo_request:declined', updated);

      return reply.send(updated);
    },
  );

  /**
   * GET /api/photo-requests/:id/file — signed URL (parent/child o'qiydi)
   */
  fastify.get<{ Params: { id: string } }>('/photo-requests/:id/file', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const photoRequest = await prisma.photoRequest.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!photoRequest) return reply.code(404).send({ error: 'Photo request not found' });
    if (
      photoRequest.parentId !== userId &&
      photoRequest.child.childUserId !== userId
    ) {
      return reply.code(403).send({ error: 'Forbidden' });
    }
    if (!photoRequest.photoPath) {
      return reply.code(404).send({ error: 'Photo not uploaded yet' });
    }

    try {
      const url = await getDownloadUrl(BUCKETS.avatars, photoRequest.photoPath, 3600);
      return reply.send({ url, expiresIn: 3600 });
    } catch (err) {
      fastify.log.error(err);
      return reply.code(500).send({ error: 'Could not generate URL' });
    }
  });

  /**
   * DELETE /api/photo-requests/:id — parent o'chiradi (photo va DB row)
   */
  fastify.delete<{ Params: { id: string } }>('/photo-requests/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const photoRequest = await prisma.photoRequest.findUnique({ where: { id } });
    if (!photoRequest) return reply.code(404).send({ error: 'Photo request not found' });
    if (photoRequest.parentId !== userId) {
      return reply.code(403).send({ error: 'Only parent can delete' });
    }

    if (photoRequest.photoPath) {
      try {
        await deleteFile(BUCKETS.avatars, photoRequest.photoPath);
      } catch (err) {
        fastify.log.warn({ err }, 'MinIO delete failed for photo, removing DB row anyway');
      }
    }

    await prisma.photoRequest.delete({ where: { id } });
    await writeAudit(request, 'photo_request', 'DELETE', id);

    return reply.send({ ok: true });
  });
};
