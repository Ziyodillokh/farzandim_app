import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { NotificationType } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import { FcmService } from '../fcm/fcm.service';

/**
 * Bola shu sekunddan ortiq heartbeat yubormasa "aloqa uzildi" deb hisoblanadi.
 *
 * AVVAL 30 daqiqa edi (reboot lag, Doze ~15min timer paketlash, OEM FGS kill
 * uchun konservativ). Endi TEZ aniqlash kerak: ota-ona force-stop / internet
 * uzilishini bir necha daqiqada bilishi shart. Heartbeat foreground-service
 * (wakelock bilan) ichida ~30-60s da ketadi, demak 2 daqiqalik ostona xavfsiz.
 *
 * False-positive (vaqtinchalik Doze/reboot) "aloqa tiklandi" push bilan
 * yumshatiladi: qisqa uzilishdan keyin bola qaytsa, ota-ona darhol "tiklandi"
 * xabarini oladi. Agar real qurilmalarda false-positive ko'p chiqsa,
 * CONNECTION_LOST_SECONDS env-ni oshiring (masalan 300 = 5 daqiqa).
 */
const _envSeconds = Number(process.env.CONNECTION_LOST_SECONDS);
export const CONNECTION_LOST_SECONDS =
  Number.isFinite(_envSeconds) && _envSeconds > 0 ? _envSeconds : 120;

/** Eski export — endi sekunddan hisoblanadi (boshqa modul ishlatishi mumkin). */
export const CONNECTION_LOST_MINUTES = Math.max(
  1,
  Math.round(CONNECTION_LOST_SECONDS / 60),
);

/**
 * "Aloqa uzildi" — umumiy matn (sabab noaniq: ilova to'xtatilgan / internet
 * uzilgan / telefon o'chiq). COMPLIANCE: AYNAN shunday bo'lishi shart,
 * o'zgartirilmasin. "Farzandingiz appni o'chirdi" deb AYBLAMAYDI.
 */
export const CONNECTION_LOST_BODY =
  "Parvoz app bilan aloqa uzildi. Ilova o'chirilgan, internet uzilgan yoki " +
  'telefon faol emas bo\'lishi mumkin.';

/** Batareya tugagan ehtimoli (oxirgi batareya past + quvvatlanmayotgan edi). */
export const CONNECTION_LOST_BATTERY_BODY =
  "Parvoz app bilan aloqa uzildi. Qurilma batareyasi tugagan bo'lishi mumkin.";

/** Aloqa qayta tiklandi — bola qurilmasi qayta onlayn. */
export const CONNECTION_RESTORED_BODY =
  'Parvoz app bilan aloqa tiklandi. Farzandingiz qurilmasi qayta onlayn.';

/** Shundan past + quvvatlanmayotgan bo'lsa — sabab "batareya". */
const LOW_BATTERY_REASON_THRESHOLD = 15;

type ConnReason = 'battery' | 'app_or_device';

/**
 * ConnectionMonitorService — bola qurilmasi heartbeat'ni to'xtatsa (ilova
 * majburiy to'xtatilgan / internet uzilgan / telefon o'chiq / batareya tugagan)
 * ota-onaga BIR MARTA "aloqa uzildi" push; qayta onlayn bo'lsa BIR MARTA
 * "aloqa tiklandi" push.
 *
 * Heartbeat: bola `POST /children/:id/device-info` (yoki `/location`) yuboradi
 * → `Child.lastSeenAt` yangilanadi. `lastSeenAt` ostonadan eski bo'lsa → uzilgan.
 *
 * SPAM YO'Q: uzilish push'idan keyin `connectionLostNotifiedAt = now`. Bola
 * jim turganda `connectionLostNotifiedAt > lastSeenAt` bo'lib qayta yuborilmaydi.
 * Qayta heartbeat kelsa (`lastSeenAt` o'sadi) → shu servis "tiklandi" push
 * yuborib `connectionLostNotifiedAt = null` qiladi (markazlashtirilgan — eski
 * children.service reset'i shu yerga ko'chirilgan, location heartbeat bilan ham
 * izchil).
 */
@Injectable()
export class ConnectionMonitorService {
  private readonly logger = new Logger(ConnectionMonitorService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmService,
  ) {}

