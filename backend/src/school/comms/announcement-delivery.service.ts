// E'lonni yuborish: (1) tranzaksiya ichida SHARTLI ravishda SENT ga o'tkazish
// (holat / vaqt sharti — ikki jarayon bir xabarni ikki marta yubormaydi) va har
// vasiyga yetkazish yozuvi; (2) tranzaksiyadan keyin push — natija haqiqiy:
// FCM qabul qildi → `deliveredAt`; ilovasiz vasiy (userId yo'q) yoki xato → yo'q.

import { Injectable, Logger } from '@nestjs/common';
import { Prisma, SchoolAnnouncement, SchoolMessageStatus } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { announcementPush } from './comms.i18n';
import { Audience } from './comms.schemas';
import { CommsPushService } from './comms-push.service';
import { RosterGuardian } from './comms-roster';

export interface ClaimInput {
  id: string;
  schoolId: string;
  /** Qaysi holat(lar)dan yuborish mumkin. */
  from: SchoolMessageStatus[];
  /** Rejali yuborish: faqat vaqti kelgan bo'lsa (`scheduledAt <= dueBy`). */
  dueBy?: Date;
  /** `true` — rejalashtirilgan vaqt saqlanadi (cron); aks holda tozalanadi. */
  keepSchedule?: boolean;
  /** Yuborish paytidagi yangi mazmun (tahrirlab yuborish). */
  content?: { title: string; body: string; priority: string; audience: Audience };
  guardians: readonly RosterGuardian[];
  now: Date;
}

@Injectable()
export class AnnouncementDeliveryService {
  private readonly logger = new Logger(AnnouncementDeliveryService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly push: CommsPushService,
  ) {}

  /**
   * SENT ga shartli o'tkazish + yetkazish yozuvlari (tranzaksiya ichida).
   * `null` — shart bajarilmadi (allaqachon yuborilgan / o'chirilgan / vaqti kelmagan).
   */
  async claim(tx: Prisma.TransactionClient, input: ClaimInput): Promise<SchoolAnnouncement | null> {
    const { content } = input;
    const claimed = await tx.schoolAnnouncement.updateMany({
      where: {
        id: input.id,
        schoolId: input.schoolId,
        status: { in: input.from },
        ...(input.dueBy && { scheduledAt: { lte: input.dueBy } }),
      },
      data: {
        ...(content && {
          title: content.title,
          body: content.body,
          priority: content.priority,
          audience: content.audience as unknown as Prisma.InputJsonValue,
        }),
        status: 'SENT',
        sentAt: input.now,
        recipients: input.guardians.length,
        ...(!input.keepSchedule && { scheduledAt: null }),
      },
    });
    if (claimed.count !== 1) return null;
    await tx.schoolAnnouncementDelivery.createMany({
      data: input.guardians.map((g) => ({ announcementId: input.id, guardianId: g.id, userId: g.userId })),
      skipDuplicates: true,
    });
    return tx.schoolAnnouncement.findUniqueOrThrow({ where: { id: input.id } });
  }

  /** Ilovasi bor vasiylarga push; FCM qabul qilganlar — `deliveredAt`. Xato yutilmaydi — log. */
  async pushPending(announcementId: string, now: Date): Promise<void> {
    try {
      await this.pushOrThrow(announcementId, now);
    } catch (err) {
      this.logger.error(`e'lon push xatosi (${announcementId}): ${String(err)}`);
    }
  }

  private async pushOrThrow(announcementId: string, now: Date): Promise<void> {
    const a = await this.prisma.schoolAnnouncement.findUnique({ where: { id: announcementId } });
    if (!a || a.status !== 'SENT') return;
    const pending = await this.prisma.schoolAnnouncementDelivery.findMany({
      where: { announcementId, userId: { not: null }, deliveredAt: null },
      select: { userId: true },
    });
    const userIds = pending.map((p) => p.userId).filter((u): u is string => u !== null);
    if (userIds.length === 0) return;
    const school = await this.push.schoolLabel(a.schoolId);
    const priority = a.priority === 'IMPORTANT' ? 'IMPORTANT' : 'NORMAL';
    const outcomes = await this.push.sendToUsers(userIds, (lang) =>
      announcementPush(lang, { id: a.id, school, title: a.title, body: a.body, priority }),
    );
    const delivered = [...outcomes].filter(([, ok]) => ok).map(([userId]) => userId);
    if (delivered.length === 0) return;
    await this.prisma.schoolAnnouncementDelivery.updateMany({
      where: { announcementId, userId: { in: delivered }, deliveredAt: null },
      data: { deliveredAt: now },
    });
  }
}
