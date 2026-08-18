import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { BatteryAlertService } from '../../common/battery/battery-alert.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { distanceMeters } from '../../common/helpers/haversine';
import { WriteLocationDto } from './dto/write-location.dto';
import { LocationHistoryQueryDto } from './dto/location-history-query.dto';
import { tr } from '../../common/i18n/notification-i18n';

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

// ── Kirish (ingest) filtri — GPS "jitter" va xato fix'larni history'ga
//    yozmaslik uchun. Muammo: bola bir joyda turganda GPS 10–40m sakraydi
//    (heartbeat har 60s) → har sakrash >10m yangi nuqta → tarixda soxta
//    "borib-kelish" zigzag + shishgan masofa (masalan 356 km). ──
/** Aniqligi shundan yomon (kattaroq, m) fix history'ga yozilmaydi (cell-tower/garbage). */
const MAX_ACCURACY_M = 50;
/** Harakat chegarasi (m/s) — shundan tez bo'lsa "harakatda" deb hisoblanadi.
 *  1.0 m/s: sekin yurish ham harakat sanaladi (bola yurishi ~1.0-1.4 m/s),
 *  aks holda piyoda yo'l "statsionar" filtrga tushib chizilmay qolardi. */
const MOVING_SPEED_MS = 1.0;
/** Harakatda: yo'l chizig'i shu qadamda yoziladi (m) — nozik, ko'cha bo'ylab. */
const MOVE_MIN_M = 12;
/** Statsionar/noma'lum: jitter'ni yutish uchun shundan kam siljish yozilmaydi (m).
 *  25m — uy ichidagi GPS sakrashini hali ham yutadi, lekin sekin siljishni
 *  avvalgi 35m kabi uzoq yutib yubormaydi. */
