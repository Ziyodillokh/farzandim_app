import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../common/database/prisma.service';

/**
 * Ma'lumot saqlash muddati (data retention).
 *
 * Bola XOM joylashuv/faollik tarixi 90 kundan eski bo'lsa har kuni avtomatik
 * o'chiriladi (maxfiylik + Google Play "bounded retention" — bola sezgir
 * ma'lumoti cheksiz saqlanmasligi kerak).
 *
 * FAQAT xom tarix o'chadi: `locations`, `location_stops`, `app_usage`.
 * Qadamlar (`child_step_daily`) — gamification/DON yozuvi, tegilmaydi.
 * Kesim SANASI qat'iy (now - 90 kun); faqat aniq eski satrlar o'chadi — yaqin/
 * aktiv ma'lumotga hech qachon tegmaydi.
 */
@Injectable()
export class RetentionService {
  private readonly logger = new Logger(RetentionService.name);

  private static readonly RETENTION_DAYS = 90;
  private static readonly DAY_MS = 24 * 60 * 60 * 1000;

  constructor(private readonly prisma: PrismaService) {}

  /** Har kuni 03:15 (server vaqti) — kam yuklama oynasida. */
  @Cron('0 15 3 * * *', { name: 'data-retention' })
  async purgeOldData(): Promise<void> {
    const cutoff = new Date(
      Date.now() - RetentionService.RETENTION_DAYS * RetentionService.DAY_MS,
    );

    try {
      // Alohida (transaksiyasiz) — uzoq lock bo'lmasin; har biri mustaqil tozalash.
      const loc = await this.prisma.location.deleteMany({
        where: { createdAt: { lt: cutoff } },
      });
      const stops = await this.prisma.locationStop.deleteMany({
        where: { createdAt: { lt: cutoff } },
      });
      const usage = await this.prisma.appUsage.deleteMany({
        where: { date: { lt: cutoff } },
      });

      this.logger.log(
        `retention(${RetentionService.RETENTION_DAYS}d, <${cutoff.toISOString()}): ` +
          `locations=${loc.count}, stops=${stops.count}, appUsage=${usage.count}`,
      );
    } catch (err) {
      // Cleanup best-effort — xato bo'lsa keyingi kun qayta uriniladi.
      this.logger.error(`retention purge failed: ${err}`);
    }
  }
}
