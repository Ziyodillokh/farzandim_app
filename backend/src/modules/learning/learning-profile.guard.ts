import { ConflictException } from '@nestjs/common';
import { LearningProfile, Prisma } from '@prisma/client';

/**
 * Bolaning o'quv profili — yo'q bo'lsa 409 `PROFILE_REQUIRED` (urinish
 * boshlash va mavzular ro'yxati bir xil xulq-atvor ko'rsatadi).
 */
export async function requireProfile(
  db: Pick<Prisma.TransactionClient, 'learningProfile'>,
  childId: string,
): Promise<LearningProfile> {
  const profile = await db.learningProfile.findUnique({ where: { childId } });
  if (!profile) {
    throw new ConflictException({
      message: 'Learning profile required',
      code: 'PROFILE_REQUIRED',
    });
  }
  return profile;
}
