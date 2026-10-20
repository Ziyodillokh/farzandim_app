// Yangi maktab + direktor hisobi (CLI va testlar umumiy ishlatadi).

import { PrismaClient } from '@prisma/client';
import { randomBytes } from 'node:crypto';
import { hashStaffPassword } from '../auth/school-auth.service';

export interface NewSchoolInput {
  code: string;
  name: string;
  shortName?: string;
  city?: string;
  academicYear?: string;
  director: { fullName: string; username: string; password: string };
}

/** Standart 1-smena: 08:00–13:25, 6 dars, dushanba–shanba. */
export const DEFAULT_SHIFT = {
  name: '1-smena',
  start: '08:00',
  end: '13:25',
  weekdays: [1, 2, 3, 4, 5, 6],
  periods: [
    { no: 1, start: '08:00', end: '08:45', kind: 'LESSON' },
    { no: 1, start: '08:45', end: '08:55', kind: 'BREAK' },
    { no: 2, start: '08:55', end: '09:40', kind: 'LESSON' },
    { no: 2, start: '09:40', end: '09:50', kind: 'BREAK' },
    { no: 3, start: '09:50', end: '10:35', kind: 'LESSON' },
    { no: 3, start: '10:35', end: '10:55', kind: 'BREAK' },
    { no: 4, start: '10:55', end: '11:40', kind: 'LESSON' },
    { no: 4, start: '11:40', end: '11:50', kind: 'BREAK' },
    { no: 5, start: '11:50', end: '12:35', kind: 'LESSON' },
    { no: 5, start: '12:35', end: '12:40', kind: 'BREAK' },
    { no: 6, start: '12:40', end: '13:25', kind: 'LESSON' },
  ],
};

export function defaultAcademicYear(now = new Date()): string {
  const year = now.getUTCMonth() >= 7 ? now.getUTCFullYear() : now.getUTCFullYear() - 1;
  return `${year}–${year + 1}`;
}

export async function createSchoolWithDirector(prisma: PrismaClient, input: NewSchoolInput) {
  const code = input.code.trim().toLowerCase();
  if (!/^[a-z0-9-]{2,40}$/.test(code)) throw new Error('code: a-z, 0-9, "-" (2–40)');
  return prisma.$transaction(async (tx) => {
    const school = await tx.school.create({
      data: {
        code,
        name: input.name,
        shortName: input.shortName ?? input.name.slice(0, 12),
        city: input.city ?? '',
        academicYear: input.academicYear ?? defaultAcademicYear(),
        kioskSecret: randomBytes(32).toString('base64url'),
      },
    });
    await tx.schoolShift.create({ data: { schoolId: school.id, ...DEFAULT_SHIFT } });
    const director = await tx.schoolStaff.create({
      data: {
        schoolId: school.id,
        fullName: input.director.fullName,
        position: 'Direktor',
        role: 'DIRECTOR',
        username: input.director.username.trim().toLowerCase(),
        passwordHash: await hashStaffPassword(input.director.password),
        mustChangePassword: true,
      },
    });
    return { school, director };
  });
}
