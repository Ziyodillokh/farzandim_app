// Maktab e2e fixture'lari: maktab + direktor (+ boshqa rollar), kirish.

import type { NestFastifyApplication } from '@nestjs/platform-fastify';
import type { PrismaClient, SchoolStaffRole } from '@prisma/client';
import { hashStaffPassword } from '../../src/school/auth/school-auth.service';
import { createSchoolWithDirector } from '../../src/school/common/school-bootstrap';

export const PASSWORD = 'Parvoz-School-2026';

export async function createSchool(prisma: PrismaClient, code = 'test-school') {
  const { school, director } = await createSchoolWithDirector(prisma, {
    code,
    name: 'Test maktab',
    director: { fullName: 'Karimov Akmal', username: 'direktor', password: PASSWORD },
  });
  await prisma.schoolStaff.update({ where: { id: director.id }, data: { mustChangePassword: false } });
  return { school, director };
}

export async function createStaff(
  prisma: PrismaClient,
  schoolId: string,
  role: SchoolStaffRole,
  username: string,
  classIds: string[] = [],
) {
  return prisma.schoolStaff.create({
    data: {
      schoolId,
      fullName: `${role} xodim`,
      role,
      username,
      passwordHash: await hashStaffPassword(PASSWORD),
      classes: { create: classIds.map((classId) => ({ classId })) },
    },
  });
}

export interface LoggedIn {
  token: string;
  cookie: string;
  me: { staff: { id: string }; permissions: string[]; classIds: string[] };
}

export async function login(
  app: NestFastifyApplication,
  username: string,
  school = 'test-school',
  password = PASSWORD,
): Promise<LoggedIn> {
  const res = await app.inject({
    method: 'POST',
    url: '/api/school/auth/login',
    payload: { school, username, password },
  });
  if (res.statusCode !== 200) throw new Error(`login ${res.statusCode}: ${res.body}`);
  const cookie = res.cookies.find((c) => c.name === 'parvoz_school_rt');
  return { token: res.json().accessToken, cookie: `parvoz_school_rt=${cookie?.value}`, me: res.json().me };
}
