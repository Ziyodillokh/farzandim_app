import { childAssignmentWhere, isAssignmentVisible, OVERDUE_VISIBLE_DAYS } from './assignment-visibility';
import {
  childrenWithPendingTomorrow,
  CompletedAttempt,
  handInKey,
  PendingInput,
  ReminderAssignment,
  ReminderStudent,
} from './homework-reminder';

const TODAY = '2026-11-06';
const TOMORROW = '2026-11-07';
const ASSIGNED_AT = new Date('2026-11-04T08:00:00Z');

const assignment = (over: Partial<ReminderAssignment> = {}): ReminderAssignment => ({
  id: 'a-1',
  schoolId: 's-1',
  classIds: ['c-5a'],
  materialKind: 'TEST',
  materialId: 'test:MATH',
  dueDate: TOMORROW,
  createdAt: ASSIGNED_AT,
  ...over,
});

const student = (over: Partial<ReminderStudent> = {}): ReminderStudent => ({
  studentId: 'st-1',
  childId: 'ch-1',
  schoolId: 's-1',
  classId: 'c-5a',
  ...over,
});

const run = (over: Partial<PendingInput>) =>
  childrenWithPendingTomorrow({
    today: TODAY,
    tomorrow: TOMORROW,
    assignments: [assignment()],
    students: [student()],
    handedIn: new Set(),
    attempts: [],
    ...over,
  });

const attempt = (over: Partial<CompletedAttempt> = {}): CompletedAttempt => ({
  childId: 'ch-1',
  subject: 'MATH',
  completedAt: new Date('2026-11-05T10:00:00Z'),
  ...over,
});

describe('childrenWithPendingTomorrow', () => {
  it('selects a child whose test assignment is due tomorrow and not done', () => {
    expect([...run({})]).toEqual(['ch-1']);
  });

  it('ignores assignments due today or on any other day', () => {
    const others = [assignment({ dueDate: TODAY }), assignment({ id: 'a-2', dueDate: '2026-11-08' }), assignment({ id: 'a-3', dueDate: '2026-11-05' })];

    expect(run({ assignments: others }).size).toBe(0);
  });

  describe('test assignments', () => {
    it('excludes a child who completed the subject test after the assignment was given', () => {
      expect(run({ attempts: [attempt()] }).size).toBe(0);
    });

    it('still reminds when the completed test predates the assignment', () => {
      const early = attempt({ completedAt: new Date('2026-11-03T10:00:00Z') });

      expect([...run({ attempts: [early] })]).toEqual(['ch-1']);
    });

    it('still reminds when the completed test is for another subject or another child', () => {
      const attempts = [attempt({ subject: 'ENGLISH' }), attempt({ childId: 'ch-2' })];

      expect([...run({ attempts })]).toEqual(['ch-1']);
    });

    it('treats a material whose completion cannot be tracked (audiobook) as not done', () => {
      const book = assignment({ materialKind: 'AUDIOBOOK', materialId: 'audiobook:abc' });

      expect([...run({ assignments: [book], attempts: [attempt()] })]).toEqual(['ch-1']);
    });
  });

  describe('written homework', () => {
    const written = assignment({ id: 'w-1', materialKind: 'WRITTEN', materialId: 'written' });

    it('excludes a submitted (waiting for review) homework', () => {
      expect(run({ assignments: [written], handedIn: new Set([handInKey('w-1', 'st-1')]) }).size).toBe(0);
    });

    it('excludes an accepted homework (accepted ones are in the same hand-in set as submitted)', () => {
      expect(run({ assignments: [written], handedIn: new Set([handInKey('w-1', 'st-1')]) }).size).toBe(0);
    });

    it('reminds when nothing was handed in or the homework was returned for redoing', () => {
      // RETURNED submissions are not part of the hand-in set (only SUBMITTED / ACCEPTED are).
      expect([...run({ assignments: [written], handedIn: new Set() })]).toEqual(['ch-1']);
    });

    it('does not count another student\'s submission', () => {
      expect([...run({ assignments: [written], handedIn: new Set([handInKey('w-1', 'st-2')]) })]).toEqual(['ch-1']);
    });
  });

  describe('visibility', () => {
    it('only includes students of the assigned class', () => {
      const other = student({ studentId: 'st-2', childId: 'ch-2', classId: 'c-6b' });

      expect([...run({ students: [student(), other] })]).toEqual(['ch-1']);
    });

    it('only includes students of the same school', () => {
      const foreign = student({ studentId: 'st-3', childId: 'ch-3', schoolId: 's-2' });

      expect([...run({ students: [foreign] })]).toEqual([]);
    });
  });

  it('reminds a child with several pending assignments once and keeps others out of it', () => {
    const two = [assignment(), assignment({ id: 'a-2', materialId: 'test:ENGLISH' })];
    const students = [student(), student({ studentId: 'st-2', childId: 'ch-2' })];
    const attempts = [attempt({ childId: 'ch-2' }), attempt({ childId: 'ch-2', subject: 'ENGLISH' })];

    const result = run({ assignments: two, students, attempts });

    expect([...result]).toEqual(['ch-1']);
  });

  it('reminds a child when at least one of the assignments is still pending', () => {
    const two = [assignment(), assignment({ id: 'a-2', materialId: 'test:ENGLISH' })];

    const result = run({ assignments: two, attempts: [attempt()] });

    expect([...result]).toEqual(['ch-1']);
  });
});

describe('isAssignmentVisible (must mirror childAssignmentWhere)', () => {
  const s = { schoolId: 's-1', classId: 'c-5a' };
  const base = { schoolId: 's-1', classIds: ['c-5a', 'c-5b'], dueDate: TODAY };

  it('uses the same overdue window as the Prisma filter', () => {
    const where = childAssignmentWhere(s, TODAY);

    expect(where).toEqual({
      schoolId: 's-1',
      classIds: { has: 'c-5a' },
      dueDate: { gte: '2026-10-30' },
    });
    expect(isAssignmentVisible(s, { ...base, dueDate: '2026-10-30' }, TODAY)).toBe(true);
    expect(isAssignmentVisible(s, { ...base, dueDate: '2026-10-29' }, TODAY)).toBe(false);
    expect(OVERDUE_VISIBLE_DAYS).toBe(7);
  });

  it('requires the same school and the current class', () => {
    expect(isAssignmentVisible(s, { ...base, schoolId: 's-2' }, TODAY)).toBe(false);
    expect(isAssignmentVisible({ ...s, classId: 'c-9z' }, base, TODAY)).toBe(false);
    expect(isAssignmentVisible(s, base, TODAY)).toBe(true);
  });
});
