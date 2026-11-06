// Sessiyani yopish: sabab saqlanadi (`revokedReason`) va bola foydalanuvchi xonasiga WebSocket
// `session:closed` yuboriladi — ilova "sessiya yopildi" (A12) ekranini darhol ko'rsatadi.
// Sabab ro'yxati kontrakt bilan bir xil; yangilash tokenida `SESSION_REVOKED` shu sababni qaytaradi.

import { Prisma } from '@prisma/client';
import type { RealtimeGateway } from '../../common/realtime/realtime.gateway';

export const SESSION_CLOSE_REASONS = [
  'RECOVERED',
  'SIGNED_IN_ELSEWHERE',
  'SIGNED_OUT',
  'PERMISSIONS_CHANGED',
] as const;
export type SessionCloseReason = (typeof SESSION_CLOSE_REASONS)[number];

export const SESSION_CLOSED_EVENT = 'session:closed';

type SessionDb = Pick<Prisma.TransactionClient, 'userSession'>;

/**
 * Foydalanuvchining tugatilmagan sessiyalarini (`where` bilan toraytirilgan) sababi bilan yopadi.
 * Yopilgan id'lar qaytadi; hodisani tranzaksiya yakunlangach {@link announceSessionsClosed} yuboradi.
 */
export async function closeSessions(
  db: SessionDb,
  userId: string,
  reason: SessionCloseReason,
  where: Prisma.UserSessionWhereInput = {},
  now: Date = new Date(),
): Promise<string[]> {
  const rows = await db.userSession.findMany({
    where: { userId, revokedAt: null, ...where },
    select: { id: true },
  });
  if (rows.length === 0) return [];
  const ids = rows.map((r) => r.id);
  await db.userSession.updateMany({
    where: { id: { in: ids }, revokedAt: null },
    data: { revokedAt: now, revokedReason: reason },
  });
  return ids;
}

/**
 * WebSocket `session:closed` — best-effort: ulanish bo'lmasa ham yopish muvaffaqiyatli.
 * Bo'sh ro'yxat odatda yuborilmaydi; `emitWhenEmpty` — tiklashda faqat eski (sid'siz) token yopilganda.
 */
export function announceSessionsClosed(
  realtime: Pick<RealtimeGateway, 'emitToUser'>,
  userId: string,
  sessionIds: readonly string[],
  reason: SessionCloseReason,
  emitWhenEmpty = false,
): void {
  if (sessionIds.length === 0 && !emitWhenEmpty) return;
  try {
    realtime.emitToUser(userId, SESSION_CLOSED_EVENT, { sessionIds: [...sessionIds], reason });
  } catch {
    // WS server ishlamayotgan bo'lishi mumkin (test / ishga tushish) — yopish baribir kuchda.
  }
}
