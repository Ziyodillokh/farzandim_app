// DON daftarini sahifalash: qadam yozuvlari Toshkent kuni bo'yicha BITTA elementga
// guruhlanadi, kursor esa guruhlarga qaramay to'g'ri ishlaydi.
//
// Qoida (kursor to'g'riligi uchun):
//  - Element tartibi — "langar" qator (createdAt, id) bo'yicha kamayish.
//  - Oddiy yozuvning langari — o'zi. Qadam kunining langari — shu kunning
//    `donDelta != 0` DAILY_GOAL qatorlari ichida ENG SO'NGGISI.
//  - Xom qatorlar langar tartibida (yangisi birinchi) o'qiladi; qadam qatori faqat
//    o'zi shu kunning langari bo'lsa element beradi (yig'indi — kunning HAMMA
//    qatorlaridan), kunning eski qatorlari o'tkazib yuboriladi.
//  - Kursor = oxirgi elementning langari. Keyingi sahifa: (createdAt, id) < kursor.
//    Qadam kuni faqat langari kursordan eski bo'lsa chiqadi — ya'ni bir kun ikki
//    sahifada takrorlanmaydi va yo'qolmaydi (kunning eski qatorlari kursordan
//    pastda bo'lsa ham, langari yuqorida bo'lgani uchun ular element bermaydi).

import { XpEventType } from '@prisma/client';
import { tashkentDay } from '../../../common/time/tashkent';
import { LedgerPosition, stepsItemId } from './don-ledger';

export interface LedgerRow {
  id: string;
  type: XpEventType;
  donDelta: number;
  relatedId: string | null;
  createdAt: Date;
}

export interface StepDayStat {
  amount: number;
  /** Kunning eng so'nggi qadam qatori id'si. */
  anchorId: string;
}

/** Ma'lumot manbai (prod — Prisma; testda — xotira). */
export interface LedgerSource {
  /** `position`dan ESKI (createdAt, id) qatorlar, kamayish tartibida, `donDelta != 0`. */
  rowsBefore(position: LedgerPosition | null, take: number): Promise<LedgerRow[]>;
  /** Kunlar (Toshkent `YYYY-MM-DD`) bo'yicha qadam yig'indisi va langari. */
  stepDays(days: readonly string[]): Promise<Map<string, StepDayStat>>;
}

/** Daftar elementi (boyitishdan oldin). */
export interface LedgerEntry {
  /** Oddiy yozuv — XpEvent id; qadam kuni — `steps:YYYY-MM-DD`. */
  id: string;
  row: LedgerRow;
  amount: number;
  isSteps: boolean;
}

/** Xom qatorlardan elementlar (qadam kunlari guruhlangan). */
export function entriesFromRows(
  rows: readonly LedgerRow[],
  stepDays: ReadonlyMap<string, StepDayStat>,
): LedgerEntry[] {
  return rows.flatMap((row): LedgerEntry[] => {
    if (row.type !== XpEventType.DAILY_GOAL) {
      return [{ id: row.id, row, amount: row.donDelta, isSteps: false }];
    }
    const day = tashkentDay(row.createdAt);
    const stat = stepDays.get(day);
    if (!stat || stat.anchorId !== row.id) return [];
    return [{ id: stepsItemId(day), row, amount: stat.amount, isSteps: true }];
  });
}

/** `after`dan keyingi `want` ta element (kamroq — daftar tugagan). */
export async function collectLedgerEntries(
  source: LedgerSource,
  after: LedgerPosition | null,
  want: number,
): Promise<LedgerEntry[]> {
  const batch = Math.max(want * 2, 50);
  const entries: LedgerEntry[] = [];
  let position = after;
  while (entries.length < want) {
    const rows = await source.rowsBefore(position, batch);
    if (rows.length === 0) break;
    const days = [
      ...new Set(
        rows.filter((r) => r.type === XpEventType.DAILY_GOAL).map((r) => tashkentDay(r.createdAt)),
      ),
    ];
    const stepDays = days.length > 0 ? await source.stepDays(days) : new Map<string, StepDayStat>();
    entries.push(...entriesFromRows(rows, stepDays));
    if (rows.length < batch) break;
    const last = rows[rows.length - 1];
    position = { at: last.createdAt, id: last.id };
  }
  return entries.slice(0, want);
}
