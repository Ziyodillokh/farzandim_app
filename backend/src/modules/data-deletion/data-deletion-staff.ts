// Maktab rahbariyatiga saqlangan bildirishnoma (DB'ga yozuv, push yo'q): bola maktab o'quvchisiga bog'langan bo'lsa,
// DIRECTOR va ADMIN uchun `SchoolStaffNotification` — FAQAT `{ studentName, className }` (sabab, bola/so'rov id'si yo'q).
// Id barqaror (`data-deletion:<requestId>`), shuning uchun yozuv idempotent: so'rov bilan BIR tranzaksiyada yoziladi va
// takroriy so'rovda qayta bajariladi (avval yo'qolgan bo'lsa tiklanadi).

import { Prisma } from '@prisma/client';
import { DATA_DELETION_NOTIFICATION_KIND, deletionNotificationId } from './data-deletion-purge';

/** Saqlangan bildirishnoma qaysi rollarga ko'rinadi. */
export const DATA_DELETION_STAFF_ROLES = ['DIRECTOR', 'ADMIN'];

export async function upsertDeletionStaffNotification(
  tx: Prisma.TransactionClient,
  request: { id: string; childId: string; createdAt: Date },
): Promise<void> {
  const student = await tx.schoolStudent.findUnique({
    where: { childId: request.childId },
    select: { schoolId: true, lastName: true, firstName: true, class: { select: { name: true } } },
  });
  if (!student) return;
  const id = deletionNotificationId(request.id);
  const data = {
    schoolId: student.schoolId,
    kind: DATA_DELETION_NOTIFICATION_KIND,
    at: request.createdAt,
    roles: DATA_DELETION_STAFF_ROLES,
    classIds: [],
    staffIds: [],
    params: { studentName: `${student.lastName} ${student.firstName}`, className: student.class?.name ?? '' },
  };
  await tx.schoolStaffNotification.upsert({ where: { id }, create: { id, ...data }, update: data });
}
