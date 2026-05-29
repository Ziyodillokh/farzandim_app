import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { staffAuthGuard } from '../../middleware/staff-auth';
import { requirePermission } from '../../middleware/require-permission';

// ─── Helpers ───────────────────────────────────────────────────────

const TYPES = ['test', 'creative', 'mixed'] as const;
const DIFFICULTIES = ['oson', "o'rta", 'qiyin'] as const;
const STATUSES = ['draft', 'published', 'archived'] as const;

/**
 * Status — admin tomonidan boshqariladigan flag (draft|published|archived).
 * Lifecycle — vaqt asosida hisoblanadi: scheduled (kelajakda boshlanadi) →
 * active (hozir ishlamoqda) → finished (tugagan). draft bo'lsa lifecycle ham draft.
 */
function lifecycleOf(o: { status: string; startTime: Date; endTime: Date }): string {
  if (o.status !== 'published') return o.status;
  const now = Date.now();
  if (o.endTime.getTime() < now) return 'finished';
  if (o.startTime.getTime() > now) return 'scheduled';
  return 'active';
}

const QuestionSchema = z.object({
  text: z.string().trim().min(1).max(2000),
  options: z.array(z.string().trim().min(1).max(500)).min(2).max(8),
  correctIndex: z.coerce.number().int().min(0),
  points: z.coerce.number().int().min(1).default(10),
});

const OlympiadCreate = z.object({
  title: z.string().trim().min(1).max(160),
  description: z.string().trim().max(4000).optional().nullable(),
  subject: z.string().trim().min(1).max(50),
  ageFrom: z.coerce.number().int().min(0).max(25),
  ageTo: z.coerce.number().int().min(0).max(25),
  type: z.enum(TYPES).default('test'),
  difficulty: z.enum(DIFFICULTIES).default("o'rta"),
  startTime: z.string().datetime(),
  endTime: z.string().datetime(),
  durationMin: z.coerce.number().int().min(1).max(600).default(30),
  maxAttempts: z.coerce.number().int().min(1).max(20).default(1),
  xpReward: z.coerce.number().int().min(0).max(10_000).default(50),
  shuffleQuestions: z.boolean().optional(),
  shuffleAnswers: z.boolean().optional(),
  hideResults: z.boolean().optional(),
  allowBack: z.boolean().optional(),
  certificateEnabled: z.boolean().optional(),
  questions: z.array(QuestionSchema).optional(),
  status: z.enum(STATUSES).optional(),
});

const OlympiadUpdate = OlympiadCreate.partial().omit({ questions: true });

const ListQuery = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  q: z.string().trim().optional(),
  status: z.string().trim().optional(),
  subject: z.string().trim().optional(),
  ageFrom: z.coerce.number().int().optional(),
  ageTo: z.coerce.number().int().optional(),
  dateFrom: z.string().datetime().optional(),
  dateTo: z.string().datetime().optional(),
});

interface OlympiadWithCounts {
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
  maxAttempts: number;
  xpReward: number;
  shuffleQuestions: boolean;
  shuffleAnswers: boolean;
  hideResults: boolean;
  allowBack: boolean;
  certificateEnabled: boolean;
  status: string;
  createdAt: Date;
  updatedAt: Date;
  _count?: { questions: number; attempts: number };
}

function olympiadRow(o: OlympiadWithCounts) {
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
    lifecycle: lifecycleOf(o),
    participantCount: o._count?.attempts ?? 0,
    questionCount: o._count?.questions ?? 0,
    createdAt: o.createdAt.toISOString(),
    updatedAt: o.updatedAt.toISOString(),
  };
}

