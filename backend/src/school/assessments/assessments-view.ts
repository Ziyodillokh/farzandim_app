// Javob shakllari (panel `assessmentsService` qaytaradigan turlar) va sof
// yordamchilar: test qatori, tayinlash holati, filtrlar.

import type { SchoolPsychAssignment } from '@prisma/client';
import { matchesSearch } from '../common/list-query';
import type {
  AssignmentState,
  AssignmentStatus,
  AssignmentTarget,
  Localized,
  PsychNorms,
  PsychTest,
  PsychTestKind,
  PsychTestSource,
  PsychTestStatus,
} from './psych/types';

export type PsychTestRow = PsychTest & { itemCount: number; assignmentsActive: number; resultsCount: number };
export type PsychTestDetail = PsychTestRow & { readOnly: boolean; normsOverridden: boolean; defaultNorms: PsychNorms | null };
export type PsychTestFilter = { kind?: PsychTestKind; status?: PsychTestStatus; source?: PsychTestSource; search?: string };

export type PsychAssignment = {
  id: string;
  testId: string;
  testVersion: number;
  target: AssignmentTarget;
  classIds: string[];
  opensAt: string;
  closesAt: string;
  status: AssignmentStatus;
  invited: number;
  consent: 'PARENTS_INFORMED';
  createdBy: string;
  createdAt: string;
};

export type AssignmentRow = PsychAssignment & {
  state: AssignmentState;
  completed: number;
  testTitle: Localized;
  testKind: PsychTestKind | null;
  classNames: string[];
};

export type RowsContext = { active: ReadonlyMap<string, number>; results: ReadonlyMap<string, number> };

export function toTestRow(test: PsychTest, ctx: RowsContext): PsychTestRow {
  return { ...test, itemCount: test.items.length, assignmentsActive: ctx.active.get(test.id) ?? 0, resultsCount: ctx.results.get(test.id) ?? 0 };
}

export function matchesTestFilter(test: PsychTest, f: PsychTestFilter): boolean {
  if (f.kind && test.kind !== f.kind) return false;
  if (f.status && test.status !== f.status) return false;
  if (f.source && test.source !== f.source) return false;
  return !f.search || matchesSearch(`${test.title.uz} ${test.title.ru}`, f.search);
}

/** Holat oynadan va statusdan: bekor → CANCELLED, yopilgan/o'tgan → ENDED. */
export function assignmentState(a: { status: string; opensAt: Date; closesAt: Date }, nowMs: number): AssignmentState {
  if (a.status === 'CANCELLED') return 'CANCELLED';
  if (a.status === 'CLOSED' || nowMs > a.closesAt.getTime()) return 'ENDED';
  return nowMs < a.opensAt.getTime() ? 'SCHEDULED' : 'ACTIVE';
}

const ASSIGNMENT_STATUSES: readonly AssignmentStatus[] = ['OPEN', 'CLOSED', 'CANCELLED'];

export function toAssignment(row: SchoolPsychAssignment): PsychAssignment {
  return {
    id: row.id,
    testId: row.testId,
    testVersion: row.testVersion,
    target: row.target as AssignmentTarget,
    classIds: row.classIds,
    opensAt: row.opensAt.toISOString(),
    closesAt: row.closesAt.toISOString(),
    status: ASSIGNMENT_STATUSES.includes(row.status as AssignmentStatus) ? (row.status as AssignmentStatus) : 'CLOSED',
    invited: row.invited,
    consent: 'PARENTS_INFORMED',
    createdBy: row.createdBy,
    createdAt: row.createdAt.toISOString(),
  };
}

export function toAssignmentRow(
  row: SchoolPsychAssignment,
  nowMs: number,
  completed: ReadonlyMap<string, number>,
  test: PsychTest | undefined,
  classNames: ReadonlyMap<string, string>,
): AssignmentRow {
  return {
    ...toAssignment(row),
    state: assignmentState(row, nowMs),
    completed: completed.get(row.id) ?? 0,
    testTitle: test?.title ?? { uz: row.testId, ru: row.testId },
    testKind: test?.kind ?? null,
    classNames: row.classIds.map((id) => classNames.get(id) ?? id),
  };
}

/** Test → hozir faol tayinlashlar soni. */
export function activeByTest(
  rows: ReadonlyArray<Pick<SchoolPsychAssignment, 'testId' | 'status' | 'opensAt' | 'closesAt'>>,
  nowMs: number,
): Map<string, number> {
  const active = new Map<string, number>();
  for (const a of rows) {
    if (assignmentState(a, nowMs) === 'ACTIVE') active.set(a.testId, (active.get(a.testId) ?? 0) + 1);
  }
  return active;
}
