// Psixologik testlar e2e fixture'lari: maktab, sinflar, rollar, bola ilovasiga
// ulangan o'quvchilar, namunaviy test va so'rov yordamchilari.

import type { SchoolStaffRole } from '@prisma/client';
import type { LightMyRequestResponse } from 'fastify';
import { SchoolTokensService } from '../../src/school/auth/school-tokens.service';
import { createChild, createParent, TestChild } from './factories';
import { createSchool } from './school-fixtures';
import { createClass, createStudent } from './school-students-fixtures';
import type { TestApp } from './test-app';

export const L = (s: string) => ({ uz: s, ru: `${s} (ru)` });

/** Panel `assessments-fixtures.ts` `sampleInput` bilan bir xil (4 ta SINGLE savol, 5–8-sinflar). */
export function sampleInput(overrides: Record<string, unknown> = {}) {
  return {
    title: L('Sinov testi'),
    description: L('Tavsif'),
    instructions: L('Ko\'rsatma'),
    kind: 'CUSTOM',
    grades: [5, 6, 7, 8],
    timeLimitMin: 10,
    scales: [{ key: 'total', label: L('Umumiy'), domain: 'REASONING', polarity: 'HIGHER_BETTER', display: 'STANDARD' }],
    items: [1, 2, 3, 4].map((n) => ({
      id: `q${n}`,
      type: 'SINGLE',
      scale: 'total',
      text: L(`Savol ${n}`),
      options: [
        { key: 'a', text: L('A') },
        { key: 'b', text: L('B') },
      ],
      correct: n % 2 ? 'a' : 'b',
    })),
    scoring: { method: 'SUM' },
    norms: { total: [{ band: 'A13_14', mean: 2, sd: 1 }] },
    ...overrides,
  };
}

const pad = (n: number) => String(n).padStart(2, '0');

/** Lahza → panel `datetime-local` qiymati (Toshkent devor soati, "YYYY-MM-DDTHH:MM"). */
export function localInput(at: Date): string {
  const t = new Date(at.getTime() + 5 * 3_600_000);
  return `${t.getUTCFullYear()}-${pad(t.getUTCMonth() + 1)}-${pad(t.getUTCDate())}T${pad(t.getUTCHours())}:${pad(t.getUTCMinutes())}`;
}

/** Hozir ochiq oyna (1 soat oldin — 7 kun keyin). */
export function openWindow(now = Date.now()) {
  return { opensAt: localInput(new Date(now - 3_600_000)), closesAt: localInput(new Date(now + 7 * 86_400_000)) };
}

export type Kid = TestChild & { studentId: string; studentCode: string };

/** Xodim sessiyasi — login throttle'siz (sessiya + access token to'g'ridan-to'g'ri, guard to'liq tekshiradi). */
export type Staff = { token: string; staffId: string };

export async function sessionFor(t: TestApp, staffId: string): Promise<Staff> {
  const staff = await t.prisma.schoolStaff.findUniqueOrThrow({ where: { id: staffId } });
  const session = await t.prisma.schoolStaffSession.create({
    data: { schoolId: staff.schoolId, staffId, tokenHash: `e2e-assess-${staffId}-${Date.now()}`, expiresAt: new Date(Date.now() + 3_600_000) },
  });
  const token = t.app.get(SchoolTokensService).signAccess({ sub: staffId, sch: staff.schoolId, sid: session.id, tv: staff.tokenVersion });
  return { token, staffId };
}

/** Xodim (parolsiz — testlar login qilmaydi, bcrypt sekin) va uning sessiyasi. */
export async function staffWith(t: TestApp, schoolId: string, role: SchoolStaffRole, username: string, classIds: string[] = []): Promise<Staff> {
  const staff = await t.prisma.schoolStaff.create({
    data: { schoolId, fullName: `${role} xodim`, role, username, classes: { create: classIds.map((classId) => ({ classId })) } },
  });
  return sessionFor(t, staff.id);
}

