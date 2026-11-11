// Admin → Maktablar: javob shakllari. Parol xeshi, TOTP siri va kiosk kaliti
// hech qachon chiqmaydi; vaqtinchalik parol faqat yaratish / tiklash javobida
// (`AdminCredentialsView`) bir marta qaytadi.

import { Prisma, SchoolStaffRole, SchoolStatus } from '@prisma/client';
import { ADMIN_MANAGED_ROLES } from './admin-schools.input';

export const ACCOUNT_SELECT = {
  id: true,
  fullName: true,
  role: true,
  position: true,
  username: true,
  active: true,
  mustChangePassword: true,
  totpEnabled: true,
  lockedUntil: true,
  lastLoginAt: true,
  createdAt: true,
} satisfies Prisma.SchoolStaffSelect;

export const SCHOOL_SELECT = {
  id: true,
  code: true,
  name: true,
  shortName: true,
  city: true,
  status: true,
  academicYear: true,
  createdAt: true,
  _count: {
    select: {
      classes: true,
      students: { where: { archived: false } },
      staff: { where: { active: true } },
      guardians: { where: { linkStatus: 'LINKED' } },
    },
  },
  staff: {
    where: { role: { in: [...ADMIN_MANAGED_ROLES] } },
    orderBy: [{ role: 'asc' }, { createdAt: 'asc' }],
    select: ACCOUNT_SELECT,
  },
} satisfies Prisma.SchoolSelect;

type SchoolRow = Prisma.SchoolGetPayload<{ select: typeof SCHOOL_SELECT }>;
type AccountRow = Prisma.SchoolStaffGetPayload<{ select: typeof ACCOUNT_SELECT }>;

export interface AdminSchoolAccountView {
  id: string;
  fullName: string;
  role: SchoolStaffRole;
  position: string;
  username: string | null;
  active: boolean;
  mustChangePassword: boolean;
  totpEnabled: boolean;
  /** Ko'p xato urinish — vaqtincha bloklangan (parol tiklansa ochiladi). */
  locked: boolean;
  lastLoginAt: string | null;
  createdAt: string;
}

export interface AdminSchoolView {
  id: string;
  code: string;
  name: string;
  shortName: string;
  city: string;
  status: SchoolStatus;
  academicYear: string;
  createdAt: string;
  counts: { classes: number; students: number; staff: number; linkedGuardians: number };
  /** Direktor(lar) va himoyalangan rollar (psixolog) — admin boshqaradigan hisoblar. */
  accounts: AdminSchoolAccountView[];
}

export interface AdminCredentialsView {
  schoolCode: string;
  username: string;
  temporaryPassword: string;
  account: AdminSchoolAccountView;
}

export function toAccountView(row: AccountRow, now = new Date()): AdminSchoolAccountView {
  return {
    id: row.id,
    fullName: row.fullName,
    role: row.role,
    position: row.position,
    username: row.username,
    active: row.active,
    mustChangePassword: row.mustChangePassword,
    totpEnabled: row.totpEnabled,
    locked: row.lockedUntil !== null && row.lockedUntil > now,
    lastLoginAt: row.lastLoginAt?.toISOString() ?? null,
    createdAt: row.createdAt.toISOString(),
  };
}

export function toSchoolView(row: SchoolRow, now = new Date()): AdminSchoolView {
  return {
    id: row.id,
    code: row.code,
    name: row.name,
    shortName: row.shortName,
    city: row.city,
    status: row.status,
    academicYear: row.academicYear,
    createdAt: row.createdAt.toISOString(),
    counts: {
      classes: row._count.classes,
      students: row._count.students,
      staff: row._count.staff,
      linkedGuardians: row._count.guardians,
    },
    accounts: row.staff.map((s) => toAccountView(s, now)),
  };
}
