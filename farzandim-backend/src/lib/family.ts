import { prisma } from './prisma';

/**
 * Ikki user (PARENT yoki CHILD) bir oilaviy bog'lanishga tegishlimi tekshiradi.
 * Voice/video xabarlar, parent↔child kanali ochiq bo'lishi shartligi uchun.
 *
 * Ruxsat etilgan kombinatsiyalar:
 *   - PARENT → child.parentId == parent.userId va child.childUserId == receiver.userId
 *   - CHILD  → child.childUserId == sender.userId va child.parentId == receiver.userId
 *   - PARENT → PARENT (o'zining boshqa qurilmasi/akkaunti) — false (hozir qo'llanmaydi)
 *   - CHILD  → CHILD (boshqa oila) — false
 *
 * Qaytaradi: agar bog'langan oila topilsa, ularning ulanish nuqtasi (childId).
 * Aks holda null.
 */
export async function findFamilyLink(
  userA: string,
  userB: string,
): Promise<{ childId: string; parentId: string; childUserId: string } | null> {
  if (userA === userB) return null;

  const child = await prisma.child.findFirst({
    where: {
      OR: [
        { parentId: userA, childUserId: userB },
        { parentId: userB, childUserId: userA },
      ],
    },
    select: { id: true, parentId: true, childUserId: true },
  });

  if (!child || !child.childUserId) return null;
  return { childId: child.id, parentId: child.parentId, childUserId: child.childUserId };
}
