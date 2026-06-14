import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { NotificationType } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import { FcmService } from '../fcm/fcm.service';

/** Bola shu daqiqadan ko'p heartbeat yubormasa "aloqa uzildi" deb hisoblanadi. */
export const CONNECTION_LOST_MINUTES = 10;

/**
 * "Aloqa uzildi" matni — COMPLIANCE: AYNAN shunday bo'lishi shart, o'zgartirilmasin.
 * Bu "anti-uninstall" emas — oddiy aloqa holati ogohlantirishi. "Farzandingiz
 * appni o'chirdi" deb YOZILMAYDI (ilova o'chirilgan BO'LISHI MUMKIN, deb yozamiz).
 */
export const CONNECTION_LOST_BODY =
  "Parvoz app bilan aloqa uzildi. Ilova o'chirilgan, internet uzilgan yoki " +
  'telefon faol emas bo\'lishi mumkin.';

/**
 * ConnectionMonitorService — bola qurilmasi heartbeat'ni to'xtatsa (ilova
 * o'chirilgan / internet uzilgan / telefon o'chiq) ota-onaga BIR MARTA push.
 *
 * Heartbeat: bola `POST /children/:id/device-info` (yoki `/location`) yuboradi
 * → `Child.lastSeenAt` yangilanadi. Agar `lastSeenAt` 10 daqiqadan eski bo'lsa
 * → aloqa uzilgan deb hisoblanadi.
 *
 * SPAM YO'Q: push yuborilgach `connectionLostNotifiedAt = now` belgilanadi.
 * Keyingi cron'larda `connectionLostNotifiedAt >= lastSeenAt` bo'lgani uchun
 * qayta yuborilmaydi. Bola qayta online bo'lsa `lastSeenAt` o'sadi (heartbeat),
 * `connectionLostNotifiedAt < lastSeenAt` bo'ladi → keyingi uzilishda yana
 * BITTA push chiqadi (device-info heartbeat `connectionLostNotifiedAt`ni
 * null'ga ham qaytaradi — children.service.ts).
 */
@Injectable()
export class ConnectionMonitorService {
  private readonly logger = new Logger(ConnectionMonitorService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmService,
  ) {}

  /** Har 3 daqiqada — sekund 0'da (soat bo'yicha tekis). */
  @Cron('0 */3 * * * *', { name: 'connection-lost-monitor' })
  async checkConnections(): Promise<void> {
    const now = new Date();
    const threshold = new Date(now.getTime() - CONNECTION_LOST_MINUTES * 60_000);

    // Nomzodlar: qurilmasi ulangan (childUserId bor), kamida bir marta
    // heartbeat yuborgan (lastSeenAt bor) va 10 daqiqadan beri jim.
    const candidates = await this.prisma.child.findMany({
      where: {
        childUserId: { not: null },
        lastSeenAt: { not: null, lt: threshold },
      },
      select: {
        id: true,
        name: true,
        parentId: true,
        lastSeenAt: true,
        connectionLostNotifiedAt: true,
      },
    });

    // Prisma ikki ustunni (notifiedAt < lastSeenAt) bevosita solishtira
    // olmaydi → JS'da filtrlaymiz. Yangi push KERAK bo'lganlar: hech qachon
    // ogohlantirilmagan YOKI oxirgi ogohlantirishdan keyin qayta online
    // bo'lib (lastSeenAt o'sib) yana uzilganlar.
    const needNotify = candidates.filter(
      (c) =>
        c.connectionLostNotifiedAt === null ||
        (c.lastSeenAt !== null &&
          c.connectionLostNotifiedAt < c.lastSeenAt),
    );

    if (needNotify.length === 0) return;

    this.logger.log(`connection-lost: notifying ${needNotify.length} parent(s)`);

    for (const child of needNotify) {
      try {
        await this.fcm.sendPushToUser(child.parentId, {
          title: child.name,
          body: CONNECTION_LOST_BODY,
          data: {
            type: 'connection_lost',
            childId: child.id,
            childName: child.name,
          },
        });

        // Ota-ona bildirishnoma markazida ham ko'rinadi (childId'ga bog'liq).
        await this.prisma.notification.create({
          data: {
            childId: child.id,
            type: NotificationType.CONNECTION_LOST,
            title: child.name,
            body: CONNECTION_LOST_BODY,
            data: { type: 'connection_lost', childId: child.id },
          },
        });

        // Bir martalik — keyingi cron'da qayta yubormaslik uchun.
        await this.prisma.child.update({
          where: { id: child.id },
          data: { connectionLostNotifiedAt: now },
        });
      } catch (err) {
        // Bitta bola xatosi butun partiyani to'xtatmasin.
        this.logger.warn({ err }, `connection-lost push failed for ${child.id}`);
      }
    }
  }
}
