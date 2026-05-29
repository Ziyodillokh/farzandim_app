import {
  Injectable,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { StorageService } from '../../common/storage/storage.service';
import { BUCKETS, BucketName } from '../../common/storage/storage.constants';

const SIGNED_URL_TTL_SECONDS = 60 * 60; // 1 hour

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

  async getVideos(userId: string, page: number, limit: number) {
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

    const items = await Promise.all(
      rows.map(async (v) => {
        const [url, thumbnail] = await Promise.all([
          this.resignOrFallback(BUCKETS.contentVideos, v.storageKey, v.url),
          this.resignOptional(
            BUCKETS.contentThumbnails,
            v.thumbStorageKey,
            v.thumbnail,
          ),
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
      }),
    );

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

  async getAudiobooks(userId: string, page: number, limit: number) {
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

    const items = await Promise.all(
      rows.map(async (ab) => {
        const [audioUrl, thumbnail] = await Promise.all([
          this.resignOrFallback(
            BUCKETS.contentAudio,
            ab.storageKey,
            ab.audioUrl,
          ),
          this.resignOptional(
            BUCKETS.contentThumbnails,
            ab.thumbStorageKey,
            ab.thumbnail,
          ),
        ]);
        return {
          id: ab.id,
          title: ab.title,
          author: ab.author,
          description: ab.description,
          audioUrl,
          thumbnail,
          durationSec: ab.durationSec,
          partsCount: ab.partsCount,
          ageFrom: ab.ageFrom,
          ageTo: ab.ageTo,
          category: ab.category,
          planRequired: ab.planRequired,
          listens: ab.listens,
          createdAt: ab.createdAt.toISOString(),
        };
      }),
    );

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

  async getBooks(userId: string, page: number, limit: number) {
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

    const items = await Promise.all(
      rows.map(async (b) => {
        const [pdfUrl, coverUrl] = await Promise.all([
          this.resignOptional(BUCKETS.contentBooks, b.storageKey, b.pdfUrl),
          this.resignOptional(
            BUCKETS.contentThumbnails,
            b.thumbStorageKey,
            b.coverUrl,
          ),
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
    );

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
}
