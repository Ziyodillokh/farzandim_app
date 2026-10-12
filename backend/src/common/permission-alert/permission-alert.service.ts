import { Injectable, Logger } from '@nestjs/common';
import { NotificationType } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import { FcmService } from '../fcm/fcm.service';

/** Kuzatiladigan muhim ruxsatlar va ularning o'zbekcha nomlari (#43). */
const PERMISSION_LABELS: Record<string, string> = {
  location: 'Joylashuv',
  notification: 'Bildirishnoma',
  background: 'Fon rejimi',
  accessibility: 'Maxsus imkoniyatlar',
  screenTime: 'Ekran vaqti',
};

/** iOS Ekran vaqti o'chsa ilovalar cheklovi umuman ishlamaydi — aniq aytamiz. */
const SCREEN_TIME_NOTE = " iPhone'da ilovalar cheklovi hozir ishlamayapti.";

/** device-info heartbeat'idan keladigan ruxsat holatlari (har biri ixtiyoriy). */
export interface IncomingPermissions {
  locationPermission?: boolean;
  notificationPermission?: boolean;
  backgroundAllowed?: boolean;
  accessibilityEnabled?: boolean;
  screenTimePermission?: boolean;
}

/**
 * PermissionAlertService — bola telefonida muhim ruxsat granted→denied
 * bo'lganda ota-onaga BIR MARTA holat ogohlantirishi (#43).
 *
 * Bu "anti-bypass" EMAS — permission status monitoring. Ohang ayblovchi emas.
 *
 * Spam yo'q: faqat o'zgarish momentида (prev=true → new=false). children.service
 * keyin yangi qiymatni saqlaydi, shu sababli keyingi heartbeat'da prev=false →
 * qayta push ketmaydi (batareya crossing bilan bir xil mexanizm). Qayta yoqilsa
 * push yo'q.
 */
@Injectable()
export class PermissionAlertService {
  private readonly logger = new Logger(PermissionAlertService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmService,
  ) {}

  /**
   * `prev` — child YANGILANISHIDAN OLDINGI holat (DB'dagi joriy qiymat).
   * `next` — device-info'da kelgan yangi holat. true→false bo'lganlar uchun
   * yagona push + Notification yoziladi.
   */
  async checkCrossings(
    child: { id: string; name: string; parentId: string },
    prev: {
      locationPermission: boolean | null;
      notificationPermission: boolean | null;
      backgroundAllowed: boolean | null;
      accessibilityEnabled: boolean | null;
      screenTimePermission: boolean | null;
    },
    next: IncomingPermissions,
  ): Promise<void> {
    const checks: { key: string; was: boolean | null; now?: boolean }[] = [
      { key: 'location', was: prev.locationPermission, now: next.locationPermission },
      {
        key: 'notification',
        was: prev.notificationPermission,
        now: next.notificationPermission,
      },
      { key: 'background', was: prev.backgroundAllowed, now: next.backgroundAllowed },
      {
        key: 'accessibility',
        was: prev.accessibilityEnabled,
        now: next.accessibilityEnabled,
      },
      {
        key: 'screenTime',
        was: prev.screenTimePermission,
        now: next.screenTimePermission,
      },
    ];

    // Faqat true → false (o'chirildi). null (noma'lum) yoki false→* — e'tiborsiz.
    const revokedKeys = checks
      .filter((c) => c.was === true && c.now === false)
      .map((c) => c.key);
    const revoked = revokedKeys.map((key) => PERMISSION_LABELS[key]);

    if (revoked.length === 0) return;

    const list = revoked.join(', ');
    const body =
      `Parvoz uchun "${list}" ruxsati o'chirildi — ilova to'liq ` +
      'ishlamasligi mumkin.' +
      (revokedKeys.includes('screenTime') ? SCREEN_TIME_NOTE : '');

    try {
      await this.fcm.sendPushToUser(child.parentId, {
        title: child.name,
        body,
        data: {
          type: 'permission_changed',
          childId: child.id,
          childName: child.name,
          permissions: revoked.join(','),
        },
      });
    } catch (err) {
      this.logger.warn({ err }, 'permission_changed push failed');
    }

    await this.prisma.notification.create({
      data: {
        childId: child.id,
        type: NotificationType.PERMISSION_CHANGED,
        title: child.name,
        body,
        data: { type: 'permission_changed', permissions: revoked },
      },
    });
  }
}
