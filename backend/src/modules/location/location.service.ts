import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { distanceMeters } from '../../common/helpers/haversine';
import { WriteLocationDto } from './dto/write-location.dto';
import { LocationHistoryQueryDto } from './dto/location-history-query.dto';

export interface GeofenceEvent {
  zoneId: string;
  zoneName: string;
  type: 'enter' | 'exit';
}

// ── Stop-detection sozlamalari ──
/** Klaster radiusi — shu masofadagi nuqtalar "bir joy" hisoblanadi. */
const STOP_RADIUS_M = 20;
/** Minimal to'xtash davomiyligi — shundan kam bo'lsa marker yaratilmaydi. */
const MIN_STOP_SEC = 180; // 3 daqiqa

/** detectStop uchun kerakli minimal Child maydonlari. */
interface StopState {
  id: string;
  parentId: string;
  stopAnchorLat: number | null;
  stopAnchorLng: number | null;
  stopAnchorAt: Date | null;
  openStopId: string | null;
}

@Injectable()
export class LocationService {
  private readonly logger = new Logger(LocationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmService,
    private readonly realtime: RealtimeGateway,
  ) {}

  /* ------------------------------------------------------------------ */
  /*  POST /location — write + geofence check                           */
  /* ------------------------------------------------------------------ */

