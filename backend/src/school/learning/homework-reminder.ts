// Ertangi topshiriq eslatmasi: kim eslatma oladi — sof mantiq (DB'siz).
// Qoidalar bolaning `GET /child/school/assignments` ro'yxati bilan BIR XIL:
//  - ko'rinish: `isAssignmentVisible` (o'z maktabi, HOZIRGI sinfi);
//  - yozma vazifa: topshirilgan (SUBMITTED) yoki qabul qilingan (ACCEPTED) bo'lsa — bajarilgan; qaytarilgan (RETURNED) — yo'q;
//  - test: topshiriq berilgandan keyin shu fan bo'yicha yakunlangan urinish bo'lsa — bajarilgan;
//  - bajarilganini aniqlab bo'lmaydigan material (audiokitob) — bajarilmagan hisoblanadi.

import type { LearningSubject } from '@prisma/client';
import { isAssignmentVisible } from './assignment-visibility';
import { testSubjectOf } from './school-learning-catalog';
import { WRITTEN_KIND } from './school-learning.schemas';

export interface ReminderAssignment {
  id: string;
  schoolId: string;
  classIds: readonly string[];
  materialKind: string;
  materialId: string;
  dueDate: string;
  createdAt: Date;
}

export interface ReminderStudent {
  studentId: string;
  childId: string;
  schoolId: string;
  classId: string;
}

export interface CompletedAttempt {
  childId: string;
  subject: LearningSubject;
  completedAt: Date;
}

export interface PendingInput {
  today: string;
  /** Eslatma kuni + 1 (`YYYY-MM-DD`): faqat shu kunga muddatli topshiriqlar. */
  tomorrow: string;
  assignments: readonly ReminderAssignment[];
  students: readonly ReminderStudent[];
  /** Topshirilgan / qabul qilingan yozma vazifalar: `"<assignmentId>:<studentId>"`. */
  handedIn: ReadonlySet<string>;
  attempts: readonly CompletedAttempt[];
}

export const handInKey = (assignmentId: string, studentId: string) => `${assignmentId}:${studentId}`;

function isDone(a: ReminderAssignment, s: ReminderStudent, input: PendingInput): boolean {
  if (a.materialKind === WRITTEN_KIND) return input.handedIn.has(handInKey(a.id, s.studentId));
  const subject = testSubjectOf(a.materialId);
  if (!subject) return false;
  return input.attempts.some((t) => t.childId === s.childId && t.subject === subject && t.completedAt >= a.createdAt);
}

/** Ertaga muddati tugaydigan va hali bajarilmagan topshirig'i bor bolalar (har bola bir marta). */
export function childrenWithPendingTomorrow(input: PendingInput): Set<string> {
  const due = input.assignments.filter((a) => a.dueDate === input.tomorrow);
  const result = new Set<string>();
  for (const student of input.students) {
    if (result.has(student.childId)) continue;
    const pending = due.some(
      (a) => isAssignmentVisible(student, a, input.today) && !isDone(a, student, input),
    );
    if (pending) result.add(student.childId);
  }
  return result;
}
