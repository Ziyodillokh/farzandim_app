import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { authGuard } from '../../middleware/auth';

/**
 * Consumer-side Olympiad endpoint'lari — Child App bola tomonida
 * konkurslar ko'rishi va ishtirok etishi uchun.
 *
 * Admin Sprint 5.4'da yaratgan Olympiad'lar shu yerdan filter qilib
 * (status='published', age moslangan) bolaga taqdim etiladi.
 *
 *   GET /api/content/olympiads             — list (published, age filter)
 *   GET /api/content/olympiads/:id         — detail + questions[]
 *   GET /api/content/olympiads/ranking     — global leaderboard (real DB)
 *   POST /api/content/olympiads/:id/start  — attempt yaratish
 *   POST /api/content/attempts/:id/submit  — attempt yakunlash + score
 */

function lifecycleOf(o: { status: string; startTime: Date; endTime: Date }): string {
  if (o.status !== 'published') return o.status;
  const now = Date.now();
  if (o.endTime.getTime() < now) return 'finished';
  if (o.startTime.getTime() > now) return 'scheduled';
  return 'active';
}

async function loadChild(userId: string): Promise<{ childId: string; age: number | null } | null> {
  const u = await prisma.user.findUnique({
    where: { id: userId },
    include: { childRecord: true },
  });
  if (!u || u.role !== 'CHILD' || !u.childRecord) return null;
  return { childId: u.childRecord.id, age: u.childRecord.age };
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
  // Sprint 5.7e: correctIndex bolaga ko'rsatilmaydi (network inspector
  // orqali oldindan ko'rib bo'lmaydi). Bola har savolga javob bergach
  // POST /attempts/:id/answer canonical isCorrect + correctIndex qaytaradi.
  return {
    id: q.id,
    text: q.text,
    options: q.options,
    points: q.points,
    orderIdx: q.orderIdx,
  };
}

const SubmitBody = z.object({
  answers: z.array(
    z.object({
      questionId: z.string().uuid(),
      selectedIndex: z.coerce.number().int().min(0),
    }),
  ),
  timeSec: z.coerce.number().int().min(0).default(0),
});

const RankingQuery = z.object({
  range: z.enum(['all', 'daily', 'weekly', 'monthly']).default('all'),
  limit: z.coerce.number().int().min(1).max(200).default(50),
});

