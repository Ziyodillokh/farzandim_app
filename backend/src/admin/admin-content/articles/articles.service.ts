import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, Article } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../../common/database/prisma.service';
import { StorageService } from '../../../common/storage/storage.service';
import { BUCKETS } from '../../../common/storage/storage.constants';
import { CreateArticleDto, UpdateArticleDto } from './dto/create-article.dto';

const MAX_COVER_BYTES = 5 * 1024 * 1024;
const ALLOWED_IMAGE_MIMES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
];

@Injectable()
export class ArticlesService {
  private readonly logger = new Logger(ArticlesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  private rowOf(a: Article) {
    return {
      id: a.id,
      title: a.title,
      body: a.body,
      coverPath: a.coverPath,
      ageFrom: a.ageFrom,
      ageTo: a.ageTo,
      category: a.category,
      status: a.status,
      views: a.views,
      likes: a.likes,
      createdAt: a.createdAt.toISOString(),
      updatedAt: a.updatedAt.toISOString(),
    };
  }

  async list(query: {
    page: number;
    limit: number;
    q?: string;
    status?: string;
    category?: string;
    ageFrom?: number;
    ageTo?: number;
  }) {
    const { page, limit, q, status, category, ageFrom, ageTo } = query;
    const where: Prisma.ArticleWhereInput = {};
    if (status) where.status = status;
    if (category) where.category = category;
    if (ageFrom !== undefined) where.ageTo = { gte: ageFrom };
    if (ageTo !== undefined) where.ageFrom = { lte: ageTo };
    if (q && q.trim().length > 0) {
      where.title = { contains: q.trim(), mode: 'insensitive' };
    }

    const [total, rows] = await Promise.all([
      this.prisma.article.count({ where }),
      this.prisma.article.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    return {
      items: rows.map((r) => this.rowOf(r)),
      pagination: {
        page,
        totalPages: Math.max(1, Math.ceil(total / limit)),
        total,
        limit,
      },
    };
  }

  async create(dto: CreateArticleDto) {
    const created = await this.prisma.article.create({
      data: {
        title: dto.title,
        body: dto.body,
        coverPath: dto.coverPath ?? null,
        ageFrom: dto.ageFrom ?? 0,
        ageTo: dto.ageTo ?? 18,
        category: dto.category ?? null,
        status: dto.status ?? 'approved',
      },
    });
    return this.rowOf(created);
  }

  async update(id: string, dto: UpdateArticleDto) {
    const updates: Prisma.ArticleUpdateInput = {};
    if (dto.title !== undefined) updates.title = dto.title;
    if (dto.body !== undefined) updates.body = dto.body;
    if (dto.coverPath !== undefined) updates.coverPath = dto.coverPath ?? null;
    if (dto.ageFrom !== undefined) updates.ageFrom = dto.ageFrom;
    if (dto.ageTo !== undefined) updates.ageTo = dto.ageTo;
    if (dto.category !== undefined) updates.category = dto.category ?? null;
    if (dto.status !== undefined) updates.status = dto.status;
    try {
      const updated = await this.prisma.article.update({
        where: { id },
        data: updates,
      });
      return this.rowOf(updated);
    } catch (err) {
      if ((err as { code?: string }).code === 'P2025') {
        throw new NotFoundException('Article not found');
      }
      throw err;
    }
  }

  async setStatus(id: string, status: string) {
    try {
      const updated = await this.prisma.article.update({
        where: { id },
        data: { status },
      });
      return this.rowOf(updated);
    } catch (err) {
      if ((err as { code?: string }).code === 'P2025') {
        throw new NotFoundException('Article not found');
      }
      throw err;
    }
  }

  /** Muqova rasmni MinIO'ga yuklab `coverPath`ni o'rnatadi (media proxy 'cover'). */
  async uploadCover(
    id: string,
    cover: { buffer: Buffer; mimetype: string; originalname: string },
  ) {
    const existing = await this.prisma.article.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Article not found');
    if (!cover?.buffer) throw new BadRequestException('coverFile required');
    if (cover.buffer.length > MAX_COVER_BYTES) {
      throw new BadRequestException(`Cover too large (max ${MAX_COVER_BYTES})`);
    }
    if (!ALLOWED_IMAGE_MIMES.includes(cover.mimetype)) {
      throw new BadRequestException(
        `Unsupported image format: ${cover.mimetype}`,
      );
    }

    const ext = cover.originalname.includes('.')
      ? '.' + cover.originalname.split('.').pop()
      : '.jpg';
    const coverKey = `articles/${id}-${randomUUID()}${ext}`;
    await this.storage.upload(
      BUCKETS.contentThumbnails,
      coverKey,
      cover.buffer,
      cover.mimetype,
    );
    // Eski muqovani o'chiramiz (bo'lsa).
    if (existing.coverPath) {
      await this.storage
        .delete(BUCKETS.contentThumbnails, existing.coverPath)
        .catch(() => {
          /* eski fayl yo'q — e'tiborsiz */
        });
    }
    const updated = await this.prisma.article.update({
      where: { id },
      data: { coverPath: coverKey },
    });
    return this.rowOf(updated);
  }

  async remove(id: string) {
    const existing = await this.prisma.article.findUnique({
      where: { id },
      select: { coverPath: true },
    });
    if (!existing) throw new NotFoundException('Article not found');
    await this.prisma.article.delete({ where: { id } });
    if (existing.coverPath) {
      await this.storage
        .delete(BUCKETS.contentThumbnails, existing.coverPath)
        .catch(() => {
          /* e'tiborsiz */
        });
    }
  }
}
