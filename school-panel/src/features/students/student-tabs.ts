import type { Permission } from '@/auth/permissions';

/** O'quvchi 360° kartasi tablari (URL: `?tab=`). */
export const STUDENT_TABS = ['profile', 'attendance', 'development', 'history', 'notes', 'access'] as const;
export type StudentTab = (typeof STUDENT_TABS)[number];

/**
 * Rol bo'yicha tablar:
 * - psixolog: profil (minimal) + rivojlanish;
 * - direktor/admin: profil, davomat, tarix, eslatmalar (`development.individual` yo'q);
 * - sinf rahbari: barchasi (servis o'z sinfi bilan cheklaydi).
 * Ota-onaga ulash huquqi yo'q rollar (psixolog, o'qituvchi) shaxsiy ma'lumotlarni ko'rmaydi.
 * «Kirish» (taklif kodi, kirish ma'lumotlari, tiklash so'rovlari): `guardians.link` yoki `students.manage`.
 */
export function visibleStudentTabs(can: (permission: Permission) => boolean): StudentTab[] {
  const personal = can('guardians.link');
  const rules: Record<StudentTab, boolean> = {
    profile: true,
    attendance: personal && can('attendance.view'),
    development: can('development.individual'),
    history: personal && can('attendance.view'),
    notes: personal,
    access: personal || can('students.manage'),
  };
  return STUDENT_TABS.filter((tab) => rules[tab]);
}
