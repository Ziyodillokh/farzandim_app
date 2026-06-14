import {
  Injectable,
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { StorageService } from '../../common/storage/storage.service';
import { mediaProxyUrl, MediaSegment } from './media-proxy';
import { BUCKETS, BucketName } from '../../common/storage/storage.constants';

const SIGNED_URL_TTL_SECONDS = 60 * 60; // 1 hour

// Tarif darajalari (past -> baland). Obuna shu rankdan past yoki teng
// kontentni ko'radi. Slug'lar entitlementTier va planRequired DTO bilan
// bir xil: free/standard/premium/vip.
const PLAN_RANK: Record<string, number> = {
  free: 0,
  standard: 1,
  premium: 2,
  vip: 3,
};

interface ChildContext {
  childId: string;
  age: number | null;
  parentPlan: string;
}

@Injectable()
export class ConsumerContentService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  private async resignOrFallback(
    bucket: BucketName,
    storageKey: string | null,
    fallbackUrl: string,
  ): Promise<string> {
    if (!storageKey) return fallbackUrl;
    try {
      return await this.storage.getSignedUrl(
        bucket,
        storageKey,
        SIGNED_URL_TTL_SECONDS,
      );
    } catch {
      return fallbackUrl;
    }
  }

  private async resignOptional(
    bucket: BucketName,
    storageKey: string | null,
    fallbackUrl: string | null,
  ): Promise<string | null> {
    if (!storageKey) return fallbackUrl;
    try {
      return await this.storage.getSignedUrl(
        bucket,
        storageKey,
        SIGNED_URL_TTL_SECONDS,
      );
    } catch {
      return fallbackUrl;
    }
  }

  async loadChildContext(userId: string): Promise<ChildContext> {
    const childUser = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { childRecord: true },
    });
    if (
      !childUser ||
      childUser.role !== 'CHILD' ||
      !childUser.childRecord
    ) {
      throw new ForbiddenException('Child profile required');
    }
    const child = childUser.childRecord;

    // Get active subscription for parent -> entitlement tier
    const subscription = await this.prisma.subscription.findFirst({
      where: {
        userId: child.parentId,
        status: 'ACTIVE',
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
      },
      orderBy: { expiresAt: 'desc' },
      include: { plan: true },
    });

    const parentPlan = subscription?.plan?.entitlementTier ?? 'free';

    return {
      childId: child.id,
      age: child.age,
      parentPlan,
    };
  }

  private allowedPlans(parentPlan: string): string[] {
    const rank = PLAN_RANK[parentPlan] ?? 0;
    return Object.entries(PLAN_RANK)
      .filter(([, r]) => r <= rank)
      .map(([slug]) => slug);
  }

  async getMe(userId: string) {
    const ctx = await this.loadChildContext(userId);
    return {
      childId: ctx.childId,
      age: ctx.age,
      parentPlan: ctx.parentPlan,
      allowedPlans: this.allowedPlans(ctx.parentPlan),
    };
  }

  async getVideos(userId: string, origin: string, page: number, limit: number) {
    const ctx = await this.loadChildContext(userId);
    const a = ctx.age ?? 8;

    const where: Prisma.VideoWhereInput = {
      status: 'approved',
      ageFrom: { lte: a },
      ageTo: { gte: a },
      planRequired: { in: this.allowedPlans(ctx.parentPlan) },
    };

    const [total, rows] = await Promise.all([
      this.prisma.video.count({ where }),
      this.prisma.video.findMany({
        where,
        orderBy: [{ featured: 'desc' }, { createdAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    // Proxy URL (telefonga yetadi); storageKey yo'q bo'lsa (YouTube/link)
    // asl tashqi url ishlatiladi.
    const items = rows.map((v) => ({
      id: v.id,
      title: v.title,
      description: v.description,
      url: mediaProxyUrl(origin, 'video', v.storageKey) ?? v.url,
      thumbnail:
        mediaProxyUrl(origin, 'thumb', v.thumbStorageKey) ?? v.thumbnail,
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
    }));

    return {
      items,
      pagination: {
        page,
        totalPages: Math.max(1, Math.ceil(total / limit)),
        total,
        limit,
      },
    };
  }

  async getAudiobooks(userId: string, origin: string, page: number, limit: number) {
    const ctx = await this.loadChildContext(userId);
    const a = ctx.age ?? 8;

    const where: Prisma.AudiobookWhereInput = {
      status: 'approved',
      ageFrom: { lte: a },
      ageTo: { gte: a },
      planRequired: { in: this.allowedPlans(ctx.parentPlan) },
    };

    const [total, rows] = await Promise.all([
      this.prisma.audiobook.count({ where }),
      this.prisma.audiobook.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    const items = rows.map((ab) => ({
      id: ab.id,
      title: ab.title,
      author: ab.author,
      description: ab.description,
      audioUrl: mediaProxyUrl(origin, 'audio', ab.storageKey) ?? ab.audioUrl,
      thumbnail:
        mediaProxyUrl(origin, 'thumb', ab.thumbStorageKey) ?? ab.thumbnail,
      durationSec: ab.durationSec,
      partsCount: ab.partsCount,
      ageFrom: ab.ageFrom,
      ageTo: ab.ageTo,
      category: ab.category,
      planRequired: ab.planRequired,
      listens: ab.listens,
      createdAt: ab.createdAt.toISOString(),
    }));

    return {
      items,
      pagination: {
        page,
        totalPages: Math.max(1, Math.ceil(total / limit)),
        total,
        limit,
      },
    };
  }

  async getBooks(userId: string, origin: string, page: number, limit: number) {
    const ctx = await this.loadChildContext(userId);
    const a = ctx.age ?? 8;

    const where: Prisma.BookWhereInput = {
      status: 'approved',
      ageFrom: { lte: a },
      ageTo: { gte: a },
      planRequired: { in: this.allowedPlans(ctx.parentPlan) },
    };

    const [total, rows] = await Promise.all([
      this.prisma.book.count({ where }),
      this.prisma.book.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    const items = rows.map((b) => ({
      id: b.id,
      title: b.title,
      author: b.author,
      description: b.description,
      pdfUrl: mediaProxyUrl(origin, 'pdf', b.storageKey) ?? b.pdfUrl,
      coverUrl:
        mediaProxyUrl(origin, 'cover', b.thumbStorageKey) ?? b.coverUrl,
      pages: b.pages,
      ageFrom: b.ageFrom,
      ageTo: b.ageTo,
      category: b.category,
      planRequired: b.planRequired,
      reads: b.reads,
      createdAt: b.createdAt.toISOString(),
    }));

    return {
      items,
      pagination: {
        page,
        totalPages: Math.max(1, Math.ceil(total / limit)),
        total,
        limit,
      },
    };
  }

  /** Maqolalar — bola yoshiga mos + approved (#48). Markdown `body` qaytadi. */
  async getArticles(
    userId: string,
    origin: string,
    page: number,
    limit: number,
  ) {
    const ctx = await this.loadChildContext(userId);
    const a = ctx.age ?? 8;

    const where: Prisma.ArticleWhereInput = {
      status: 'approved',
      ageFrom: { lte: a },
      ageTo: { gte: a },
    };

    const [total, rows] = await Promise.all([
      this.prisma.article.count({ where }),
      this.prisma.article.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    const items = rows.map((r) => ({
      id: r.id,
      title: r.title,
      body: r.body,
      coverUrl: mediaProxyUrl(origin, 'cover', r.coverPath),
      ageFrom: r.ageFrom,
      ageTo: r.ageTo,
      category: r.category,
      views: r.views,
      createdAt: r.createdAt.toISOString(),
    }));

    return {
      items,
      pagination: {
        page,
        totalPages: Math.max(1, Math.ceil(total / limit)),
        total,
        limit,
      },
    };
  }

  async getCategories(kind?: string) {
    const where: Prisma.ContentCategoryWhereInput = {};
    if (kind) where.kind = kind;

    const rows = await this.prisma.contentCategory.findMany({
      where,
      orderBy: [{ kind: 'asc' }, { sortOrder: 'asc' }],
    });

    return rows.map((c) => ({
      id: c.id,
      kind: c.kind,
      slug: c.slug,
      name: c.name,
    }));
  }

  async recordVideoView(id: string) {
    try {
      await this.prisma.video.update({
        where: { id },
        data: { views: { increment: 1 } },
      });
      return { ok: true };
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        throw new NotFoundException('Video not found');
      }
      throw err;
    }
  }

  // Player aniqlagan haqiqiy davomiylikni yozadi — FAQAT hozir noma'lum
  // (null yoki 0) bo'lsa. Link orqali qo'shilgan YouTube videolari uchun:
  // admin duration kiritmaydi, bola ko'rganda player o'zi to'g'rilab beradi.
  // updateMany shart bilan — admin kiritgan qiymatni hech qachon bosmaydi.
  async reportVideoDuration(id: string, durationSec: number) {
    const res = await this.prisma.video.updateMany({
      where: {
        id,
        OR: [{ durationSec: null }, { durationSec: 0 }],
      },
      data: { durationSec: Math.round(durationSec) },
    });
    return { ok: true, updated: res.count };
  }

  // Audiokitob player aniqlagan haqiqiy davomiylik — faqat noma'lum (0/null)
  // bo'lsa yoziladi (admin upload paytida durationSec yubormaydi).
  async reportAudiobookDuration(id: string, durationSec: number) {
    const res = await this.prisma.audiobook.updateMany({
      where: {
        id,
        OR: [{ durationSec: null }, { durationSec: 0 }],
      },
      data: { durationSec: Math.round(durationSec) },
    });
    return { ok: true, updated: res.count };
  }

  // @Public content media proxy — xom signed MinIO URL telefonga yetmaydi,
  // shuning uchun baytlarni backend orqali stream qilamiz (voice/video media
  // bilan bir xil). `file` — storageKey'ning oxirgi qismi (uuid.ext).
  private resolveMediaKey(
    segment: string,
    file: string,
  ): { bucket: BucketName; key: string } {
    if (file.includes('/') || file.includes('..')) {
      throw new BadRequestException('Invalid media key');
    }
    const map: Record<MediaSegment, { bucket: BucketName; prefix: string }> = {
      audio: { bucket: BUCKETS.contentAudio, prefix: 'audio/' },
      thumb: { bucket: BUCKETS.contentThumbnails, prefix: 'thumbnails/' },
      cover: { bucket: BUCKETS.contentThumbnails, prefix: 'covers/' },
      video: { bucket: BUCKETS.contentVideos, prefix: 'videos/' },
      pdf: { bucket: BUCKETS.contentBooks, prefix: 'books/' },
    };
    const m = map[segment as MediaSegment];
    if (!m) throw new NotFoundException('Media not found');
    return { bucket: m.bucket, key: m.prefix + file };
  }

  // Range-aware media stream — audio/video seek va M4A moov uchun shart.
  // `range` berilsa MinIO 206 (Content-Range bilan) qaytaradi.
  async getMediaStream(segment: string, file: string, range?: string) {
    const { bucket, key } = this.resolveMediaKey(segment, file);
    return this.storage.getObjectStream(bucket, key, range);
  }

  async recordVideoLike(id: string) {
    try {
      const updated = await this.prisma.video.update({
        where: { id },
        data: { likes: { increment: 1 } },
      });
      return { ok: true, likes: updated.likes };
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        throw new NotFoundException('Video not found');
      }
      throw err;
    }
  }

  async recordAudiobookPlay(id: string) {
    try {
      await this.prisma.audiobook.update({
        where: { id },
        data: { listens: { increment: 1 } },
      });
      return { ok: true };
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        throw new NotFoundException('Audiobook not found');
      }
      throw err;
    }
  }

  async recordBookRead(id: string) {
    try {
      await this.prisma.book.update({
        where: { id },
        data: { reads: { increment: 1 } },
      });
      return { ok: true };
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        throw new NotFoundException('Book not found');
      }
      throw err;
    }
  }

  async recordArticleRead(id: string) {
    try {
      await this.prisma.article.update({
        where: { id },
        data: { views: { increment: 1 } },
      });
      return { ok: true };
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        throw new NotFoundException('Article not found');
      }
      throw err;
    }
  }
}
