import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { authGuard } from '../../middleware/auth';
import { prisma } from '../../lib/prisma';
import { writeAudit } from '../../lib/audit';
import { emitToChild } from '../../lib/realtime';

// GeoZone = bola atrofidagi geo-fence (uy, maktab, ...). Parent App'da xarita orqali
// chiziladi. Child App location yuborganda backend yoki client tomondan check qilinadi:
// — Zona ichidamiz? alertOnEnter bo'lsa parent'ga push
// — Zona tashqarisidamiz? alertOnExit bo'lsa parent'ga push
// Hozir REST CRUD. Real-time alert WebSocket (4.2.10) + FCM (4.2.11) bilan qo'shiladi.

const RADIUS_MIN_METERS = 10;
const RADIUS_MAX_METERS = 50_000; // 50 km

const createSchema = z.object({
  name: z.string().min(1).max(100),
  centerLat: z.number().min(-90).max(90),
  centerLng: z.number().min(-180).max(180),
  radiusMeters: z.number().int().min(RADIUS_MIN_METERS).max(RADIUS_MAX_METERS),
  alertOnEnter: z.boolean().optional(),
  alertOnExit: z.boolean().optional(),
  isActive: z.boolean().optional(),
});

const updateSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  centerLat: z.number().min(-90).max(90).optional(),
  centerLng: z.number().min(-180).max(180).optional(),
  radiusMeters: z.number().int().min(RADIUS_MIN_METERS).max(RADIUS_MAX_METERS).optional(),
  alertOnEnter: z.boolean().optional(),
  alertOnExit: z.boolean().optional(),
  isActive: z.boolean().optional(),
});

const eventsQuerySchema = z.object({
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
  limit: z.coerce.number().int().min(1).max(200).default(50),
});

export const geoZoneRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.addHook('preHandler', authGuard);

  /**
   * GET /api/children/:childId/geo-zones
   * Bolaning hamma geo-zonalari (PARENT yoki bog'langan CHILD)
   */
  fastify.get<{ Params: { childId: string } }>(
    '/children/:childId/geo-zones',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.parentId !== userId && child.childUserId !== userId) {
        return reply.code(403).send({ error: 'Forbidden' });
      }

      const zones = await prisma.geoZone.findMany({
        where: { childId },
        orderBy: { createdAt: 'desc' },
      });

      return reply.send({ zones, count: zones.length });
    },
  );

  /**
   * POST /api/children/:childId/geo-zones
   * Yangi geo-zona yaratish (PARENT only)
   */
  fastify.post<{ Params: { childId: string } }>(
    '/children/:childId/geo-zones',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.parentId !== userId) {
        return reply.code(403).send({ error: 'Only parent can create geo-zones' });
      }

      const parsed = createSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
      }

      const zone = await prisma.geoZone.create({
        data: {
          childId,
          name: parsed.data.name,
          centerLat: parsed.data.centerLat,
          centerLng: parsed.data.centerLng,
          radiusMeters: parsed.data.radiusMeters,
          alertOnEnter: parsed.data.alertOnEnter ?? false,
          alertOnExit: parsed.data.alertOnExit ?? false,
          isActive: parsed.data.isActive ?? true,
        },
      });

      await writeAudit(request, 'geo_zone', 'CREATE', zone.id, parsed.data);
      emitToChild(childId, 'geo_zone:created', zone);

      return reply.code(201).send(zone);
    },
  );

  /**
   * GET /api/geo-zones/:id
   * Bitta geo-zona (PARENT yoki bog'langan CHILD)
   */
  fastify.get<{ Params: { id: string } }>('/geo-zones/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const zone = await prisma.geoZone.findUnique({
      where: { id },
      include: { child: true },
    });

    if (!zone) return reply.code(404).send({ error: 'Geo-zone not found' });
    if (zone.child.parentId !== userId && zone.child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    const { child: _omit, ...rest } = zone;
    return reply.send(rest);
  });

  /**
   * PUT /api/geo-zones/:id
   * Geo-zona yangilash (PARENT only)
   */
  fastify.put<{ Params: { id: string } }>('/geo-zones/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const zone = await prisma.geoZone.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!zone) return reply.code(404).send({ error: 'Geo-zone not found' });
    if (zone.child.parentId !== userId) {
      return reply.code(403).send({ error: 'Only parent can update geo-zones' });
    }

    const parsed = updateSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
    }

    const updated = await prisma.geoZone.update({
      where: { id },
      data: parsed.data,
    });

    await writeAudit(request, 'geo_zone', 'UPDATE', id, parsed.data);
    emitToChild(updated.childId, 'geo_zone:updated', updated);

    return reply.send(updated);
  });

  /**
   * DELETE /api/geo-zones/:id
   * Geo-zona o'chirish (PARENT only)
   */
  fastify.delete<{ Params: { id: string } }>('/geo-zones/:id', async (request, reply) => {
    const userId = request.user!.userId;
    const { id } = request.params;

    const zone = await prisma.geoZone.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!zone) return reply.code(404).send({ error: 'Geo-zone not found' });
    if (zone.child.parentId !== userId) {
      return reply.code(403).send({ error: 'Only parent can delete geo-zones' });
    }

    const childIdForEmit = zone.childId;
    await prisma.geoZone.delete({ where: { id } });
    await writeAudit(request, 'geo_zone', 'DELETE', id);
    emitToChild(childIdForEmit, 'geo_zone:deleted', { id });

    return reply.send({ ok: true });
  });

  /**
   * GET /api/children/:childId/geo-zone-events
   * Geo-zona kirish/chiqish hodisalari tarixi (PARENT yoki bog'langan CHILD).
   */
  fastify.get<{
    Params: { childId: string };
    Querystring: { from?: string; to?: string; limit?: number };
  }>('/children/:childId/geo-zone-events', async (request, reply) => {
    const userId = request.user!.userId;
    const { childId } = request.params;

    const child = await prisma.child.findUnique({ where: { id: childId } });
    if (!child) return reply.code(404).send({ error: 'Child not found' });
    if (child.parentId !== userId && child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    const parsed = eventsQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid query', details: parsed.error.format() });
    }
    const { from, to, limit } = parsed.data;

    const events = await prisma.geoZoneEvent.findMany({
      where: {
        childId,
        createdAt: {
          ...(from && { gte: new Date(from) }),
          ...(to && { lte: new Date(to) }),
        },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
      include: { zone: { select: { name: true } } },
    });

    return reply.send({
      events: events.map((e) => ({
        id: e.id,
        zoneId: e.zoneId,
        zoneName: e.zone.name,
        type: e.type,
        latitude: e.latitude,
        longitude: e.longitude,
        createdAt: e.createdAt.toISOString(),
      })),
      count: events.length,
    });
  });
};
