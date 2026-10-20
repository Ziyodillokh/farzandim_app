import type { PsychAssignment, PsychTest } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import type { assessmentsService } from '@/data/mock/services/assessments';
import type { AssignInput, PsychNormsInput, PsychTestInput } from '@/data/schemas/assessments';
import { http } from '../client';

type Assessments = typeof assessmentsService;
type Result<K extends keyof Assessments> = Awaited<ReturnType<Assessments[K]>>;
const BASE = '/school/assessments';
const id = (v: string) => encodeURIComponent(v);

/**
 * Psixologik testlar (backend). JSON eksport — server konvertni obyekt sifatida
 * qaytaradi, fayl matni mock bilan bir xil (2 bo'shliqli JSON). Fayl importlari
 * matn sifatida yuboriladi (`{ json }`, `{ text }`) — tekshiruv serverda.
 * `simulateCompletion` — faqat demo (haqiqiy rejimda bolalar ilovada yechadi).
 */
export const assessmentsHttp: Assessments = {
  listTests: (filter = {}) => http<Result<'listTests'>>('GET', `${BASE}/tests`, { query: filter }),
  getTest: (testId) => http<Result<'getTest'>>('GET', `${BASE}/tests/${id(testId)}`),
  createTest: (input: PsychTestInput) => http<PsychTest>('POST', `${BASE}/tests`, { body: input }),
  updateTest: (testId, input: PsychTestInput) => http<PsychTest>('PUT', `${BASE}/tests/${id(testId)}`, { body: input }),
  updateNorms: (testId, norms: PsychNormsInput | null) => http<void>('PUT', `${BASE}/tests/${id(testId)}/norms`, { body: { norms } }),
  publishTest: (testId) => http<PsychTest>('POST', `${BASE}/tests/${id(testId)}/publish`),
  archiveTest: (testId) => http<PsychTest>('POST', `${BASE}/tests/${id(testId)}/archive`),
  duplicateTest: (testId) => http<PsychTest>('POST', `${BASE}/tests/${id(testId)}/duplicate`),
  classOptions: () => http<Result<'classOptions'>>('GET', `${BASE}/class-options`),
  listAssignments: (filter = {}) => http<Result<'listAssignments'>>('GET', `${BASE}/assignments`, { query: filter }),
  assign: (input: AssignInput) => http<PsychAssignment>('POST', `${BASE}/assignments`, { body: input }),
  unassign: (assignmentId) => http<PsychAssignment>('POST', `${BASE}/assignments/${id(assignmentId)}/unassign`),
  closeAssignment: (assignmentId) => http<PsychAssignment>('POST', `${BASE}/assignments/${id(assignmentId)}/close`),
  exportTest: async (testId) => JSON.stringify(await http<unknown>('GET', `${BASE}/tests/${id(testId)}/export`), null, 2),
  importTest: (json) => http<PsychTest>('POST', `${BASE}/tests/import`, { body: { json } }),
  previewResultsCsv: (text) => http<Result<'previewResultsCsv'>>('POST', `${BASE}/results/csv/preview`, { body: { text } }),
  importResultsCsv: (text) => http<Result<'importResultsCsv'>>('POST', `${BASE}/results/csv/import`, { body: { text } }),
  resultsByTest: (testId, filter = {}) => http<Result<'resultsByTest'>>('GET', `${BASE}/tests/${id(testId)}/results`, { query: filter }),
  simulateCompletion: async () => {
    throw new ServiceError('UNKNOWN', 'demo-only');
  },
};
