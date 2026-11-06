import { assignInputSchema, MAX_STUDENT_TARGETS } from './assessments-inputs.schemas';
import { parseOrThrow } from '../common/school-zod';
import { resolveClasses } from './assessments-assign.service';

const base = { testId: 'tpl-logic', opensAt: '2026-11-06T09:00', closesAt: '2026-11-13T09:00', consent: true };
const ids = (n: number) => Array.from({ length: n }, (_, i) => `s${i}`);
const messageOf = (input: unknown) => {
  try {
    parseOrThrow(assignInputSchema, input);
    return 'ok';
  } catch (err) {
    return (err as { response: { message: string } }).response.message;
  }
};

describe('assignInputSchema STUDENTS target', () => {
  it('accepts 1..30 student ids and an optional careRequestId', () => {
    expect(messageOf({ ...base, target: { kind: 'STUDENTS', studentIds: ids(1) } })).toBe('ok');
    expect(messageOf({ ...base, target: { kind: 'STUDENTS', studentIds: ids(MAX_STUDENT_TARGETS) }, careRequestId: 'req-1' })).toBe('ok');
  });

  it('rejects an empty list and more than 30 ids', () => {
    expect(messageOf({ ...base, target: { kind: 'STUDENTS', studentIds: [] } })).toBe('target.studentIds: errors.form.selectAtLeastOne');
    expect(messageOf({ ...base, target: { kind: 'STUDENTS', studentIds: ids(MAX_STUDENT_TARGETS + 1) } })).toBe('target.studentIds: errors.form.tooLong');
  });

  it('still requires the parents-informed consent', () => {
    expect(messageOf({ ...base, consent: false, target: { kind: 'STUDENTS', studentIds: ids(1) } })).toContain('consent');
  });

  it('keeps CLASSES and GRADES targets working', () => {
    expect(messageOf({ ...base, target: { kind: 'CLASSES', classIds: ['c1'] } })).toBe('ok');
    expect(messageOf({ ...base, target: { kind: 'GRADES', grades: [7] } })).toBe('ok');
  });
});

describe('resolveClasses', () => {
  it('resolves no classes for a personal (STUDENTS) target', () => {
    expect(resolveClasses([{ id: 'c1', name: '7-A', grade: 7, letter: 'A' }], { kind: 'STUDENTS', studentIds: ['s1'] }, { grades: [7] })).toEqual([]);
  });
});