function questionRow(q: {
  id: string;
  olympiadId: string;
  text: string;
  options: string[];
  correctIndex: number;
  points: number;
  orderIdx: number;
}) {
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

function progressLabel(a: { correctAnswers: number; questionsTotal: number }): string {
  return `${a.correctAnswers}/${a.questionsTotal || '0'}`;
}

// ─── Routes ────────────────────────────────────────────────────────

export const adminOlympiadsRoutes: FastifyPluginAsync = async (fastify) => {
  // Sprint 6 — RBAC: butun modul auth + permission tekshiruvidan o'tadi.
  fastify.addHook('preHandler', staffAuthGuard);
  fastify.addHook(
    'preHandler',
    requirePermission('create_contest', 'edit_contest', 'delete_contest', 'select_winner'),
  );

  // LIST -----------------------------------------------------------

  fastify.get('/', { preHandler: staffAuthGuard }, async (request, reply) => {
    const parsed = ListQuery.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid query', details: parsed.error.flatten() });
    }
    const { page, limit, q, status, subject, ageFrom, ageTo, dateFrom, dateTo } = parsed.data;

    const where: Prisma.OlympiadWhereInput = {};
    if (status && (STATUSES as readonly string[]).includes(status)) where.status = status;
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
      prisma.olympiad.count({ where }),
      prisma.olympiad.findMany({
        where,
        include: { _count: { select: { questions: true, attempts: true } } },
        orderBy: [{ startTime: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    const totalPages = Math.max(1, Math.ceil(total / limit));
    return reply.send({
      items: rows.map(olympiadRow),
      pagination: { page, totalPages, total, limit },
    });
  });

  // GET ONE --------------------------------------------------------

  fastify.get('/:id', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const o = await prisma.olympiad.findUnique({
      where: { id },
      include: {
        _count: { select: { questions: true, attempts: true } },
        questions: { orderBy: [{ orderIdx: 'asc' }, { createdAt: 'asc' }] },
      },
    });
    if (!o) return reply.code(404).send({ error: 'Olympiad not found' });
    return reply.send({
      ...olympiadRow(o),
      questions: o.questions.map(questionRow),
    });
  });

  // CREATE ---------------------------------------------------------

  fastify.post('/', { preHandler: staffAuthGuard }, async (request, reply) => {
    const parsed = OlympiadCreate.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid olympiad payload', details: parsed.error.flatten() });
    }
    const data = parsed.data;
    const start = new Date(data.startTime);
    const end = new Date(data.endTime);
    if (start >= end) {
      return reply.code(400).send({ error: 'startTime must be before endTime' });
    }
    if (data.ageFrom > data.ageTo) {
      return reply.code(400).send({ error: 'ageFrom must be <= ageTo' });
    }

    // Question correctIndex bounds vs options length validation
    for (const q of data.questions ?? []) {
      if (q.correctIndex >= q.options.length) {
        return reply.code(400).send({ error: 'correctIndex out of range for question' });
      }
    }

    const created = await prisma.olympiad.create({
      data: {
        title: data.title,
        description: data.description ?? null,
        subject: data.subject,
        ageFrom: data.ageFrom,
        ageTo: data.ageTo,
        type: data.type,
        difficulty: data.difficulty,
        startTime: start,
        endTime: end,
        durationMin: data.durationMin,
        maxAttempts: data.maxAttempts,
        xpReward: data.xpReward,
        shuffleQuestions: data.shuffleQuestions ?? true,
        shuffleAnswers: data.shuffleAnswers ?? true,
        hideResults: data.hideResults ?? false,
        allowBack: data.allowBack ?? true,
        certificateEnabled: data.certificateEnabled ?? true,
        status: data.status ?? 'draft',
        questions: data.questions
          ? {
              create: data.questions.map((q, idx) => ({
                text: q.text,
                options: q.options,
                correctIndex: q.correctIndex,
                points: q.points,
                orderIdx: idx,
              })),
            }
          : undefined,
      },
      include: { _count: { select: { questions: true, attempts: true } } },
    });
    return reply.code(201).send(olympiadRow(created));
  });

  // UPDATE ---------------------------------------------------------

  fastify.patch('/:id', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const parsed = OlympiadUpdate.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid olympiad payload', details: parsed.error.flatten() });
    }
    const data = parsed.data;
    const updates: Prisma.OlympiadUpdateInput = {};
    if (data.title !== undefined) updates.title = data.title;
    if (data.description !== undefined) updates.description = data.description ?? null;
    if (data.subject !== undefined) updates.subject = data.subject;
    if (data.ageFrom !== undefined) updates.ageFrom = data.ageFrom;
    if (data.ageTo !== undefined) updates.ageTo = data.ageTo;
    if (data.type !== undefined) updates.type = data.type;
    if (data.difficulty !== undefined) updates.difficulty = data.difficulty;
    if (data.startTime !== undefined) updates.startTime = new Date(data.startTime);
    if (data.endTime !== undefined) updates.endTime = new Date(data.endTime);
    if (data.durationMin !== undefined) updates.durationMin = data.durationMin;
    if (data.maxAttempts !== undefined) updates.maxAttempts = data.maxAttempts;
    if (data.xpReward !== undefined) updates.xpReward = data.xpReward;
    if (data.shuffleQuestions !== undefined) updates.shuffleQuestions = data.shuffleQuestions;
    if (data.shuffleAnswers !== undefined) updates.shuffleAnswers = data.shuffleAnswers;
    if (data.hideResults !== undefined) updates.hideResults = data.hideResults;
    if (data.allowBack !== undefined) updates.allowBack = data.allowBack;
    if (data.certificateEnabled !== undefined) updates.certificateEnabled = data.certificateEnabled;
    if (data.status !== undefined) updates.status = data.status;

    try {
      const updated = await prisma.olympiad.update({
        where: { id },
        data: updates,
        include: { _count: { select: { questions: true, attempts: true } } },
      });
      return reply.send(olympiadRow(updated));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Olympiad not found' });
      }
      throw err;
    }
  });

  // PUBLISH / UNPUBLISH --------------------------------------------

  fastify.post('/:id/publish', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      const updated = await prisma.olympiad.update({
        where: { id },
        data: { status: 'published' },
        include: { _count: { select: { questions: true, attempts: true } } },
      });
      return reply.send(olympiadRow(updated));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Olympiad not found' });
      }
      throw err;
    }
  });

  fastify.post('/:id/unpublish', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      const updated = await prisma.olympiad.update({
        where: { id },
        data: { status: 'draft' },
        include: { _count: { select: { questions: true, attempts: true } } },
      });
      return reply.send(olympiadRow(updated));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Olympiad not found' });
      }
      throw err;
    }
  });

  // DELETE ---------------------------------------------------------

  fastify.delete('/:id', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    try {
      await prisma.olympiad.delete({ where: { id } });
      return reply.code(204).send();
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Olympiad not found' });
      }
      throw err;
    }
  });

  // PARTICIPANTS ---------------------------------------------------

  fastify.get('/:id/participants', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const exists = await prisma.olympiad.findUnique({ where: { id }, select: { id: true } });
    if (!exists) return reply.code(404).send({ error: 'Olympiad not found' });

    const attempts = await prisma.olympiadAttempt.findMany({
      where: { olympiadId: id },
      include: { child: { select: { id: true, name: true, age: true } } },
      orderBy: [{ status: 'asc' }, { startedAt: 'desc' }],
      take: 500,
    });
    return reply.send(
      attempts.map((a) => ({
        attemptId: a.id,
        childId: a.childId,
        childName: a.child?.name ?? '—',
        age: a.child?.age ?? null,
        progress: progressLabel(a),
        score: a.score,
        status: a.status,
        startedAt: a.startedAt.toISOString(),
        finishedAt: a.finishedAt?.toISOString() ?? null,
        timeSec: a.timeSec,
      })),
    );
  });

  // LEADERBOARD ----------------------------------------------------

  fastify.get('/:id/leaderboard', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const q = request.query as { page?: string; limit?: string };
    const page = Math.max(1, parseInt(q.page ?? '1', 10) || 1);
    const limit = Math.min(500, Math.max(1, parseInt(q.limit ?? '200', 10) || 200));

    const exists = await prisma.olympiad.findUnique({ where: { id }, select: { id: true } });
    if (!exists) return reply.code(404).send({ error: 'Olympiad not found' });

    const attempts = await prisma.olympiadAttempt.findMany({
      where: { olympiadId: id, status: 'finished' },
      include: { child: { select: { id: true, name: true } } },
      orderBy: [{ score: 'desc' }, { timeSec: 'asc' }, { finishedAt: 'asc' }],
      skip: (page - 1) * limit,
      take: limit,
    });
    return reply.send(
      attempts.map((a, i) => ({
        position: (page - 1) * limit + i + 1,
        childId: a.childId,
        name: a.child?.name ?? '—',
        score: a.score,
        timeSec: a.timeSec,
        finishedAt: a.finishedAt?.toISOString() ?? null,
      })),
    );
  });

  // QUESTIONS (nested) ---------------------------------------------

  fastify.post('/:id/questions', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { id: olympiadId } = request.params as { id: string };
    const parsed = QuestionSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid question payload', details: parsed.error.flatten() });
    }
    const data = parsed.data;
    if (data.correctIndex >= data.options.length) {
      return reply.code(400).send({ error: 'correctIndex out of range' });
    }
    const last = await prisma.olympiadQuestion.findFirst({
      where: { olympiadId },
      orderBy: { orderIdx: 'desc' },
      select: { orderIdx: true },
    });
    try {
      const created = await prisma.olympiadQuestion.create({
        data: {
          olympiadId,
          text: data.text,
          options: data.options,
          correctIndex: data.correctIndex,
          points: data.points,
          orderIdx: (last?.orderIdx ?? -1) + 1,
        },
      });
      return reply.code(201).send(questionRow(created));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2003') {
        return reply.code(404).send({ error: 'Olympiad not found' });
      }
      throw err;
    }
  });

  fastify.patch('/:olympiadId/questions/:questionId', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { olympiadId, questionId } = request.params as { olympiadId: string; questionId: string };
    const parsed = QuestionSchema.partial().safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid question payload', details: parsed.error.flatten() });
    }
    const data = parsed.data;
    if (data.correctIndex !== undefined && data.options !== undefined && data.correctIndex >= data.options.length) {
      return reply.code(400).send({ error: 'correctIndex out of range' });
    }
    const updates: Prisma.OlympiadQuestionUpdateInput = {};
    if (data.text !== undefined) updates.text = data.text;
    if (data.options !== undefined) updates.options = data.options;
    if (data.correctIndex !== undefined) updates.correctIndex = data.correctIndex;
    if (data.points !== undefined) updates.points = data.points;
    try {
      const updated = await prisma.olympiadQuestion.update({
        where: { id: questionId, olympiadId },
        data: updates,
      });
      return reply.send(questionRow(updated));
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Question not found' });
      }
      throw err;
    }
  });

  fastify.delete('/:olympiadId/questions/:questionId', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { olympiadId, questionId } = request.params as { olympiadId: string; questionId: string };
    try {
      await prisma.olympiadQuestion.delete({ where: { id: questionId, olympiadId } });
      return reply.code(204).send();
    } catch (err: unknown) {
      if ((err as { code?: string }).code === 'P2025') {
        return reply.code(404).send({ error: 'Question not found' });
      }
      throw err;
    }
  });
};
