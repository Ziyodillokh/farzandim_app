import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { Child } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';

/**
 * Bolaga kirish: faqat bolaning o'z foydalanuvchisi yoki uning ota-onasi.
 * Bola yo'q — 404, begona foydalanuvchi — 403 (gamification yo'llarining umumiy qoidasi).
 */
export async function assertChildAccess(
  prisma: Pick<PrismaService, 'child'>,
  childId: string,
  userId: string,
): Promise<Child> {
  const child = await prisma.child.findUnique({ where: { id: childId } });
  if (!child) throw new NotFoundException('Child not found');
  if (child.parentId !== userId && child.childUserId !== userId) {
    throw new ForbiddenException('Forbidden');
  }
  return child;
}
