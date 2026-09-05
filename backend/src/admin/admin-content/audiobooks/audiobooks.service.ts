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
import { CreateAudiobookDto, UpdateAudiobookDto } from './dto/create-audiobook.dto';
import {
  normalizePlanRequired,
  normalizeXpReward,
} from '../content-meta.utils';

const MAX_AUDIO_BYTES = 90 * 1024 * 1024;
const MAX_THUMB_BYTES = 5 * 1024 * 1024;
const SIX_DAYS_SEC = 6 * 86_400;

const ALLOWED_AUDIO_MIMES = [
  'audio/mp4',
  'audio/mpeg',
  'audio/aac',
  'audio/x-m4a',
  'audio/m4a',
  'audio/wav',
  'audio/ogg',
  'audio/webm',
];
const ALLOWED_IMAGE_MIMES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
];

export type BulkAudiobookAction = 'approve' | 'reject' | 'hide' | 'delete';

@Injectable()
export class AudiobooksService {
  private readonly logger = new Logger(AudiobooksService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  private rowOf(a: any) {
    return {
      id: a.id,
      title: a.title,
      author: a.author,
      description: a.description,
      audioUrl: a.audioUrl,
      storageKey: a.storageKey,
      thumbStorageKey: a.thumbStorageKey,
      thumbnail: a.thumbnail,
      durationSec: a.durationSec,
      partsCount: a.partsCount,
      ageFrom: a.ageFrom,
      ageTo: a.ageTo,
      categoryId: a.categoryId,
      category: a.category,
      planRequired: a.planRequired,
      status: a.status,
      listens: a.listens,
      xpReward: a.xpReward,
      createdAt: a.createdAt.toISOString(),
      updatedAt: a.updatedAt.toISOString(),
    };
  }

  async list(query: {
    page: number;
    limit: number;
    q?: string;
    status?: string;
    categoryId?: string;
    planRequired?: string;
    ageFrom?: number;
    ageTo?: number;
  }) {
    const { page, limit, q, status, categoryId, planRequired, ageFrom, ageTo } = query;
    const where: Prisma.AudiobookWhereInput = {};
    if (status) where.status = status;
    if (categoryId) where.categoryId = categoryId;
    if (planRequired) where.planRequired = planRequired;
    if (ageFrom !== undefined) where.ageTo = { gte: ageFrom };
    if (ageTo !== undefined) where.ageFrom = { lte: ageTo };
    if (q && q.trim().length > 0) {
      where.OR = [
        { title: { contains: q.trim(), mode: 'insensitive' } },
        { author: { contains: q.trim(), mode: 'insensitive' } },
      ];
    }

    const [total, rows] = await Promise.all([
      this.prisma.audiobook.count({ where }),
      this.prisma.audiobook.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    return {
      items: rows.map((r) => this.rowOf(r)),
      pagination: { page, totalPages: Math.max(1, Math.ceil(total / limit)), total, limit },
    };
  }

  async create(dto: CreateAudiobookDto) {
    const created = await this.prisma.audiobook.create({
      data: {
        title: dto.title,
        author: dto.author,
        description: dto.description ?? null,
        audioUrl: dto.audioUrl,
        thumbnail: dto.thumbnail ?? null,
        durationSec: dto.durationSec ?? null,
        partsCount: dto.partsCount ?? 1,
        ageFrom: dto.ageFrom ?? 0,
        ageTo: dto.ageTo ?? 18,
        categoryId: dto.categoryId ?? null,
        planRequired: dto.planRequired ?? 'free',
        status: dto.status ?? 'approved',
        xpReward: dto.xpReward ?? 50,
      },
    });
    return this.rowOf(created);
  }

  async update(id: string, dto: UpdateAudiobookDto) {
    const updates: Prisma.AudiobookUpdateInput = {};
    if (dto.title !== undefined) updates.title = dto.title;
    if (dto.author !== undefined) updates.author = dto.author;
    if (dto.description !== undefined) updates.description = dto.description ?? null;
    if (dto.audioUrl !== undefined) updates.audioUrl = dto.audioUrl;
    if (dto.thumbnail !== undefined) updates.thumbnail = dto.thumbnail ?? null;
    if (dto.durationSec !== undefined) updates.durationSec = dto.durationSec;
    if (dto.partsCount !== undefined) updates.partsCount = dto.partsCount;
    if (dto.ageFrom !== undefined) updates.ageFrom = dto.ageFrom;
    if (dto.ageTo !== undefined) updates.ageTo = dto.ageTo;
    if (dto.categoryId !== undefined) updates.categoryId = dto.categoryId ?? null;
    if (dto.planRequired !== undefined) updates.planRequired = dto.planRequired;
    if (dto.status !== undefined) updates.status = dto.status;
    if (dto.xpReward !== undefined) updates.xpReward = dto.xpReward;
    try {
      const updated = await this.prisma.audiobook.update({ where: { id }, data: updates });
      return this.rowOf(updated);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Audiobook not found');
      throw err;
    }
  }

  async approve(id: string) {
    try {
      const updated = await this.prisma.audiobook.update({ where: { id }, data: { status: 'approved' } });
      return this.rowOf(updated);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Audiobook not found');
      throw err;
    }
  }

  async reject(id: string) {
    try {
      const updated = await this.prisma.audiobook.update({ where: { id }, data: { status: 'rejected' } });
      return this.rowOf(updated);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Audiobook not found');
      throw err;
    }
  }

  /**
   * Port of Fastify `POST /admin/audiobooks/upload`. Uploads main audio and an
   * optional thumbnail to MinIO and persists a row with storageKey for consumer
   * re-signing.
   */
  async upload(
    audio: { buffer: Buffer; mimetype: string; originalname: string },
    thumb: { buffer: Buffer; mimetype: string; originalname: string } | null,
    meta: any,
  ) {
    if (!audio?.buffer) throw new BadRequestException('audioFile required');
    if (audio.buffer.length > MAX_AUDIO_BYTES) {
      throw new BadRequestException(`Audio too large (max ${MAX_AUDIO_BYTES})`);
    }
    if (!ALLOWED_AUDIO_MIMES.includes(audio.mimetype)) {
      throw new BadRequestException(
        `Unsupported audio format: ${audio.mimetype}`,
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
    if (!meta?.title || !meta?.author) {
      throw new BadRequestException('metadata.title and author required');
    }

    const id = randomUUID();
    const audioExt = audio.originalname.includes('.')
      ? '.' + audio.originalname.split('.').pop()
      : '.m4a';
    const audioKey = `audio/${id}${audioExt}`;
    try {
      await this.storage.upload(
        BUCKETS.contentAudio,
        audioKey,
        audio.buffer,
        audio.mimetype,
      );
    } catch (err) {
      this.logger.error(
        `admin-audiobooks/upload: audio MinIO upload failed: ${(err as Error).message}`,
      );
      throw err;
    }
    const audioUrl = await this.storage.getSignedUrl(
      BUCKETS.contentAudio,
      audioKey,
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
          `admin-audiobooks/upload: thumbnail failed: ${(err as Error).message}`,
        );
      }
    }

    const created = await this.prisma.audiobook.create({
      data: {
        title: meta.title,
        author: meta.author,
        description: meta.description ?? null,
        audioUrl,
        thumbnail: thumbnailUrl ?? meta.thumbnail ?? null,
        storageKey: audioKey,
        thumbStorageKey,
        durationSec: meta.durationSec ?? null,
        partsCount: meta.partsCount ?? 1,
        ageFrom: meta.ageFrom ?? 0,
        ageTo: meta.ageTo ?? 18,
        categoryId: meta.categoryId ?? null,
        planRequired: normalizePlanRequired(meta.planRequired),
        // xpReward ILGARI umuman yozilmasdi — admin kiritgan DON ball
        // e'tiborsiz qolib, har doim Prisma standarti (50) ishlatilardi.
        xpReward: normalizeXpReward(meta.xpReward),
        status: meta.status ?? 'approved',
      },
    });
    return {
      ...this.rowOf(created),
      storage: {
        audioKey,
        bucket: BUCKETS.contentAudio,
        sizeBytes: audio.buffer.length,
      },
    };
  }

  /**
   * Port of Fastify `POST /admin/audiobooks/bulk` — approve/reject/hide/delete.
   */
  async bulk(ids: string[], action: BulkAudiobookAction) {
    let updated = 0;
    let deleted = 0;
    if (action === 'approve' || action === 'reject' || action === 'hide') {
      const target =
        action === 'approve'
          ? 'approved'
          : action === 'reject'
          ? 'rejected'
          : 'hidden';
      const r = await this.prisma.audiobook.updateMany({
        where: { id: { in: ids } },
        data: { status: target },
      });
      updated = r.count;
    } else if (action === 'delete') {
      const rows = await this.prisma.audiobook.findMany({
        where: { id: { in: ids } },
        select: { storageKey: true, thumbStorageKey: true },
      });
      const r = await this.prisma.audiobook.deleteMany({
        where: { id: { in: ids } },
      });
      deleted = r.count;
      await Promise.allSettled(
        rows.flatMap((row) => [
          row.storageKey
            ? this.storage.delete(BUCKETS.contentAudio, row.storageKey)
            : Promise.resolve(),
          row.thumbStorageKey
            ? this.storage.delete(
                BUCKETS.contentThumbnails,
                row.thumbStorageKey,
              )
            : Promise.resolve(),
        ]),
      );
    } else {
      throw new BadRequestException(`Unknown action: ${String(action)}`);
    }
    return { ok: true, updated, deleted };
  }

  async remove(id: string) {
    try {
      const existing = await this.prisma.audiobook.findUnique({
        where: { id },
        select: { storageKey: true, thumbStorageKey: true },
      });
      if (!existing) throw new NotFoundException('Audiobook not found');
      await this.prisma.audiobook.delete({ where: { id } });
      await Promise.allSettled([
        existing.storageKey ? this.storage.delete(BUCKETS.contentAudio, existing.storageKey) : Promise.resolve(),
        existing.thumbStorageKey ? this.storage.delete(BUCKETS.contentThumbnails, existing.thumbStorageKey) : Promise.resolve(),
      ]);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Audiobook not found');
      throw err;
    }
  }
}
