// Bola ma'lumotlari o'chirilganda o'quvchi kodi yozuvlari ham ketadi: bola o'rnini band qilgan kodlar
// (`SchoolStudentInvite`), tuzatish so'rovlari (`SchoolLinkCorrection`) va ularga bog'liq saqlangan xodim
// bildirishnomalari (o'quvchi ismi / sinfi shu yerda). Ota-ona o'rni (`parentUserId`) ota-ona akkaunti
// o'chganda begona kalit orqali o'zi bo'shaydi (SET NULL). Chaqiruv bola (Child) o'chirilishidan OLDIN bo'lishi
// shart — bildirishnomalarning begona kaliti yo'q, id'lari faqat shu qatorlardan topiladi.

import { Prisma } from '@prisma/client';
import { correctionNotificationId, guardianReviewNotificationId, reviewNotificationId } from './link-notification-ids';

export async function deleteLinkDataOfChildren(tx: Prisma.TransactionClient, childIds: readonly string[]): Promise<void> {
  if (childIds.length === 0) return;
  const ids = [...childIds];
  const invites = await tx.schoolStudentInvite.findMany({ where: { studentChildId: { in: ids } }, select: { id: true } });
  const corrections = await tx.schoolLinkCorrection.findMany({ where: { childId: { in: ids } }, select: { id: true } });
  if (invites.length === 0 && corrections.length === 0) return;
  await tx.schoolStaffNotification.deleteMany({
    where: { id: { in: [...invites.map((r) => reviewNotificationId(r.id)), ...corrections.map((r) => correctionNotificationId(r.id))] } },
  });
  await tx.schoolStudentInvite.deleteMany({ where: { studentChildId: { in: ids } } });
  await tx.schoolLinkCorrection.deleteMany({ where: { childId: { in: ids } } });
}

/**
 * Ota-ona akkaunti o'chirilganda uning vasiylik so'rovlari (`SchoolGuardianReview`) va ularga bog'liq xodim
 * bildirishnomalari ham ketadi (bildirishnomalarning begona kaliti yo'q — id'lari shu qatorlardan topiladi; chaqiruv
 * foydalanuvchi o'chirilishidan OLDIN bo'lishi shart).
 */
export async function deleteGuardianReviewsOfUsers(tx: Prisma.TransactionClient, userIds: readonly string[]): Promise<void> {
  if (userIds.length === 0) return;
  const ids = [...userIds];
  const reviews = await tx.schoolGuardianReview.findMany({ where: { userId: { in: ids } }, select: { id: true } });
  if (reviews.length === 0) return;
  await tx.schoolStaffNotification.deleteMany({ where: { id: { in: reviews.map((r) => guardianReviewNotificationId(r.id)) } } });
  await tx.schoolGuardianReview.deleteMany({ where: { userId: { in: ids } } });
}
