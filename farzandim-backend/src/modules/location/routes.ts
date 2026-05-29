import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { authGuard } from '../../middleware/auth';
import { prisma } from '../../lib/prisma';
import { sendPushToUser } from '../../lib/fcm';
import { emitToUser, emitToChild } from '../../lib/realtime';

type GeofenceEvent = {
  zoneId: string;
  zoneName: string;
  type: 'enter' | 'exit';
};

const writeLocationSchema = z.object({
  childId: z.string().uuid(),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  accuracy: z.number().optional(),
  speed: z.number().optional(),
  batteryLevel: z.number().int().min(0).max(100).optional(),
  isCharging: z.boolean().optional(),
  // Device info (Child App har location POST'da yuboradi — Sprint 4.4.12)
  deviceModel: z.string().max(100).optional(),
  androidVersion: z.string().max(50).optional(),
  appVersion: z.string().max(50).optional(),
  wifiName: z.string().max(100).optional(),
});

const historyQuerySchema = z.object({
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
  limit: z.coerce.number().int().min(1).max(500).default(100),
});

function distanceMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

export const locationRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.addHook('preHandler', authGuard);

  fastify.post('/location', async (request, reply) => {
    const userId = request.user!.userId;
    const parsed = writeLocationSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
    }

    const { childId, latitude, longitude, deviceModel, androidVersion, appVersion, wifiName, ...rest } = parsed.data;

    const child = await prisma.child.findUnique({ where: { id: childId } });
    if (!child) return reply.code(404).send({ error: 'Child not found' });
    if (child.childUserId !== userId && child.parentId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    // Device info — Child obyektida yangilash uchun (har POST'da yuborilsa yangilanadi)
    const childDeviceUpdate = {
      lastSeenAt: new Date(),
      batteryLevel: rest.batteryLevel ?? child.batteryLevel,
      isCharging: rest.isCharging ?? child.isCharging,
      ...(deviceModel !== undefined && { deviceModel }),
      ...(androidVersion !== undefined && { androidVersion }),
      ...(appVersion !== undefined && { appVersion }),
      ...(wifiName !== undefined && { wifiName }),
    };

    const lastLocation = await prisma.location.findFirst({
      where: { childId },
      orderBy: { createdAt: 'desc' },
    });

    if (lastLocation) {
      const distance = distanceMeters(lastLocation.latitude, lastLocation.longitude, latitude, longitude);
      if (distance < 10) {
        await prisma.child.update({
          where: { id: childId },
          data: childDeviceUpdate,
        });
        return reply.send({ ok: true, written: false, reason: 'too_close', distance });
      }
    }

    // Location row uchun faqat lokatsiya field'lari (rest'da batteryLevel + isCharging ham bor)
    const location = await prisma.location.create({
      data: {
        childId,
        latitude,
        longitude,
        accuracy: rest.accuracy,
        speed: rest.speed,
        batteryLevel: rest.batteryLevel,
        isCharging: rest.isCharging,
      },
    });

    await prisma.child.update({
      where: { id: childId },
      data: childDeviceUpdate,
    });

    // Real-time: parent'ga yangi lokatsiya, child room'ga ham (parent socket child room'da)
    emitToUser(child.parentId, 'location:updated', { childId, location });
    emitToChild(childId, 'location:updated', { childId, location });

    // Geofence transition detection (faqat lastLocation bo'lsa — birinchi location event'lar tug'dirmaydi)
    const geofenceEvents: GeofenceEvent[] = [];
    if (lastLocation) {
      const zones = await prisma.geoZone.findMany({
        where: {
          childId,
          isActive: true,
          OR: [{ alertOnEnter: true }, { alertOnExit: true }],
        },
      });

      for (const zone of zones) {
        const prevDist = distanceMeters(
          lastLocation.latitude,
          lastLocation.longitude,
          zone.centerLat,
          zone.centerLng,
        );
        const currDist = distanceMeters(latitude, longitude, zone.centerLat, zone.centerLng);
        const wasInside = prevDist <= zone.radiusMeters;
        const isInside = currDist <= zone.radiusMeters;

        if (!wasInside && isInside && zone.alertOnEnter) {
          geofenceEvents.push({ zoneId: zone.id, zoneName: zone.name, type: 'enter' });
        } else if (wasInside && !isInside && zone.alertOnExit) {
          geofenceEvents.push({ zoneId: zone.id, zoneName: zone.name, type: 'exit' });
        }
      }

      // Sprint 6 P2 — hodisalarni tarix jadvaliga saqlash.
      if (geofenceEvents.length > 0) {
        await prisma.geoZoneEvent.createMany({
          data: geofenceEvents.map((e) => ({
            zoneId: e.zoneId,
            childId,
            type: e.type,
            latitude,
            longitude,
          })),
        });
      }

      // Parent'ga push (FCM service account .env'da yo'q bo'lsa silently no-op)
      // + WebSocket real-time event (Sprint 4.2.10)
      for (const event of geofenceEvents) {
        const isEntry = event.type === 'enter';
        const payload = {
          type: 'geofence' as const,
          event: event.type,
          zoneId: event.zoneId,
          zoneName: event.zoneName,
          childId,
          location: { latitude, longitude },
        };

        emitToUser(child.parentId, 'geo_zone:alert', payload);
        emitToChild(childId, 'geo_zone:alert', payload);

        try {
          await sendPushToUser(prisma, child.parentId, {
            title: `${child.name} ${isEntry ? 'zonaga kirdi' : 'zonadan chiqdi'}`,
            body: `${event.zoneName}${isEntry ? "ga kirdi" : "dan chiqdi"}`,
            data: {
              type: 'geofence',
              event: event.type,
              zoneId: event.zoneId,
              childId,
            },
          });
        } catch (err) {
          request.log.warn({ err, zoneId: event.zoneId }, 'geofence push failed');
        }
      }
    }

    return reply.send({ ok: true, written: true, location, geofenceEvents });
  });

  fastify.get<{ Params: { childId: string } }>('/children/:childId/location', async (request, reply) => {
    const userId = request.user!.userId;
    const { childId } = request.params;

    const child = await prisma.child.findUnique({ where: { id: childId } });
    if (!child) return reply.code(404).send({ error: 'Child not found' });
    if (child.parentId !== userId && child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    const location = await prisma.location.findFirst({
      where: { childId },
      orderBy: { createdAt: 'desc' },
    });

    if (!location) return reply.code(404).send({ error: 'No location data' });

    return reply.send({
      location,
      child: {
        id: child.id,
        name: child.name,
        batteryLevel: child.batteryLevel,
        isCharging: child.isCharging,
        lastSeenAt: child.lastSeenAt,
      },
    });
  });

  fastify.get<{
    Params: { childId: string };
    Querystring: { from?: string; to?: string; limit?: number };
  }>('/children/:childId/location/history', async (request, reply) => {
    const userId = request.user!.userId;
    const { childId } = request.params;

    const parsed = historyQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid query', details: parsed.error.format() });
    }

    const child = await prisma.child.findUnique({ where: { id: childId } });
    if (!child) return reply.code(404).send({ error: 'Child not found' });
    if (child.parentId !== userId && child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    const { from, to, limit } = parsed.data;

    const locations = await prisma.location.findMany({
      where: {
        childId,
        createdAt: {
          ...(from && { gte: new Date(from) }),
          ...(to && { lte: new Date(to) }),
        },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    return reply.send({ locations, count: locations.length });
  });
};
