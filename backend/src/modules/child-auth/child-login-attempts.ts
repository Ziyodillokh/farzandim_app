// Bola logini xatolari hisobi (DB): qator qulflanadi, shuning uchun parallel noto'g'ri urinishlar ham
// aniq sanaladi va blokni chetlab o'tolmaydi. Qoida — `child-login-lock.ts` (sof funksiyalar).

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import {
  CLEAN_LOGIN_STATE,
  LoginFailureState,
  lockRemainingSeconds,
  registerFailure,
} from './child-login-lock';
import { invalidCredentials, lockedError } from './child-auth.errors';

@Injectable()
export class ChildLoginAttempts {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Xato parolni qayd etadi; yangi holat qaytadi. `justLocked` — blokni aynan shu urinish qo'ydi
   * (parallel urinishlar allaqachon qo'yilgan blokni ko'radi, ular uchun `false`).
   */
  async recordFailure(childId: string, now: Date): Promise<{ state: LoginFailureState; justLocked: boolean }> {
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT child_id FROM child_credentials WHERE child_id = ${childId} FOR UPDATE`;
      const row = await tx.childCredential.findUnique({
        where: { childId },
        select: { failedLogins: true, failedWindowStartedAt: true, lockedUntil: true },
      });
      if (!row) return { state: CLEAN_LOGIN_STATE, justLocked: false };
      const next = registerFailure(row, now);
      if (next !== row) {
        await tx.childCredential.update({
          where: { childId },
          data: {
            failedLogins: next.failedLogins,
            failedWindowStartedAt: next.failedWindowStartedAt,
            lockedUntil: next.lockedUntil,
          },
        });
      }
      return { state: next, justLocked: lockRemainingSeconds(row, now) === 0 && lockRemainingSeconds(next, now) > 0 };
    });
  }

  /**
   * To'g'ri parol: hisobni tozalaydi. Parol tekshirilgandan keyin boshqa so'rov blok qo'ygan yoki
   * parolni almashtirgan bo'lsa (parallel) — kirish rad etiladi. `lastLoginAt` faqat sessiya ochiladigan
   * kirishda (vaqtinchalik parol bilan "o'rnatish talab etiladi" holatida emas) yangilanadi.
   */
  async recordSuccess(
    childId: string,
    verifiedHash: string,
    now: Date,
  ): Promise<{ mustChangePassword: boolean }> {
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT child_id FROM child_credentials WHERE child_id = ${childId} FOR UPDATE`;
      const row = await tx.childCredential.findUnique({ where: { childId } });
      if (!row || row.passwordHash !== verifiedHash) throw invalidCredentials();
      const remaining = lockRemainingSeconds(row, now);
      if (remaining > 0) throw lockedError(remaining);
      await tx.childCredential.update({
        where: { childId },
        data: {
          failedLogins: 0,
          failedWindowStartedAt: null,
          lockedUntil: null,
          ...(!row.mustChangePassword && { lastLoginAt: now }),
        },
      });
      return { mustChangePassword: row.mustChangePassword };
    });
  }
}
