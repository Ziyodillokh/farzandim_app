// O'quvchi kodi (K2) e2e fixture'lari: maktab (2 sinf, rollar), ulanmagan o'quvchilar, oilalar (ota-ona + bola) va
// HTTP yordamchilari. Barcha xodim sessiyalari login throttle'siz (to'g'ridan-to'g'ri sessiya + token).

import type { SchoolStaffRole, SchoolStudent } from '@prisma/client';
import { SCHOOL_ROLES, SchoolPermission } from '../../src/school/auth/permissions';
import { createChild, createParent, TestChild, TestParent } from './factories';
import { createSchool } from './school-fixtures';
import { Session, sessionFor, staffSession } from './school-attendance-fixtures';
import { appReq, schoolReq } from './school-child-fixtures';
import { createClass, createStudent } from './school-students-fixtures';
import { TestApp } from './test-app';
import { LinkAttemptLimiter } from '../../src/school/students/link-attempt-limiter';

export const SCHOOL_NAME = 'Test maktab';

export interface Family {
  parent: TestParent;
  child: TestChild;
}

export interface CodeWorld {
  schoolId: string;
  classA: string;
  classB: string;
  /** 7-A, ulanmagan. */
  aziz: SchoolStudent;
  /** 7-A, ulanmagan. */
  bobur: SchoolStudent;
  /** 7-B, ulanmagan. */
  sardor: SchoolStudent;
  director: Session;
  admin: Session;
  homeroomA: Session;
  homeroomB: Session;
  teacher: Session;
  duty: Session;
  psych: Session;
}

export async function buildCodeWorld(t: TestApp): Promise<CodeWorld> {
  const { school } = await createSchool(t.prisma);
  const classA = await createClass(t.prisma, school.id, 7, 'A');
  const classB = await createClass(t.prisma, school.id, 7, 'B');
  const aziz = await createStudent(t.prisma, school.id, classA.id, { lastName: 'Karimov', firstName: 'Aziz' });
  const bobur = await createStudent(t.prisma, school.id, classA.id, { lastName: 'Rahimov', firstName: 'Bobur' });
  const sardor = await createStudent(t.prisma, school.id, classB.id, { lastName: 'Yusupov', firstName: 'Sardor' });
  const director = await t.prisma.schoolStaff.findFirstOrThrow({ where: { schoolId: school.id, role: 'DIRECTOR' } });
  return {
    schoolId: school.id,
    classA: classA.id,
    classB: classB.id,
    aziz,
    bobur,
    sardor,
    director: await sessionFor(t, director.id),
    admin: await staffSession(t, school.id, 'ADMIN', 'admin'),
    homeroomA: await staffSession(t, school.id, 'HOMEROOM', 'rahbar-a', [classA.id]),
    homeroomB: await staffSession(t, school.id, 'HOMEROOM', 'rahbar-b', [classB.id]),
    teacher: await staffSession(t, school.id, 'TEACHER', 'oqituvchi', [classA.id]),
    duty: await staffSession(t, school.id, 'DUTY', 'navbatchi'),
    psych: await staffSession(t, school.id, 'PSYCHOLOGIST', 'psixolog'),
  };
}

let familySeq = 0;

/** Yangi oila: ota-ona (telefonsiz) va ulangan bola qurilmasi. */
export async function newFamily(t: TestApp, childName = 'Bola', parentName = 'Ota-ona'): Promise<Family> {
  familySeq += 1;
  const parent = await createParent(t.prisma, { name: `${parentName} ${familySeq}` });
  const child = await createChild(t.prisma, parent, { name: childName });
  return { parent, child };
}

/** Bir xil IP (inject) uchun xotiradagi urinish limitini tozalash. */
export function resetLinkLimits(t: TestApp): void {
  t.app.get(LinkAttemptLimiter).reset();
}

// ─── HTTP ───────────────────────────────────────────────────────────

export const generateCode = (t: TestApp, s: Session, studentId: string) =>
  schoolReq(t, s, 'POST', `/students/${studentId}/invite-code`);

