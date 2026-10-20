// Davomat e2e fixture'lari: maktab (2 sinf, barcha rollar), o'quvchilar,
// Parvoz Parents'ga ulangan ota-ona va Parvoz Growth bolasi, boshqariladigan soat.

import type { SchoolStaffRole } from '@prisma/client';
import { AttendanceClock } from '../../src/school/attendance/attendance-time';
import { SchoolTokensService } from '../../src/school/auth/school-tokens.service';
import { createChild, createParent, TestChild, TestParent } from './factories';
import { createSchool, createStaff } from './school-fixtures';
import { TestApp } from './test-app';

/** Xodim sessiyasi (login throttle'siz — sessiya + access token to'g'ridan-to'g'ri). */
export interface Session {
  token: string;
  staffId: string;
}

type Method = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

/** Toshkent mahalliy vaqti → lahza (`at('2026-10-20', '08:05')`). */
export const at = (day: string, hhmm: string) => new Date(`${day}T${hhmm}:00+05:00`);

/** Seshanba (o'quv kuni, default smena dushanba–shanba). */
export const DAY = '2026-10-20';

/** Davomat servislari soatini qotirish (auth/token muddati — haqiqiy soat). */
export function setNow(t: TestApp, now: Date): void {
  const clock = t.app.get(AttendanceClock);
  clock.now = () => new Date(now.getTime());
}

export function staffCall(t: TestApp, s: Session, method: Method, url: string, payload?: object) {
  return t.app.inject({
    method,
    url: `/api/school/attendance${url}`,
    headers: { authorization: `Bearer ${s.token}` },
    ...(payload && { payload }),
  });
}

export function consumerCall(t: TestApp, token: string, method: Method, url: string, payload?: object) {
  return t.app.inject({
    method,
    url: `/api${url}`,
    headers: { authorization: `Bearer ${token}` },
    ...(payload && { payload }),
  });
}

export interface World {
  schoolId: string;
  shiftId: string;
  classA: string;
  classB: string;
  /** 7-A: ota-onasi ulangan, Parvoz bolasi bog'langan. */
  vali: string;
  /** 7-A: ota-onasi ilovada yo'q. */
  malika: string;
  /** 8-B. */
  bek: string;
  parent: TestParent;
  child: TestChild;
  guardianId: string;
  director: Session;
  admin: Session;
  homeroom: Session;
  duty: Session;
  teacher: Session;
  psych: Session;
}

let codeSeq = 0;

export async function addStudent(
  t: TestApp,
  schoolId: string,
  classId: string | null,
  lastName: string,
  firstName: string,
) {
  codeSeq += 1;
  return t.prisma.schoolStudent.create({
    data: {
      schoolId,
      classId,
      lastName,
      firstName,
      gender: 'MALE',
      birthDate: '2013-05-01',
      device: 'IOS',
      studentCode: `P-${1000 + codeSeq}`,
      enrolledAt: '2026-09-02',
    },
  });
}

/** Ota-ona (Parvoz Parents foydalanuvchisi) — o'quvchiga LINKED guardian sifatida. */
export async function linkGuardian(t: TestApp, schoolId: string, studentId: string, parent: TestParent) {
  return t.prisma.schoolGuardian.create({
    data: {
      schoolId,
      fullName: 'Aliyeva Nodira',
      phone: '+998 90 123 45 67',
      relation: 'MOTHER',
      linkStatus: 'LINKED',
      linkedAt: new Date(),
      userId: parent.userId,
      students: { create: { studentId } },
    },
  });
}

/** Xodim uchun sessiya va access token (haqiqiy guard tekshiruvidan o'tadi). */
export async function sessionFor(t: TestApp, staffId: string): Promise<Session> {
  const staff = await t.prisma.schoolStaff.findUniqueOrThrow({ where: { id: staffId } });
  const session = await t.prisma.schoolStaffSession.create({
    data: {
      schoolId: staff.schoolId,
      staffId,
      tokenHash: `e2e-${staffId}-${Date.now()}`,
      expiresAt: new Date(Date.now() + 3_600_000),
    },
  });
  const token = t.app
    .get(SchoolTokensService)
    .signAccess({ sub: staffId, sch: staff.schoolId, sid: session.id, tv: staff.tokenVersion });
  return { token, staffId };
}

export async function staffSession(
  t: TestApp,
  schoolId: string,
  role: SchoolStaffRole,
  username: string,
  classIds: string[] = [],
): Promise<Session> {
  const staff = await createStaff(t.prisma, schoolId, role, username, classIds);
  return sessionFor(t, staff.id);
}

export async function seedWorld(t: TestApp, code = 'test-school'): Promise<World> {
  const { school, director } = await createSchool(t.prisma, code);
  const shift = await t.prisma.schoolShift.findFirstOrThrow({ where: { schoolId: school.id } });
  const mk = (grade: number, letter: string) =>
    t.prisma.schoolClass.create({
      data: { schoolId: school.id, grade, letter, name: `${grade}-${letter}`, shiftId: shift.id },
    });
  const classA = await mk(7, 'A');
  const classB = await mk(8, 'B');
  const vali = await addStudent(t, school.id, classA.id, 'Aliyev', 'Vali');
  const malika = await addStudent(t, school.id, classA.id, 'Karimova', 'Malika');
  const bek = await addStudent(t, school.id, classB.id, 'Rasulov', 'Bek');
  const parent = await createParent(t.prisma);
  const child = await createChild(t.prisma, parent, { name: 'Vali' });
  await t.prisma.schoolStudent.update({ where: { id: vali.id }, data: { childId: child.childId } });
  const guardian = await linkGuardian(t, school.id, vali.id, parent);
  await t.prisma.schoolGuardian.create({
    data: {
      schoolId: school.id,
      fullName: 'Karimov Anvar',
      phone: '+998 90 765 43 21',
      relation: 'FATHER',
      students: { create: { studentId: malika.id } },
    },
  });
  return {
    schoolId: school.id,
    shiftId: shift.id,
    classA: classA.id,
    classB: classB.id,
    vali: vali.id,
    malika: malika.id,
    bek: bek.id,
    parent,
    child,
    guardianId: guardian.id,
    director: await sessionFor(t, director.id),
    admin: await staffSession(t, school.id, 'ADMIN', 'admin'),
    homeroom: await staffSession(t, school.id, 'HOMEROOM', 'homeroom', [classA.id]),
    duty: await staffSession(t, school.id, 'DUTY', 'duty'),
    teacher: await staffSession(t, school.id, 'TEACHER', 'teacher', [classB.id]),
    psych: await staffSession(t, school.id, 'PSYCHOLOGIST', 'psych'),
  };
}
