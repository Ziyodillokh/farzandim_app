import {
  BadRequestException,
  Injectable,
  NotFoundException,
  PayloadTooLargeException,
  UnsupportedMediaTypeException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { randomUUID } from 'crypto';
import { extname } from 'path';
import { PrismaService } from '../../common/database/prisma.service';
import { StorageService } from '../../common/storage/storage.service';
import { BUCKETS } from '../../common/storage/storage.constants';
import { CreateOlympiadDto, QuestionDto } from './dto/create-olympiad.dto';
import { UpdateOlympiadDto } from './dto/update-olympiad.dto';

const MAX_IMAGE_BYTES = 5 * 1024 * 1024; // 5 MB
const ALLOWED_IMAGE_MIMES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
];

@Injectable()
export class AdminOlympiadsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  private lifecycleOf(o: { status: string; startTime: Date; endTime: Date }): string {
    if (o.status !== 'published') return o.status;
    const now = Date.now();
    if (o.endTime.getTime() < now) return 'finished';
    if (o.startTime.getTime() > now) return 'scheduled';
    return 'active';
  }

  private olympiadRow(o: any) {
    return {
      id: o.id,
      title: o.title,
      description: o.description,
      coverKey: o.coverKey ?? null,
      subject: o.subject,
      ageFrom: o.ageFrom,
      ageTo: o.ageTo,
      type: o.type,
      difficulty: o.difficulty,
      planRequired: o.planRequired ?? 'free',
      startTime: o.startTime.toISOString(),
      endTime: o.endTime.toISOString(),
      durationMin: o.durationMin,
      xpReward: o.xpReward,
      shuffleQuestions: o.shuffleQuestions,
      shuffleAnswers: o.shuffleAnswers,
      hideResults: o.hideResults,
      allowBack: o.allowBack,
      certificateEnabled: o.certificateEnabled,
      status: o.status,
      lifecycle: this.lifecycleOf(o),
      participantCount: o._count?.attempts ?? 0,
      questionCount: o._count?.questions ?? 0,
      createdAt: o.createdAt.toISOString(),
      updatedAt: o.updatedAt.toISOString(),
    };
  }

  private questionRow(q: any) {
    return {
      id: q.id,
      olympiadId: q.olympiadId,
      text: q.text,
      options: q.options,
      optionImages: q.optionImages ?? [],
      correctIndex: q.correctIndex,
      points: q.points,
      orderIdx: q.orderIdx,
      imageKey: q.imageKey ?? null,
    };
  }

  async list(query: {
    page: number;
    limit: number;
    q?: string;
    status?: string;
    subject?: string;
    ageFrom?: number;
    ageTo?: number;
    dateFrom?: string;
    dateTo?: string;
  }) {
    const { page, limit, q, status, subject, ageFrom, ageTo, dateFrom, dateTo } = query;
    const where: Prisma.OlympiadWhereInput = {};
    if (status) where.status = status;
    if (subject) where.subject = subject;
    if (ageFrom !== undefined) where.ageTo = { gte: ageFrom };
    if (ageTo !== undefined) where.ageFrom = { lte: ageTo };
    if (dateFrom || dateTo) {
      where.startTime = {};
      if (dateFrom) where.startTime.gte = new Date(dateFrom);
      if (dateTo) where.startTime.lte = new Date(dateTo);
    }
    if (q && q.trim().length > 0) {
      where.OR = [
        { title: { contains: q.trim(), mode: 'insensitive' } },
        { description: { contains: q.trim(), mode: 'insensitive' } },
        { subject: { contains: q.trim(), mode: 'insensitive' } },
      ];
    }

    const [total, rows] = await Promise.all([
      this.prisma.olympiad.count({ where }),
      this.prisma.olympiad.findMany({
        where,
        include: { _count: { select: { questions: true, attempts: true } } },
        orderBy: [{ startTime: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    return {
      items: rows.map((r) => this.olympiadRow(r)),
      pagination: {
        page,
        totalPages: Math.max(1, Math.ceil(total / limit)),
        total,
        limit,
      },
    };
  }

  async findOne(id: string) {
    const o = await this.prisma.olympiad.findUnique({
      where: { id },
      include: {
        _count: { select: { questions: true, attempts: true } },
        questions: { orderBy: [{ orderIdx: 'asc' }, { createdAt: 'asc' }] },
      },
    });
    if (!o) throw new NotFoundException('Olympiad not found');
    return {
      ...this.olympiadRow(o),
      questions: o.questions.map((q) => this.questionRow(q)),
    };
  }

  async create(dto: CreateOlympiadDto) {
    const start = new Date(dto.startTime);
    const end = new Date(dto.endTime);
    if (start >= end) {
      throw new BadRequestException('startTime must be before endTime');
    }
    if (dto.ageFrom > dto.ageTo) {
      throw new BadRequestException('ageFrom must be <= ageTo');
    }

    for (const q of dto.questions ?? []) {
      if (!Array.isArray(q.options) || q.options.length < 2) {
        throw new BadRequestException(
          'Har bir savol kamida 2 ta variantga ega bo\'lishi shart',
        );
      }
      if (q.correctIndex < 0 || q.correctIndex >= q.options.length) {
        throw new BadRequestException('correctIndex out of range for question');
      }
    }
    // Nashr qilingan holatda yaratilsa — kamida 1 savol shart (bo'sh konkurs
    // bola tomonda darhol "tugagan" bo'lib qoladi).
    if ((dto.status ?? 'draft') === 'published' && (dto.questions?.length ?? 0) === 0) {
      throw new BadRequestException('Nashr qilish uchun kamida 1 savol kerak');
    }

    const created = await this.prisma.olympiad.create({
      data: {
        title: dto.title,
        description: dto.description ?? null,
        coverKey: dto.coverKey ?? null,
        subject: dto.subject,
        ageFrom: dto.ageFrom,
        ageTo: dto.ageTo,
        type: dto.type ?? 'test',
        difficulty: dto.difficulty ?? "o'rta",
        planRequired: dto.planRequired ?? 'free',
        startTime: start,
        endTime: end,
        durationMin: dto.durationMin ?? 30,
        xpReward: dto.xpReward ?? 50,
        shuffleQuestions: dto.shuffleQuestions ?? true,
        shuffleAnswers: dto.shuffleAnswers ?? true,
        hideResults: dto.hideResults ?? false,
        allowBack: dto.allowBack ?? true,
        certificateEnabled: dto.certificateEnabled ?? true,
        status: dto.status ?? 'draft',
        questions: dto.questions
          ? {
              create: dto.questions.map((q, idx) => ({
                text: q.text,
                options: q.options,
                optionImages: q.optionImages ?? [],
                correctIndex: q.correctIndex,
                points: q.points ?? 10,
                imageKey: q.imageKey ?? null,
                orderIdx: idx,
              })),
            }
          : undefined,
      },
      include: { _count: { select: { questions: true, attempts: true } } },
    });

    return this.olympiadRow(created);
  }

  async update(id: string, dto: UpdateOlympiadDto) {
    // Cross-field validatsiya — create() bilan bir xil, lekin partial update
    // uchun mavjud qiymatlarni DB'dan o'qib effektiv juftlikni tekshiramiz
    // (faqat bitta maydon yangilansa ham). Avval umuman tekshirilmasdi.
    if (
      dto.startTime !== undefined ||
      dto.endTime !== undefined ||
      dto.ageFrom !== undefined ||
      dto.ageTo !== undefined
    ) {
      const cur = await this.prisma.olympiad.findUnique({
        where: { id },
        select: { startTime: true, endTime: true, ageFrom: true, ageTo: true },
      });
      if (!cur) throw new NotFoundException('Olympiad not found');
      const start = dto.startTime !== undefined ? new Date(dto.startTime) : cur.startTime;
      const end = dto.endTime !== undefined ? new Date(dto.endTime) : cur.endTime;
      const ageFrom = dto.ageFrom ?? cur.ageFrom;
      const ageTo = dto.ageTo ?? cur.ageTo;
      if (start >= end) {
        throw new BadRequestException('startTime must be before endTime');
      }
      if (ageFrom > ageTo) {
        throw new BadRequestException('ageFrom must be <= ageTo');
      }
    }
    if (dto.durationMin !== undefined && dto.durationMin < 1) {
      throw new BadRequestException('durationMin must be >= 1');
    }

    const updates: Prisma.OlympiadUpdateInput = {};
    if (dto.title !== undefined) updates.title = dto.title;
    if (dto.description !== undefined) updates.description = dto.description ?? null;
    if (dto.coverKey !== undefined) updates.coverKey = dto.coverKey ?? null;
    if (dto.subject !== undefined) updates.subject = dto.subject;
    if (dto.ageFrom !== undefined) updates.ageFrom = dto.ageFrom;
    if (dto.ageTo !== undefined) updates.ageTo = dto.ageTo;
    if (dto.type !== undefined) updates.type = dto.type;
    if (dto.difficulty !== undefined) updates.difficulty = dto.difficulty;
    if (dto.planRequired !== undefined) updates.planRequired = dto.planRequired;
    if (dto.startTime !== undefined) updates.startTime = new Date(dto.startTime);
    if (dto.endTime !== undefined) updates.endTime = new Date(dto.endTime);
    if (dto.durationMin !== undefined) updates.durationMin = dto.durationMin;
    if (dto.xpReward !== undefined) updates.xpReward = dto.xpReward;
    if (dto.shuffleQuestions !== undefined) updates.shuffleQuestions = dto.shuffleQuestions;
    if (dto.shuffleAnswers !== undefined) updates.shuffleAnswers = dto.shuffleAnswers;
    if (dto.hideResults !== undefined) updates.hideResults = dto.hideResults;
    if (dto.allowBack !== undefined) updates.allowBack = dto.allowBack;
    if (dto.certificateEnabled !== undefined) updates.certificateEnabled = dto.certificateEnabled;
    if (dto.status !== undefined) updates.status = dto.status;

    try {
      const updated = await this.prisma.olympiad.update({
        where: { id },
        data: updates,
        include: { _count: { select: { questions: true, attempts: true } } },
      });
      return this.olympiadRow(updated);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Olympiad not found');
      throw err;
    }
  }

  async publish(id: string) {
    // Bo'sh (0 savol) konkursni nashr qilib bo'lmaydi — bola tomonda u darhol
    // "tugagan" bo'lib, score buziladi (questionsTotal=0).
    const o = await this.prisma.olympiad.findUnique({
      where: { id },
      include: { _count: { select: { questions: true } } },
    });
    if (!o) throw new NotFoundException('Olympiad not found');
    if (o._count.questions === 0) {
      throw new BadRequestException(
        'Konkursni nashr qilish uchun kamida 1 ta savol kerak',
      );
    }
    try {
      const updated = await this.prisma.olympiad.update({
        where: { id },
        data: { status: 'published' },
        include: { _count: { select: { questions: true, attempts: true } } },
      });
      return this.olympiadRow(updated);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Olympiad not found');
      throw err;
    }
  }

  async unpublish(id: string) {
    try {
      const updated = await this.prisma.olympiad.update({
        where: { id },
        data: { status: 'draft' },
        include: { _count: { select: { questions: true, attempts: true } } },
      });
      return this.olympiadRow(updated);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Olympiad not found');
      throw err;
    }
  }

  async remove(id: string) {
    try {
      await this.prisma.olympiad.delete({ where: { id } });
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Olympiad not found');
      throw err;
    }
  }

  async participants(id: string) {
    const exists = await this.prisma.olympiad.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!exists) throw new NotFoundException('Olympiad not found');

    const attempts = await this.prisma.olympiadAttempt.findMany({
      where: { olympiadId: id },
      include: { child: { select: { id: true, name: true, age: true } } },
      orderBy: [{ status: 'asc' }, { startedAt: 'desc' }],
      take: 500,
    });

    return attempts.map((a) => ({
      attemptId: a.id,
      childId: a.childId,
      childName: a.child?.name ?? '—',
      age: a.child?.age ?? null,
      progress: `${a.correctAnswers}/${a.questionsTotal || '0'}`,
      score: a.score,
      status: a.status,
      startedAt: a.startedAt.toISOString(),
      finishedAt: a.finishedAt?.toISOString() ?? null,
      timeSec: a.timeSec,
    }));
  }

  async leaderboard(id: string, page = 1, limit = 200) {
    const exists = await this.prisma.olympiad.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!exists) throw new NotFoundException('Olympiad not found');

    const cappedLimit = Math.min(500, Math.max(1, limit));
    const attempts = await this.prisma.olympiadAttempt.findMany({
      where: { olympiadId: id, status: 'finished' },
      include: { child: { select: { id: true, name: true } } },
      orderBy: [
        { score: 'desc' },
        { timeSec: 'asc' },
        { finishedAt: 'asc' },
      ],
      skip: (page - 1) * cappedLimit,
      take: cappedLimit,
    });

    return attempts.map((a, i) => ({
      position: (page - 1) * cappedLimit + i + 1,
      childId: a.childId,
      name: a.child?.name ?? '—',
      score: a.score,
      timeSec: a.timeSec,
      finishedAt: a.finishedAt?.toISOString() ?? null,
    }));
  }

  async archive(id: string) {
    try {
      const updated = await this.prisma.olympiad.update({
        where: { id },
        data: { status: 'archived' },
        include: { _count: { select: { questions: true, attempts: true } } },
      });
      return this.olympiadRow(updated);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Olympiad not found');
      throw err;
    }
  }

  async addQuestion(olympiadId: string, dto: QuestionDto) {
    if (!Array.isArray(dto.options) || dto.options.length < 2) {
      throw new BadRequestException('Savol kamida 2 ta variantga ega bo\'lishi shart');
    }
    if (dto.correctIndex < 0 || dto.correctIndex >= dto.options.length) {
      throw new BadRequestException('correctIndex out of range');
    }
    const last = await this.prisma.olympiadQuestion.findFirst({
      where: { olympiadId },
      orderBy: { orderIdx: 'desc' },
      select: { orderIdx: true },
    });
    try {
      const created = await this.prisma.olympiadQuestion.create({
        data: {
          olympiadId,
          text: dto.text,
          options: dto.options,
          optionImages: dto.optionImages ?? [],
          correctIndex: dto.correctIndex,
          points: dto.points ?? 10,
          imageKey: dto.imageKey ?? null,
          orderIdx: (last?.orderIdx ?? -1) + 1,
        },
      });
      return this.questionRow(created);
    } catch (err: any) {
      if (err?.code === 'P2003') throw new NotFoundException('Olympiad not found');
      throw err;
    }
  }

  async updateQuestion(olympiadId: string, questionId: string, dto: Partial<QuestionDto>) {
    if (dto.options !== undefined && dto.options.length < 2) {
      throw new BadRequestException('Savol kamida 2 ta variantga ega bo\'lishi shart');
    }
    const updates: Prisma.OlympiadQuestionUpdateInput = {};
    if (dto.text !== undefined) updates.text = dto.text;
    if (dto.options !== undefined) updates.options = dto.options;
    if (dto.optionImages !== undefined) updates.optionImages = dto.optionImages;
    if (dto.correctIndex !== undefined) updates.correctIndex = dto.correctIndex;
    if (dto.points !== undefined) updates.points = dto.points;
    if (dto.imageKey !== undefined) updates.imageKey = dto.imageKey ?? null;
    try {
      const updated = await this.prisma.olympiadQuestion.update({
        where: { id: questionId, olympiadId },
        data: updates,
      });
      return this.questionRow(updated);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Question not found');
      throw err;
    }
  }

  async deleteQuestion(olympiadId: string, questionId: string) {
    try {
      await this.prisma.olympiadQuestion.delete({
        where: { id: questionId, olympiadId },
      });
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Question not found');
      throw err;
    }
  }

  async getStats(id: string) {
    const exists = await this.prisma.olympiad.findUnique({ where: { id }, select: { id: true } });
    if (!exists) throw new NotFoundException('Olympiad not found');

    const attempts = await this.prisma.olympiadAttempt.findMany({
      where: { olympiadId: id, status: 'finished' },
      include: { child: { select: { id: true, name: true } } },
      orderBy: [{ score: 'desc' }, { timeSec: 'asc' }],
      take: 200,
    });

    const totalParticipants = await this.prisma.olympiadAttempt.count({
      where: { olympiadId: id },
    });

    return {
      totalParticipants,
      leaderboard: attempts.map((a, i) => ({
        position: i + 1,
        childId: a.childId,
        name: a.child?.name ?? '—',
        score: a.score,
        timeSec: a.timeSec,
        finishedAt: a.finishedAt?.toISOString() ?? null,
      })),
    };
  }

  // ─── Savol rasmi upload (MinIO `olympiad` bucket) ──────────────────
  // Matematik funksiyalar kabi yozib bo'lmaydigan savollar uchun. Konkurs
  // yaratishdan oldin alohida chaqiriladi; qaytgan `key` savol bilan
  // yuboriladi. Ko'rsatish: GET /olympiad-images/:key (@Public proxy).
  async uploadQuestionImage(file: {
    buffer: Buffer;
    mimetype?: string;
    filename?: string;
  }): Promise<{ key: string }> {
    if (!file.buffer || file.buffer.length === 0) {
      throw new BadRequestException("Bo'sh fayl");
    }
    if (file.buffer.length > MAX_IMAGE_BYTES) {
      throw new PayloadTooLargeException('Rasm juda katta (maks 5 MB)');
    }
    const mime = file.mimetype || 'application/octet-stream';
    if (!ALLOWED_IMAGE_MIMES.includes(mime)) {
      throw new UnsupportedMediaTypeException(
        `Qo'llab-quvvatlanmaydigan format: ${mime}`,
      );
    }
    // Kengaytmani MIME'dan aniqlaymiz (filename bo'sh/noto'g'ri bo'lsa PNG ham
    // .jpg saqlanardi). MIME yuqorida allaqachon validatsiyalangan.
    const mimeToExt: Record<string, string> = {
      'image/jpeg': '.jpg',
      'image/png': '.png',
      'image/webp': '.webp',
      'image/gif': '.gif',
    };
    const ext = mimeToExt[mime] ?? extname(file.filename || '') ?? '.jpg';
    // Single-segment key (slash yo'q) — proxy `:key` path param uchun.
    const key = `q_${randomUUID()}${ext}`;
    await this.storage.upload(BUCKETS.olympiad, key, file.buffer, mime);
    return { key };
  }

  /** Savol rasmini MinIO'dan o'qiydi (guardsiz public proxy uchun). */
  async getQuestionImage(
    key: string,
  ): Promise<{ body: Buffer; contentType: string }> {
    return this.storage.getObject(BUCKETS.olympiad, key);
  }
}
