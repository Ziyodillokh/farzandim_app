// O'quvchilar e2e fixture'lari: sinf, o'quvchi, ota-ona (to'g'ridan-to'g'ri Prisma).

import type { GuardianLinkStatus, PrismaClient, SchoolDeviceOs } from '@prisma/client';
import { randomInt } from 'node:crypto';

export async function createClass(prisma: PrismaClient, schoolId: string, grade: number, letter: string) {
  const shift = await prisma.schoolShift.findFirstOrThrow({ where: { schoolId } });
  return prisma.schoolClass.create({
    data: { schoolId, grade, letter, name: `${grade}-${letter}`, shiftId: shift.id },
  });
}

export async function createStudent(
  prisma: PrismaClient,
  schoolId: string,
  classId: string,
  overrides: { lastName?: string; firstName?: string; birthDate?: string; device?: SchoolDeviceOs; childId?: string } = {},
) {
  return prisma.schoolStudent.create({
    data: {
      schoolId,
      classId,
      lastName: overrides.lastName ?? 'Karimov',
      firstName: overrides.firstName ?? 'Aziz',
      gender: 'MALE',
      birthDate: overrides.birthDate ?? '2013-05-14',
      device: overrides.device ?? 'ANDROID',
      studentCode: `P-${randomInt(1000, 9999)}-${randomInt(100)}`,
      enrolledAt: '2026-09-02',
      childId: overrides.childId,
    },
  });
}

export async function createGuardian(
  prisma: PrismaClient,
  schoolId: string,
  studentIds: string[],
  overrides: { fullName?: string; linkStatus?: GuardianLinkStatus; userId?: string; inviteCode?: string; inviteExpiresAt?: Date } = {},
) {
  return prisma.schoolGuardian.create({
    data: {
      schoolId,
      fullName: overrides.fullName ?? 'Karimova Malika',
      phone: '+998 90 123 45 67',
      relation: 'MOTHER',
      linkStatus: overrides.linkStatus ?? 'NOT_INVITED',
      userId: overrides.userId,
      inviteCode: overrides.inviteCode,
      inviteExpiresAt: overrides.inviteExpiresAt,
      linkedAt: overrides.linkStatus === 'LINKED' ? new Date() : null,
      students: { create: studentIds.map((studentId) => ({ studentId })) },
    },
  });
}
