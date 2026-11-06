// Bola ma'lumotlari o'chirilganda so'rovlar ham ketadi: so'rov qatorlari va ularga bog'liq maktab xodimi
// bildirishnomasi (o'quvchi ismi/sinfi shu yerda saqlanadi). Chaqiruv bola (Child) o'chirilishidan OLDIN bo'lishi
// shart — keyin qatorlar cascade bilan ketib, bildirishnoma id'larini topib bo'lmaydi.

import { Prisma } from '@prisma/client';

/** `SchoolStaffNotification.kind` — maktab xodimlariga (direktor, administrator). */
export const DATA_DELETION_NOTIFICATION_KIND = 'DATA_DELETION_REQUEST';

/** Saqlangan xodim bildirishnomasining barqaror id'si (upsert va tozalash uchun). */
export const deletionNotificationId = (requestId: string) => `data-deletion:${requestId}`;

export async function deleteDeletionRequestsOfChildren(
  tx: Prisma.TransactionClient,
  childIds: readonly string[],
): Promise<void> {
  if (childIds.length === 0) return;
  const requests = await tx.childDataDeletionRequest.findMany({
    where: { childId: { in: [...childIds] } },
    select: { id: true },
  });
  if (requests.length === 0) return;
  await tx.schoolStaffNotification.deleteMany({
    where: { id: { in: requests.map((r) => deletionNotificationId(r.id)) } },
  });
  await tx.childDataDeletionRequest.deleteMany({ where: { childId: { in: [...childIds] } } });
}