  /** Har 30 sekundda — tez aniqlash uchun. */
  @Cron('*/30 * * * * *', { name: 'connection-monitor' })
  async checkConnections(): Promise<void> {
    const now = new Date();
    const threshold = new Date(now.getTime() - CONNECTION_LOST_SECONDS * 1000);

    // Nomzodlar: qurilmasi ulangan bolalar — (a) jim qolib uzilganlar
    // (lastSeenAt eski) YOKI (b) avval "uzildi" deb belgilangan, endi qaytishi
    // mumkin bo'lganlar (connectionLostNotifiedAt set).
    const candidates = await this.prisma.child.findMany({
      where: {
        childUserId: { not: null },
        lastSeenAt: { not: null },
        OR: [
          { lastSeenAt: { lt: threshold } },
          { connectionLostNotifiedAt: { not: null } },
        ],
      },
      select: {
        id: true,
        name: true,
        parentId: true,
        lastSeenAt: true,
        connectionLostNotifiedAt: true,
        batteryLevel: true,
        isCharging: true,
      },
    });

    for (const child of candidates) {
      const lastSeen = child.lastSeenAt;
      if (lastSeen === null) continue;
      const notifiedAt = child.connectionLostNotifiedAt;
      const isLost = lastSeen < threshold;

      try {
        if (isLost) {
          // Uzilish: hech qachon ogohlantirilmagan YOKI oxirgi ogohlantirishdan
          // keyin qayta online bo'lib (lastSeenAt o'sgan) yana uzilgan.
          if (notifiedAt === null || notifiedAt < lastSeen) {
            await this.sendLost(child);
            await this.prisma.child.update({
              where: { id: child.id },
              data: { connectionLostNotifiedAt: now },
            });
          }
        } else if (notifiedAt !== null) {
          // Qaytdi: avval "uzildi" deb belgilangan, endi yangi heartbeat keldi.
          await this.sendRestored(child);
          await this.prisma.child.update({
            where: { id: child.id },
            data: { connectionLostNotifiedAt: null },
          });
        }
      } catch (err) {
        this.logger.warn({ err }, `connection-monitor failed for ${child.id}`);
      }
    }
  }

  /**
   * Sabab inference — server faqat heartbeat yo'qligini ko'radi, "nega"ni
   * 100% bilmaydi. Oxirgi batareya past + quvvatlanmayotgan bo'lsa → "batareya".
   * Aks holda umumiy (force-stop / internet / telefon o'chiq) — Android'da
   * bularni serverdan ajratib bo'lmaydi.
   */
  private inferReason(child: {
    batteryLevel: number | null;
    isCharging: boolean | null;
  }): ConnReason {
    if (
      child.batteryLevel !== null &&
      child.batteryLevel <= LOW_BATTERY_REASON_THRESHOLD &&
      child.isCharging !== true
    ) {
      return 'battery';
    }
    return 'app_or_device';
  }

  private async sendLost(child: {
    id: string;
    name: string;
    parentId: string;
    batteryLevel: number | null;
    isCharging: boolean | null;
  }): Promise<void> {
    const reason = this.inferReason(child);
    const body =
      reason === 'battery'
        ? CONNECTION_LOST_BATTERY_BODY
        : CONNECTION_LOST_BODY;

    await this.fcm.sendPushToUser(child.parentId, {
      title: child.name,
      body,
      data: {
        type: 'connection_lost',
        reason,
        childId: child.id,
        childName: child.name,
      },
    });

    // Bildirishnoma markazida ham ko'rinadi.
    await this.prisma.notification.create({
      data: {
        childId: child.id,
        type: NotificationType.CONNECTION_LOST,
        title: child.name,
        body,
        data: { type: 'connection_lost', reason, childId: child.id },
      },
    });

    this.logger.log(`connection-lost: ${child.id} reason=${reason}`);
  }

  private async sendRestored(child: {
    id: string;
    name: string;
    parentId: string;
  }): Promise<void> {
    await this.fcm.sendPushToUser(child.parentId, {
      title: child.name,
      body: CONNECTION_RESTORED_BODY,
      data: {
        type: 'connection_restored',
        childId: child.id,
        childName: child.name,
      },
    });

    this.logger.log(`connection-restored: ${child.id}`);
  }
}
