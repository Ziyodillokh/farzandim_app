// Ulanish so'rovlari uchun saqlangan xodim bildirishnomalari (`SchoolStaffNotification`): LINK_REVIEW (bola kod kiritdi,
// tasdiq kutilmoqda), LINK_CORRECTION (bola "maktab / sinf noto'g'ri" dedi) va GUARDIAN_REVIEW (ishonchsiz ota-ona
// 6 raqamli kod kiritdi). FAQAT `{ studentName, className }`:
// bola ismi, kod, izoh va id'lar yo'q. Id barqaror (upsert / tozalash uchun); so'rov hal bo'lganda yozuv o'chadi.
// Oluvchilar — so'rovni hal qila oladigan xodimlar (`link-access.ts`): ruxsat + faol + shu maktab + o'quvchi sinfi
// doirasida; hech kim bo'lmasa direktorlar. Ular `staffIds` bilan nishonlanadi (rol sharti ham saqlanadi), shuning
// uchun begona sinf rahbari yoki ruxsatsiz rol hech qachon ko'rmaydi.

import { Prisma } from '@prisma/client';
import { resolveLinkRecipients } from './link-access';
import { LINK_REQUESTS_HREF, LinkNotificationKind } from './link-notification-ids';
import { studentName } from './student-view';

type Tx = Prisma.TransactionClient;

export interface NotifiableStudent {
  schoolId: string;
  lastName: string;
  firstName: string;
  classId: string | null;
  class: { name: string } | null;
}

export async function upsertLinkNotification(
  tx: Tx,
  input: { id: string; kind: LinkNotificationKind; student: NotifiableStudent; at: Date },
): Promise<void> {
  const { id, kind, student, at } = input;
  const recipients = await resolveLinkRecipients(tx, student);
  if (recipients.staffIds.length === 0) {
    // Faol xodim yo'q: ko'radigan odam bo'lmagan yozuv saqlanmaydi (avvalgisi bo'lsa, o'chiriladi).
    await tx.schoolStaffNotification.deleteMany({ where: { id } });
    return;
  }
  const data = {
    schoolId: student.schoolId,
    kind,
    at,
    roles: recipients.roles,
    classIds: student.classId ? [student.classId] : [],
    staffIds: recipients.staffIds,
    params: { studentName: studentName(student), className: student.class?.name ?? '' },
    href: LINK_REQUESTS_HREF,
  };
  await tx.schoolStaffNotification.upsert({ where: { id }, create: { id, ...data }, update: data });
}

export async function clearLinkNotifications(tx: Tx, ids: readonly string[]): Promise<void> {
  if (ids.length === 0) return;
  await tx.schoolStaffNotification.deleteMany({ where: { id: { in: [...ids] } } });
}
