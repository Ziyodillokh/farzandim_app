import type { LearningAssignment } from '@/data/contracts';
import type { learningService } from '@/data/mock/services/learning';
import type { AssignmentInput, MaterialFilter } from '@/data/schemas/learning';
import { http } from '../client';

type Learning = typeof learningService;
type Result<K extends keyof Learning> = Awaited<ReturnType<Learning[K]>>;
const BASE = '/school/learning';

export const learningHttp: Learning = {
  activity: (filter = {}) => http<Result<'activity'>>('GET', `${BASE}/activity`, { query: filter }),
  interests: () => http<Result<'interests'>>('GET', `${BASE}/interests`),
  materials: (filter: MaterialFilter = {}) => http<Result<'materials'>>('GET', `${BASE}/materials`, { query: filter }),
  assignments: () => http<Result<'assignments'>>('GET', `${BASE}/assignments`),
  classOptions: () => http<Result<'classOptions'>>('GET', `${BASE}/class-options`),
  createAssignment: (input: AssignmentInput) => http<LearningAssignment>('POST', `${BASE}/assignments`, { body: input }),
  deleteAssignment: (id) => http<void>('DELETE', `${BASE}/assignments/${encodeURIComponent(id)}`),
};
