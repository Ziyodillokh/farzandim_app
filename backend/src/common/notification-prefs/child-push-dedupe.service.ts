// Bolaga push'ni "bir marta" yuborish kafolati. `(bola, tur, kalit)` bo'yicha yagona qator
// (`child_push_dedupe`): qatorni yozish uddasidan chiqqan chaqiruvchi yuboradi, qolganlar — yo'q.
// Shu sabab takroriy cron / qayta urinish / bir vaqtda ikki nusxa dublikat push yubormaydi.

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';

/** Dedupe qatorlari shuncha kundan keyin tozalanadi (qayta urinishlar daqiqalar ichida bo'ladi). */
export const DEDUPE_RETENTION_DAYS = 30;
const DAY_MS = 24 * 60 * 60 * 1000;

@Injectable()
export class ChildPushDedupeService {
  constructor(private readonly prisma: PrismaService) {}

  /** Shu `(kind, refKey)` uchun hali yuborilmagan bolalar (qatorni egallaganlar). Takroriy id'lar bitta hisoblanadi. */
  async claim(childIds: readonly string[], kind: string, refKey: string): Promise<string[]> {
    const unique = [...new Set(childIds)];
    if (unique.length === 0) return [];
    const rows = await this.prisma.childPushDedupe.createManyAndReturn({
      data: unique.map((childId) => ({ childId, kind, refKey })),
      skipDuplicates: true,
      select: { childId: true },
    });
    return rows.map((r) => r.childId);
  }

  /** Eski qatorlarni o'chirish; o'chirilganlar soni. */
  async prune(now: Date): Promise<number> {
    const result = await this.prisma.childPushDedupe.deleteMany({
      where: { createdAt: { lt: new Date(now.getTime() - DEDUPE_RETENTION_DAYS * DAY_MS) } },
    });
    return result.count;
  }
}
