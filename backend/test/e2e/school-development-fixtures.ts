// Rivojlanish e2e fixture'lari: maktab (7-A — 6 ta Parvoz'ga ulangan bola, 7-B — 6,
// 8-A — 3 ta kichik sinf), barcha rollar, natijalar partiyalari (yopilgan / ochiq
// tayinlash yoki CSV import) to'g'ridan-to'g'ri bazaga — o'tgan choraklar uchun ham.

import type { LightMyRequestResponse } from 'fastify';
import { SchoolCryptoService } from '../../src/school/common/school-crypto.service';
import { enroll, Kid, sessionFor, Staff, staffWith } from './school-assessments-fixtures';
import { createSchool } from './school-fixtures';
import { createClass, createStudent } from './school-students-fixtures';
import type { TestApp } from './test-app';

export type Pupil = { id: string; classId: string; grade: number; name: string };

export interface DevWorld {
  schoolId: string;
  classes: { c7a: string; c7b: string; c8a: string };
  psych: Staff;
  director: Staff;
  admin: Staff;
  homeroom: Staff;
  duty: Staff;
  teacher: Staff;
  kids7a: Kid[];
  pupils7a: Pupil[];
  pupils7b: Pupil[];
  pupils8a: Pupil[];
}

async function pupils(t: TestApp, schoolId: string, classId: string, grade: number, n: number, prefix: string): Promise<Pupil[]> {
  const out: Pupil[] = [];
  for (let i = 0; i < n; i++) {
    const s = await createStudent(t.prisma, schoolId, classId, { lastName: `${prefix}ova`, firstName: `${prefix}${i}` });
    out.push({ id: s.id, classId, grade, name: `${prefix}ova ${prefix}${i}` });
  }
  return out;
}

export async function buildDevWorld(t: TestApp, code = 'test-school'): Promise<DevWorld> {
  const { school, director } = await createSchool(t.prisma, code);
  const schoolId = school.id;
  const c7a = (await createClass(t.prisma, schoolId, 7, 'A')).id;
  const c7b = (await createClass(t.prisma, schoolId, 7, 'B')).id;
  const c8a = (await createClass(t.prisma, schoolId, 8, 'A')).id;
  const kids7a = await enroll(t, schoolId, c7a, 6, 'uz', 'Alfa');
  return {
    schoolId,
    classes: { c7a, c7b, c8a },
    psych: await staffWith(t, schoolId, 'PSYCHOLOGIST', `psixolog-${code}`),
    director: await sessionFor(t, director.id),
    admin: await staffWith(t, schoolId, 'ADMIN', `admin-${code}`),
    homeroom: await staffWith(t, schoolId, 'HOMEROOM', `rahbar-${code}`, [c7a]),
    duty: await staffWith(t, schoolId, 'DUTY', `navbatchi-${code}`),
    teacher: await staffWith(t, schoolId, 'TEACHER', `oqituvchi-${code}`, [c7a]),
    kids7a,
    pupils7a: kids7a.map((k, i) => ({ id: k.studentId, classId: c7a, grade: 7, name: `Alfaov Alfa${i}` })),
    pupils7b: await pupils(t, schoolId, c7b, 7, 6, 'Beta'),
    pupils8a: await pupils(t, schoolId, c8a, 8, 3, 'Gamma'),
  };
}

export type BatchKind = 'CLOSED' | 'OPEN' | 'IMPORT';

/**
 * Bitta partiya natijalari: `raw(i)` — i-o'quvchining xom ballari. `CLOSED` / `OPEN` —
 * tayinlash yozuvi bilan; `IMPORT` — tayinlashsiz (bitta tranzaksiya, bir xil `createdAt`).
 * Javoblar shifrlangan holda saqlanadi ("0123…" — ixcham kod namunasi).
 */
export async function seedBatch(
  t: TestApp,
  w: DevWorld,
  opts: { testId: string; at: Date; pupils: readonly Pupil[]; raw: (i: number) => Record<string, number>; kind?: BatchKind },
): Promise<string | null> {
  const kind = opts.kind ?? 'CLOSED';
  const crypto = t.app.get(SchoolCryptoService);
  return t.prisma.$transaction(async (tx) => {
    const classIds = [...new Set(opts.pupils.map((p) => p.classId))];
    const assignment =
      kind === 'IMPORT'
        ? null
        : await tx.schoolPsychAssignment.create({
            data: {
              schoolId: w.schoolId,
              testId: opts.testId,
              testVersion: 1,
              target: { kind: 'CLASSES', classIds },
              classIds,
              opensAt: new Date(opts.at.getTime() - 86_400_000),
              closesAt: kind === 'OPEN' ? new Date(Date.now() + 7 * 86_400_000) : new Date(opts.at.getTime() + 3_600_000),
              status: kind === 'OPEN' ? 'OPEN' : 'CLOSED',
              invited: opts.pupils.length,
              createdBy: w.psych.staffId,
            },
          });
    await tx.schoolPsychResult.createMany({
      data: opts.pupils.map((p, i) => ({
        schoolId: w.schoolId,
        studentId: p.id,
        classId: p.classId,
        grade: p.grade,
        ageBand: 'A13_14',
        testId: opts.testId,
        version: 1,
        assignmentId: assignment?.id ?? null,
        takenAt: new Date(opts.at.getTime() + i * 1000),
        origin: kind === 'IMPORT' ? 'IMPORT' : 'APP',
        raw: opts.raw(i),
        answersEnc: kind === 'IMPORT' ? null : crypto.encrypt('0123'),
        durationSec: kind === 'IMPORT' ? null : 200 + i,
      })),
    });
    return assignment?.id ?? null;
  });
}

type Method = 'GET' | 'POST' | 'PUT';

export function devApi(t: TestApp) {
  return (who: Staff, url: string): Promise<LightMyRequestResponse> =>
    t.app.inject({ method: 'GET', url: `/api/school/development${url}`, headers: { authorization: `Bearer ${who.token}` } });
}

export function schoolApi(t: TestApp) {
  return (who: Staff, method: Method, url: string, payload?: unknown): Promise<LightMyRequestResponse> =>
    t.app.inject({ method, url: `/api/school${url}`, payload: payload as object, headers: { authorization: `Bearer ${who.token}` } });
}

export const DAY_MS = 86_400_000;
