import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { FcmService } from '../fcm/fcm.service';
import { tr } from '../i18n/notification-i18n';

/** Batareya shu foizdan past tushganda ota-onaga push (bir marta — crossing). */
export const LOW_BATTERY_PCT = 10;

/**
 * BatteryAlertService — past batareya (<10%) crossing aniqlash + push.
 *
 * NEGA UMUMIY: `child.batteryLevel` IKKI endpoint orqali yangilanadi —
 * `POST /location` (location.service) va `POST /children/:id/device-info`
 * (children.service, GPS'siz heartbeat, tez-tez). Agar crossing tekshiruvi
 * faqat bittasida bo'lsa, ikkinchisi batareyani jimgina 10%'dan past qilib
 * yangilab "crossing"ni yeb qo'yadi → push hech qachon ketmaydi. Shuning
 * uchun ikkala endpoint ham child.batteryLevel'ni YANGILASHDAN OLDIN shu
 * servisni chaqiradi. Bir martalik: birinchi crossing push'idan keyin DB
 * <10 bo'ladi va keyingilar (prev<10) qayta ishlamaydi.
 */
@Injectable()
export class BatteryAlertService {
  private readonly logger = new Logger(BatteryAlertService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmService,
  ) {}

  /**
   * `prevBattery` — child.batteryLevel YANGILANISHIDAN OLDINGI qiymat.
   * `location` berilmasa (device-info heartbeat) oxirgi ma'lum joylashuv
   * olinadi (push ota-onani joylashuv ekraniga olib boradi).
   */
  async checkCrossing(
    child: { id: string; name: string; parentId: string },
    prevBattery: number | null,
    newBattery: number | null | undefined,
    isCharging: boolean | null | undefined,
    location?: { latitude: number; longitude: number },
  ): Promise<void> {
    const next = newBattery ?? null;
    const crossed =
      next !== null &&
      next < LOW_BATTERY_PCT &&
      (prevBattery === null || prevBattery >= LOW_BATTERY_PCT) &&
      !(isCharging ?? false);
    if (!crossed) return;

    let lat = location?.latitude;
    let lng = location?.longitude;
    if (lat === undefined || lng === undefined) {
      const last = await this.prisma.location.findFirst({
        where: { childId: child.id },
        orderBy: { createdAt: 'desc' },
        select: { latitude: true, longitude: true },
      });
      lat = last?.latitude ?? 0;
      lng = last?.longitude ?? 0;
    }

    try {
      const lang = await this.fcm.getUserLang(child.parentId);
      await this.fcm.sendPushToUser(child.parentId, {
        title: tr(lang, 'battery.title', { name: child.name, pct: next }),
        body: tr(lang, 'battery.body'),
        data: {
          type: 'low_battery',
          childId: child.id,
          latitude: String(lat),
          longitude: String(lng),
        },
      });
    } catch (err) {
      this.logger.warn({ err }, 'low battery push failed');
    }
  }
}
