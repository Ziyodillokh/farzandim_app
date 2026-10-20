// Ertalabki School Mode sinxroni (har kuni 06:30, Toshkent). Virtual "Maktab"
// jadvali faqat BUGUN uchun beriladi; iPhone bola ilovasi jadvalni push yoki
// ochilganda yangilaydi — shuning uchun har ertalab bog'langan bolalarga jim
// push. Android ilovasi o'zi 15 soniyada so'raydi (push'ni e'tiborsiz qoldiradi).

import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../common/database/prisma.service';
import { TASHKENT_TZ } from '../../common/time/tashkent';
import { SchoolModeSyncService } from './school-mode-sync.service';

@Injectable()
export class SchoolModeMorningCron {
  private readonly logger = new Logger(SchoolModeMorningCron.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly sync: SchoolModeSyncService,
  ) {}

  @Cron('0 30 6 * * *', { name: 'school-mode-morning-resync', timeZone: TASHKENT_TZ })
  async handleCron(): Promise<void> {
    try {
      const schools = await this.resyncEnabledSchools();
      if (schools > 0) this.logger.log(`School Mode ertalabki sinxron: ${schools} maktab`);
    } catch (err) {
      this.logger.warn(`School Mode ertalabki sinxron: ${String(err)}`);
    }
  }

  /** Siyosati yoqilgan faol maktablarning bog'langan bolalariga jim push; maktablar soni. */
  async resyncEnabledSchools(): Promise<number> {
    const policies = await this.prisma.schoolModePolicy.findMany({
      where: { enabled: true, school: { status: 'ACTIVE' } },
      select: { schoolId: true },
    });
    for (const p of policies) await this.sync.resync(p.schoolId);
    return policies.length;
  }
}
