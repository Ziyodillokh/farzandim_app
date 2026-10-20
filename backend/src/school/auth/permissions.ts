// Maktab paneli ruxsatlari — panel `school-panel/src/auth/permissions.ts`
// bilan BIR XIL matritsa (TZ 2.1). Backend haqiqat manbai: panel http
// rejimida rol ruxsatlarini `/school/auth/me` javobidan oladi.

import { SchoolStaffRole } from '@prisma/client';

/** `@SchoolPermissions(...)` metama'lumot kaliti. */
/** Vaqtinchalik parol bilan ham ochiq yo'llar (`/me`, parol almashtirish). */
export const SCHOOL_TEMP_PASSWORD_OK_KEY = 'school:tempPasswordOk';
export const SCHOOL_PERMISSIONS_KEY = 'school:permissions';

export const SCHOOL_PERMISSIONS = [
  'dashboard.view',
  'settings.manage',
  'staff.view',
  'staff.manage',
  'audit.view',
  'demo.reset',
  'classes.view',
  'classes.manage',
  'students.view',
  'students.manage',
  'guardians.link',
  'schoolMode.view',
  'schoolMode.manage',
  'schoolMode.exception',
  'schoolMode.emergency',
  'attendance.view',
  'attendance.history',
  'attendance.mark',
  'attendance.correct',
  'attendance.earlyExit',
  'attendance.kiosk',
  'messages.view',
  'messages.sendSchool',
  'messages.sendClass',
  'reminders.manage',
  'payments.manage',
  'care.aggregate',
  'care.individual',
  'care.surveys',
  'learning.view',
  'learning.assign',
  'reports.view',
  'assessments.manage',
  'development.view',
  'development.individual',
] as const;

export type SchoolPermission = (typeof SCHOOL_PERMISSIONS)[number];

/** SCHOOL — butun maktab; OWN_CLASS — faqat biriktirilgan sinf(lar). */
export type SchoolScope = 'SCHOOL' | 'OWN_CLASS';

export interface SchoolRoleDefinition {
  key: SchoolStaffRole;
  scope: SchoolScope;
  permissions: readonly SchoolPermission[];
}

export const SCHOOL_ROLES: Record<SchoolStaffRole, SchoolRoleDefinition> = {
  DIRECTOR: {
    key: 'DIRECTOR',
    scope: 'SCHOOL',
    permissions: [
      'dashboard.view',
      'settings.manage',
      'staff.view',
      'staff.manage',
      'audit.view',
      'demo.reset',
      'classes.view',
      'classes.manage',
      'students.view',
      'students.manage',
      'guardians.link',
      'schoolMode.view',
      'schoolMode.manage',
      'schoolMode.exception',
      'schoolMode.emergency',
      'attendance.view',
      'attendance.history',
      'messages.view',
      'messages.sendSchool',
      'messages.sendClass',
      'reminders.manage',
      'payments.manage',
      'care.aggregate',
      'learning.view',
      'reports.view',
      'development.view',
    ],
  },
  ADMIN: {
    key: 'ADMIN',
    scope: 'SCHOOL',
    permissions: [
      'dashboard.view',
      'staff.view',
      'audit.view',
      'classes.view',
      'classes.manage',
      'students.view',
      'students.manage',
      'guardians.link',
      'schoolMode.view',
      'schoolMode.manage',
      'schoolMode.exception',
      'schoolMode.emergency',
      'attendance.view',
      'attendance.history',
      'attendance.mark',
      'attendance.correct',
      'attendance.earlyExit',
      'attendance.kiosk',
      'messages.view',
      'messages.sendSchool',
      'messages.sendClass',
      'reminders.manage',
      'payments.manage',
      'care.aggregate',
      'learning.view',
      'learning.assign',
      'reports.view',
      'development.view',
    ],
  },
  HOMEROOM: {
    key: 'HOMEROOM',
    scope: 'OWN_CLASS',
    permissions: [
      'dashboard.view',
      'classes.view',
      'students.view',
      'guardians.link',
      'schoolMode.view',
      'schoolMode.exception',
      'attendance.view',
      'attendance.history',
      'attendance.mark',
      'attendance.correct',
      'attendance.earlyExit',
      'messages.view',
      'messages.sendClass',
      'learning.view',
      'learning.assign',
      'development.view',
      'development.individual',
    ],
  },
  PSYCHOLOGIST: {
    key: 'PSYCHOLOGIST',
    scope: 'SCHOOL',
    permissions: [
      'dashboard.view',
      'students.view',
      'care.aggregate',
      'care.individual',
      'care.surveys',
      'assessments.manage',
      'development.view',
      'development.individual',
    ],
  },
  DUTY: {
    key: 'DUTY',
    scope: 'SCHOOL',
    permissions: ['dashboard.view', 'attendance.view', 'attendance.mark', 'attendance.kiosk'],
  },
  TEACHER: {
    key: 'TEACHER',
    scope: 'OWN_CLASS',
    permissions: ['dashboard.view', 'classes.view', 'students.view', 'attendance.view'],
  },
};

export function roleHas(role: SchoolStaffRole, permission: SchoolPermission): boolean {
  return SCHOOL_ROLES[role].permissions.includes(permission);
}

/**
 * Himoyalangan rollar — bolaning maxfiy ma'lumotiga (murojaat matni, test
 * javoblari) kiradi. `staff.manage` (direktor) ularni yarata, ularga ko'tara
 * yoki ularning login / parolini o'rnata olmaydi — aks holda direktor o'zi
 * "psixolog" hisobi ochib, 403 matritsasini chetlab o'tardi. Faqat operator
 * (`scripts/school/create-staff.ts`) beradi.
 */
export const PROTECTED_ROLES: readonly SchoolStaffRole[] = (Object.keys(SCHOOL_ROLES) as SchoolStaffRole[]).filter(
  (role) => roleHas(role, 'care.individual') || roleHas(role, 'assessments.manage'),
);

export const isProtectedRole = (role: SchoolStaffRole) => PROTECTED_ROLES.includes(role);

/** Sinf doirasidagi rollar — faqat shularda `classIds` saqlanadi. */
export const CLASS_SCOPED_ROLES: readonly SchoolStaffRole[] = ['HOMEROOM', 'TEACHER'];
