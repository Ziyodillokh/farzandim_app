import { FastifyPluginAsync } from 'fastify';
import multipart from '@fastify/multipart';
import { z } from 'zod';
import { authGuard } from '../../middleware/auth';
import { prisma } from '../../lib/prisma';
import { BUCKETS, uploadFile, deleteFile, getDownloadUrl } from '../../lib/minio';
import { writeAudit } from '../../lib/audit';

const ALLOWED_AVATAR_MIMES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
const MAX_AVATAR_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB

const createChildSchema = z.object({
  name: z.string().min(1).max(100),
  age: z.number().int().min(1).max(25).optional(),
  gender: z.enum(['male', 'female']).optional(),
  region: z.string().max(100).optional(),
});

const updateChildSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  age: z.number().int().min(1).max(25).optional(),
  gender: z.enum(['male', 'female']).optional(),
  region: z.string().max(100).optional(),
});

/**
 * 5-belgili tasodifiy familyCode yaratish
 * 5 raqam (0-9), oson eslab qolish
 */
function generateFamilyCode(): string {
  return Math.floor(10000 + Math.random() * 90000).toString();
}

async function generateUniqueFamilyCode(): Promise<string> {
  for (let i = 0; i < 10; i++) {
    const code = generateFamilyCode();
    const existing = await prisma.child.findUnique({ where: { familyCode: code } });
    if (!existing) return code;
  }
  throw new Error('Could not generate unique family code');
}

