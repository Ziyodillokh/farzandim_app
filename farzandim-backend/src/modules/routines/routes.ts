import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import type { Routine } from '@prisma/client';
import { authGuard } from '../../middleware/auth';
import { prisma } from '../../lib/prisma';
import { writeAudit } from '../../lib/audit';
import { emitToChild } from '../../lib/realtime';
import { tashkentNow, isActiveNow } from '../../lib/routines-rules';

// Routine = bola kun rejasi (Uxlash/Maktab/Sport/...). Cheklash YO'Q — faqat display.
// Child App Dashboard'ning "Hozir/Keyingi" mini-card'i shu modulni ishlatadi.

const ROUTINE_TYPES = ['SLEEP', 'SCHOOL', 'HOMEWORK', 'SPORT', 'OTHER'] as const;

// weekdays: ISO 8601 (1=Mon ... 7=Sun)
const weekdaysSchema = z
  .array(z.number().int().min(1).max(7))
  .min(1)
  .max(7)
  .transform((arr) => Array.from(new Set(arr)).sort((a, b) => a - b));

const createSchema = z
  .object({
    title: z.string().min(1).max(50),
    type: z.enum(ROUTINE_TYPES),
    startHour: z.number().int().min(0).max(23),
    startMinute: z.number().int().min(0).max(59),
    endHour: z.number().int().min(0).max(23),
    endMinute: z.number().int().min(0).max(59),
    weekdays: weekdaysSchema,
    isActive: z.boolean().optional(),
  })
  .refine((d) => d.startHour * 60 + d.startMinute !== d.endHour * 60 + d.endMinute, {
    message: 'start and end must differ',
    path: ['endHour'],
  });

const updateSchema = z.object({
  title: z.string().min(1).max(50).optional(),
  type: z.enum(ROUTINE_TYPES).optional(),
  startHour: z.number().int().min(0).max(23).optional(),
  startMinute: z.number().int().min(0).max(59).optional(),
  endHour: z.number().int().min(0).max(23).optional(),
  endMinute: z.number().int().min(0).max(59).optional(),
  weekdays: weekdaysSchema.optional(),
  isActive: z.boolean().optional(),
});

export const routineRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.addHook('preHandler', authGuard);

  /**
   * GET /api/children/:childId/routines
   * Bolaning hamma routine'lari (PARENT yoki bog'langan CHILD)
   */
  fastify.get<{ Params: { childId: string } }>(
    '/children/:childId/routines',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.parentId !== userId && child.childUserId !== userId) {
        return reply.code(403).send({ error: 'Forbidden' });
      }

      const routines = await prisma.routine.findMany({
        where: { childId },
        orderBy: [{ startHour: 'asc' }, { startMinute: 'asc' }],
      });

      return reply.send({ routines, count: routines.length });
    },
  );

  /**
   * GET /api/children/:childId/routines/today
   * Bugungi aktiv routine'lar + hozirgi va keyingi (Tashkent UTC+5)
   * Child Dashboard mini-card uchun.
   */
  fastify.get<{ Params: { childId: string } }>(
    '/children/:childId/routines/today',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.parentId !== userId && child.childUserId !== userId) {
        return reply.code(403).send({ error: 'Forbidden' });
      }

      const { isoWeekday, totalMinutes, hour, minute } = tashkentNow();

      // weekdays array contains today's ISO day → has(currentWeekday)
      const todayRoutines = await prisma.routine.findMany({
        where: {
          childId,
          isActive: true,
          weekdays: { has: isoWeekday },
        },
        orderBy: [{ startHour: 'asc' }, { startMinute: 'asc' }],
      });

      // current: hozir window ichida bo'lgani
      let current: Routine | null = null;
      for (const r of todayRoutines) {
        if (isActiveNow(r, totalMinutes)) {
          current = r;
          break;
        }
      }

      // next: hozirdan keyin boshlanadigan eng yaqini (bugun ichida)
      let next: (Routine & { startsInMinutes: number }) | null = null;
      let bestDelta = Infinity;
      for (const r of todayRoutines) {
        const startMin = r.startHour * 60 + r.startMinute;
        if (startMin > totalMinutes) {
          const delta = startMin - totalMinutes;
          if (delta < bestDelta) {
            bestDelta = delta;
            next = { ...r, startsInMinutes: delta };
          }
        }
      }

      return reply.send({
        today: todayRoutines,
        current,
        next,
        serverTime: {
          isoWeekday,
          hour,
          minute,
          timezone: 'Asia/Tashkent',
        },
      });
    },
  );

  /**
   * POST /api/children/:childId/routines
   * Yangi routine yaratish (PARENT only)
   */
  fastify.post<{ Params: { childId: string } }>(
    '/children/:childId/routines',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.parentId !== userId) {
        return reply.code(403).send({ error: 'Only parent can create routines' });
      }

      const parsed = createSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
      }

      const routine = await prisma.routine.create({
        data: {
          childId,
          title: parsed.data.title,
          type: parsed.data.type,
          startHour: parsed.data.startHour,
          startMinute: parsed.data.startMinute,
          endHour: parsed.data.endHour,
          endMinute: parsed.data.endMinute,
          weekdays: parsed.data.weekdays,
          isActive: parsed.data.isActive ?? true,
        },
      });

      await writeAudit(request, 'routine', 'CREATE', routine.id, parsed.data);
      emitToChild(childId, 'routine:created', routine);

      return reply.code(201).send(routine);
    },
  );

  /**
   * GET /api/routines/:id
   */
  fastify.get<{ Params: { id: string } }>('/routines/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const routine = await prisma.routine.findUnique({
      where: { id },
      include: { child: true },
    });

    if (!routine) return reply.code(404).send({ error: 'Routine not found' });
    if (routine.child.parentId !== userId && routine.child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    const { child: _omit, ...rest } = routine;
    return reply.send(rest);
  });

  /**
   * PUT /api/routines/:id
   * Routine yangilash (PARENT only)
   */
  fastify.put<{ Params: { id: string } }>('/routines/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const routine = await prisma.routine.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!routine) return reply.code(404).send({ error: 'Routine not found' });
    if (routine.child.parentId !== userId) {
      return reply.code(403).send({ error: 'Only parent can update routines' });
    }

    const parsed = updateSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
    }

    const nextStartMin =
      (parsed.data.startHour ?? routine.startHour) * 60 +
      (parsed.data.startMinute ?? routine.startMinute);
    const nextEndMin =
      (parsed.data.endHour ?? routine.endHour) * 60 +
      (parsed.data.endMinute ?? routine.endMinute);
    if (nextStartMin === nextEndMin) {
      return reply.code(400).send({ error: 'start and end must differ' });
    }

    const updated = await prisma.routine.update({
      where: { id },
      data: parsed.data,
    });

    await writeAudit(request, 'routine', 'UPDATE', id, parsed.data);
    emitToChild(updated.childId, 'routine:updated', updated);

    return reply.send(updated);
  });

  /**
   * DELETE /api/routines/:id
   */
  fastify.delete<{ Params: { id: string } }>('/routines/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const routine = await prisma.routine.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!routine) return reply.code(404).send({ error: 'Routine not found' });
    if (routine.child.parentId !== userId) {
      return reply.code(403).send({ error: 'Only parent can delete routines' });
    }

    const childIdForEmit = routine.childId;
    await prisma.routine.delete({ where: { id } });
    await writeAudit(request, 'routine', 'DELETE', id);
    emitToChild(childIdForEmit, 'routine:deleted', { id });

    return reply.send({ ok: true });
  });
};
