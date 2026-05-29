import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { authGuard } from '../../middleware/auth';
import { BUCKETS, getDownloadUrl, type BucketName } from '../../lib/minio';
import { getActiveSubscription } from '../../lib/payments';

// Sprint 5.6c — har consumer fetch'da MinIO storage key'dan signed URL
// qayta sign qilish (1 soat TTL). Eski rowlarda storageKey=null bo'lsa,
// saqlangan url field ishlatiladi (CDN / 6-kunlik signed URL).
const SIGNED_URL_TTL_SECONDS = 60 * 60; // 1 soat

async function resignOrFallback(
  bucket: BucketName,
  storageKey: string | null,
  fallbackUrl: string,
): Promise<string> {
  if (!storageKey) return fallbackUrl;
  try {
    return await getDownloadUrl(bucket, storageKey, SIGNED_URL_TTL_SECONDS);
  } catch {
    return fallbackUrl;
  }
}

async function resignOptional(
  bucket: BucketName,
  storageKey: string | null,
  fallbackUrl: string | null,
): Promise<string | null> {
  if (!storageKey) return fallbackUrl;
  try {
    return await getDownloadUrl(bucket, storageKey, SIGNED_URL_TTL_SECONDS);
  } catch {
    return fallbackUrl;
  }
}

/**
 * Bola Child App'i admin tomonidan tasdiqlangan kontentni shu yerdan oladi.
 *
 *   admin video joylaydi → status=approved → bu endpoint qaytaradi
 *
 * Filter:
 *   - status='approved' faqat
 *   - child.age ageFrom..ageTo oraliqida
 *   - planRequired bola ota-onasining aktiv obunasiga mos bo'lsa
 *     (Subscription.plan.entitlementTier — Sprint 6)
 */

const PaginationQuery = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

const PLAN_RANK: Record<string, number> = {
  free: 0,
  basic: 1,
  standard: 2,
  premium: 3,
};

interface ChildContext {
  childId: string;
  age: number | null;
  parentPlan: string;
}

async function loadChildContext(userId: string): Promise<ChildContext | null> {
  // Child JWT'da userId = User row id (role: CHILD).
  const childUser = await prisma.user.findUnique({
    where: { id: userId },
    include: { childRecord: true },
  });
  if (!childUser || childUser.role !== 'CHILD' || !childUser.childRecord) {
    return null;
  }
  const child = childUser.childRecord;

  // Sprint 6 — ota-onaning entitlement tier'i aktiv obunadan olinadi
  // (avvalgi Payment-scan approximation o'rniga). Obuna yo'q → 'free'.
  const subscription = await getActiveSubscription(child.parentId);
  const parentPlan = subscription?.plan?.entitlementTier ?? 'free';

  return {
    childId: child.id,
    age: child.age,
    parentPlan,
  };
}

function ageFilter(age: number | null): Prisma.IntFilter {
  // Bola yoshi noma'lum bo'lsa default: 8 yosh (eng keng diapazonni qoplaydi)
  const a = age ?? 8;
  return { lte: a };
}

function allowedPlans(parentPlan: string): string[] {
  const rank = PLAN_RANK[parentPlan] ?? 0;
  return Object.entries(PLAN_RANK)
    .filter(([, r]) => r <= rank)
    .map(([slug]) => slug);
}

async function videoRow(v: {
  id: string;
  title: string;
  description: string | null;
  url: string;
  thumbnail: string | null;
  storageKey: string | null;
  thumbStorageKey: string | null;
  durationSec: number | null;
  ageFrom: number;
  ageTo: number;
  category: string | null;
  planRequired: string;
  level: string | null;
  featured: boolean;
  views: number;
  likes: number;
  createdAt: Date;
}) {
  const [url, thumbnail] = await Promise.all([
    resignOrFallback(BUCKETS.contentVideos, v.storageKey, v.url),
    resignOptional(BUCKETS.contentThumbnails, v.thumbStorageKey, v.thumbnail),
  ]);
  return {
    id: v.id,
    title: v.title,
    description: v.description,
    url,
    thumbnail,
    durationSec: v.durationSec,
    ageFrom: v.ageFrom,
    ageTo: v.ageTo,
    category: v.category,
    planRequired: v.planRequired,
    level: v.level,
    featured: v.featured,
    views: v.views,
    likes: v.likes,
    createdAt: v.createdAt.toISOString(),
  };
}

