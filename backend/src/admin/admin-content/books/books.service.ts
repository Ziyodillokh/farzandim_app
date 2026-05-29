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
import { CreateBookDto, UpdateBookDto } from './dto/create-book.dto';

const MAX_PDF_BYTES = 50 * 1024 * 1024;
const MAX_COVER_BYTES = 5 * 1024 * 1024;
const SIX_DAYS_SEC = 6 * 86_400;

const ALLOWED_PDF_MIMES = ['application/pdf'];
const ALLOWED_IMAGE_MIMES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
];

@Injectable()
export class BooksService {
  private readonly logger = new Logger(BooksService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  private rowOf(b: any) {
    return {
      id: b.id,
      title: b.title,
      author: b.author,
      description: b.description,
      pdfUrl: b.pdfUrl,
      coverUrl: b.coverUrl,
      pages: b.pages,
      ageFrom: b.ageFrom,
      ageTo: b.ageTo,
      category: b.category,
      categoryId: b.categoryId,
      planRequired: b.planRequired,
      status: b.status,
      reads: b.reads,
      createdAt: b.createdAt.toISOString(),
      updatedAt: b.updatedAt.toISOString(),
    };
  }

  async list(query: {
    page: number;
    limit: number;
    q?: string;
    status?: string;
    category?: string;
    planRequired?: string;
    ageFrom?: number;
    ageTo?: number;
  }) {
    const { page, limit, q, status, category, planRequired, ageFrom, ageTo } = query;
    const where: Prisma.BookWhereInput = {};
    if (status) where.status = status;
    if (category) where.category = category;
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
      this.prisma.book.count({ where }),
      this.prisma.book.findMany({
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

  async create(dto: CreateBookDto) {
    const created = await this.prisma.book.create({
      data: {
        title: dto.title,
        author: dto.author,
        description: dto.description ?? null,
        pdfUrl: dto.pdfUrl ?? null,
        coverUrl: dto.coverUrl ?? null,
        pages: dto.pages ?? 0,
        ageFrom: dto.ageFrom ?? 0,
        ageTo: dto.ageTo ?? 18,
        category: dto.category ?? 'school',
        planRequired: dto.planRequired ?? 'free',
        status: dto.status ?? 'hidden',
      },
    });
    return this.rowOf(created);
  }

  async update(id: string, dto: UpdateBookDto) {
    const updates: Prisma.BookUpdateInput = {};
    if (dto.title !== undefined) updates.title = dto.title;
    if (dto.author !== undefined) updates.author = dto.author;
    if (dto.description !== undefined) updates.description = dto.description ?? null;
    if (dto.pdfUrl !== undefined) updates.pdfUrl = dto.pdfUrl ?? null;
    if (dto.coverUrl !== undefined) updates.coverUrl = dto.coverUrl ?? null;
    if (dto.pages !== undefined) updates.pages = dto.pages;
    if (dto.ageFrom !== undefined) updates.ageFrom = dto.ageFrom;
    if (dto.ageTo !== undefined) updates.ageTo = dto.ageTo;
    if (dto.category !== undefined) updates.category = dto.category;
    if (dto.planRequired !== undefined) updates.planRequired = dto.planRequired;
    if (dto.status !== undefined) updates.status = dto.status;
    try {
      const updated = await this.prisma.book.update({ where: { id }, data: updates });
      return this.rowOf(updated);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Book not found');
      throw err;
    }
  }

  async approve(id: string) {
    try {
      const updated = await this.prisma.book.update({ where: { id }, data: { status: 'approved' } });
      return this.rowOf(updated);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Book not found');
      throw err;
    }
  }

  async reject(id: string) {
    try {
      const updated = await this.prisma.book.update({ where: { id }, data: { status: 'rejected' } });
      return this.rowOf(updated);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Book not found');
      throw err;
    }
  }

  /**
   * Port of Fastify `POST /admin/books/upload`. Uploads PDF + optional cover
   * image to MinIO and persists a Book row with storageKey set.
   */
  async upload(
    pdf: { buffer: Buffer; mimetype: string; originalname: string },
    cover: { buffer: Buffer; mimetype: string; originalname: string } | null,
    meta: any,
  ) {
    if (!pdf?.buffer) throw new BadRequestException('pdfFile required');
    if (pdf.buffer.length > MAX_PDF_BYTES) {
      throw new BadRequestException(`PDF too large (max ${MAX_PDF_BYTES})`);
    }
    if (!ALLOWED_PDF_MIMES.includes(pdf.mimetype)) {
      throw new BadRequestException(
        `Unsupported PDF format: ${pdf.mimetype}`,
      );
    }
    if (cover) {
      if (cover.buffer.length > MAX_COVER_BYTES) {
        throw new BadRequestException(
          `Cover too large (max ${MAX_COVER_BYTES})`,
        );
      }
      if (!ALLOWED_IMAGE_MIMES.includes(cover.mimetype)) {
        throw new BadRequestException(
          `Unsupported image format: ${cover.mimetype}`,
        );
      }
    }
    if (!meta?.title || !meta?.author) {
      throw new BadRequestException('metadata.title and author required');
    }

    const id = randomUUID();
    const pdfExt = pdf.originalname.includes('.')
      ? '.' + pdf.originalname.split('.').pop()
      : '.pdf';
    const pdfKey = `books/${id}${pdfExt}`;
    try {
      await this.storage.upload(
        BUCKETS.contentBooks,
        pdfKey,
        pdf.buffer,
        pdf.mimetype,
      );
    } catch (err) {
      this.logger.error(
        `admin-books/upload: PDF MinIO upload failed: ${(err as Error).message}`,
      );
      throw err;
    }
    const pdfUrl = await this.storage.getSignedUrl(
      BUCKETS.contentBooks,
      pdfKey,
      SIX_DAYS_SEC,
    );

    let coverUrl: string | null = null;
    let coverStorageKey: string | null = null;
    if (cover) {
      const coverExt = cover.originalname.includes('.')
        ? '.' + cover.originalname.split('.').pop()
        : '.jpg';
      const coverKey = `covers/${id}${coverExt}`;
      try {
        await this.storage.upload(
          BUCKETS.contentThumbnails,
          coverKey,
          cover.buffer,
          cover.mimetype,
        );
        coverUrl = await this.storage.getSignedUrl(
          BUCKETS.contentThumbnails,
          coverKey,
          SIX_DAYS_SEC,
        );
        coverStorageKey = coverKey;
      } catch (err) {
        this.logger.warn(
          `admin-books/upload: cover failed: ${(err as Error).message}`,
        );
      }
    }

    const created = await this.prisma.book.create({
      data: {
        title: meta.title,
        author: meta.author,
        description: meta.description ?? null,
        pdfUrl,
        coverUrl: coverUrl ?? meta.coverUrl ?? null,
        storageKey: pdfKey,
        thumbStorageKey: coverStorageKey,
        pages: meta.pages ?? 0,
        ageFrom: meta.ageFrom ?? 0,
        ageTo: meta.ageTo ?? 18,
        category: meta.category ?? 'school',
        planRequired: meta.planRequired ?? 'free',
        status: meta.status ?? 'hidden',
      },
    });
    return {
      ...this.rowOf(created),
      storage: {
        pdfKey,
        bucket: BUCKETS.contentBooks,
        sizeBytes: pdf.buffer.length,
      },
    };
  }

  async remove(id: string) {
    try {
      const existing = await this.prisma.book.findUnique({
        where: { id },
        select: { storageKey: true, thumbStorageKey: true },
      });
      if (!existing) throw new NotFoundException('Book not found');
      await this.prisma.book.delete({ where: { id } });
      await Promise.allSettled([
        existing.storageKey ? this.storage.delete(BUCKETS.contentBooks, existing.storageKey) : Promise.resolve(),
        existing.thumbStorageKey ? this.storage.delete(BUCKETS.contentThumbnails, existing.thumbStorageKey) : Promise.resolve(),
      ]);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Book not found');
      throw err;
    }
  }
}
