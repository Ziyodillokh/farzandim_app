import type { HomeworkSubmission, LearningAssignment, LearningMaterial, StudentSubmissionRow } from '@/data/contracts';
import type { learningService } from '@/data/mock/services/learning';
import type { AssignmentInput, MaterialFilter, MaterialInput, ReviewInput } from '@/data/schemas/learning';
import { http } from '../client';

type Learning = typeof learningService;
type Result<K extends keyof Learning> = Awaited<ReturnType<Learning[K]>>;
const BASE = '/school/learning';
const id = (v: string) => encodeURIComponent(v);

/** Backend javobi: `{ assignment, counts, students: [{ studentId, name, classId, className, submission }] }`. */
type SubmissionsWire = {
  students?: { studentId: string; name: string; classId: string; submission: HomeworkSubmission | null }[];
};

/** Backend qatorlarini panel shakliga (`StudentSubmissionRow`) keltiradi. */
export const toSubmissionRows = (wire: SubmissionsWire): StudentSubmissionRow[] =>
  (wire.students ?? []).map((s) => ({ student: { id: s.studentId, fullName: s.name }, classId: s.classId, submission: s.submission }));

export const learningHttp: Learning = {
  activity: (filter = {}) => http<Result<'activity'>>('GET', `${BASE}/activity`, { query: filter }),
  interests: () => http<Result<'interests'>>('GET', `${BASE}/interests`),
  materials: (filter: MaterialFilter = {}) => http<Result<'materials'>>('GET', `${BASE}/materials`, { query: filter }),
  assignments: () => http<Result<'assignments'>>('GET', `${BASE}/assignments`),
  classOptions: () => http<Result<'classOptions'>>('GET', `${BASE}/class-options`),
  createAssignment: (input: AssignmentInput) => http<LearningAssignment>('POST', `${BASE}/assignments`, { body: input }),
  deleteAssignment: (assignmentId) => http<void>('DELETE', `${BASE}/assignments/${id(assignmentId)}`),
  createMaterial: (input: MaterialInput) => http<LearningMaterial>('POST', `${BASE}/materials`, { body: input }),
  updateMaterial: (materialId, input: MaterialInput) => http<LearningMaterial>('PUT', `${BASE}/materials/${id(materialId)}`, { body: input }),
  archiveMaterial: (materialId) => http<void>('DELETE', `${BASE}/materials/${id(materialId)}`),
  /** Yozma vazifa topshiriqlari; rasm havolalari imzolangan mutlaq URL (~1 soat). */
  submissions: async (assignmentId) =>
    toSubmissionRows(await http<SubmissionsWire>('GET', `${BASE}/assignments/${id(assignmentId)}/submissions`)),
  reviewSubmission: (submissionId, input: ReviewInput) => http<HomeworkSubmission>('POST', `${BASE}/submissions/${id(submissionId)}/review`, { body: input }),
};
