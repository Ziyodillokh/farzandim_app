import { FastifyPluginAsync } from 'fastify';
import multipart from '@fastify/multipart';
import { z } from 'zod';
import { randomUUID } from 'crypto';
import { authGuard } from '../../middleware/auth';
import { prisma } from '../../lib/prisma';
import { BUCKETS, uploadFile, deleteFile, getDownloadUrl } from '../../lib/minio';
import { emitToUser } from '../../lib/realtime';
import { getFieldNumber, getFieldString } from '../../lib/multipart';
import { findFamilyLink } from '../../lib/family';
import { sendPushToUser } from '../../lib/fcm';

const userSelect = { id: true, name: true, role: true, avatarUrl: true } as const;

const ALLOWED_MIMES = ['audio/mp4', 'audio/m4a', 'audio/aac', 'audio/mpeg', 'audio/ogg', 'audio/webm', 'audio/wav'];
const MAX_SIZE_BYTES = 10 * 1024 * 1024; // 10 MB

export const voiceMessagesRoutes: FastifyPluginAsync = async (fastify) => {
  await fastify.register(multipart, {
    limits: {
      fileSize: MAX_SIZE_BYTES,
      files: 1,
    },
  });
  
  fastify.addHook('preHandler', authGuard);
  
  /**
   * POST /api/voice-messages
   * Multipart: file (audio) + receiverId (form field) + durationSeconds (optional)
   */
  fastify.post('/', async (request, reply) => {
    const senderId = request.user!.userId;
    
    const data = await request.file();
    if (!data) {
      return reply.code(400).send({ error: 'No file uploaded' });
    }
    
    // Mime type tekshirish
    if (!ALLOWED_MIMES.includes(data.mimetype)) {
      return reply.code(415).send({ error: 'Unsupported audio format', mimetype: data.mimetype });
    }
    
    // Form fields
    const receiverId = getFieldString(data.fields, 'receiverId');
    const durationSeconds = getFieldNumber(data.fields, 'durationSeconds');

    if (!receiverId) {
      return reply.code(400).send({ error: 'receiverId required' });
    }

    if (receiverId === senderId) {
      return reply.code(400).send({ error: 'Cannot send to yourself' });
    }

    // Receiver bormi
    const receiver = await prisma.user.findUnique({ where: { id: receiverId } });
    if (!receiver) {
      return reply.code(404).send({ error: 'Receiver not found' });
    }

    // Faqat parent ↔ paired child kanali ochiq
    const link = await findFamilyLink(senderId, receiverId);
    if (!link) {
      return reply.code(403).send({ error: 'Sender and receiver are not in the same family' });
    }

    // Fayl o'qish (buffer)
    const buffer = await data.toBuffer();
    
    if (buffer.length > MAX_SIZE_BYTES) {
      return reply.code(413).send({ error: 'File too large', max: MAX_SIZE_BYTES });
    }
    
    // Storage path
    const ext = data.filename.split('.').pop() || 'm4a';
    const messageId = randomUUID();
    const storagePath = `${senderId}/${messageId}.${ext}`;
    
    // MinIO'ga yuklash
    try {
      await uploadFile(BUCKETS.voice, storagePath, buffer, data.mimetype);
    } catch (err) {
      fastify.log.error(err);
      return reply.code(500).send({ error: 'Storage upload failed' });
    }
    
    // Database row
    const voiceMessage = await prisma.voiceMessage.create({
      data: {
        id: messageId,
        senderId,
        receiverId,
        storagePath,
        durationSeconds: durationSeconds && !isNaN(durationSeconds) ? Math.round(durationSeconds) : null,
      },
      include: { sender: { select: userSelect }, receiver: { select: userSelect } },
    });

    // Real-time: receiver'ga yangi voice message keldi (sender bilan)
    emitToUser(receiverId, 'voice:received', voiceMessage);

    // FCM push receiver'ga — app background bo'lsa ham xabar yetadi
    try {
      await sendPushToUser(prisma, receiverId, {
        title: voiceMessage.sender.name ?? 'Yangi xabar',
        body: 'Ovozli xabar yubordi',
        data: {
          type: 'voice',
          messageId: voiceMessage.id,
          senderId,
        },
      });
    } catch (err) {
      request.log.warn({ err, messageId: voiceMessage.id }, 'voice push failed');
    }

    return reply.code(201).send(voiceMessage);
  });
  
  /**
   * GET /api/voice-messages
   * User'ning hamma xabarlari (sender + receiver)
   * Query: ?role=received|sent (optional, default both)
   */
  fastify.get('/', async (request, reply) => {
    const userId = request.user!.userId;
    const role = (request.query as any).role as string | undefined;
    
    let where: any;
    if (role === 'received') {
      where = { receiverId: userId };
    } else if (role === 'sent') {
      where = { senderId: userId };
    } else {
      where = { OR: [{ senderId: userId }, { receiverId: userId }] };
    }
    
    const messages = await prisma.voiceMessage.findMany({
      where,
      include: { sender: { select: userSelect }, receiver: { select: userSelect } },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });

    return reply.send({ messages, count: messages.length });
  });
  
  /**
   * GET /api/voice-messages/:id/file
   * Signed URL qaytarish (1 soat amal qiladi)
   */
  fastify.get<{ Params: { id: string } }>('/:id/file', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;
    
    const message = await prisma.voiceMessage.findUnique({ where: { id } });
    if (!message) {
      return reply.code(404).send({ error: 'Voice message not found' });
    }
    
    if (message.senderId !== userId && message.receiverId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }
    
    try {
      const url = await getDownloadUrl(BUCKETS.voice, message.storagePath, 3600);
      return reply.send({ url, expiresIn: 3600 });
    } catch (err) {
      fastify.log.error(err);
      return reply.code(500).send({ error: 'Could not generate URL' });
    }
  });
  
  /**
   * PUT /api/voice-messages/:id/read
   * O'qildi belgilash (faqat receiver)
   */
  fastify.put<{ Params: { id: string } }>('/:id/read', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const message = await prisma.voiceMessage.findUnique({ where: { id } });
    if (!message) {
      return reply.code(404).send({ error: 'Voice message not found' });
    }
    if (message.receiverId !== userId) {
      return reply.code(403).send({ error: 'Only receiver can mark as read' });
    }

    const updated = await prisma.voiceMessage.update({
      where: { id },
      data: { isRead: true },
    });

    return reply.send(updated);
  });

  /**
   * POST /api/voice-messages/read-all
   * Hozirgi user'ga kelgan barcha o'qilmagan xabarlarni bulk mark as read.
   * Optional `fromUserId` — faqat shu sender'dan kelganlarni mark.
   *
   * Sprint 4.4.31: chat ekran ochilganda 1 ta chaqiruv bilan
   * barcha unread'larni belgilash (tap-by-tap o'rniga).
   */
  fastify.post<{ Body: { fromUserId?: string } }>(
    '/read-all',
    async (request, reply) => {
      const userId = request.user!.userId;
      const body = (request.body as { fromUserId?: string } | null) ?? {};
      const fromUserId = body.fromUserId;

      const result = await prisma.voiceMessage.updateMany({
        where: {
          receiverId: userId,
          isRead: false,
          ...(fromUserId ? { senderId: fromUserId } : {}),
        },
        data: { isRead: true },
      });

      return reply.send({ ok: true, updated: result.count });
    },
  );
  
  /**
   * DELETE /api/voice-messages/:id
   * Database row + MinIO fayl o'chirish (sender yoki receiver)
   */
  fastify.delete<{ Params: { id: string } }>('/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;
    
    const message = await prisma.voiceMessage.findUnique({ where: { id } });
    if (!message) {
      return reply.code(404).send({ error: 'Voice message not found' });
    }
    if (message.senderId !== userId && message.receiverId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }
    
    // MinIO'dan o'chirish
    try {
      await deleteFile(BUCKETS.voice, message.storagePath);
    } catch (err) {
      // Storage'dan o'chirish xato bo'lsa ham DB row o'chiramiz (eventual consistency)
      fastify.log.warn({ err }, 'MinIO delete failed, removing DB row anyway');
    }
    
    await prisma.voiceMessage.delete({ where: { id } });
    
    return reply.send({ ok: true });
  });
};
