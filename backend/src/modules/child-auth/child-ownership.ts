import { ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { childNotFound } from './child-auth.errors';

export interface OwnedChild {
  id: string;
  name: string;
  parentId: string;
  childUserId: string | null;
}

/** Ota-onaning o'z bolasi: bola yo'q -> 404, boshqa oilaniki -> 403. */
export async function findOwnedChild(prisma: PrismaService, parentId: string, childId: string): Promise<OwnedChild> {
  const child = await prisma.child.findUnique({
    where: { id: childId },
    select: { id: true, name: true, parentId: true, childUserId: true },
  });
  if (!child) throw childNotFound();
  if (child.parentId !== parentId) throw new ForbiddenException({ code: 'FORBIDDEN', message: 'Forbidden' });
  return child;
}
