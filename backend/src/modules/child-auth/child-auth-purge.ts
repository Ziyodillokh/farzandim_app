// Bola ma'lumotlari o'chirilganda kirish maʼlumotlari ham ketadi: login/parol xeshi va tiklash so'rovlari
// (hamda ularga bog'liq maktab xodimi bildirishnomalari — o'quvchi ismi/sinfi shu yerda saqlanadi).
// Bola profili qoladigan yo'lda (bola o'z akkauntini o'chirsa) cascade ishlamaydi, shuning uchun aniq o'chiriladi;
// profil o'chadigan yo'llarda ham bildirishnomalar FK'siz — baribir shu yerdan.

import { Prisma } from '@prisma/client';
import { childRecoveryNotificationId } from './child-auth.constants';

export async function deleteChildAuthOfChildren(tx: Prisma.TransactionClient, childIds: readonly string[]): Promise<void> {
  if (childIds.length === 0) return;
  const ids = [...childIds];
  const requests = await tx.childRecoveryRequest.findMany({ where: { childId: { in: ids } }, select: { id: true } });
  if (requests.length > 0) {
    await tx.schoolStaffNotification.deleteMany({
      where: { id: { in: requests.map((r) => childRecoveryNotificationId(r.id)) } },
    });
    await tx.childRecoveryRequest.deleteMany({ where: { childId: { in: ids } } });
  }
  await tx.childCredential.deleteMany({ where: { childId: { in: ids } } });
}
