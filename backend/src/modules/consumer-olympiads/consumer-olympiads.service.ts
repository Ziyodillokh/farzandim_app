import {
  Injectable,
  ForbiddenException,
  NotFoundException,
  ConflictException,
  BadRequestException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { GamificationService } from '../gamification/gamification.service';
import { XpEventType } from '../gamification/dto/create-xp-event.dto';

function lifecycleOf(o: {
  status: string;
  startTime: Date;
  endTime: Date;
}): string {
  if (o.status !== 'published') return o.status;
  const now = Date.now();
  if (o.endTime.getTime() < now) return 'finished';
  if (o.startTime.getTime() > now) return 'scheduled';
  return 'active';
}

function olympiadRow(o: {
  id: string;
  title: string;
  description: string | null;
  subject: string;
  ageFrom: number;
  ageTo: number;
  type: string;
  difficulty: string;
  startTime: Date;
  endTime: Date;
  durationMin: number;
  xpReward: number;
  status: string;
  createdAt: Date;
  _count?: { attempts: number; questions: number };
}) {
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
    xpReward: o.xpReward,
    status: o.status,
    lifecycle: lifecycleOf(o),
    participantCount: o._count?.attempts ?? 0,
    questionCount: o._count?.questions ?? 0,
    createdAt: o.createdAt.toISOString(),
  };
}

function questionRow(q: {
  id: string;
  text: string;
  options: string[];
  points: number;
  orderIdx: number;
}) {
  return {
    id: q.id,
    text: q.text,
    options: q.options,
    points: q.points,
    orderIdx: q.orderIdx,
  };
}

