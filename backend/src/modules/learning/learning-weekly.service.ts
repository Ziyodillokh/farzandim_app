// Bola ilovasi: haftalik o'quv faolligi (I02) — joriy va oldingi ISO hafta.

import { Injectable } from '@nestjs/common';
import { LearningAttemptStatus } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { addDays, isoWeekStart, tashkentDay } from '../../common/time/tashkent';
import { buildWeeklyReport, WeeklyReport } from './domain/learning-weekly';

@Injectable()
export class LearningWeeklyService {
  constructor(private readonly prisma: PrismaService) {}

  async weekly(childId: string, now: Date = new Date()): Promise<WeeklyReport> {
    const today = tashkentDay(now);
    const previousStart = addDays(isoWeekStart(today), -7);
    const completed = { childId, status: LearningAttemptStatus.COMPLETED };

    // Indeks: (child_id, day). Urinishlar — faqat ikki hafta; streak uchun
    // faqat KUNLAR (GROUP BY day: faol kun soni bilan chegaralangan, qatorlar emas).
    const [attempts, dayRows] = await Promise.all([
      this.prisma.learningAttempt.findMany({
        where: { ...completed, day: { gte: previousStart, lte: today } },
        select: { day: true, startedAt: true, completedAt: true },
      }),
      this.prisma.learningAttempt.groupBy({
        by: ['day'],
        where: { ...completed, day: { lte: today } },
      }),
    ]);
    return buildWeeklyReport({
      today,
      attempts,
      completedDays: new Set(dayRows.map((r) => r.day)),
    });
  }
}
