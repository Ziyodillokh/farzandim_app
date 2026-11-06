import { Prisma } from '@prisma/client';

/**
 * Mukofot tranzaksiyalari (bola qulfi ostida): avvalgi qulfsiz kod kabi
 * band paytda kutadi — standart 2 s kutishdan keyin 500 qaytarmasin.
 */
export const AWARD_TX_OPTIONS = { maxWait: 10_000, timeout: 15_000 } as const;

/**
 * Bola mukofotlari / yutuqlari qulfi (tranzaksiya oxirigacha; qayta olish xavfsiz).
 * XP, DON, streak va yutuqlar ro'yxati bir qulf ostida o'zgaradi.
 */
export async function lockChildAwards(
  tx: Prisma.TransactionClient,
  childId: string,
): Promise<void> {
  await tx.$queryRaw`SELECT 1 AS locked FROM pg_advisory_xact_lock(hashtextextended(${`xp:${childId}`}, 0))`;
}
