// Bildirishnoma oluvchilari: o'quvchi bo'yicha ish qila oladigan xodimlar — FAOL, berilgan ruxsatga ega va
// doirasi shu o'quvchining sinfini qamrab oladi. Ruxsat va doira tekshiruvi xodim panelidagi bilan BIR XIL
// (`roleHas` + `SCHOOL_ROLES[role].scope`, sinf doirasi — `school_staff_classes`; qarang `school-actor.ts`
// `assertClassInScope`). Rollar jadvali o'zgarsa (masalan, sinf rahbariga `students.manage` berilsa) oluvchilar
// ham o'zgaradi — rol nomlari qattiq yozilmaydi.

import { SchoolStaffRole } from '@prisma/client';
import type { PrismaService } from '../../common/database/prisma.service';
import { roleHas, SCHOOL_ROLES, SchoolPermission } from '../auth/permissions';

export interface StaffRecipient {
  id: string;
  role: SchoolStaffRole;
}

type StaffDb = Pick<PrismaService, 'schoolStaff'>;

/** Berilgan ruxsatga ega rollar (rollar jadvalidan). */
export function rolesWith(permission: SchoolPermission): SchoolStaffRole[] {
  return (Object.keys(SCHOOL_ROLES) as SchoolStaffRole[]).filter((role) => roleHas(role, permission));
}

/**
 * Maktabning faol xodimlari orasidan `permission`ga ega va doirasi `classId` sinfini qamrab oladiganlar.
 * Butun maktab doirasidagi rol (DIRECTOR, ADMIN …) har qanday o'quvchini qamraydi; sinf doirasidagi rol
 * (HOMEROOM, TEACHER) — faqat o'z sinfini; sinfsiz o'quvchini (`classId = null`) faqat butun maktab doirasidagilar.
 */
export async function staffWithPermission(
  db: StaffDb,
  schoolId: string,
  permission: SchoolPermission,
  classId: string | null,
): Promise<StaffRecipient[]> {
  const roles = rolesWith(permission);
  if (roles.length === 0) return [];
  const staff = await db.schoolStaff.findMany({
    where: { schoolId, active: true, role: { in: roles } },
    select: { id: true, role: true, classes: { select: { classId: true } } },
    orderBy: [{ role: 'asc' }, { id: 'asc' }],
  });
  return staff
    .filter((s) => SCHOOL_ROLES[s.role].scope === 'SCHOOL' || (classId !== null && s.classes.some((c) => c.classId === classId)))
    .map(({ id, role }) => ({ id, role }));
}