const JITTER_MIN_M = 25;

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
    private readonly batteryAlert: BatteryAlertService,
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
    // wifiName ATAYLAB saqlanmaydi (2026-08-18) — Families Device
    // Identifiers: eski APK'lar (versionCode<=5) hali SSID yuborishi
    // mumkin; server tomonda tashlab yuboramiz. DTO'dagi maydon faqat
    // validatsiya 400 bermasligi uchun qoldirilgan.
    // Heartbeat kelgani — qurilma ulangan deb belgilaymiz (device-info
    // endpoint bilan bir xil mantiq). Aks holda device-info ishlamay qolsa
    // faqat GPS yuborayotgan bola DB'da isConnected=false bo'lib ota-onada
    // abadiy kulrang "Ulanmagan" ko'rinardi. Auth-guard'dan o'tgan (childUserId
    // yoki parentId mos) so'rovlardagina ishlaydi — regenerate qilingan eski
    // qurilma (403) buni soxta true qila olmaydi.
    if (!child.isConnected) childDeviceUpdate.isConnected = true;

    // ── Past batareya (<10%) push — umumiy BatteryAlertService orqali (bir
    //    marta — crossing). child.batteryLevel hali ESKI qiymat (update
    //    quyiroqda) → prevBattery sifatida uzatamiz. Lokatsiya push ichida —
    //    ota-ona joyni ko'radi. Device-info heartbeat ham shu servisni
    //    chaqiradi (aks holda u crossing'ni "yeb" qo'yardi).
    void this.batteryAlert.checkCrossing(
      child,
      child.batteryLevel,
      rest.batteryLevel,
      rest.isCharging,
      { latitude, longitude },
    );

    // ── Kirish filtri: jitter/garbage nuqtalar history'ga yozilmaydi ──
    const acc = rest.accuracy ?? null;
    const spd = rest.speed ?? null;
    const capturedAt = this.parseAt(dto.capturedAt);

    // Oxirgi yozilgan nuqta — dedup va filtr-branch emit uchun
    // (low_accuracy tekshiruvidan oldin olinadi: o'sha branch ham emit qilsin).
    const lastLocation = await this.prisma.location.findFirst({
      where: { childId },
      orderBy: { createdAt: 'desc' },
    });

    // Jonli kanal uchun emit. Muhim: too_close nuqta ham HAQIQIY joriy
    // pozitsiya — history'ga yozilmasa ham xaritaga real koordinata bilan
    // yuboramiz. Avval bu yerda eski nuqta yangi vaqt bilan ketardi —
    // ota-ona xaritasi "yangilangan" ko'rinib, joy esa qotib qolardi.
    const emitLive = (
      lat: number,
      lng: number,
      at: Date,
      extra: Record<string, unknown> = {},
    ) => {
      const payload = {
        childId,
        location: {
          latitude: lat,
          longitude: lng,
          accuracy: acc,
          speed: spd,
          batteryLevel: rest.batteryLevel ?? child.batteryLevel,
          isCharging: rest.isCharging ?? child.isCharging,
          createdAt: at,
          capturedAt: at,
          ...extra,
        },
      };
      this.realtime.emitToUser(child.parentId, 'location:updated', payload);
      this.realtime.emitToChild(childId, 'location:updated', payload);
    };

    // (1) Aniqligi juda yomon (cell-tower) fix — history'ga yozmaymiz, lekin
    //     qurilma ma'lumotini (batareya/last-seen) baribir yangilaymiz.
    //     Emit'da oxirgi ISHONCHLI nuqta o'zining haqiqiy vaqti bilan ketadi
    //     (soxta "hozir" emas) — klient eskirganlikni ko'rsata oladi.
    // `acc === null` ham ISHONCHSIZ: hech bir qatlam uni filtrlay olmaydi
    // (klient/backend/parent — hammasi 'noma'lum' deb o'tkazib yuborardi).
    if (acc === null || acc > MAX_ACCURACY_M) {
      await this.prisma.child.update({
        where: { id: childId },
        data: childDeviceUpdate,
      });
      if (lastLocation) {
        emitLive(
          lastLocation.latitude,
          lastLocation.longitude,
          lastLocation.capturedAt ?? lastLocation.createdAt,
          { accuracy: lastLocation.accuracy, stale: true },
        );
      }
      return { ok: true, written: false, reason: 'low_accuracy', accuracy: acc };
    }

    if (lastLocation) {
      const distance = distanceMeters(
        lastLocation.latitude,
        lastLocation.longitude,
        latitude,
        longitude,
      );
      // (2) Harakatda bo'lsa nozik (12m), statsionar/noma'lum bo'lsa kattaroq
      //     (25m) chegara — uydagi GPS jitter'ini yutadi, haqiqiy harakatni
      //     saqlaydi. Kliyent speed bermasa (ko'p qurilmada 0/null keladi)
      //     tezlikni oldingi nuqtadan o'zimiz hisoblaymiz — busiz piyoda
      //     yurish doim "statsionar" sanalib yo'l chizilmay qolardi.
      let effSpeed = spd;
      if ((effSpeed === null || effSpeed === 0) && lastLocation) {
        const lastAt = lastLocation.capturedAt ?? lastLocation.createdAt;
        const dtSec = Math.max(1, (capturedAt.getTime() - lastAt.getTime()) / 1000);
        effSpeed = distance / dtSec;
      }
      const isMoving = effSpeed !== null && effSpeed >= MOVING_SPEED_MS;
      const minMove = isMoving ? MOVE_MIN_M : JITTER_MIN_M;
      // Statsionar jitter ba'zan 25m'dan ham oshib yoziladi va xaritada
      // zigzag "chiziqlar to'pi" hosil qiladi. 2 daqiqalik oyna juda
      // qisqa edi: uyda o'tirgan bola soatiga ~30 ta tarqoq nuqta berardi
      // (ota-onada bu ko'chada yurish bo'lib ko'rinardi). Endi harakatsiz
      // holatda 80m'gacha siljish eng ko'pi 15 daqiqada bir marta yoziladi.
      const lastAt = lastLocation.capturedAt ?? lastLocation.createdAt;
      const dtMs = capturedAt.getTime() - lastAt.getTime();
      const isStationaryJitter =
        !isMoving && distance < 80 && dtMs < 900_000;
      if (distance < minMove || isStationaryJitter) {
        await this.prisma.child.update({
          where: { id: childId },
          data: childDeviceUpdate,
        });
        // Haqiqiy joriy koordinata jonli kanalga ketadi (yozilmasa ham).
        emitLive(latitude, longitude, capturedAt);
        return {
          ok: true,
          written: false,
          reason: 'too_close',
          distance,
          minMove,
        };
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
        capturedAt,
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
          const zoneLang = await this.fcm.getUserLang(child.parentId);
          await this.fcm.sendPushToUser(child.parentId, {
            // Zona nomi va ism {param} sifatida — faqat qat'iy matn tarjima.
            title: isEntry
              ? tr(zoneLang, 'geoZone.enterTitle', {
                  name: child.name,
                  zone: event.zoneName,
                })
              : tr(zoneLang, 'geoZone.exitTitle', {
                  name: child.name,
                  zone: event.zoneName,
                }),
            body: isEntry
              ? tr(zoneLang, 'geoZone.enterBody')
              : tr(zoneLang, 'geoZone.exitBody'),
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

    // Bola hali joylashuv yubormagan (yangi/ulanmagan) holat — bu xato emas,
    // kutilgan bo'sh holat. 404 o'rniga 200 + location:null qaytaramiz: klient
    // null'ni qulay ishlaydi va brauzer konsolida ortiqcha qizil 404 chiqmaydi.
    return {
      location: location ?? null,
      child: {
        id: child.id,
        name: child.name,
        batteryLevel: child.batteryLevel,
        isCharging: child.isCharging,
        lastSeenAt: child.lastSeenAt,
        // Ota-ona xaritasi "fon kuzatuv cheklangan" ogohlantirishi uchun.
        locationPermission: child.locationPermission,
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

    const { from, to, before, limit } = query;

    // capturedAt bo'yicha filtrlaymiz — offline flush qilingan nuqtalar
    // o'zining haqiqiy fix vaqti bilan to'g'ri kunga tushadi (createdAt
    // server qabul vaqti bo'lib safarni noto'g'ri kunga olib ketardi).
    // Eski yozuvlarda capturedAt migratsiyada createdAt bilan to'ldirilgan.
    const atFilter: Record<string, Date> = {};
    if (from) atFilter.gte = new Date(from);
    if (to) atFilter.lte = new Date(to);
    // Cursor: to'liq kunni 500 talik sahifalar bilan olish uchun.
    if (before) atFilter.lt = new Date(before);

    const take = limit ?? 100;
    const locations = await this.prisma.location.findMany({
      where: {
        childId,
        ...(Object.keys(atFilter).length > 0 && { capturedAt: atFilter }),
      },
      orderBy: { capturedAt: 'desc' },
      take,
    });

    return {
      locations,
      count: locations.length,
      // To'liq sahifa qaytdi = ehtimol yana bor; klient oxirgi nuqtaning
      // capturedAt'i bilan keyingi sahifani so'raydi.
      hasMore: locations.length === take,
    };
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

  /* ------------------------------------------------------------------ */
  /*  POST /location/batch — offline buferdan yig'ilgan nuqtalar          */
  /* ------------------------------------------------------------------ */

  /** Nuqtalarni eski→yangi tartibda yozadi (dedup/stop-detection oxirgi
   *  nuqtaga tayanadi). Bitta nuqta xatosi qolganlarini to'xtatmaydi. */
  async writeLocationBatch(userId: string, points: WriteLocationDto[]) {
    const sorted = [...points].sort((a, b) => {
      const ta = a.capturedAt ? new Date(a.capturedAt).getTime() : 0;
      const tb = b.capturedAt ? new Date(b.capturedAt).getTime() : 0;
      return ta - tb;
    });
    let written = 0;
    let skipped = 0;
    for (const point of sorted) {
      try {
        const res = await this.writeLocation(userId, point);
        if (res.written) written++;
        else skipped++;
      } catch (err) {
        skipped++;
        this.logger.warn({ err }, 'batch point failed');
      }
    }
    return { ok: true, written, skipped, total: points.length };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /children/:childId/location/request-update — wake push        */
  /* ------------------------------------------------------------------ */

  /** Ota-ona xaritani ochganda bola qurilmasiga data-only FCM yuboradi —
   *  bola ilovasi yangi GPS fix olib darhol POST qiladi. Servis o'lik
   *  bo'lsa ham FCM ilovani qisqa uyg'otadi (best-effort). */
  async requestLocationUpdate(childId: string, userId: string) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    if (child.parentId !== userId) {
      throw new ForbiddenException('Forbidden');
    }
    if (!child.childUserId) {
      return { ok: false, reason: 'not_paired' };
    }
    const result = await this.fcm.sendPushToUser(child.childUserId, {
      title: '',
      body: '',
      dataOnly: true,
      data: { type: 'location_wake', childId },
    });
    return { ok: true, sent: result.sent };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /children/:childId/location/request-enable — "yoqing" so'rovi  */
  /* ------------------------------------------------------------------ */

  /** Ota-ona bola joylashuvni O'CHIRGANда "joylashuvni yoqing" so'rovini
   *  yuboradi — KO'RINADIGAN push (bola ilova yopiq bo'lsa ham ko'radi).
   *  `location_wake` dan farqi: u data-only (avtomatik fix) — bu esa bolaga
   *  MODAL/bildirishnoma ko'rsatadi, chunki joylashuv o'chiq bo'lsa avtomatik
   *  fix olib bo'lmaydi, bola qo'lda yoqishi kerak. */
  async requestLocationEnable(childId: string, userId: string) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    if (child.parentId !== userId) {
      throw new ForbiddenException('Forbidden');
    }
    if (!child.childUserId) {
      return { ok: false, reason: 'not_paired' };
    }
    const locLang = await this.fcm.getUserLang(child.childUserId);
    const result = await this.fcm.sendPushToUser(child.childUserId, {
      title: tr(locLang, 'locationRequest.title'),
      body: tr(locLang, 'locationRequest.body'),
      data: { type: 'location_request', childId },
    });
    return { ok: true, sent: result.sent };
  }
}