export const childrenRoutes: FastifyPluginAsync = async (fastify) => {
  await fastify.register(multipart, {
    limits: {
      fileSize: MAX_AVATAR_SIZE_BYTES,
      files: 1,
    },
  });

  fastify.addHook('preHandler', authGuard);
  
  /**
   * GET /api/children
   * Parent'ning bolalari ro'yxat
   */
  fastify.get('/', async (request, reply) => {
    const userId = request.user!.userId;
    
    const children = await prisma.child.findMany({
      where: { parentId: userId },
      orderBy: { createdAt: 'desc' },
    });
    
    return reply.send({ children });
  });
  
  /**
   * POST /api/children
   * Yangi bola yaratish + familyCode
   */
  fastify.post('/', async (request, reply) => {
    const userId = request.user!.userId;
    
    // Faqat PARENT bola qo'sha oladi
    if (request.user!.role !== 'PARENT') {
      return reply.code(403).send({ error: 'Only parents can create children' });
    }
    
    const parsed = createChildSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
    }
    
    const familyCode = await generateUniqueFamilyCode();
    
    const child = await prisma.child.create({
      data: {
        parentId: userId,
        ...parsed.data,
        familyCode,
      },
    });

    await writeAudit(request, 'child', 'CREATE', child.id, parsed.data);

    return reply.code(201).send(child);
  });
  
  /**
   * GET /api/children/:id
   * Bitta bola ma'lumotlari
   */
  fastify.get<{ Params: { id: string } }>('/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;
    
    const child = await prisma.child.findUnique({ where: { id } });
    
    if (!child) {
      return reply.code(404).send({ error: 'Child not found' });
    }
    
    // Faqat parent yoki child o'zi ko'ra oladi
    if (child.parentId !== userId && child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }
    
    return reply.send(child);
  });
  
  /**
   * PUT /api/children/:id
   * Bola ma'lumotlarini yangilash
   */
  fastify.put<{ Params: { id: string } }>('/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;
    
    const child = await prisma.child.findUnique({ where: { id } });
    if (!child) {
      return reply.code(404).send({ error: 'Child not found' });
    }
    if (child.parentId !== userId) {
      return reply.code(403).send({ error: 'Only parent can update' });
    }
    
    const parsed = updateChildSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
    }
    
    const updated = await prisma.child.update({
      where: { id },
      data: parsed.data,
    });

    await writeAudit(request, 'child', 'UPDATE', id, parsed.data);

    return reply.send(updated);
  });

  /**
   * DELETE /api/children/:id
   * Bolani o'chirish (cascade: location, schedules, ...)
   */
  fastify.delete<{ Params: { id: string } }>('/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;
    
    const child = await prisma.child.findUnique({ where: { id } });
    if (!child) {
      return reply.code(404).send({ error: 'Child not found' });
    }
    if (child.parentId !== userId) {
      return reply.code(403).send({ error: 'Only parent can delete' });
    }
    
    await prisma.child.delete({ where: { id } });
    await writeAudit(request, 'child', 'DELETE', id);

    return reply.send({ ok: true });
  });
  
  /**
   * POST /api/children/:id/pair-code
   * familyCode'ni qaytadan yaratish. Agar eski paired child user bo'lsa,
   * uni isActive=false qilib soft-delete — eski JWT'lar refresh paytida
   * to'xtaydi, lekin audit trail (voice/video) saqlanadi.
   */
  fastify.post<{ Params: { id: string } }>('/:id/pair-code', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const child = await prisma.child.findUnique({ where: { id } });
    if (!child) {
      return reply.code(404).send({ error: 'Child not found' });
    }
    if (child.parentId !== userId) {
      return reply.code(403).send({ error: 'Only parent can regenerate' });
    }

    const familyCode = await generateUniqueFamilyCode();
    const oldChildUserId = child.childUserId;

    const updated = await prisma.$transaction(async (tx) => {
      const c = await tx.child.update({
        where: { id },
        data: { familyCode, isConnected: false, childUserId: null, pairedAt: null },
      });

      if (oldChildUserId) {
        await tx.user.update({
          where: { id: oldChildUserId },
          data: { isActive: false },
        });
        // FCM tokenlarni ham tozalash — eski qurilmaga push bormaydi
        await tx.fcmToken.deleteMany({ where: { userId: oldChildUserId } });
      }

      return c;
    });

    await writeAudit(request, 'child', 'UPDATE', id, {
      action: 'PAIR_CODE_REGENERATE',
      previousChildUserId: oldChildUserId,
    });

    return reply.send({ familyCode: updated.familyCode });
  });
  
  /**
   * POST /api/children/:id/avatar — multipart upload (image, max 5 MB)
   * Avatar MinIO 'farzandim-avatars' bucket'ga saqlanadi, child.photoPath yangilanadi.
   */
  fastify.post<{ Params: { id: string } }>('/:id/avatar', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const child = await prisma.child.findUnique({ where: { id } });
    if (!child) return reply.code(404).send({ error: 'Child not found' });
    if (child.parentId !== userId) {
      return reply.code(403).send({ error: 'Only parent can update avatar' });
    }

    const data = await request.file();
    if (!data) {
      return reply.code(400).send({ error: 'No file uploaded' });
    }

    if (!ALLOWED_AVATAR_MIMES.includes(data.mimetype)) {
      return reply.code(415).send({ error: 'Unsupported image format', mimetype: data.mimetype });
    }

    const buffer = await data.toBuffer();
    if (buffer.length > MAX_AVATAR_SIZE_BYTES) {
      return reply.code(413).send({ error: 'File too large', max: MAX_AVATAR_SIZE_BYTES });
    }

    const ext = data.filename.split('.').pop() || 'jpg';
    const storagePath = `child-avatars/${id}.${ext}`;

    try {
      await uploadFile(BUCKETS.avatars, storagePath, buffer, data.mimetype);
    } catch (err) {
      fastify.log.error(err);
      return reply.code(500).send({ error: 'Storage upload failed' });
    }

    // Eski rasm bo'lsa va boshqa path bo'lsa o'chirish
    if (child.photoPath && child.photoPath !== storagePath) {
      try {
        await deleteFile(BUCKETS.avatars, child.photoPath);
      } catch (err) {
        fastify.log.warn({ err }, 'Old avatar delete failed');
      }
    }

    const updated = await prisma.child.update({
      where: { id },
      data: { photoPath: storagePath },
    });

    await writeAudit(request, 'child', 'UPLOAD', id, { field: 'avatar', storagePath });

    return reply.send(updated);
  });

  /**
   * GET /api/children/:id/avatar — signed URL (1 soat amal qiladi)
   */
  fastify.get<{ Params: { id: string } }>('/:id/avatar', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const child = await prisma.child.findUnique({ where: { id } });
    if (!child) return reply.code(404).send({ error: 'Child not found' });
    if (child.parentId !== userId && child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }
    if (!child.photoPath) {
      return reply.code(404).send({ error: 'No avatar uploaded' });
    }

    try {
      const url = await getDownloadUrl(BUCKETS.avatars, child.photoPath, 3600);
      return reply.send({ url, expiresIn: 3600 });
    } catch (err) {
      fastify.log.error(err);
      return reply.code(500).send({ error: 'Could not generate URL' });
    }
  });

  /**
   * DELETE /api/children/:id/avatar — rasmni o'chirish (parent only)
   */
  fastify.delete<{ Params: { id: string } }>('/:id/avatar', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const child = await prisma.child.findUnique({ where: { id } });
    if (!child) return reply.code(404).send({ error: 'Child not found' });
    if (child.parentId !== userId) {
      return reply.code(403).send({ error: 'Only parent can delete avatar' });
    }
    if (!child.photoPath) {
      return reply.send({ ok: true });
    }

    try {
      await deleteFile(BUCKETS.avatars, child.photoPath);
    } catch (err) {
      fastify.log.warn({ err }, 'Avatar delete failed, clearing DB anyway');
    }

    await prisma.child.update({
      where: { id },
      data: { photoPath: null },
    });

    await writeAudit(request, 'child', 'DELETE', id, { field: 'avatar' });

    return reply.send({ ok: true });
  });
};
