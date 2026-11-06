// DON daftari (I03): `XpEvent` qatorlari (`donDelta != 0`), yangisi birinchi.
// Qadam yozuvlari Toshkent kuni bo'yicha guruhlanadi (`ledger-collector.ts`).
// Xotiraga hamma qator yuklanmaydi: indekslangan (child_id, created_at) kalit-sahifalash,
// sahifa uchun sarlavhalar guruhlab (bitta so'rov / manba) olinadi.

import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../common/database/prisma.service';
import { TASHKENT_TZ, tashkentDayRange, tashkentDayStart } from '../../../common/time/tashkent';
import { assertChildAccess } from '../child-access';
import { DonLedgerQueryDto, LEDGER_DEFAULT_LIMIT } from '../dto/don-ledger-query.dto';
import {
  decodeLedgerCursor,
  encodeLedgerCursor,
  LedgerItem,
  LedgerPosition,
} from './don-ledger';
import {
  collectLedgerEntries,
  LedgerEntry,
  LedgerRow,
  LedgerSource,
  StepDayStat,
} from './ledger-collector';
import { loadLedgerLookups, resolveEntry } from './ledger-lookups';

const TZ_SQL = Prisma.raw(`'${TASHKENT_TZ}'`);

interface StepDayRow {
  day: string;
  amount: number;
  anchor_id: string;
}

export interface DonLedgerPage {
  balance: number;
  pending: number;
  items: LedgerItem[];
  nextCursor: string | null;
}

@Injectable()
export class DonLedgerService {
  constructor(private readonly prisma: PrismaService) {}

  async list(childId: string, userId: string, query: DonLedgerQueryDto): Promise<DonLedgerPage> {
    await assertChildAccess(this.prisma, childId, userId);
    const after = query.cursor === undefined ? null : decodeLedgerCursor(query.cursor);
    if (query.cursor !== undefined && !after) {
      throw new BadRequestException({ message: 'cursor: invalid', code: 'VALIDATION' });
    }
    const limit = query.limit ?? LEDGER_DEFAULT_LIMIT;

    const [profile, found] = await Promise.all([
      this.prisma.childProfile.findUnique({ where: { childId }, select: { donBalance: true } }),
      collectLedgerEntries(this.sourceFor(childId), after, limit + 1),
    ]);
    const page = found.slice(0, limit);
    const lookups = await loadLedgerLookups(this.prisma, childId, page);

    return {
      balance: profile?.donBalance ?? 0,
      pending: 0,
      items: page.map((entry) => resolveEntry(entry, lookups)),
      nextCursor: found.length > limit ? encodeLedgerCursor(anchorOf(page[page.length - 1])) : null,
    };
  }

  private sourceFor(childId: string): LedgerSource {
    return {
      rowsBefore: (position, take) => this.rowsBefore(childId, position, take),
      stepDays: (days) => this.stepDays(childId, days),
    };
  }

  private rowsBefore(
    childId: string,
    position: LedgerPosition | null,
    take: number,
  ): Promise<LedgerRow[]> {
    return this.prisma.xpEvent.findMany({
      where: {
        childId,
        donDelta: { not: 0 },
        ...(position && {
          OR: [
            { createdAt: { lt: position.at } },
            { createdAt: position.at, id: { lt: position.id } },
          ],
        }),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take,
      select: { id: true, type: true, donDelta: true, relatedId: true, createdAt: true },
    });
  }

  /**
   * Berilgan Toshkent kunlari uchun qadam yig'indisi va eng so'nggi qator. Bitta
   * indekslangan (child_id, created_at) oraliq: birinchi kun boshidan oxirgi kun
   * oxirigacha. `created_at` — UTC `timestamp`; kun Toshkent vaqtida hisoblanadi.
   * Faqat so'ralgan kunlar emas, oraliqdagi barcha kunlar qaytadi (chaqiruvchi kerakligini oladi).
   */
  private async stepDays(
    childId: string,
    days: readonly string[],
  ): Promise<Map<string, StepDayStat>> {
    const sorted = [...days].sort();
    const from = tashkentDayStart(sorted[0]).toISOString();
    const to = tashkentDayRange(sorted[sorted.length - 1]).lt.toISOString();
    const rows = await this.prisma.$queryRaw<StepDayRow[]>`
      SELECT to_char((e.created_at AT TIME ZONE 'UTC') AT TIME ZONE ${TZ_SQL}, 'YYYY-MM-DD') AS day,
             SUM(e.don_delta)::int AS amount,
             (ARRAY_AGG(e.id ORDER BY e.created_at DESC, e.id DESC))[1] AS anchor_id
      FROM xp_events e
      WHERE e.child_id = ${childId}
        AND e.type = 'DAILY_GOAL'
        AND e.don_delta <> 0
        AND e.created_at >= ${from}::timestamp
        AND e.created_at < ${to}::timestamp
      GROUP BY 1`;
    return new Map(rows.map((r) => [r.day, { amount: r.amount, anchorId: r.anchor_id }]));
  }
}

const anchorOf = (entry: LedgerEntry): LedgerPosition => ({
  at: entry.row.createdAt,
  id: entry.row.id,
});
