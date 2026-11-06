// Bolaga push'ni "bir marta" yuborish kafolati. `(bola, tur, kalit)` bo'yicha yagona qator
// (`child_push_dedupe`): qatorni yozish uddasidan chiqqan chaqiruvchi yuboradi, qolganlar — yo'q.
// Shu sabab takroriy cron / qayta urinish / bir vaqtda ikki nusxa (server) dublikat push yubormaydi.

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { chunk } from '../helpers/map-limit';

/** Dedupe qatorlari shuncha kundan keyin tozalanadi (qayta urinishlar daqiqalar ichida bo'ladi). */
export const DEDUPE_RETENTION_DAYS = 30;
/** Har bola uchun har kuni yoziladigan tur (kunlik eslatma) — ko'p qator, shuning uchun tezroq tozalanadi. */
export const DAILY_DEDUPE_KINDS: readonly string[] = ['STUDY_NUDGE'];
export const DAILY_DEDUPE_RETENTION_DAYS = 3;
const DAY_MS = 24 * 60 * 60 * 1000;
/** Bir so'rovda ko'pi bilan shuncha qator yoziladi (kunlik eslatma minglab bolaga birdaniga ketadi). */
const CLAIM_BATCH = 1000;

@Injectable()
export class ChildPushDedupeService {
  constructor(private readonly prisma: PrismaService) {}

  /** Shu `(kind, refKey)` uchun hali yuborilmagan bolalar (qatorni egallaganlar). Takroriy id'lar bitta hisoblanadi. */
  async claim(childIds: readonly string[], kind: string, refKey: string): Promise<string[]> {
    const unique = [...new Set(childIds)];
    const claimed: string[] = [];
    for (const batch of chunk(unique, CLAIM_BATCH)) {
      const rows = await this.prisma.childPushDedupe.createManyAndReturn({
        data: batch.map((childId) => ({ childId, kind, refKey })),
        skipDuplicates: true,
        select: { childId: true },
      });
      claimed.push(...rows.map((r) => r.childId));
    }
    return claimed;
  }

  /** Eski qatorlarni o'chirish (kunlik turlar — qisqaroq saqlanadi); o'chirilganlar soni. */
  async prune(now: Date): Promise<number> {
    const [old, daily] = await Promise.all([
      this.prisma.childPushDedupe.deleteMany({
        where: { createdAt: { lt: new Date(now.getTime() - DEDUPE_RETENTION_DAYS * DAY_MS) } },
      }),
      this.prisma.childPushDedupe.deleteMany({
        where: {
          kind: { in: [...DAILY_DEDUPE_KINDS] },
          createdAt: { lt: new Date(now.getTime() - DAILY_DEDUPE_RETENTION_DAYS * DAY_MS) },
        },
      }),
    ]);
    return old.count + daily.count;
  }
}
