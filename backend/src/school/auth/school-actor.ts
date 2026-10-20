// So'rov egasi (panel `context.ts` dagi `Actor` bilan bir xil mantiq):
// ruxsat va sinf doirasi tekshiruvlari servis qatlamida.

import { SchoolStaffRole } from '@prisma/client';
import { forbidden } from '../common/school-errors';
import {
  roleHas,
  SCHOOL_ROLES,
  SchoolPermission,
  SchoolScope,
} from './permissions';

export interface SchoolActor {
  staffId: string;
  schoolId: string;
  sessionId: string;
  name: string;
  role: SchoolStaffRole;
  scope: SchoolScope;
  /** Sinf doirasi (OWN_CLASS rollar uchun). */
  classIds: string[];
  ip?: string;
}

export function actorCan(actor: SchoolActor, permission: SchoolPermission): boolean {
  return roleHas(actor.role, permission);
}

export function assertCan(actor: SchoolActor, permission: SchoolPermission): void {
  if (!actorCan(actor, permission)) throw forbidden(permission);
}

export function assertCanAny(actor: SchoolActor, permissions: readonly SchoolPermission[]): void {
  if (!permissions.some((p) => actorCan(actor, p))) throw forbidden(permissions.join('|'));
}

/** `null` — butun maktab; aks holda ruxsat etilgan sinflar. */
export function allowedClassIds(actor: SchoolActor): string[] | null {
  return SCHOOL_ROLES[actor.role].scope === 'SCHOOL' ? null : actor.classIds;
}

export function assertClassInScope(actor: SchoolActor, classId: string | null): void {
  const allowed = allowedClassIds(actor);
  if (allowed && (!classId || !allowed.includes(classId))) {
    throw forbidden(`class ${classId}`);
  }
}

/** Prisma `where` uchun sinf doirasi (`classId` ustuni bo'lgan jadvallar). */
export function classScopeWhere(actor: SchoolActor): { classId?: { in: string[] } } {
  const allowed = allowedClassIds(actor);
  return allowed ? { classId: { in: allowed } } : {};
}
