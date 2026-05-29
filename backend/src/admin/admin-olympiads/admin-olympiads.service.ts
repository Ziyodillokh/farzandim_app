import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { CreateOlympiadDto, QuestionDto } from './dto/create-olympiad.dto';
import { UpdateOlympiadDto } from './dto/update-olympiad.dto';

@Injectable()
export class AdminOlympiadsService {
  constructor(private readonly prisma: PrismaService) {}

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
      subject: o.subject,
      ageFrom: o.ageFrom,
      ageTo: o.ageTo,
      type: o.type,
      difficulty: o.difficulty,
      startTime: o.startTime.toISOString(),
      endTime: o.endTime.toISOString(),
      durationMin: o.durationMin,
      maxAttempts: o.maxAttempts,
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
      correctIndex: q.correctIndex,
      points: q.points,
      orderIdx: q.orderIdx,
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
      if (q.correctIndex >= q.options.length) {
        throw new BadRequestException('correctIndex out of range for question');
      }
    }

    const created = await this.prisma.olympiad.create({
      data: {
        title: dto.title,
        description: dto.description ?? null,
        subject: dto.subject,
        ageFrom: dto.ageFrom,
        ageTo: dto.ageTo,
        type: dto.type ?? 'test',
        difficulty: dto.difficulty ?? "o'rta",
        startTime: start,
        endTime: end,
        durationMin: dto.durationMin ?? 30,
        maxAttempts: dto.maxAttempts ?? 1,
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
                correctIndex: q.correctIndex,
                points: q.points ?? 10,
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
    const updates: Prisma.OlympiadUpdateInput = {};
    if (dto.title !== undefined) updates.title = dto.title;
    if (dto.description !== undefined) updates.description = dto.description ?? null;
    if (dto.subject !== undefined) updates.subject = dto.subject;
    if (dto.ageFrom !== undefined) updates.ageFrom = dto.ageFrom;
    if (dto.ageTo !== undefined) updates.ageTo = dto.ageTo;
    if (dto.type !== undefined) updates.type = dto.type;
    if (dto.difficulty !== undefined) updates.difficulty = dto.difficulty;
    if (dto.startTime !== undefined) updates.startTime = new Date(dto.startTime);
    if (dto.endTime !== undefined) updates.endTime = new Date(dto.endTime);
    if (dto.durationMin !== undefined) updates.durationMin = dto.durationMin;
    if (dto.maxAttempts !== undefined) updates.maxAttempts = dto.maxAttempts;
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
    if (dto.correctIndex >= dto.options.length) {
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
          correctIndex: dto.correctIndex,
          points: dto.points ?? 10,
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
    const updates: Prisma.OlympiadQuestionUpdateInput = {};
    if (dto.text !== undefined) updates.text = dto.text;
    if (dto.options !== undefined) updates.options = dto.options;
    if (dto.correctIndex !== undefined) updates.correctIndex = dto.correctIndex;
    if (dto.points !== undefined) updates.points = dto.points;
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
}
