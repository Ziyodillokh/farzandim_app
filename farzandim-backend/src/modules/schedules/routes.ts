import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { authGuard } from '../../middleware/auth';
import { prisma } from '../../lib/prisma';
import { writeAudit } from '../../lib/audit';
import { emitToChild } from '../../lib/realtime';

// Sxema: Schedule = app cheklash (BLOCK/ALLOW). Hozir parental control core.
// Kun rejasi (Uxlash/Maktab) uchun Routine moduli ishlatiladi.

const TIME_REGEX = /^([01]\d|2[0-3]):[0-5]\d$/;

// daysOfWeek: ISO 8601 (1=Mon ... 7=Sun)
const daysOfWeekSchema = z
  .array(z.number().int().min(1).max(7))
  .min(1)
  .max(7)
  .transform((arr) => Array.from(new Set(arr)).sort((a, b) => a - b));

const createSchema = z
  .object({
    name: z.string().min(1).max(100),
    startTime: z.string().regex(TIME_REGEX, 'startTime must be HH:MM'),
    endTime: z.string().regex(TIME_REGEX, 'endTime must be HH:MM'),
    daysOfWeek: daysOfWeekSchema,
    action: z.enum(['BLOCK', 'ALLOW']),
    isActive: z.boolean().optional(),
  })
  .refine((d) => d.startTime !== d.endTime, {
    message: 'startTime and endTime must differ (use 00:00-23:59 for full day)',
    path: ['endTime'],
  });

const updateSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  startTime: z.string().regex(TIME_REGEX, 'startTime must be HH:MM').optional(),
  endTime: z.string().regex(TIME_REGEX, 'endTime must be HH:MM').optional(),
  daysOfWeek: daysOfWeekSchema.optional(),
  action: z.enum(['BLOCK', 'ALLOW']).optional(),
  isActive: z.boolean().optional(),
});

export const scheduleRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.addHook('preHandler', authGuard);

  /**
   * GET /api/children/:childId/schedules
   * Bola schedule'lari (PARENT yoki bog'langan CHILD)
   */
  fastify.get<{ Params: { childId: string } }>(
    '/children/:childId/schedules',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.parentId !== userId && child.childUserId !== userId) {
        return reply.code(403).send({ error: 'Forbidden' });
      }

      const schedules = await prisma.schedule.findMany({
        where: { childId },
        orderBy: { createdAt: 'desc' },
      });

      return reply.send({ schedules, count: schedules.length });
    },
  );

  /**
   * POST /api/children/:childId/schedules
   * Yangi schedule yaratish (PARENT only)
   */
  fastify.post<{ Params: { childId: string } }>(
    '/children/:childId/schedules',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.parentId !== userId) {
        return reply.code(403).send({ error: 'Only parent can create schedules' });
      }

      const parsed = createSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
      }

      const schedule = await prisma.schedule.create({
        data: {
          childId,
          name: parsed.data.name,
          startTime: parsed.data.startTime,
          endTime: parsed.data.endTime,
          daysOfWeek: parsed.data.daysOfWeek,
          action: parsed.data.action,
          isActive: parsed.data.isActive ?? true,
        },
      });

      await writeAudit(request, 'schedule', 'CREATE', schedule.id, parsed.data);
      emitToChild(childId, 'schedule:created', schedule);

      return reply.code(201).send(schedule);
    },
  );

  /**
   * GET /api/schedules/:id
   * Bitta schedule (PARENT yoki bog'langan CHILD)
   */
  fastify.get<{ Params: { id: string } }>('/schedules/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const schedule = await prisma.schedule.findUnique({
      where: { id },
      include: { child: true },
    });

    if (!schedule) return reply.code(404).send({ error: 'Schedule not found' });
    if (schedule.child.parentId !== userId && schedule.child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    const { child: _omit, ...rest } = schedule;
    return reply.send(rest);
  });

  /**
   * PUT /api/schedules/:id
   * Schedule yangilash (PARENT only)
   */
  fastify.put<{ Params: { id: string } }>('/schedules/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const schedule = await prisma.schedule.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!schedule) return reply.code(404).send({ error: 'Schedule not found' });
    if (schedule.child.parentId !== userId) {
      return reply.code(403).send({ error: 'Only parent can update schedules' });
    }

    const parsed = updateSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
    }

    const nextStart = parsed.data.startTime ?? schedule.startTime;
    const nextEnd = parsed.data.endTime ?? schedule.endTime;
    if (nextStart === nextEnd) {
      return reply.code(400).send({
        error: 'startTime and endTime must differ (use 00:00-23:59 for full day)',
      });
    }

    const updated = await prisma.schedule.update({
      where: { id },
      data: parsed.data,
    });

    await writeAudit(request, 'schedule', 'UPDATE', id, parsed.data);
    emitToChild(updated.childId, 'schedule:updated', updated);

    return reply.send(updated);
  });

  /**
   * DELETE /api/schedules/:id
   * Schedule o'chirish (PARENT only)
   */
  fastify.delete<{ Params: { id: string } }>('/schedules/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const schedule = await prisma.schedule.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!schedule) return reply.code(404).send({ error: 'Schedule not found' });
    if (schedule.child.parentId !== userId) {
      return reply.code(403).send({ error: 'Only parent can delete schedules' });
    }

    const childIdForEmit = schedule.childId;
    await prisma.schedule.delete({ where: { id } });
    await writeAudit(request, 'schedule', 'DELETE', id);
    emitToChild(childIdForEmit, 'schedule:deleted', { id });

    return reply.send({ ok: true });
  });
};