  async writeLocation(userId: string, dto: WriteLocationDto) {
    const {
      childId,
      latitude,
      longitude,
      deviceModel,
      androidVersion,
      appVersion,
      wifiName,
      ...rest
    } = dto;

    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    if (child.childUserId !== userId && child.parentId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    // Stop-detection — dedup'dan OLDIN ishlaydi (statsionar nuqtalar ham
    // to'xtashni aniqlashga hissa qo'shadi). Xato bo'lsa location yozuvi
    // baribir davom etadi.
    try {
      await this.detectStop(child, latitude, longitude, this.parseAt(dto.capturedAt));
    } catch (err) {
      this.logger.warn({ err }, 'stop detection failed');
    }

    // Device info update on child record
    const childDeviceUpdate: Record<string, unknown> = {
      lastSeenAt: new Date(),
      batteryLevel: rest.batteryLevel ?? child.batteryLevel,
      isCharging: rest.isCharging ?? child.isCharging,
    };
    if (deviceModel !== undefined) childDeviceUpdate.deviceModel = deviceModel;
    if (androidVersion !== undefined) childDeviceUpdate.androidVersion = androidVersion;
    if (appVersion !== undefined) childDeviceUpdate.appVersion = appVersion;
    if (wifiName !== undefined) childDeviceUpdate.wifiName = wifiName;

    // 10-meter deduplication
    const lastLocation = await this.prisma.location.findFirst({
      where: { childId },
      orderBy: { createdAt: 'desc' },
    });

    if (lastLocation) {
      const distance = distanceMeters(
        lastLocation.latitude,
        lastLocation.longitude,
        latitude,
        longitude,
      );
      if (distance < 10) {
        await this.prisma.child.update({
          where: { id: childId },
          data: childDeviceUpdate,
        });
        return { ok: true, written: false, reason: 'too_close', distance };
      }
    }

    // Create location record
    const location = await this.prisma.location.create({
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

    await this.prisma.child.update({
      where: { id: childId },
      data: childDeviceUpdate,
    });

    // Real-time: emit to parent + child room
    this.realtime.emitToUser(child.parentId, 'location:updated', {
      childId,
      location,
    });
    this.realtime.emitToChild(childId, 'location:updated', {
      childId,
      location,
    });

    // Geofence transition detection (only if previous location exists)
    const geofenceEvents: GeofenceEvent[] = [];

    if (lastLocation) {
      const zones = await this.prisma.geoZone.findMany({
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
        const currDist = distanceMeters(
          latitude,
          longitude,
          zone.centerLat,
          zone.centerLng,
        );
        const wasInside = prevDist <= zone.radiusMeters;
        const isInside = currDist <= zone.radiusMeters;

        if (!wasInside && isInside && zone.alertOnEnter) {
          geofenceEvents.push({
            zoneId: zone.id,
            zoneName: zone.name,
            type: 'enter',
          });
        } else if (wasInside && !isInside && zone.alertOnExit) {
          geofenceEvents.push({
            zoneId: zone.id,
            zoneName: zone.name,
            type: 'exit',
          });
        }
      }

      // Persist geofence events
      if (geofenceEvents.length > 0) {
        await this.prisma.geoZoneEvent.createMany({
          data: geofenceEvents.map((e) => ({
            zoneId: e.zoneId,
            childId,
            type: e.type,
            latitude,
            longitude,
          })),
        });
      }

      // Push + realtime for each geofence event
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

        this.realtime.emitToUser(child.parentId, 'geo_zone:alert', payload);
        this.realtime.emitToChild(childId, 'geo_zone:alert', payload);

        try {
          await this.fcm.sendPushToUser(child.parentId, {
            title: `${child.name} ${isEntry ? 'zonaga kirdi' : 'zonadan chiqdi'}`,
            body: `${event.zoneName}${isEntry ? 'ga kirdi' : 'dan chiqdi'}`,
            data: {
              type: 'geofence',
              event: event.type,
              zoneId: event.zoneId,
              childId,
            },
          });
        } catch (err) {
          this.logger.warn(
            { err, zoneId: event.zoneId },
            'geofence push failed',
          );
        }
      }
    }

    return { ok: true, written: true, location, geofenceEvents };
  }

  /* ------------------------------------------------------------------ */
  /*  GET /children/:childId/location — last known location              */
  /* ------------------------------------------------------------------ */

  async getLastLocation(childId: string, userId: string) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const location = await this.prisma.location.findFirst({
      where: { childId },
      orderBy: { createdAt: 'desc' },
    });

    if (!location) {
      throw new NotFoundException('No location data');
    }

    return {
      location,
      child: {
        id: child.id,
        name: child.name,
        batteryLevel: child.batteryLevel,
        isCharging: child.isCharging,
        lastSeenAt: child.lastSeenAt,
      },
    };
  }

  /* ------------------------------------------------------------------ */
  /*  GET /children/:childId/location/history                            */
  /* ------------------------------------------------------------------ */

  async getLocationHistory(
    childId: string,
    userId: string,
    query: LocationHistoryQueryDto,
  ) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const { from, to, limit } = query;

    const createdAtFilter: Record<string, Date> = {};
    if (from) createdAtFilter.gte = new Date(from);
    if (to) createdAtFilter.lte = new Date(to);

    const locations = await this.prisma.location.findMany({
      where: {
        childId,
        ...(Object.keys(createdAtFilter).length > 0 && {
          createdAt: createdAtFilter,
        }),
      },
      orderBy: { createdAt: 'desc' },
      take: limit ?? 100,
    });

    return { locations, count: locations.length };
  }

  /* ------------------------------------------------------------------ */
  /*  GET /children/:childId/location/stops — to'xtagan joylar           */
  /* ------------------------------------------------------------------ */

  async getStops(
    childId: string,
    userId: string,
    query: LocationHistoryQueryDto,
  ) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const { from, to } = query;
    const arrivedAtFilter: Record<string, Date> = {};
    if (from) arrivedAtFilter.gte = new Date(from);
    if (to) arrivedAtFilter.lte = new Date(to);

    const stops = await this.prisma.locationStop.findMany({
      where: {
        childId,
        ...(Object.keys(arrivedAtFilter).length > 0 && {
          arrivedAt: arrivedAtFilter,
        }),
      },
      orderBy: { arrivedAt: 'asc' },
    });

    return { stops, count: stops.length };
  }

