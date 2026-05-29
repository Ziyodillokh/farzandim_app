import { FastifyPluginAsync } from 'fastify';
import multipart from '@fastify/multipart';
import { z } from 'zod';
import { authGuard } from '../../middleware/auth';
import { prisma } from '../../lib/prisma';
import { writeAudit } from '../../lib/audit';
import { isSmsConfigured, sendSms } from '../../lib/sms';
import { BUCKETS, uploadFile, getDownloadUrl } from '../../lib/minio';

const updateProfileSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  avatarUrl: z.string().url().optional().nullable(),
  language: z.enum(['uz', 'ru', 'en']).optional(),
});

const addPhoneSchema = z.object({
  phone: z.string().regex(/^\+998\d{9}$/, 'Phone must be in format +998XXXXXXXXX'),
});

const verifyPhoneSchema = z.object({
  phone: z.string().regex(/^\+998\d{9}$/, 'Phone must be in format +998XXXXXXXXX'),
  code: z.string().length(6),
});

const OTP_TTL_MS = 5 * 60 * 1000; // 5 daqiqa
const OTP_RESEND_COOLDOWN_MS = 60 * 1000; // 60 soniya
const OTP_MAX_ATTEMPTS = 5;

const ALLOWED_AVATAR_MIMES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
const MAX_AVATAR_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB
const AVATAR_URL_TTL = 6 * 24 * 60 * 60; // 6 kun (signed URL)

/**
 * avatarUrl MinIO key bo'lsa signed URL qaytaradi; http(s) URL bo'lsa
 * (Telegram rasmi) o'zini qaytaradi.
 */
async function resolveAvatarUrl(stored: string | null): Promise<string | null> {
  if (!stored) return null;
  if (stored.startsWith('http')) return stored;
  try {
    return await getDownloadUrl(BUCKETS.avatars, stored, AVATAR_URL_TTL);
  } catch {
    return null;
  }
}