export const consumerOlympiadsRoutes: FastifyPluginAsync = async (fastify) => {
  // ─── List published olympiads filtered by child age ─────────────
  fastify.get('/', { preHandler: authGuard }, async (request, reply) => {
    const userId = request.user?.userId;
    if (!userId) return reply.code(401).send({ error: 'Unauthorized' });
    const child = await loadChild(userId);
    if (!child) return reply.code(403).send({ error: 'Child profile required' });

    const a = child.age ?? 8;
    const where: Prisma.OlympiadWhereInput = {
      status: 'published',
      ageFrom: { lte: a },
      ageTo: { gte: a },
    };
    const rows = await prisma.olympiad.findMany({
      where,
      include: { _count: { select: { attempts: true, questions: true } } },
      orderBy: [{ startTime: 'desc' }],
      take: 100,
    });
    return reply.send({ items: rows.map(olympiadRow) });
  });

  // ─── Detail with questions (correctIndex hidden) ────────────────
  fastify.get('/:id', { preHandler: authGuard }, async (request, reply) => {
    const userId = request.user?.userId;
    if (!userId) return reply.code(401).send({ error: 'Unauthorized' });
    const child = await loadChild(userId);
    if (!child) return reply.code(403).send({ error: 'Child profile required' });

    const { id } = request.params as { id: string };
    const o = await prisma.olympiad.findUnique({
      where: { id },
      include: {
        _count: { select: { attempts: true, questions: true } },
        questions: { orderBy: [{ orderIdx: 'asc' }] },
      },
    });
    if (!o || o.status !== 'published') {
      return reply.code(404).send({ error: 'Olympiad not found' });
    }
    return reply.send({ ...olympiadRow(o), questions: o.questions.map(questionRow) });
  });

  // ─── Global ranking (aggregated across all olympiads) ───────────
  fastify.get('/ranking', { preHandler: authGuard }, async (request, reply) => {
    const userId = request.user?.userId;
    if (!userId) return reply.code(401).send({ error: 'Unauthorized' });
    const child = await loadChild(userId);
    if (!child) return reply.code(403).send({ error: 'Child profile required' });

    const parsed = RankingQuery.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Invalid query' });
    const { range, limit } = parsed.data;

    const since =
      range === 'daily' ? new Date(Date.now() - 86_400_000)
      : range === 'weekly' ? new Date(Date.now() - 7 * 86_400_000)
      : range === 'monthly' ? new Date(Date.now() - 30 * 86_400_000)
      : null;

    const grouped = await prisma.olympiadAttempt.groupBy({
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
    if (childIds.length === 0) return reply.send({ items: [], range, currentUserId: child.childId });

    const childRows = await prisma.child.findMany({
      where: { id: { in: childIds } },
      select: { id: true, name: true, age: true, region: true },
    });
    const childMap = new Map(childRows.map((c) => [c.id, c]));

    const items = grouped.map((g, i) => {
      const c = childMap.get(g.childId);
      return {
        position: i + 1,
        childId: g.childId,
        name: c?.name ?? '—',
        age: c?.age ?? null,
        region: c?.region ?? null,
        totalScore: g._sum.score ?? 0,
        attemptCount: g._count._all,
        isCurrentUser: g.childId === child.childId,
      };
    });

    // Agar joriy bola top'da bo'lmasa — alohida qaytaramiz
    let currentUserRow = items.find((x) => x.isCurrentUser) ?? null;
    if (!currentUserRow) {
      const all = await prisma.olympiadAttempt.aggregate({
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
        const c = await prisma.child.findUnique({ where: { id: child.childId } });
        // Position approximation: 1 + count of children with higher score
        const higher = await prisma.olympiadAttempt.groupBy({
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
          name: c?.name ?? '—',
          age: c?.age ?? null,
          region: c?.region ?? null,
          totalScore: score,
          attemptCount: all._count._all,
          isCurrentUser: true,
        };
      }
    }

    return reply.send({
      items,
      currentUserId: child.childId,
      currentUser: currentUserRow,
      range,
    });
  });

  // ─── Start attempt ──────────────────────────────────────────────
  fastify.post('/:id/start', { preHandler: authGuard }, async (request, reply) => {
    const userId = request.user?.userId;
    if (!userId) return reply.code(401).send({ error: 'Unauthorized' });
    const child = await loadChild(userId);
    if (!child) return reply.code(403).send({ error: 'Child profile required' });

    const { id: olympiadId } = request.params as { id: string };
    const olympiad = await prisma.olympiad.findUnique({
      where: { id: olympiadId },
      include: { _count: { select: { questions: true } } },
    });
    if (!olympiad || olympiad.status !== 'published') {
      return reply.code(404).send({ error: 'Olympiad not found' });
    }

    // Bir bola olympiad'da faqat 1 ta attempt — unique(olympiadId, childId)
    const existing = await prisma.olympiadAttempt.findUnique({
      where: { olympiadId_childId: { olympiadId, childId: child.childId } },
    });
    if (existing) {
      return reply.send({
        attemptId: existing.id,
        startedAt: existing.startedAt.toISOString(),
        status: existing.status,
        score: existing.score,
        resumed: true,
      });
    }

    const totalPoints = await prisma.olympiadQuestion.aggregate({
      where: { olympiadId },
      _sum: { points: true },
    });

    const created = await prisma.olympiadAttempt.create({
      data: {
        olympiadId,
        childId: child.childId,
        status: 'in_progress',
        totalPoints: totalPoints._sum.points ?? 0,
        questionsTotal: olympiad._count.questions,
      },
    });
    return reply.code(201).send({
      attemptId: created.id,
      startedAt: created.startedAt.toISOString(),
      status: created.status,
      score: 0,
      resumed: false,
    });
  });

  // ─── Per-question answer (Sprint 5.7e anti-cheat) ──────────────
  //
  // Bola har savolga javob bergach shu yerga POST qiladi. Backend
  // canonical correctIndex bilan compare qiladi va isCorrect qaytaradi.
  // CorrectIndex /api/content/olympiads/:id ko'rinmaydi — faqat shu
  // endpoint javob bergandan keyin qaytariladi (oldindan ko'rib bo'lmaydi).
  //
  // Vaqt enforcement: startedAt + (durationMin * 60 + 30s grace) o'tib
  // ketgan bo'lsa attempt yopiladi (autoFinished=true), boshqa javob qabul
  // qilinmaydi.
  fastify.post('/attempts/:id/answer', { preHandler: authGuard }, async (request, reply) => {
    const userId = request.user?.userId;
    if (!userId) return reply.code(401).send({ error: 'Unauthorized' });
    const child = await loadChild(userId);
    if (!child) return reply.code(403).send({ error: 'Child profile required' });

    const { id } = request.params as { id: string };
    const SingleAnswer = z.object({
      questionId: z.string().uuid(),
      selectedIndex: z.coerce.number().int().min(0),
    });
    const parsed = SingleAnswer.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid body', details: parsed.error.flatten() });
    }

    const attempt = await prisma.olympiadAttempt.findUnique({
      where: { id },
      include: { olympiad: true },
    });
    if (!attempt || attempt.childId !== child.childId) {
      return reply.code(404).send({ error: 'Attempt not found' });
    }
    if (attempt.status === 'finished') {
      return reply.code(409).send({ error: 'Attempt already finished' });
    }

    // Vaqt enforcement (durationMin + 30s grace)
    const elapsedSec = Math.floor((Date.now() - attempt.startedAt.getTime()) / 1000);
    const limitSec = attempt.olympiad.durationMin * 60 + 30;
    if (elapsedSec > limitSec) {
      await prisma.olympiadAttempt.update({
        where: { id },
        data: { status: 'finished', finishedAt: new Date(), timeSec: elapsedSec },
      });
      return reply.code(408).send({
        error: 'Time limit exceeded',
        autoFinished: true,
        score: attempt.score,
      });
    }

    const question = await prisma.olympiadQuestion.findUnique({
      where: { id: parsed.data.questionId },
    });
    if (!question || question.olympiadId !== attempt.olympiadId) {
      return reply.code(400).send({ error: 'Question does not belong to this olympiad' });
    }

    const isCorrect = parsed.data.selectedIndex === question.correctIndex;

    // Duplicate javob — qabul qilmaymiz (idempotent)
    const prevAnswers = Array.isArray(attempt.answers) ? attempt.answers : [];
    const already = (prevAnswers as Array<{ questionId: string }>).some(
      (a) => a.questionId === parsed.data.questionId,
    );
    if (already) {
      return reply.code(409).send({
        error: 'This question already answered',
        correctIndex: question.correctIndex,
      });
    }

    const newAnswer = {
      questionId: parsed.data.questionId,
      selectedIndex: parsed.data.selectedIndex,
      isCorrect,
    };
    const nextAnswers = [...(prevAnswers as Array<unknown>), newAnswer];
    const isLastQuestion = nextAnswers.length >= attempt.questionsTotal;

    const updated = await prisma.olympiadAttempt.update({
      where: { id },
      data: {
        answers: nextAnswers as Prisma.InputJsonValue,
        score: { increment: isCorrect ? question.points : 0 },
        correctAnswers: { increment: isCorrect ? 1 : 0 },
        timeSec: elapsedSec,
        status: isLastQuestion ? 'finished' : 'in_progress',
        finishedAt: isLastQuestion ? new Date() : null,
      },
    });

    return reply.send({
      isCorrect,
      correctIndex: question.correctIndex,
      points: isCorrect ? question.points : 0,
      scoreSoFar: updated.score,
      correctAnswers: updated.correctAnswers,
      questionsAnswered: nextAnswers.length,
      questionsTotal: updated.questionsTotal,
      isLastQuestion,
      attemptFinished: updated.status === 'finished',
    });
  });

  // ─── Submit attempt (legacy / batch — mock paytida) ─────────────
  fastify.post('/attempts/:id/submit', { preHandler: authGuard }, async (request, reply) => {
    const userId = request.user?.userId;
    if (!userId) return reply.code(401).send({ error: 'Unauthorized' });
    const child = await loadChild(userId);
    if (!child) return reply.code(403).send({ error: 'Child profile required' });

    const { id } = request.params as { id: string };
    const parsed = SubmitBody.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid body', details: parsed.error.flatten() });
    }

    const attempt = await prisma.olympiadAttempt.findUnique({
      where: { id },
      include: {
        olympiad: { include: { questions: true } },
      },
    });
    if (!attempt || attempt.childId !== child.childId) {
      return reply.code(404).send({ error: 'Attempt not found' });
    }
    if (attempt.status === 'finished') {
      return reply.code(409).send({ error: 'Attempt already finished' });
    }

    const questionMap = new Map(
      attempt.olympiad.questions.map((q) => [q.id, q]),
    );
    let score = 0;
    let correctAnswers = 0;
    const answers: Array<{ questionId: string; selectedIndex: number; isCorrect: boolean }> = [];
    for (const a of parsed.data.answers) {
      const q = questionMap.get(a.questionId);
      if (!q) continue;
      const isCorrect = a.selectedIndex === q.correctIndex;
      if (isCorrect) {
        score += q.points;
        correctAnswers += 1;
      }
      answers.push({ questionId: a.questionId, selectedIndex: a.selectedIndex, isCorrect });
    }

    const updated = await prisma.olympiadAttempt.update({
      where: { id },
      data: {
        status: 'finished',
        score,
        correctAnswers,
        timeSec: parsed.data.timeSec,
        finishedAt: new Date(),
        answers: answers as Prisma.InputJsonValue,
      },
    });

    return reply.send({
      attemptId: updated.id,
      score: updated.score,
      totalPoints: updated.totalPoints,
      correctAnswers: updated.correctAnswers,
      questionsTotal: updated.questionsTotal,
      timeSec: updated.timeSec,
      finishedAt: updated.finishedAt?.toISOString() ?? null,
    });
  });
};
