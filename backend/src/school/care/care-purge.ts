// Bola ma'lumotlarini o'chirish: murojaatlar (xabarlar cascade) va so'rovnoma ishtirok belgilari.
// ANONIM javoblar (`SchoolCareAnonResponse`) O'CHIRILMAYDI — ular o'quvchiga bog'lanmagan
// (shunday loyihalangan), shuning uchun kimniki ekanini aniqlab bo'lmaydi. Eski (o'quvchiga
// bog'langan) `SchoolCareResponse` qatorlari ham tegilmaydi: ular maktab yozuvi, o'quvchi
// qatori ham o'chirilmaydi. O'quvchi `childId` bog'lanishi child o'chganda SetNull bo'ladi,
// shuning uchun chaqiruv child o'chirilishidan OLDIN bo'lishi shart.

import { Prisma } from '@prisma/client';
import { careNotificationIds } from './care-notification-ids';

/** Bolalarga (Child) bog'langan o'quvchilarning murojaatlari va ishtirok belgilarini o'chiradi. */
export async function deleteCareOfChildren(tx: Prisma.TransactionClient, childIds: readonly string[]): Promise<void> {
  if (childIds.length === 0) return;
  const students = await tx.schoolStudent.findMany({ where: { childId: { in: [...childIds] } }, select: { id: true } });
  if (students.length === 0) return;
  const studentIds = students.map((s) => s.id);
  const requests = await tx.schoolCareRequest.findMany({ where: { studentId: { in: studentIds } }, select: { id: true } });
  if (requests.length > 0) {
    // Murojaatga bog'liq saqlangan xodim bildirishnomalari (sinf / mavzu) ham ketadi.
    await tx.schoolStaffNotification.deleteMany({ where: { id: { in: requests.flatMap((r) => careNotificationIds(r.id)) } } });
    await tx.schoolCareRequest.deleteMany({ where: { studentId: { in: studentIds } } });
  }
  await tx.schoolCareParticipation.deleteMany({ where: { studentId: { in: studentIds } } });
}