@Injectable()
export class ConsumerOlympiadsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly gamification: GamificationService,
  ) {}

  private async loadChild(
    userId: string,
  ): Promise<{ childId: string; age: number | null }> {
    const u = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { childRecord: true },
    });
    if (!u || u.role !== 'CHILD' || !u.childRecord) {
      throw new ForbiddenException('Child profile required');
    }
    return { childId: u.childRecord.id, age: u.childRecord.age };
  }

  async listOlympiads(userId: string) {
    const child = await this.loadChild(userId);
    const a = child.age ?? 8;

    const where: Prisma.OlympiadWhereInput = {
      status: 'published',
      ageFrom: { lte: a },
      ageTo: { gte: a },
    };

    const rows = await this.prisma.olympiad.findMany({
      where,
      include: { _count: { select: { attempts: true, questions: true } } },
      orderBy: [{ startTime: 'desc' }],
      take: 100,
    });

    return { items: rows.map(olympiadRow) };
  }

  async getOlympiadDetail(userId: string, id: string) {
    await this.loadChild(userId);

    const o = await this.prisma.olympiad.findUnique({
      where: { id },
      include: {
        _count: { select: { attempts: true, questions: true } },
        questions: { orderBy: [{ orderIdx: 'asc' }] },
      },
    });
    if (!o || o.status !== 'published') {
      throw new NotFoundException('Olympiad not found');
    }

    return {
      ...olympiadRow(o),
      questions: o.questions.map(questionRow),
    };
  }

  async startAttempt(userId: string, olympiadId: string) {
    const child = await this.loadChild(userId);

    const olympiad = await this.prisma.olympiad.findUnique({
      where: { id: olympiadId },
      include: { _count: { select: { questions: true } } },
    });
    if (!olympiad || olympiad.status !== 'published') {
      throw new NotFoundException('Olympiad not found');
    }

    // Check existing attempt (unique constraint: olympiadId + childId)
    const existing = await this.prisma.olympiadAttempt.findUnique({
      where: {
        olympiadId_childId: { olympiadId, childId: child.childId },
      },
    });
    if (existing) {
      return {
        attemptId: existing.id,
        startedAt: existing.startedAt.toISOString(),
        status: existing.status,
        score: existing.score,
        resumed: true,
      };
    }

    const totalPoints = await this.prisma.olympiadQuestion.aggregate({
      where: { olympiadId },
      _sum: { points: true },
    });

    const created = await this.prisma.olympiadAttempt.create({
      data: {
        olympiadId,
        childId: child.childId,
        status: 'in_progress',
        totalPoints: totalPoints._sum.points ?? 0,
        questionsTotal: olympiad._count.questions,
      },
    });

    return {
      attemptId: created.id,
      startedAt: created.startedAt.toISOString(),
      status: created.status,
      score: 0,
      resumed: false,
    };
  }

  async answerQuestion(
    userId: string,
    attemptId: string,
    questionId: string,
    selectedIndex: number,
  ) {
    const child = await this.loadChild(userId);

    const attempt = await this.prisma.olympiadAttempt.findUnique({
      where: { id: attemptId },
      include: { olympiad: true },
    });
    if (!attempt || attempt.childId !== child.childId) {
      throw new NotFoundException('Attempt not found');
    }
    if (attempt.status === 'finished') {
      throw new ConflictException('Attempt already finished');
    }

    // Time enforcement (durationMin + 30s grace)
    const elapsedSec = Math.floor(
      (Date.now() - attempt.startedAt.getTime()) / 1000,
    );
    const limitSec = attempt.olympiad.durationMin * 60 + 30;
    if (elapsedSec > limitSec) {
      await this.prisma.olympiadAttempt.update({
        where: { id: attemptId },
        data: {
          status: 'finished',
          finishedAt: new Date(),
          timeSec: elapsedSec,
        },
      });
      throw new HttpException(
        {
          error: 'Time limit exceeded',
          autoFinished: true,
          score: attempt.score,
        },
        HttpStatus.REQUEST_TIMEOUT,
      );
    }

    const question = await this.prisma.olympiadQuestion.findUnique({
      where: { id: questionId },
    });
    if (!question || question.olympiadId !== attempt.olympiadId) {
      throw new BadRequestException(
        'Question does not belong to this olympiad',
      );
    }

    const isCorrect = selectedIndex === question.correctIndex;

    // Check for duplicate answer
    const prevAnswers = Array.isArray(attempt.answers)
      ? attempt.answers
      : [];
    const already = (
      prevAnswers as Array<{ questionId: string }>
    ).some((a) => a.questionId === questionId);
    if (already) {
      throw new ConflictException({
        error: 'This question already answered',
        correctIndex: question.correctIndex,
      });
    }

    const newAnswer = { questionId, selectedIndex, isCorrect };
    const nextAnswers = [
      ...(prevAnswers as Array<unknown>),
      newAnswer,
    ];
    const isLastQuestion = nextAnswers.length >= attempt.questionsTotal;

    const updated = await this.prisma.olympiadAttempt.update({
      where: { id: attemptId },
      data: {
        answers: nextAnswers as Prisma.InputJsonValue,
        score: { increment: isCorrect ? question.points : 0 },
        correctAnswers: { increment: isCorrect ? 1 : 0 },
        timeSec: elapsedSec,
        status: isLastQuestion ? 'finished' : 'in_progress',
        finishedAt: isLastQuestion ? new Date() : null,
      },
    });

    return {
      isCorrect,
      correctIndex: question.correctIndex,
      points: isCorrect ? question.points : 0,
      scoreSoFar: updated.score,
      correctAnswers: updated.correctAnswers,
      questionsAnswered: nextAnswers.length,
      questionsTotal: updated.questionsTotal,
      isLastQuestion,
      attemptFinished: updated.status === 'finished',
    };
  }

  async submitAttempt(
    userId: string,
    attemptId: string,
    answers: Array<{ questionId: string; selectedIndex: number }>,
    timeSec: number,
  ) {
    const child = await this.loadChild(userId);

    const attempt = await this.prisma.olympiadAttempt.findUnique({
      where: { id: attemptId },
      include: {
        olympiad: { include: { questions: true } },
      },
    });
    if (!attempt || attempt.childId !== child.childId) {
      throw new NotFoundException('Attempt not found');
    }
    if (attempt.status === 'finished') {
      throw new ConflictException('Attempt already finished');
    }

    const questionMap = new Map(
      attempt.olympiad.questions.map((q) => [q.id, q]),
    );
    let score = 0;
    let correctAnswers = 0;
    const graded: Array<{
      questionId: string;
      selectedIndex: number;
      isCorrect: boolean;
    }> = [];
    for (const a of answers) {
      const q = questionMap.get(a.questionId);
      if (!q) continue;
      const isCorrect = a.selectedIndex === q.correctIndex;
      if (isCorrect) {
        score += q.points;
        correctAnswers += 1;
      }
      graded.push({
        questionId: a.questionId,
        selectedIndex: a.selectedIndex,
        isCorrect,
      });
    }

    const updated = await this.prisma.olympiadAttempt.update({
      where: { id: attemptId },
      data: {
        status: 'finished',
        score,
        correctAnswers,
        timeSec,
        finishedAt: new Date(),
        answers: graded as Prisma.InputJsonValue,
      },
    });

    // XP berish — test (olympiad) tugatildi → reyting shu XP'dan hisoblanadi.
    // Idempotent (relatedId = attemptId) — qayta yuborilsa ikki marta bermaydi.
    // `submitAttempt` allaqachon finished bo'lsa yuqorida 409 qaytaradi.
    await this.gamification.awardXp(child.childId, {
      type: XpEventType.CONTEST_WIN,
      xpDelta: attempt.olympiad.xpReward,
      relatedId: updated.id,
    });

    return {
      attemptId: updated.id,
      score: updated.score,
      totalPoints: updated.totalPoints,
      correctAnswers: updated.correctAnswers,
      questionsTotal: updated.questionsTotal,
      timeSec: updated.timeSec,
      finishedAt: updated.finishedAt?.toISOString() ?? null,
    };
  }

  async getRanking(
    userId: string,
    range: string,
    limit: number,
  ) {
    const child = await this.loadChild(userId);

    const since =
      range === 'daily'
        ? new Date(Date.now() - 86_400_000)
        : range === 'weekly'
          ? new Date(Date.now() - 7 * 86_400_000)
          : range === 'monthly'
            ? new Date(Date.now() - 30 * 86_400_000)
            : null;

    const grouped = await this.prisma.olympiadAttempt.groupBy({
      by: ['childId'],
      where: {
        status: 'finished',
        ...(since ? { finishedAt: { gte: since } } : {}),
      },
      _sum: { score: true },
      _count: { _all: true },
      orderBy: { _sum: { score: 'desc' } },
      take: limit,
    });

    const childIds = grouped.map((g) => g.childId);
    if (childIds.length === 0) {
      return {
        items: [],
        range,
        currentUserId: child.childId,
        currentUser: null,
      };
    }

    const childRows = await this.prisma.child.findMany({
      where: { id: { in: childIds } },
      select: { id: true, name: true, age: true, region: true },
    });
    const childMap = new Map(childRows.map((c) => [c.id, c]));

    const items = grouped.map((g, i) => {
      const c = childMap.get(g.childId);
      return {
        position: i + 1,
        childId: g.childId,
        name: c?.name ?? '--',
        age: c?.age ?? null,
        region: c?.region ?? null,
        totalScore: g._sum.score ?? 0,
        attemptCount: g._count._all,
        isCurrentUser: g.childId === child.childId,
      };
    });

    // If current user not in top, add them separately
    let currentUserRow = items.find((x) => x.isCurrentUser) ?? null;
    if (!currentUserRow) {
      const all = await this.prisma.olympiadAttempt.aggregate({
        where: {
          childId: child.childId,
          status: 'finished',
          ...(since ? { finishedAt: { gte: since } } : {}),
        },
        _sum: { score: true },
        _count: { _all: true },
      });
      const score = all._sum.score ?? 0;
      if (score > 0 || (all._count._all ?? 0) > 0) {
        const c = await this.prisma.child.findUnique({
          where: { id: child.childId },
        });
        const higher = await this.prisma.olympiadAttempt.groupBy({
          by: ['childId'],
          where: {
            status: 'finished',
            ...(since ? { finishedAt: { gte: since } } : {}),
          },
          _sum: { score: true },
          having: { score: { _sum: { gt: score } } },
        });
        currentUserRow = {
          position: higher.length + 1,
          childId: child.childId,
          name: c?.name ?? '--',
          age: c?.age ?? null,
          region: c?.region ?? null,
          totalScore: score,
          attemptCount: all._count._all,
          isCurrentUser: true,
        };
      }
    }

    return {
      items,
      currentUserId: child.childId,
      currentUser: currentUserRow,
      range,
    };
  }
}