export const consumerContentRoutes: FastifyPluginAsync = async (fastify) => {
  // GET /api/content/me — debug helper: bola Child App'i o'z context'ini tekshirsin
  fastify.get('/me', { preHandler: authGuard }, async (request, reply) => {
    const userId = request.user?.userId;
    if (!userId) return reply.code(401).send({ error: 'Unauthorized' });
    const ctx = await loadChildContext(userId);
    if (!ctx) return reply.code(403).send({ error: 'Child profile required' });
    return reply.send({
      childId: ctx.childId,
      age: ctx.age,
      parentPlan: ctx.parentPlan,
      allowedPlans: allowedPlans(ctx.parentPlan),
    });
  });

  // GET /api/content/videos
  fastify.get('/videos', { preHandler: authGuard }, async (request, reply) => {
    const userId = request.user?.userId;
    if (!userId) return reply.code(401).send({ error: 'Unauthorized' });
    const ctx = await loadChildContext(userId);
    if (!ctx) return reply.code(403).send({ error: 'Child profile required' });

    const parsed = PaginationQuery.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Invalid query' });
    const { page, limit } = parsed.data;

    const a = ctx.age ?? 8;
    const where: Prisma.VideoWhereInput = {
      status: 'approved',
      ageFrom: { lte: a },
      ageTo: { gte: a },
      planRequired: { in: allowedPlans(ctx.parentPlan) },
    };
    const [total, rows] = await Promise.all([
      prisma.video.count({ where }),
      prisma.video.findMany({
        where,
        orderBy: [{ featured: 'desc' }, { createdAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return reply.send({
      items: await Promise.all(rows.map(videoRow)),
      pagination: { page, totalPages: Math.max(1, Math.ceil(total / limit)), total, limit },
    });
  });

  // GET /api/content/audiobooks
  fastify.get('/audiobooks', { preHandler: authGuard }, async (request, reply) => {
    const userId = request.user?.userId;
    if (!userId) return reply.code(401).send({ error: 'Unauthorized' });
    const ctx = await loadChildContext(userId);
    if (!ctx) return reply.code(403).send({ error: 'Child profile required' });

    const parsed = PaginationQuery.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Invalid query' });
    const { page, limit } = parsed.data;

    const a = ctx.age ?? 8;
    const where: Prisma.AudiobookWhereInput = {
      status: 'approved',
      ageFrom: { lte: a },
      ageTo: { gte: a },
      planRequired: { in: allowedPlans(ctx.parentPlan) },
    };
    const [total, rows] = await Promise.all([
      prisma.audiobook.count({ where }),
      prisma.audiobook.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return reply.send({
      items: await Promise.all(
        rows.map(async (a) => {
          const [audioUrl, thumbnail] = await Promise.all([
            resignOrFallback(BUCKETS.contentAudio, a.storageKey, a.audioUrl),
            resignOptional(BUCKETS.contentThumbnails, a.thumbStorageKey, a.thumbnail),
          ]);
          return {
            id: a.id,
            title: a.title,
            author: a.author,
            description: a.description,
            audioUrl,
            thumbnail,
            durationSec: a.durationSec,
            partsCount: a.partsCount,
            ageFrom: a.ageFrom,
            ageTo: a.ageTo,
            category: a.category,
            planRequired: a.planRequired,
            listens: a.listens,
            createdAt: a.createdAt.toISOString(),
          };
        }),
      ),
      pagination: { page, totalPages: Math.max(1, Math.ceil(total / limit)), total, limit },
    });
  });

  // GET /api/content/books
  fastify.get('/books', { preHandler: authGuard }, async (request, reply) => {
    const userId = request.user?.userId;
    if (!userId) return reply.code(401).send({ error: 'Unauthorized' });
    const ctx = await loadChildContext(userId);
    if (!ctx) return reply.code(403).send({ error: 'Child profile required' });

    const parsed = PaginationQuery.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Invalid query' });
    const { page, limit } = parsed.data;

    const a = ctx.age ?? 8;
    const where: Prisma.BookWhereInput = {
      status: 'approved',
      ageFrom: { lte: a },
      ageTo: { gte: a },
      planRequired: { in: allowedPlans(ctx.parentPlan) },
    };
    const [total, rows] = await Promise.all([
      prisma.book.count({ where }),
      prisma.book.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return reply.send({
      items: await Promise.all(
        rows.map(async (b) => {
          const [pdfUrl, coverUrl] = await Promise.all([
            resignOptional(BUCKETS.contentBooks, b.storageKey, b.pdfUrl),
            resignOptional(BUCKETS.contentThumbnails, b.thumbStorageKey, b.coverUrl),
          ]);
          return {
            id: b.id,
            title: b.title,
            author: b.author,
            description: b.description,
            pdfUrl,
            coverUrl,
            pages: b.pages,
            ageFrom: b.ageFrom,
            ageTo: b.ageTo,
            category: b.category,
            planRequired: b.planRequired,
            reads: b.reads,
            createdAt: b.createdAt.toISOString(),
          };
        }),
      ),
      pagination: { page, totalPages: Math.max(1, Math.ceil(total / limit)), total, limit },
    });
  });

  // GET /api/content/categories?kind=video|audiobook|book
  fastify.get('/categories', { preHandler: authGuard }, async (request, reply) => {
    const q = request.query as { kind?: string };
    const where: Prisma.ContentCategoryWhereInput = {};
    if (q.kind) where.kind = q.kind;
    const rows = await prisma.contentCategory.findMany({
      where,
      orderBy: [{ kind: 'asc' }, { sortOrder: 'asc' }],
    });
    return reply.send(
      rows.map((c) => ({ id: c.id, kind: c.kind, slug: c.slug, name: c.name })),
    );
  });

  // POST /api/content/videos/:id/view
  fastify.post('/videos/:id/view', { preHandler: authGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      await prisma.video.update({ where: { id }, data: { views: { increment: 1 } } });
      return reply.send({ ok: true });
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') return reply.code(404).send({ error: 'Video not found' });
      throw err;
    }
  });

  // POST /api/content/videos/:id/like
  fastify.post('/videos/:id/like', { preHandler: authGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      const updated = await prisma.video.update({
        where: { id },
        data: { likes: { increment: 1 } },
      });
      return reply.send({ ok: true, likes: updated.likes });
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') return reply.code(404).send({ error: 'Video not found' });
      throw err;
    }
  });

  // POST /api/content/audiobooks/:id/play (listens increment)
  fastify.post('/audiobooks/:id/play', { preHandler: authGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      await prisma.audiobook.update({ where: { id }, data: { listens: { increment: 1 } } });
      return reply.send({ ok: true });
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') return reply.code(404).send({ error: 'Audiobook not found' });
      throw err;
    }
  });

  // POST /api/content/books/:id/read
  fastify.post('/books/:id/read', { preHandler: authGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      await prisma.book.update({ where: { id }, data: { reads: { increment: 1 } } });
      return reply.send({ ok: true });
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') return reply.code(404).send({ error: 'Book not found' });
      throw err;
    }
  });

};
