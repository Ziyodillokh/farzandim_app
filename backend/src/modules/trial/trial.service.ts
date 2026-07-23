import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../common/database/prisma.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { tr } from '../../common/i18n/notification-i18n';

/**
 * Standart 1-haftalik demo (trial).
 *
 * - Yangi ota-onaga ro'yxatdan o'tganda BIR MARTA beriladi (ACTIVE Standart
 *   obuna, expiresAt = now + 7 kun, isTrial=true).
 * - 7 kundan keyin AVTOMATIK free'ga tushadi: EntitlementService obunani
 *   `expiresAt > now` bo'yicha o'qiydi, muddat o'tsa uni ko'rmaydi. Obuna satri
 *   O'CHIRILMAYDI/o'zgarmaydi — bola ma'lumotlari saqlanadi, keyin Standart/
 *   Premiumga o'tsa hammasi qaytadi.
 * - Cron faqat push eslatma yuboradi (mexanizm uchun cron shart emas).
 */
@Injectable()
export class TrialService {
  private readonly logger = new Logger(TrialService.name);

  private static readonly TRIAL_DAYS = 7;
  private static readonly DAY_MS = 24 * 60 * 60 * 1000;
  /** Tugashiga shuncha kun qolganda "tugayapti" eslatmasi yuboriladi. */
  private static readonly REMIND_BEFORE_DAYS = 2;

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmService,
  ) {}

  /**
   * Yangi ota-onaga 1-haftalik Standart demo beradi (bir marta, idempotent).
   * Ro'yxatdan o'tishni BLOKLAMAYDI — xatoda jimgina o'tkazadi (best-effort).
   */
  async grantStandardTrial(userId: string): Promise<void> {
    try {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { role: true, trialUsed: true },
      });
      // Faqat ota-ona, faqat bir marta.
      if (!user || user.role !== 'PARENT' || user.trialUsed) return;

      // Standart tarif — eng arzon aktiv pullik 'standard' plan.
      const plan = await this.prisma.plan.findFirst({
        where: { entitlementTier: 'standard', isActive: true },
        orderBy: { priceUzs: 'asc' },
      });
      if (!plan) {
        // Plan hali yaratilmagan — trialUsed'ni belgilamaymiz, keyin beriladi.
        this.logger.warn(
          `Standart tarif topilmadi — trial berilmadi (user=${userId})`,
        );
        return;
      }

      const now = new Date();
      const expiresAt = new Date(
        now.getTime() + TrialService.TRIAL_DAYS * TrialService.DAY_MS,
      );
      await this.prisma.$transaction([
        this.prisma.subscription.create({
          data: {
            userId,
            planId: plan.id,
            status: 'ACTIVE',
            startedAt: now,
            expiresAt,
            isTrial: true,
          },
        }),
        this.prisma.user.update({
          where: { id: userId },
          data: { trialUsed: true },
        }),
      ]);
      this.logger.log(
        `Standart trial berildi: user=${userId} -> ${expiresAt.toISOString()}`,
      );
    } catch (err) {
      this.logger.warn(`grantStandardTrial failed (user=${userId}): ${err}`);
    }
  }

  /**
   * Har 6 soatda: (1) tugashiga <=2 kun qolgan triallarga eslatma; (2) endigina
   * tugagan (free'ga tushgan) triallarga "tugadi" xabari. Har biri BIR MARTA
   * (flag bilan dedup).
   */
  @Cron('0 0 */6 * * *', { name: 'trial-reminders' })
  async sendTrialReminders(): Promise<void> {
    const now = new Date();
    const soon = new Date(
      now.getTime() + TrialService.REMIND_BEFORE_DAYS * TrialService.DAY_MS,
    );

    // (1) Tugashiga <= 2 kun qolgan aktiv triallar — bir marta eslatma.
    const ending = await this.prisma.subscription.findMany({
      where: {
        isTrial: true,
        status: 'ACTIVE',
        trialReminderSentAt: null,
        expiresAt: { gt: now, lte: soon },
      },
      select: { id: true, userId: true, expiresAt: true },
    });
    for (const sub of ending) {
      const msLeft = (sub.expiresAt?.getTime() ?? now.getTime()) - now.getTime();
      const daysLeft = Math.max(1, Math.ceil(msLeft / TrialService.DAY_MS));
      await this.pushTrial(sub.userId, 'trialEnding', { days: daysLeft });
      await this.prisma.subscription.update({
        where: { id: sub.id },
        data: { trialReminderSentAt: now },
      });
    }

    // (2) Endigina tugagan triallar — bir marta "free'ga o'tdingiz".
    const ended = await this.prisma.subscription.findMany({
      where: {
        isTrial: true,
        status: 'ACTIVE',
        trialEndedNotifiedAt: null,
        expiresAt: { lte: now },
      },
      select: { id: true, userId: true },
    });
    for (const sub of ended) {
      await this.pushTrial(sub.userId, 'trialEnded');
      await this.prisma.subscription.update({
        where: { id: sub.id },
        data: { trialEndedNotifiedAt: now },
      });
    }

    if (ending.length || ended.length) {
      this.logger.log(
        `trial-reminders: ${ending.length} tugayapti, ${ended.length} tugadi`,
      );
    }
  }

  private async pushTrial(
    userId: string,
    key: 'trialEnding' | 'trialEnded',
    params?: Record<string, string | number>,
  ): Promise<void> {
    try {
      const lang = await this.fcm.getUserLang(userId);
      await this.fcm.sendPushToUser(userId, {
        title: tr(lang, `${key}.title`),
        body: tr(lang, `${key}.body`, params),
        data: { type: key, relatedRoute: '/premium' },
      });
    } catch (err) {
      this.logger.warn(`trial push failed (user=${userId}): ${err}`);
    }
  }
}
