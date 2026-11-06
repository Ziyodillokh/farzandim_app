// Ulanish so'rovlari (K2): kim hal qila oladi va kimga bildirishnoma boradi. Bitta manba: bildirishnoma FAQAT so'rovni
// haqiqatan hal qila oladigan xodimlarga ketadi — ya'ni ko'rish / tasdiqlash / rad etish endpointlari talab qiladigan
// ruxsat (`LINK_REQUESTS_PERMISSION`) bor, faol, shu maktabning va o'quvchi sinfi doirasidagi xodimlarga. Tekshiruv
// endpointlardagi `assertCan` + `assertClassInScope` bilan AYNAN bir xil funksiyalar (`actorCan`, `allowedClassIds`)
// orqali — rol / ruxsat jadvali o'zgarsa, oluvchilar ham o'zi o'zgaradi (rol nomlari qattiq yozilmagan).
// Hech kim mos kelmasa — maktabning faol DIREKTORlari (so'rov e'tiborsiz qolmasin).

import { Prisma, SchoolStaffRole } from '@prisma/client';
import { SCHOOL_ROLES, SchoolPermission } from '../auth/permissions';
import { actorCan, allowedClassIds, SchoolActor } from '../auth/school-actor';

type Tx = Prisma.TransactionClient;

/**
 * Ulanish so'rovlarini ko'rish, tasdiqlash va rad etish (shu jumladan bolaning tuzatish so'rovini hal qilish)
 * huquqi: `GET /school/link-requests`, `POST /school/link-requests/:id/confirm|reject`.
 */
export const LINK_REQUESTS_PERMISSION: SchoolPermission = 'guardians.link';

export interface StaffCandidate {
  id: string;
  fullName: string;
  role: SchoolStaffRole;
  classes: ReadonlyArray<{ classId: string }>;
}

export interface LinkRecipients {
  roles: SchoolStaffRole[];
  staffIds: string[];
}

/** Xodimni so'rov endpointlari ko'radigan `SchoolActor` ko'rinishiga keltiradi (sessiyasiz). */
const asActor = (staff: StaffCandidate, schoolId: string): SchoolActor => ({
  staffId: staff.id,
  schoolId,
  sessionId: '',
  name: staff.fullName,
  role: staff.role,
  scope: SCHOOL_ROLES[staff.role].scope,
  classIds: staff.classes.map((c) => c.classId),
});

/** Xodim shu maktab o'quvchisi bo'yicha so'rovni hal qila oladimi: ruxsat bor va o'quvchi sinfi doirada. */
export function canHandleLinkRequest(staff: StaffCandidate, student: { schoolId: string; classId: string | null }): boolean {
  const actor = asActor(staff, student.schoolId);
  if (!actorCan(actor, LINK_REQUESTS_PERMISSION)) return false;
  const allowed = allowedClassIds(actor);
  return allowed === null || (student.classId !== null && allowed.includes(student.classId));
}

/**
 * Bildirishnoma oluvchilari: o'quvchi maktabining FAOL xodimlaridan so'rovni hal qila oladiganlar; hech kim bo'lmasa —
 * faol direktorlar. Bo'sh natija — oluvchi yo'q (bildirishnoma yozilmaydi).
 */
export async function resolveLinkRecipients(tx: Tx, student: { schoolId: string; classId: string | null }): Promise<LinkRecipients> {
  const staff = await tx.schoolStaff.findMany({
    where: { schoolId: student.schoolId, active: true },
    select: { id: true, fullName: true, role: true, classes: { select: { classId: true } } },
    orderBy: { id: 'asc' },
  });
  const qualified = staff.filter((s) => canHandleLinkRequest(s, student));
  const chosen = qualified.length > 0 ? qualified : staff.filter((s) => s.role === 'DIRECTOR');
  return { roles: [...new Set(chosen.map((s) => s.role))].sort(), staffIds: chosen.map((s) => s.id) };
}
