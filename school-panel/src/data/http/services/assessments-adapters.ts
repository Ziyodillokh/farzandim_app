import type { AssignmentState, AssignmentTarget, Localized, PsychTestKind } from '@/data/contracts';
import type { AssignmentRow } from '@/data/mock/services/assessments';
import type { AssignInput } from '@/data/schemas/assessments';
import { isRecord, malformed, nullableString, requiredInt, requiredString, type Wire } from './care-adapters';

/**
 * Psixologik testlarni tayinlash (kontrakt D) uchun adapterlar: ro'yxat qatori va POST tanasi.
 * Backend `target` ni JSON sifatida saqlab qaytaradi; `STUDENTS` — `{ kind: 'STUDENTS', studentIds }`.
 */

const STATES: readonly AssignmentState[] = ['SCHEDULED', 'ACTIVE', 'ENDED', 'CANCELLED'];
const STATUSES = ['OPEN', 'CLOSED', 'CANCELLED'] as const;
const KINDS: readonly PsychTestKind[] = ['COGNITIVE', 'ATTENTION', 'EMOTIONAL', 'SELF_ESTEEM', 'CAREER', 'SOCIAL', 'CUSTOM'];

function stringList(value: unknown, what: string): string[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value) || value.some((v) => typeof v !== 'string')) throw malformed(what);
  return value as string[];
}

function intList(value: unknown, what: string): number[] {
  if (!Array.isArray(value) || value.some((v) => typeof v !== 'number' || !Number.isInteger(v))) throw malformed(what);
  return value as number[];
}

function localized(value: unknown, fallback: string): Localized {
  if (isRecord(value) && typeof value.uz === 'string' && typeof value.ru === 'string') return { uz: value.uz, ru: value.ru };
  return { uz: fallback, ru: fallback };
}

/** `target` — backend JSON; yo'q bo'lsa `studentIds` (shaxsiy) yoki `classIds` dan tiklanadi. */
function targetOf(raw: Wire, classIds: string[]): AssignmentTarget {
  const target = raw.target;
  if (isRecord(target)) {
    if (target.kind === 'CLASSES') return { kind: 'CLASSES', classIds: stringList(target.classIds, 'target.classIds') };
    if (target.kind === 'GRADES') return { kind: 'GRADES', grades: intList(target.grades, 'target.grades') };
    if (target.kind === 'STUDENTS') return { kind: 'STUDENTS', studentIds: stringList(target.studentIds, 'target.studentIds') };
    throw malformed('target.kind');
  }
  const studentIds = stringList(raw.studentIds, 'studentIds');
  return studentIds.length > 0 ? { kind: 'STUDENTS', studentIds } : { kind: 'CLASSES', classIds };
}

function oneOf<T extends string>(value: unknown, allowed: readonly T[], what: string): T {
  const found = allowed.find((a) => a === value);
  if (found === undefined) throw malformed(what);
  return found;
}

/** `GET /school/assessments/assignments` qatori. */
export function toAssignmentRow(raw: unknown): AssignmentRow {
  if (!isRecord(raw)) throw malformed('assignment');
  const classIds = stringList(raw.classIds, 'classIds');
  const careRequestId = nullableString(raw.careRequestId, 'careRequestId');
  return {
    id: requiredString(raw.id, 'id'),
    testId: requiredString(raw.testId, 'testId'),
    testVersion: requiredInt(raw.testVersion, 'testVersion'),
    target: targetOf(raw, classIds),
    classIds,
    opensAt: requiredString(raw.opensAt, 'opensAt'),
    closesAt: requiredString(raw.closesAt, 'closesAt'),
    status: oneOf(raw.status, STATUSES, 'status'),
    invited: requiredInt(raw.invited, 'invited'),
    consent: 'PARENTS_INFORMED',
    ...(careRequestId ? { careRequestId } : {}),
    createdBy: typeof raw.createdBy === 'string' ? raw.createdBy : '',
    createdAt: typeof raw.createdAt === 'string' ? raw.createdAt : '',
    state: oneOf(raw.state, STATES, 'state'),
    completed: requiredInt(raw.completed, 'completed'),
    testTitle: localized(raw.testTitle, typeof raw.testId === 'string' ? raw.testId : ''),
    testKind: KINDS.find((k) => k === raw.testKind) ?? null,
    classNames: stringList(raw.classNames, 'classNames'),
  };
}

export function toAssignmentRows(raw: unknown): AssignmentRow[] {
  if (!Array.isArray(raw)) throw malformed('assignments');
  return raw.map(toAssignmentRow);
}

/** `POST /school/assessments/assignments` tanasi: `careRequestId` — yuqori darajada (maqsad ichida emas). */
export function toAssignBody(input: AssignInput): Record<string, unknown> {
  const target: Record<string, unknown> =
    input.target.kind === 'CLASSES'
      ? { kind: 'CLASSES', classIds: input.target.classIds }
      : input.target.kind === 'GRADES'
        ? { kind: 'GRADES', grades: input.target.grades }
        : { kind: 'STUDENTS', studentIds: input.target.studentIds };
  return {
    testId: input.testId,
    target,
    opensAt: input.opensAt,
    closesAt: input.closesAt,
    consent: input.consent,
    ...(input.careRequestId ? { careRequestId: input.careRequestId } : {}),
  };
}