  /* ------------------------------------------------------------------ */
  /*  Stop detection — incremental state machine                         */
  /* ------------------------------------------------------------------ */
  //
  // Algoritm (har location nuqtasida, dedup'dan oldin):
  //   - `anchor` = joriy klaster boshlangan nuqta (lat/lng/at).
  //   - Yangi nuqta anchor'dan <= STOP_RADIUS_M bo'lsa → bola hali shu joyda:
  //       * dwell = now - anchorAt. dwell >= MIN_STOP_SEC bo'lsa va ochiq
  //         to'xtash yo'q bo'lsa → yangi LocationStop yaratiladi.
  //       * Ochiq to'xtash bor bo'lsa → davomiyligi/leftAt yangilanadi.
  //   - Yangi nuqta anchor'dan uzoq bo'lsa → bola harakatlandi: anchor yangi
  //     nuqtaga ko'chiriladi, ochiq to'xtash yopiladi (oxirgi leftAt bilan).
  //
  // Natija: faqat ≥2.5 daqiqa turilgan joylar marker bo'ladi; harakat
  // nuqtalari (locations) faqat yupqa chiziq uchun. "Belgi kam, hech biri
  // o'tkazilmaydi".

  private async detectStop(
    child: StopState,
    latitude: number,
    longitude: number,
    at: Date,
  ): Promise<void> {
    const { stopAnchorLat, stopAnchorLng, stopAnchorAt, openStopId } = child;

    // Anchor hali yo'q (birinchi nuqta) — o'rnatamiz.
    if (stopAnchorLat === null || stopAnchorLng === null || stopAnchorAt === null) {
      await this.prisma.child.update({
        where: { id: child.id },
        data: {
          stopAnchorLat: latitude,
          stopAnchorLng: longitude,
          stopAnchorAt: at,
          openStopId: null,
        },
      });
      return;
    }

    const dist = distanceMeters(
      stopAnchorLat,
      stopAnchorLng,
      latitude,
      longitude,
    );

    if (dist <= STOP_RADIUS_M) {
      // Anchor atrofida — potensial yoki davom etayotgan to'xtash.
      const dwellSec = Math.max(
        0,
        Math.round((at.getTime() - stopAnchorAt.getTime()) / 1000),
      );

      if (openStopId) {
        // Ochiq to'xtashni yangilash (o'chirilgan bo'lsa jim o'tamiz).
        await this.prisma.locationStop
          .update({
            where: { id: openStopId },
            data: {
              leftAt: at,
              durationSec: dwellSec,
              pointCount: { increment: 1 },
            },
          })
          .catch(() => undefined);
      } else if (dwellSec >= MIN_STOP_SEC) {
        // Yangi to'xtash ochish — markaz = klaster boshi (anchor).
        const stop = await this.prisma.locationStop.create({
          data: {
            childId: child.id,
            latitude: stopAnchorLat,
            longitude: stopAnchorLng,
            arrivedAt: stopAnchorAt,
            leftAt: at,
            durationSec: dwellSec,
            pointCount: 2,
          },
        });
        await this.prisma.child.update({
          where: { id: child.id },
          data: { openStopId: stop.id },
        });
        this.realtime.emitToUser(child.parentId, 'location:stop', {
          childId: child.id,
          stop,
        });
      }
      // else: hali 2.5 daqiqa bo'lmadi — anchor saqlanadi, kutamiz.
    } else {
      // Harakat — anchor yangi nuqtaga ko'chadi, ochiq to'xtash yopiladi.
      await this.prisma.child.update({
        where: { id: child.id },
        data: {
          stopAnchorLat: latitude,
          stopAnchorLng: longitude,
          stopAnchorAt: at,
          openStopId: null,
        },
      });
    }
  }

  /** ISO 8601 client timestamp → Date. Noto'g'ri/bo'sh bo'lsa server vaqti. */
  private parseAt(raw?: string): Date {
    if (raw) {
      const d = new Date(raw);
      if (!Number.isNaN(d.getTime())) return d;
    }
    return new Date();
  }
}
