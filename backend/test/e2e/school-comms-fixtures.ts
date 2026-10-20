// Xabarlar (S4) e2e fixture'lari: sinf, oila (o'quvchi + vasiy, ixtiyoriy —
// Parvoz Parents foydalanuvchisiga bog'langan), to'lov eslatmasi va so'rovlar.

import type { NestFastifyApplication } from '@nestjs/platform-fastify';
import type { PrismaClient } from '@prisma/client';
import { randomInt } from 'node:crypto';
import type { LoggedIn } from './school-fixtures';

export const SCHOOL = { kind: 'SCHOOL', classIds: [], guardianIds: [] } as const;
export const classesAudience = (...classIds: string[]) => ({ kind: 'CLASSES', classIds, guardianIds: [] });
export const guardiansAudience = (...guardianIds: string[]) => ({ kind: 'GUARDIANS', classIds: [], guardianIds });

export const draft = (audience: object, title = 'Sinov xabari') => ({
  title,
  body: "Ertaga soat 09:00 da yig'ilish bo'ladi.",
  priority: 'NORMAL',
  audience,
});

export async function createClass(prisma: PrismaClient, schoolId: string, grade: number, letter: string) {
  const shift = await prisma.schoolShift.findFirstOrThrow({ where: { schoolId } });
  return prisma.schoolClass.create({
    data: { schoolId, grade, letter, name: `${grade}-${letter}`, shiftId: shift.id },
  });
}

export interface Family {
  studentId: string;
  guardianId: string;
}

/** O'quvchi + vasiy; `userId` berilsa — vasiy Parvoz Parents'ga ulangan (LINKED). */
export async function addFamily(
  prisma: PrismaClient,
  schoolId: string,
  classId: string | null,
  opts: { userId?: string; guardianName?: string; lastName?: string; archived?: boolean } = {},
): Promise<Family> {
  const student = await prisma.schoolStudent.create({
    data: {
      schoolId,
      classId,
      lastName: opts.lastName ?? 'Aliyev',
      firstName: 'Vali',
      gender: 'MALE',
      birthDate: '2014-03-01',
      studentCode: `P-${randomInt(100000, 999999)}`,
      enrolledAt: '2026-09-02',
      archived: opts.archived ?? false,
    },
  });
  const guardian = await prisma.schoolGuardian.create({
    data: {
      schoolId,
      fullName: opts.guardianName ?? 'Aliyeva Nodira',
      phone: '+998 90 123 45 67',
      relation: 'MOTHER',
      linkStatus: opts.userId ? 'LINKED' : 'NOT_INVITED',
      userId: opts.userId ?? null,
      students: { create: { studentId: student.id } },
    },
  });
  return { studentId: student.id, guardianId: guardian.id };
}

/** Mavjud o'quvchiga ikkinchi vasiy (masalan, otasi). */
export async function addGuardian(prisma: PrismaClient, schoolId: string, studentId: string, userId?: string) {
  return prisma.schoolGuardian.create({
    data: {
      schoolId,
      fullName: 'Aliyev Bobur',
      phone: '+998 91 000 00 00',
      relation: 'FATHER',
      linkStatus: userId ? 'LINKED' : 'NOT_INVITED',
      userId: userId ?? null,
      students: { create: { studentId } },
    },
  });
}

export async function addPayment(
  prisma: PrismaClient,
  schoolId: string,
  family: Family,
  nextDate: string,
  extra: { prepaidMonths?: number; paused?: boolean } = {},
) {
  return prisma.schoolPaymentReminder.create({
    data: {
      schoolId,
      guardianId: family.guardianId,
      studentIds: [family.studentId],
      nextDate,
      prepaidMonths: extra.prepaidMonths ?? 0,
      paused: extra.paused ?? false,
      history: [{ at: '2026-09-01T05:00:00.000Z', byStaffId: 'seed', action: 'CREATED', note: 'Boshlang\'ich' }],
    },
  });
}

/** Maktab paneli so'rovi (`/api/school` + url). */
export function schoolCall(app: NestFastifyApplication) {
  return (s: LoggedIn, method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE', url: string, payload?: object) =>
    app.inject({
      method,
      url: `/api/school${url}`,
      headers: { authorization: `Bearer ${s.token}` },
      ...(payload && { payload }),
    });
}

/** Ota-ona ilovasi so'rovi (`/api/parent/school` + url). */
export function parentCall(app: NestFastifyApplication) {
  return (token: string, method: 'GET' | 'POST', url: string, payload?: object) =>
    app.inject({
      method,
      url: `/api/parent/school${url}`,
      headers: { authorization: `Bearer ${token}` },
      ...(payload && { payload }),
    });
}

/** Toshkent devor soati bo'yicha kelajakdagi vaqt ("YYYY-MM-DDTHH:MM"). */
export function localInFuture(minutes: number, from = new Date()): string {
  return new Date(from.getTime() + minutes * 60_000 + 5 * 3_600_000).toISOString().slice(0, 16);
}
