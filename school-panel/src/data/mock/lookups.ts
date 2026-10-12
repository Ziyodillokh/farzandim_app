import type { SchoolClass, Shift, Staff, Student } from '@/data/contracts';
import type { Tables } from './tables';

export function studentName(s: Pick<Student, 'lastName' | 'firstName'>): string {
  return `${s.lastName} ${s.firstName}`;
}

export function studentFullName(s: Pick<Student, 'lastName' | 'firstName' | 'middleName'>): string {
  return [s.lastName, s.firstName, s.middleName].filter(Boolean).join(' ');
}

export type Indexes = {
  classes: Map<string, SchoolClass>;
  shifts: Map<string, Shift>;
  staff: Map<string, Staff>;
  students: Map<string, Student>;
};

export function buildIndexes(tables: Tables): Indexes {
  return {
    classes: new Map(tables.classes.map((c) => [c.id, c])),
    shifts: new Map(tables.shifts.map((s) => [s.id, s])),
    staff: new Map(tables.staff.map((s) => [s.id, s])),
    students: new Map(tables.students.map((s) => [s.id, s])),
  };
}

/** Sinflarni "1-A, 1-B, 2-A…" tartibida saralash. */
export function compareClasses(a: Pick<SchoolClass, 'grade' | 'letter'>, b: Pick<SchoolClass, 'grade' | 'letter'>): number {
  return a.grade - b.grade || a.letter.localeCompare(b.letter);
}

export function classSizes(tables: Tables): Map<string, number> {
  const sizes = new Map<string, number>();
  for (const s of tables.students) if (!s.archived) sizes.set(s.classId, (sizes.get(s.classId) ?? 0) + 1);
  return sizes;
}
