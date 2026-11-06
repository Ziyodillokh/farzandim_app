import { beforeEach, describe, expect, it } from 'vitest';

import type { AssignInput } from '@/data/schemas/assessments';
import { getTables, transact } from '../db';
import { targetStudents } from '../psych/sim';
import { assessmentsService } from '../services/assessments';
import { freshDb, loginAs } from './helpers';

const TEST_ID = 'tpl-logic';

function windowInput(extra: Partial<AssignInput> & Pick<AssignInput, 'target'>): AssignInput {
  return { testId: TEST_ID, opensAt: '2026-10-12T08:00', closesAt: '2026-10-19T18:00', consent: true, ...extra };
}

/** `tpl-logic` parallellariga mos o'quvchilar. */
function eligibleStudents(count: number) {
  const t = getTables();
  const grades = new Set<number>([5, 6, 7, 8, 9, 10, 11]);
  const classGrade = new Map(t.classes.map((c) => [c.id, c.grade]));
  return t.students.filter((s) => !s.archived && grades.has(classGrade.get(s.classId) ?? 0)).slice(0, count);
}

describe('shaxsiy tayinlash (kontrakt D) — mock', () => {
  beforeEach(() => {
    freshDb();
    loginAs('PSYCHOLOGIST');
  });

  it('tanlangan o\'quvchilarga tayinlanadi: invited = soni, sinflar — ularning sinflari, maqsad STUDENTS', async () => {
    const students = eligibleStudents(3);
    const a = await assessmentsService.assign(windowInput({ target: { kind: 'STUDENTS', studentIds: students.map((s) => s.id) } }));
    expect(a.target).toEqual({ kind: 'STUDENTS', studentIds: students.map((s) => s.id) });
    expect(a.invited).toBe(3);
    expect(new Set(a.classIds)).toEqual(new Set(students.map((s) => s.classId)));
    expect(a.careRequestId).toBeUndefined();
    const row = (await assessmentsService.listAssignments()).find((r) => r.id === a.id);
    expect(row).toMatchObject({ state: expect.any(String), invited: 3, completed: 0 });
  });

  it('faqat tanlangan o\'quvchilar nishon (sinfdoshlari emas); takrorlangan ID bir marta', async () => {
    const [first, second] = eligibleStudents(2);
    const a = await assessmentsService.assign(windowInput({ target: { kind: 'STUDENTS', studentIds: [first!.id, first!.id] } }));
    expect(a.invited).toBe(1);
    const target = targetStudents(getTables(), a).map((x) => x.student.id);
    expect(target).toEqual([first!.id]);
    expect(target).not.toContain(second!.id);
  });

  it('natijalar: ishtirok — faqat tanlanganlar, butun sinf emas; demo simulyatsiya faqat ularga', async () => {
    const [student] = eligibleStudents(1);
    const a = await assessmentsService.assign(windowInput({ target: { kind: 'STUDENTS', studentIds: [student!.id] }, opensAt: '2026-10-12T08:00' }));
    const sim = await assessmentsService.simulateCompletion(a.id, 1);
    expect(sim.created).toBe(1);
    const results = await assessmentsService.resultsByTest(TEST_ID, { assignmentId: a.id });
    expect(results.participation).toEqual({ invited: 1, completed: 1 });
    expect(results.rows.map((r) => r.studentId)).toEqual([student!.id]);
  });

  it('murojaatdan boshlangan: careRequestId saqlanadi; mavjud bo\'lmagan murojaat — NOT_FOUND', async () => {
    const [student] = eligibleStudents(1);
    const a = await assessmentsService.assign(windowInput({ target: { kind: 'STUDENTS', studentIds: [student!.id] }, careRequestId: 'care-3' }));
    expect(a.careRequestId).toBe('care-3');
    await expect(
      assessmentsService.assign(windowInput({ target: { kind: 'STUDENTS', studentIds: [student!.id] }, careRequestId: 'care-yoq' })),
    ).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('auditda o\'quvchi ismi, ID va murojaat ID\'si YO\'Q (variant: personal)', async () => {
    const [student] = eligibleStudents(1);
    await assessmentsService.assign(windowInput({ target: { kind: 'STUDENTS', studentIds: [student!.id] }, careRequestId: 'care-3' }));
    const entry = getTables().audit.filter((x) => x.action === 'assessments.assign').at(-1);
    expect(entry?.params).toMatchObject({ count: 1, variant: 'personal' });
    const json = JSON.stringify(entry);
    for (const secret of [student!.id, student!.lastName, student!.firstName, 'care-3']) expect(json.includes(secret)).toBe(false);
  });

  it('chegaralar: 1..30; 31 ta, bo\'sh ro\'yxat — VALIDATION', async () => {
    const many = eligibleStudents(31).map((s) => s.id);
    expect(many).toHaveLength(31);
    await expect(assessmentsService.assign(windowInput({ target: { kind: 'STUDENTS', studentIds: many } }))).rejects.toMatchObject({
      code: 'VALIDATION',
      message: expect.stringContaining('assessments.validation.tooManyStudents'),
    });
    await expect(assessmentsService.assign(windowInput({ target: { kind: 'STUDENTS', studentIds: [] } }))).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(assessmentsService.assign(windowInput({ target: { kind: 'STUDENTS', studentIds: many.slice(0, 30) } }))).resolves.toMatchObject({ invited: 30 });
  });

  it('rozilik majburiy: consent yo\'q — VALIDATION', async () => {
    const [student] = eligibleStudents(1);
    const input = { ...windowInput({ target: { kind: 'STUDENTS', studentIds: [student!.id] } }), consent: false } as unknown as AssignInput;
    await expect(assessmentsService.assign(input)).rejects.toMatchObject({ code: 'VALIDATION', message: expect.stringContaining('assessments.validation.consent') });
  });

  it('noma\'lum, arxivlangan o\'quvchi yoki test parallellariga mos kelmagan sinf — rad etiladi', async () => {
    const [student] = eligibleStudents(1);
    await expect(assessmentsService.assign(windowInput({ target: { kind: 'STUDENTS', studentIds: ['stu-yoq'] } }))).rejects.toMatchObject({
      message: 'target: assessments.validation.studentsInvalid',
    });
    transact((t) => {
      t.students = t.students.map((s) => (s.id === student!.id ? { ...s, archived: true } : s));
    });
    await expect(assessmentsService.assign(windowInput({ target: { kind: 'STUDENTS', studentIds: [student!.id] } }))).rejects.toMatchObject({
      message: 'target: assessments.validation.studentsInvalid',
    });
    const t = getTables();
    const tooYoung = t.students.find((s) => (t.classes.find((c) => c.id === s.classId)?.grade ?? 0) <= 2);
    await expect(assessmentsService.assign(windowInput({ target: { kind: 'STUDENTS', studentIds: [tooYoung!.id] } }))).rejects.toMatchObject({
      message: 'target: assessments.validation.studentGrade',
    });
  });

  it('faqat psixolog tayinlaydi (assessments.manage)', async () => {
    const [student] = eligibleStudents(1);
    for (const role of ['DIRECTOR', 'ADMIN', 'HOMEROOM'] as const) {
      loginAs(role);
      await expect(assessmentsService.assign(windowInput({ target: { kind: 'STUDENTS', studentIds: [student!.id] } }))).rejects.toMatchObject({ code: 'FORBIDDEN' });
    }
  });

  it('sinf/parallel tayinlash avvalgidek ishlaydi (regressiya)', async () => {
    const a = await assessmentsService.assign(windowInput({ target: { kind: 'CLASSES', classIds: ['cls-7a'] } }));
    expect(a.target).toEqual({ kind: 'CLASSES', classIds: ['cls-7a'] });
    expect(a.invited).toBeGreaterThan(20);
  });
});