export const currentCode = (t: TestApp, s: Session, studentId: string) =>
  schoolReq(t, s, 'GET', `/students/${studentId}/invite-code`);

/** Kod yaratadi va 6 raqamni qaytaradi. */
export async function issueCode(t: TestApp, s: Session, studentId: string): Promise<string> {
  const res = await generateCode(t, s, studentId);
  if (res.statusCode !== 201) throw new Error(`generateCode ${res.statusCode}: ${res.body}`);
  return res.json().code as string;
}

export const childLink = (t: TestApp, kid: TestChild, code: string) =>
  appReq(t, kid.token, 'POST', '/child/school/link', { code });

export const linkStatus = (t: TestApp, kid: TestChild) => appReq(t, kid.token, 'GET', '/child/school/link-status');

export const parentLink = (t: TestApp, p: TestParent, code: string) =>
  appReq(t, p.token, 'POST', '/parent/school/link', { code });

export const requests = (t: TestApp, s: Session) => schoolReq(t, s, 'GET', '/link-requests');

export const confirm = (t: TestApp, s: Session, id: string) => schoolReq(t, s, 'POST', `/link-requests/${id}/confirm`);

export const reject = (t: TestApp, s: Session, id: string) => schoolReq(t, s, 'POST', `/link-requests/${id}/reject`);

export const feed = (t: TestApp, s: Session) => schoolReq(t, s, 'GET', '/notifications/feed');

export const timetable = (t: TestApp, kid: TestChild) => appReq(t, kid.token, 'GET', '/child/school/timetable');

let phoneSeq = 0;

/**
 * Maktab ISHONGAN ota-ona: foydalanuvchining haqiqiy telefoni bor va maktab kiritgan (hech kimga ulanmagan) vasiy
 * yozuvi shu telefonga ega — 6 raqamli kod darhol vasiy qiladi (aks holda xodim ko'rigi kerak). Vasiy yozuvini qaytaradi.
 */
export async function trustParent(t: TestApp, student: SchoolStudent, family: Family) {
  phoneSeq += 1;
  const local = String(900_000_000 + phoneSeq);
  await t.prisma.user.update({ where: { id: family.parent.userId }, data: { phone: `+998${local}` } });
  return t.prisma.schoolGuardian.create({
    data: {
      schoolId: student.schoolId,
      fullName: `Maktab kiritgan ota-ona ${phoneSeq}`,
      phone: `+998 ${local.slice(0, 2)} ${local.slice(2, 5)} ${local.slice(5, 7)} ${local.slice(7, 9)}`,
      relation: 'MOTHER',
      students: { create: { studentId: student.id } },
    },
  });
}

/** Bola kodni kiritadi va (ishonchli) ota-onasi ham (har ikki o'rin) — bog'lanish darhol CONFIRMED. */
export async function confirmedLink(t: TestApp, s: Session, student: SchoolStudent, family: Family) {
  await trustParent(t, student, family);
  const code = await issueCode(t, s, student.id);
  const parent = await parentLink(t, family.parent, code);
  if (parent.statusCode !== 200) throw new Error(`parentLink ${parent.statusCode}: ${parent.body}`);
  const child = await childLink(t, family.child, code);
  if (child.statusCode !== 200) throw new Error(`childLink ${child.statusCode}: ${child.body}`);
  return code;
}

/**
 * Rol ruxsatlari jadvalidan (`SCHOOL_ROLES`, ilova bilan bir jarayon) ruxsatni vaqtincha olib tashlaydi; qaytarish
 * funksiyasi `finally` da chaqiriladi. "Ruxsatsiz sinf rahbari" kabi holatlarni haqiqiy endpointlar orqali sinash uchun.
 */
export function withoutPermission(roles: SchoolStaffRole[], permission: SchoolPermission = 'guardians.link'): () => void {
  const saved = roles.map((role) => [role, SCHOOL_ROLES[role].permissions] as const);
  for (const role of roles) SCHOOL_ROLES[role].permissions = SCHOOL_ROLES[role].permissions.filter((p) => p !== permission);
  return () => {
    for (const [role, permissions] of saved) SCHOOL_ROLES[role].permissions = permissions;
  };
}
