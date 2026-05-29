import { PrismaService } from '../database/prisma.service';

/**
 * Check whether two users (PARENT or CHILD) are part of the same family link.
 *
 * Allowed combinations:
 *   - PARENT -> child.parentId == sender, child.childUserId == receiver
 *   - CHILD  -> child.childUserId == sender, child.parentId == receiver
 *
 * Returns the link details if found, otherwise null.
 */
export async function findFamilyLink(
  prisma: PrismaService,
  senderId: string,
  receiverId: string,
): Promise<{
  childId: string;
  parentId: string;
  childUserId: string;
} | null> {
  if (senderId === receiverId) return null;

  const child = await prisma.child.findFirst({
    where: {
      OR: [
        { parentId: senderId, childUserId: receiverId },
        { parentId: receiverId, childUserId: senderId },
      ],
    },
    select: { id: true, parentId: true, childUserId: true },
  });

  if (!child || !child.childUserId) return null;
  return {
    childId: child.id,
    parentId: child.parentId,
    childUserId: child.childUserId,
  };
}
