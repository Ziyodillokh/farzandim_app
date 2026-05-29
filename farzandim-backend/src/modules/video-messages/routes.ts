import { FastifyPluginAsync } from 'fastify';
import multipart from '@fastify/multipart';
import { randomUUID } from 'crypto';
import { authGuard } from '../../middleware/auth';
import { prisma } from '../../lib/prisma';
import { BUCKETS, uploadFile, deleteFile, getDownloadUrl } from '../../lib/minio';
import { emitToUser } from '../../lib/realtime';
import { getFieldNumber, getFieldString } from '../../lib/multipart';
import { findFamilyLink } from '../../lib/family';
import { sendPushToUser } from '../../lib/fcm';

const userSelect = { id: true, name: true, role: true, avatarUrl: true } as const;

const ALLOWED_VIDEO_MIMES = [
  'video/mp4',
  'video/quicktime',
  'video/webm',
  'video/3gpp',
  'video/x-matroska',
];
const MAX_VIDEO_SIZE_BYTES = 100 * 1024 * 1024; // 100 MB

export const videoMessagesRoutes: FastifyPluginAsync = async (fastify) => {
  await fastify.register(multipart, {
    limits: {
      fileSize: MAX_VIDEO_SIZE_BYTES,
      files: 1,
    },
  });

  fastify.addHook('preHandler', authGuard);

  /**
   * POST /api/video-messages
   * Multipart: file + receiverId + durationSeconds (optional)
   */
  fastify.post('/', async (request, reply) => {
    const senderId = request.user!.userId;

    const data = await request.file();
    if (!data) {
      return reply.code(400).send({ error: 'No file uploaded' });
    }

    if (!ALLOWED_VIDEO_MIMES.includes(data.mimetype)) {
      return reply.code(415).send({ error: 'Unsupported video format', mimetype: data.mimetype });
    }

    const receiverId = getFieldString(data.fields, 'receiverId');
    const durationSeconds = getFieldNumber(data.fields, 'durationSeconds');

    if (!receiverId) {
      return reply.code(400).send({ error: 'receiverId required' });
    }

    if (receiverId === senderId) {
      return reply.code(400).send({ error: 'Cannot send to yourself' });
    }

    const receiver = await prisma.user.findUnique({ where: { id: receiverId } });
    if (!receiver) {
      return reply.code(404).send({ error: 'Receiver not found' });
    }

    // Faqat parent ↔ paired child kanali ochiq
    const link = await findFamilyLink(senderId, receiverId);
    if (!link) {
      return reply.code(403).send({ error: 'Sender and receiver are not in the same family' });
    }

    const buffer = await data.toBuffer();
    if (buffer.length > MAX_VIDEO_SIZE_BYTES) {
      return reply.code(413).send({ error: 'File too large', max: MAX_VIDEO_SIZE_BYTES });
    }

    const ext = data.filename.split('.').pop() || 'mp4';
    const messageId = randomUUID();
    const storagePath = `${senderId}/${messageId}.${ext}`;

    try {
      await uploadFile(BUCKETS.video, storagePath, buffer, data.mimetype);
    } catch (err) {
      fastify.log.error(err);
      return reply.code(500).send({ error: 'Storage upload failed' });
    }

    const videoMessage = await prisma.videoMessage.create({
      data: {
        id: messageId,
        senderId,
        receiverId,
        storagePath,
        durationSeconds:
          durationSeconds && !Number.isNaN(durationSeconds) ? Math.round(durationSeconds) : null,
      },
      include: { sender: { select: userSelect }, receiver: { select: userSelect } },
    });

    emitToUser(receiverId, 'video:received', videoMessage);

    try {
      await sendPushToUser(prisma, receiverId, {
        title: videoMessage.sender.name ?? 'Yangi xabar',
        body: 'Video xabar yubordi',
        data: {
          type: 'video',
          messageId: videoMessage.id,
          senderId,
        },
      });
    } catch (err) {
      request.log.warn({ err, messageId: videoMessage.id }, 'video push failed');
    }

    return reply.code(201).send(videoMessage);
  });

  /**
   * GET /api/video-messages?role=sent|received
   */
  fastify.get<{ Querystring: { role?: string } }>('/', async (request, reply) => {
    const userId = request.user!.userId;
    const role = request.query.role;

    let where: { senderId?: string; receiverId?: string; OR?: object[] };
    if (role === 'received') {
      where = { receiverId: userId };
    } else if (role === 'sent') {
      where = { senderId: userId };
    } else {
      where = { OR: [{ senderId: userId }, { receiverId: userId }] };
    }

    const messages = await prisma.videoMessage.findMany({
      where,
      include: { sender: { select: userSelect }, receiver: { select: userSelect } },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });

    return reply.send({ messages, count: messages.length });
  });

  /**
   * GET /api/video-messages/:id/file — signed URL (1h)
   */
  fastify.get<{ Params: { id: string } }>('/:id/file', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const message = await prisma.videoMessage.findUnique({ where: { id } });
    if (!message) return reply.code(404).send({ error: 'Video message not found' });
    if (message.senderId !== userId && message.receiverId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    try {
      const url = await getDownloadUrl(BUCKETS.video, message.storagePath, 3600);
      return reply.send({ url, expiresIn: 3600 });
    } catch (err) {
      fastify.log.error(err);
      return reply.code(500).send({ error: 'Could not generate URL' });
    }
  });

  /**
   * DELETE /api/video-messages/:id — MinIO file + DB row
   */
  fastify.delete<{ Params: { id: string } }>('/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const message = await prisma.videoMessage.findUnique({ where: { id } });
    if (!message) return reply.code(404).send({ error: 'Video message not found' });
    if (message.senderId !== userId && message.receiverId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    try {
      await deleteFile(BUCKETS.video, message.storagePath);
    } catch (err) {
      fastify.log.warn({ err }, 'MinIO delete failed, removing DB row anyway');
    }

    await prisma.videoMessage.delete({ where: { id } });

    return reply.send({ ok: true });
  });
};
