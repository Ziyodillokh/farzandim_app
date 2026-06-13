import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../../common/database/prisma.service';
import { StorageService } from '../../../common/storage/storage.service';
import { BUCKETS } from '../../../common/storage/storage.constants';
import { CreateVideoDto, UpdateVideoDto } from './dto/create-video.dto';

const MAX_VIDEO_BYTES = 90 * 1024 * 1024;
const MAX_THUMB_BYTES = 5 * 1024 * 1024;
const SIX_DAYS_SEC = 6 * 86_400;

const ALLOWED_VIDEO_MIMES = [
  'video/mp4',
  'video/webm',
  'video/quicktime',
  'video/x-matroska',
];
const ALLOWED_IMAGE_MIMES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
];

export type BulkVideoAction =
  | 'approve'
  | 'reject'
  | 'hide'
  | 'feature'
  | 'unfeature'
  | 'delete';

@Injectable()
export class VideosService {
  private readonly logger = new Logger(VideosService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  private rowOf(v: any) {
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

  async list(query: {
    page: number;
    limit: number;
    q?: string;
    status?: string;
    categoryId?: string;
    planRequired?: string;
    level?: string;
    ageFrom?: number;
    ageTo?: number;
  }) {
    const { page, limit, q, status, categoryId, planRequired, level, ageFrom, ageTo } = query;
    const where: Prisma.VideoWhereInput = {};
    if (status) where.status = status;
    if (categoryId) where.categoryId = categoryId;
    if (planRequired) where.planRequired = planRequired;
    if (level) where.level = level;
    if (ageFrom !== undefined) where.ageTo = { gte: ageFrom };
    if (ageTo !== undefined) where.ageFrom = { lte: ageTo };
    if (q && q.trim().length > 0) {
      where.OR = [
        { title: { contains: q.trim(), mode: 'insensitive' } },
        { description: { contains: q.trim(), mode: 'insensitive' } },
      ];
    }

    const [total, rows] = await Promise.all([
      this.prisma.video.count({ where }),
      this.prisma.video.findMany({
        where,
        orderBy: [{ featured: 'desc' }, { createdAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    return {
      items: rows.map((r) => this.rowOf(r)),
      pagination: { page, totalPages: Math.max(1, Math.ceil(total / limit)), total, limit },
    };
  }

  async create(dto: CreateVideoDto) {
    const created = await this.prisma.video.create({
      data: {
        title: dto.title,
        description: dto.description ?? null,
        url: dto.url,
        thumbnail: dto.thumbnail ?? null,
        durationSec: dto.durationSec ?? null,
        ageFrom: dto.ageFrom ?? 0,
        ageTo: dto.ageTo ?? 18,
        categoryId: dto.categoryId ?? null,
        planRequired: dto.planRequired ?? 'free',
        level: dto.level ?? null,
        status: dto.status ?? 'approved',
        featured: dto.featured ?? false,
      },
    });
    return this.rowOf(created);
  }

  async update(id: string, dto: UpdateVideoDto) {
    const updates: Prisma.VideoUpdateInput = {};
    if (dto.title !== undefined) updates.title = dto.title;
    if (dto.description !== undefined) updates.description = dto.description ?? null;
    if (dto.thumbnail !== undefined) updates.thumbnail = dto.thumbnail ?? null;
    if (dto.durationSec !== undefined) updates.durationSec = dto.durationSec;
    if (dto.ageFrom !== undefined) updates.ageFrom = dto.ageFrom;
    if (dto.ageTo !== undefined) updates.ageTo = dto.ageTo;
    if (dto.categoryId !== undefined) updates.categoryId = dto.categoryId ?? null;
    if (dto.planRequired !== undefined) updates.planRequired = dto.planRequired;
    if (dto.level !== undefined) updates.level = dto.level ?? null;
    if (dto.status !== undefined) updates.status = dto.status;
    if (dto.featured !== undefined) updates.featured = dto.featured;

    try {
      const updated = await this.prisma.video.update({ where: { id }, data: updates });
      return this.rowOf(updated);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Video not found');
      throw err;
    }
  }

  async approve(id: string) {
    try {
      const updated = await this.prisma.video.update({ where: { id }, data: { status: 'approved' } });
      return this.rowOf(updated);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Video not found');
      throw err;
    }
  }

  async reject(id: string) {
    try {
      const updated = await this.prisma.video.update({ where: { id }, data: { status: 'rejected' } });
      return this.rowOf(updated);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Video not found');
      throw err;
    }
  }

  /**
   * Port of Fastify `POST /admin/videos/upload`. Uploads the main video and an
   * optional thumbnail to MinIO, persists a Video row with storageKey set so
   * consumer endpoints can re-sign URLs.
   */
  async upload(
    video: { buffer: Buffer; mimetype: string; originalname: string },
    thumb: { buffer: Buffer; mimetype: string; originalname: string } | null,
    meta: any,
  ) {
    if (!video?.buffer) throw new BadRequestException('videoFile required');
    if (video.buffer.length > MAX_VIDEO_BYTES) {
      throw new BadRequestException(`Video too large (max ${MAX_VIDEO_BYTES})`);
    }
    if (!ALLOWED_VIDEO_MIMES.includes(video.mimetype)) {
      throw new BadRequestException(
        `Unsupported video format: ${video.mimetype}`,
      );
    }
    if (thumb) {
      if (thumb.buffer.length > MAX_THUMB_BYTES) {
        throw new BadRequestException(
          `Thumbnail too large (max ${MAX_THUMB_BYTES})`,
        );
      }
      if (!ALLOWED_IMAGE_MIMES.includes(thumb.mimetype)) {
        throw new BadRequestException(
          `Unsupported image format: ${thumb.mimetype}`,
        );
      }
    }
    if (!meta?.title) throw new BadRequestException('metadata.title required');

    const id = randomUUID();
    const videoExt = video.originalname.includes('.')
      ? '.' + video.originalname.split('.').pop()
      : '.mp4';
    const videoKey = `videos/${id}${videoExt}`;
    try {
      await this.storage.upload(
        BUCKETS.contentVideos,
        videoKey,
        video.buffer,
        video.mimetype,
      );
    } catch (err) {
      this.logger.error(
        `admin-videos/upload: video MinIO upload failed: ${(err as Error).message}`,
      );
      throw err;
    }
    const videoUrl = await this.storage.getSignedUrl(
      BUCKETS.contentVideos,
      videoKey,
      SIX_DAYS_SEC,
    );

    let thumbnailUrl: string | null = null;
    let thumbStorageKey: string | null = null;
    if (thumb) {
      const thumbExt = thumb.originalname.includes('.')
        ? '.' + thumb.originalname.split('.').pop()
        : '.jpg';
      const thumbKey = `thumbnails/${id}${thumbExt}`;
      try {
        await this.storage.upload(
          BUCKETS.contentThumbnails,
          thumbKey,
          thumb.buffer,
          thumb.mimetype,
        );
        thumbnailUrl = await this.storage.getSignedUrl(
          BUCKETS.contentThumbnails,
          thumbKey,
          SIX_DAYS_SEC,
        );
        thumbStorageKey = thumbKey;
      } catch (err) {
        this.logger.warn(
          `admin-videos/upload: thumbnail failed (continuing): ${(err as Error).message}`,
        );
      }
    }

    const created = await this.prisma.video.create({
      data: {
        title: meta.title,
        description: meta.description ?? null,
        url: videoUrl,
        thumbnail: thumbnailUrl ?? meta.thumbnail ?? null,
        storageKey: videoKey,
        thumbStorageKey,
        durationSec: meta.durationSec ?? null,
        ageFrom: meta.ageFrom ?? 0,
        ageTo: meta.ageTo ?? 18,
        categoryId: meta.categoryId ?? null,
        planRequired: meta.planRequired ?? 'free',
        level: meta.level ?? null,
        status: meta.status ?? 'approved',
        featured: meta.featured ?? false,
      },
    });
    return {
      ...this.rowOf(created),
      storage: {
        videoKey,
        bucket: BUCKETS.contentVideos,
        sizeBytes: video.buffer.length,
      },
    };
  }

  /**
   * Port of Fastify `POST /admin/videos/bulk`. Supports approve/reject/hide/
   * feature/unfeature/delete over a list of video IDs. Deletes also clean up
   * MinIO storage keys.
   */
  async bulk(ids: string[], action: BulkVideoAction) {
    let updated = 0;
    let deleted = 0;
    switch (action) {
      case 'approve': {
        const r = await this.prisma.video.updateMany({
          where: { id: { in: ids } },
          data: { status: 'approved' },
        });
        updated = r.count;
        break;
      }
      case 'reject': {
        const r = await this.prisma.video.updateMany({
          where: { id: { in: ids } },
          data: { status: 'rejected' },
        });
        updated = r.count;
        break;
      }
      case 'hide': {
        const r = await this.prisma.video.updateMany({
          where: { id: { in: ids } },
          data: { status: 'hidden' },
        });
        updated = r.count;
        break;
      }
      case 'feature': {
        const r = await this.prisma.video.updateMany({
          where: { id: { in: ids } },
          data: { featured: true },
        });
        updated = r.count;
        break;
      }
      case 'unfeature': {
        const r = await this.prisma.video.updateMany({
          where: { id: { in: ids } },
          data: { featured: false },
        });
        updated = r.count;
        break;
      }
      case 'delete': {
        const rows = await this.prisma.video.findMany({
          where: { id: { in: ids } },
          select: { storageKey: true, thumbStorageKey: true },
        });
        const r = await this.prisma.video.deleteMany({
          where: { id: { in: ids } },
        });
        deleted = r.count;
        await Promise.allSettled(
          rows.flatMap((row) => [
            row.storageKey
              ? this.storage.delete(BUCKETS.contentVideos, row.storageKey)
              : Promise.resolve(),
            row.thumbStorageKey
              ? this.storage.delete(
                  BUCKETS.contentThumbnails,
                  row.thumbStorageKey,
                )
              : Promise.resolve(),
          ]),
        );
        break;
      }
      default:
        throw new BadRequestException(`Unknown action: ${String(action)}`);
    }
    return { ok: true, updated, deleted };
  }

  async remove(id: string) {
    try {
      const existing = await this.prisma.video.findUnique({
        where: { id },
        select: { storageKey: true, thumbStorageKey: true },
      });
      if (!existing) throw new NotFoundException('Video not found');
      await this.prisma.video.delete({ where: { id } });
      await Promise.allSettled([
        existing.storageKey ? this.storage.delete(BUCKETS.contentVideos, existing.storageKey) : Promise.resolve(),
        existing.thumbStorageKey ? this.storage.delete(BUCKETS.contentThumbnails, existing.thumbStorageKey) : Promise.resolve(),
      ]);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Video not found');
      throw err;
    }
  }
}