export const userRoutes: FastifyPluginAsync = async (fastify) => {
  await fastify.register(multipart, {
    limits: { fileSize: MAX_AVATAR_SIZE_BYTES, files: 1 },
  });

  // Barcha user endpoints autentifikatsiya talab qiladi
  fastify.addHook('preHandler', authGuard);
  
  /**
   * GET /api/users/me
   * Hozirgi foydalanuvchi profili
   */
  fastify.get('/me', async (request, reply) => {
    const userId = request.user!.userId;
    
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        phone: true,
        role: true,
        name: true,
        avatarUrl: true,
        telegramId: true,
        language: true,
        isActive: true,
        createdAt: true,
      },
    });
    
    if (!user) {
      return reply.code(404).send({ error: 'User not found' });
    }
    
    // Telegram phone'ni masklash (foydalanuvchi UI'da ko'rmaydi)
    const isPhoneVerified = user.phone !== null && !user.phone.startsWith('tg:');

    return reply.send({
      ...user,
      avatarUrl: await resolveAvatarUrl(user.avatarUrl),
      phone: isPhoneVerified ? user.phone : null,
      isPhoneVerified,
    });
  });

  /**
   * POST /api/users/me/avatar
   * Profil rasmini MinIO'ga yuklash (multipart/form-data, "file" maydoni).
   */
  fastify.post('/me/avatar', async (request, reply) => {
    const userId = request.user!.userId;

    const file = await request.file();
    if (!file) {
      return reply.code(400).send({ error: 'Fayl yuborilmadi' });
    }
    if (!ALLOWED_AVATAR_MIMES.includes(file.mimetype)) {
      return reply.code(415).send({ error: 'Faqat JPEG/PNG/WebP rasm' });
    }
    const buffer = await file.toBuffer();
    if (buffer.length > MAX_AVATAR_SIZE_BYTES) {
      return reply.code(413).send({ error: 'Rasm 5 MB dan katta' });
    }

    const ext =
      file.mimetype === 'image/png'
        ? 'png'
        : file.mimetype === 'image/webp'
          ? 'webp'
          : 'jpg';
    const key = `users/${userId}.${ext}`;

    await uploadFile(BUCKETS.avatars, key, buffer, file.mimetype);
    await prisma.user.update({ where: { id: userId }, data: { avatarUrl: key } });

    const avatarUrl = await getDownloadUrl(BUCKETS.avatars, key, AVATAR_URL_TTL);
    return reply.send({ ok: true, avatarUrl });
  });

  /**
   * DELETE /api/users/me
   * Akkauntni va barcha bog'liq ma'lumotni butunlay o'chirish (Play Store talabi).
   * Prisma cascade: parent → children → locations/messages/obunalar — hammasi.
   * Bola User rowlari Child cascade'ga kirmaydi — ularni alohida tozalaymiz.
   */
  fastify.delete('/me', async (request, reply) => {
    const userId = request.user!.userId;

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return reply.code(404).send({ error: 'User not found' });
    }

    await prisma.$transaction(async (tx) => {
      const children = await tx.child.findMany({
        where: { parentId: userId },
        select: { childUserId: true },
      });
      const childUserIds = children
        .map((c) => c.childUserId)
        .filter((id): id is string => Boolean(id));

      // Parent o'chirilganda children + barcha bog'liq data cascade o'chadi.
      await tx.user.delete({ where: { id: userId } });

      // Bola User rowlari cascade'ga kirmaydi — ularni ham o'chiramiz.
      if (childUserIds.length > 0) {
        await tx.user.deleteMany({ where: { id: { in: childUserIds } } });
      }
    });

    await writeAudit(request, 'user', 'DELETE', userId, {
      role: user.role,
      telegramId: user.telegramId,
    });

    return reply.send({ ok: true, message: "Akkaunt o'chirildi" });
  });

  /**
   * PUT /api/users/me
   * Profil yangilash
   */
  fastify.put('/me', async (request, reply) => {
    const userId = request.user!.userId;
    
    const parsed = updateProfileSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
    }
    
    const updated = await prisma.user.update({
      where: { id: userId },
      data: parsed.data,
      select: {
        id: true,
        name: true,
        avatarUrl: true,
        language: true,
      },
    });
    
    return reply.send(updated);
  });
  
  /**
   * POST /api/users/me/phone
   * Telefon raqamga 6 xonali SMS OTP kod yuboradi (Eskiz.uz).
   * Raqam shu yerda saqlanmaydi — /me/phone/verify tasdiqlagandan keyin saqlanadi.
   */
  fastify.post('/me/phone', async (request, reply) => {
    const userId = request.user!.userId;

    const parsed = addPhoneSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid phone format', details: parsed.error.format() });
    }
    const { phone } = parsed.data;

    if (!isSmsConfigured()) {
      return reply.code(503).send({ error: 'SMS xizmati hozircha mavjud emas' });
    }

    // Boshqa user bu raqamni ishlatadimi
    const existing = await prisma.user.findUnique({ where: { phone } });
    if (existing && existing.id !== userId) {
      return reply.code(409).send({ error: 'Phone already in use' });
    }

    // Anti-spam: oxirgi kod 60 soniya ichida yuborilgan bo'lsa — 429.
    const recent = await prisma.otpCode.findFirst({
      where: { phone, createdAt: { gt: new Date(Date.now() - OTP_RESEND_COOLDOWN_MS) } },
    });
    if (recent) {
      return reply.code(429).send({ error: 'Kod yaqinda yuborildi. Biroz kuting.' });
    }

    const code = String(Math.floor(100000 + Math.random() * 900000));
    await prisma.otpCode.create({
      data: { phone, code, expiresAt: new Date(Date.now() + OTP_TTL_MS) },
    });

    const sms = await sendSms(phone, `Farzandim — tasdiqlash kodingiz: ${code}`);
    if (!sms.sent) {
      request.log.error({ phone, err: sms.error }, 'OTP SMS yuborilmadi');
      return reply.code(502).send({ error: "SMS yuborib bo'lmadi" });
    }

    return reply.send({ ok: true, message: 'Tasdiqlash kodi yuborildi' });
  });

  /**
   * POST /api/users/me/phone/verify
   * OTP kodni tekshiradi va to'g'ri bo'lsa telefon raqamni saqlaydi.
   */
  fastify.post('/me/phone/verify', async (request, reply) => {
    const userId = request.user!.userId;

    const parsed = verifyPhoneSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
    }
    const { phone, code } = parsed.data;

    const otp = await prisma.otpCode.findFirst({
      where: { phone, verifiedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
    });
    if (!otp) {
      return reply.code(400).send({ error: 'Kod topilmadi yoki muddati tugagan' });
    }
    if (otp.attempts >= OTP_MAX_ATTEMPTS) {
      return reply.code(429).send({ error: "Juda ko'p urinish. Yangi kod so'rang." });
    }
    if (otp.code !== code) {
      await prisma.otpCode.update({
        where: { id: otp.id },
        data: { attempts: { increment: 1 } },
      });
      return reply.code(400).send({ error: "Noto'g'ri kod" });
    }

    // Race: tasdiqlash payti raqam boshqa userga o'tib ketmaganini qayta tekshiramiz.
    const existing = await prisma.user.findUnique({ where: { phone } });
    if (existing && existing.id !== userId) {
      return reply.code(409).send({ error: 'Phone already in use' });
    }

    await prisma.$transaction([
      prisma.otpCode.update({
        where: { id: otp.id },
        data: { verifiedAt: new Date() },
      }),
      prisma.user.update({ where: { id: userId }, data: { phone } }),
    ]);

    return reply.send({ id: userId, phone, isPhoneVerified: true });
  });
};
