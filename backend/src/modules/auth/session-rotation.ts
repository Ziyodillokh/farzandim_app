// Refresh token rotatsiyasi (sessiya-asosli tokenlar). Bir qurilmadagi ikki
// jarayon (bola ilovasining UI va fon dvigatellari) bir vaqtda AYNI refresh
// token bilan kelishi mumkin. Rotatsiya atomik (`jti` sharti bilan
// yangilash) va yutqazgan so'rov ROTATION_GRACE_MS ichida joriy juftni
// oladi — shu sabab sessiya o'zidan yopilib, bola tizimdan chiqib ketmaydi.

import { UnauthorizedException } from '@nestjs/common';
import type { PrismaClient, UserSession } from '@prisma/client';
import { randomUUID } from 'crypto';

/** Oldingi jti shu muddat ichida joriy juftga almashtiriladi. */
export const ROTATION_GRACE_MS = 60_000;

type SessionDb = { userSession: Pick<PrismaClient['userSession'], 'updateMany' | 'findUnique'> };
type RotationState = Pick<UserSession, 'prevJti' | 'rotatedAt'>;

/** `rjti` — yaqinda (imtiyoz ichida) almashtirilgan oldingi jti. */
export function isWithinRotationGrace(session: RotationState, rjti: string | undefined, now: Date): boolean {
  if (!rjti || session.prevJti !== rjti || !session.rotatedAt) return false;
  return now.getTime() - session.rotatedAt.getTime() <= ROTATION_GRACE_MS;
}

/**
 * Yangi refresh token'ga yoziladigan jti. Token joriy jti bilan kelsa —
 * atomik rotatsiya; oldingi jti bilan imtiyoz ichida kelsa — joriy jti
 * (hech narsa yozilmaydi); aks holda 401 'Session rotated'.
 */
export async function rotateSessionJti(
  db: SessionDb,
  session: UserSession,
  rjti: string | undefined,
  now: Date = new Date(),
): Promise<string> {
  if (rjti && session.jti !== rjti) {
    if (isWithinRotationGrace(session, rjti, now)) return session.jti;
    throw new UnauthorizedException('Session rotated');
  }
  const next = randomUUID();
  const { count } = await db.userSession.updateMany({
    where: { id: session.id, jti: session.jti, revokedAt: null },
    data: { jti: next, prevJti: session.jti, rotatedAt: now, lastSeenAt: now },
  });
  if (count === 1) return next;
  // O'qish va yozish orasida parallel refresh rotatsiya qilgan (yoki sessiya yopilgan).
  const fresh = await db.userSession.findUnique({ where: { id: session.id } });
  if (fresh && !fresh.revokedAt && isWithinRotationGrace(fresh, session.jti, now)) return fresh.jti;
  throw new UnauthorizedException('Session rotated');
}