export interface AssessWorld {
  schoolId: string;
  classes: { c7a: string; c7b: string; c5a: string };
  psych: Staff;
  director: Staff;
  admin: Staff;
  homeroom: Staff;
  duty: Staff;
  teacher: Staff;
  kids7a: Kid[];
  kids7b: Kid[];
}

/** O'quvchilar 2013-05-14 da tug'ilgan (13 yosh → A13_14) — namunaviy me'yor shu band uchun. */
export async function enroll(t: TestApp, schoolId: string, classId: string, n: number, language = 'uz', prefix = 'Bola'): Promise<Kid[]> {
  const parent = await createParent(t.prisma);
  const kids: Kid[] = [];
  for (let i = 0; i < n; i++) {
    const kid = await createChild(t.prisma, parent, { name: `${prefix} ${i}` });
    await t.prisma.user.update({ where: { id: kid.userId }, data: { language } });
    const s = await createStudent(t.prisma, schoolId, classId, { lastName: `${prefix}ov`, firstName: `${prefix}${i}`, childId: kid.childId });
    kids.push({ ...kid, studentId: s.id, studentCode: s.studentCode });
  }
  return kids;
}

export async function buildWorld(t: TestApp, code = 'test-school'): Promise<AssessWorld> {
  const { school, director } = await createSchool(t.prisma, code);
  const schoolId = school.id;
  const c7a = (await createClass(t.prisma, schoolId, 7, 'A')).id;
  const c7b = (await createClass(t.prisma, schoolId, 7, 'B')).id;
  const c5a = (await createClass(t.prisma, schoolId, 5, 'A')).id;
  return {
    schoolId,
    classes: { c7a, c7b, c5a },
    psych: await staffWith(t, schoolId, 'PSYCHOLOGIST', `psixolog-${code}`),
    director: await sessionFor(t, director.id),
    admin: await staffWith(t, schoolId, 'ADMIN', `admin-${code}`),
    homeroom: await staffWith(t, schoolId, 'HOMEROOM', `rahbar-${code}`, [c7a]),
    duty: await staffWith(t, schoolId, 'DUTY', `navbatchi-${code}`),
    teacher: await staffWith(t, schoolId, 'TEACHER', `oqituvchi-${code}`, [c7a]),
    kids7a: await enroll(t, schoolId, c7a, 3, 'uz', 'Alfa'),
    kids7b: await enroll(t, schoolId, c7b, 2, 'ru', 'Beta'),
  };
}

type Method = 'GET' | 'POST' | 'PUT' | 'DELETE';

export function staffApi(t: TestApp) {
  return (who: Staff, method: Method, url: string, payload?: unknown): Promise<LightMyRequestResponse> =>
    t.app.inject({ method, url: `/api/school/assessments${url}`, payload: payload as object, headers: { authorization: `Bearer ${who.token}` } });
}

export function childApi(t: TestApp) {
  return (kid: TestChild, method: 'GET' | 'POST', url: string, payload?: unknown): Promise<LightMyRequestResponse> =>
    t.app.inject({ method, url: `/api/child/school/assessments${url}`, payload: payload as object, headers: { authorization: `Bearer ${kid.token}` } });
}

/** Psixolog: namunaviy test yaratib nashr qiladi va berilgan sinflarga hozir ochiq tayinlaydi. */
export async function publishedAssignment(t: TestApp, w: AssessWorld, classIds: string[], input = sampleInput()) {
  const api = staffApi(t);
  const test = (await api(w.psych, 'POST', '/tests', input)).json();
  await api(w.psych, 'POST', `/tests/${test.id}/publish`);
  const res = await api(w.psych, 'POST', '/assignments', { testId: test.id, target: { kind: 'CLASSES', classIds }, ...openWindow(), consent: true });
  if (res.statusCode !== 201) throw new Error(`assign ${res.statusCode}: ${res.body}`);
  return { testId: test.id as string, assignment: res.json() as { id: string; invited: number; classIds: string[] } };
}
