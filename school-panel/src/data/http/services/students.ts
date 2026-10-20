import type { Guardian, Paginated, Student, StudentNote } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import type { parentsService } from '@/data/mock/services/parents';
import type { StudentHistory, StudentNoteRow } from '@/data/mock/services/student-360';
import type { guardiansService, StudentDetail, StudentFilter, StudentRow, studentsService } from '@/data/mock/services/students';
import type { GuardianInput, StudentCreateInput, StudentInput } from '@/data/schemas/students';
import { http } from '../client';

type Students = typeof studentsService;
type Guardians = typeof guardiansService;
type GuardianPage = Awaited<ReturnType<Guardians['list']>>;
const id = (v: string) => encodeURIComponent(v);

/** Eksport sahifasi — backend ro'yxat chegarasi. */
const EXPORT_PAGE = 500;

async function exportRows(filter: StudentFilter = {}): Promise<StudentRow[]> {
  const rows: StudentRow[] = [];
  for (let page = 1; ; page++) {
    const res = await studentsHttp.list({ ...filter, page, limit: EXPORT_PAGE });
    rows.push(...res.items);
    if (page >= res.pagination.totalPages) return rows;
  }
}

export const studentsHttp: Students = {
  classOptions: () => http<Array<{ id: string; name: string }>>('GET', '/school/students/class-options'),
  list: (filter = {}) => http<Paginated<StudentRow>>('GET', '/school/students', { query: filter }),
  exportRows,
  get: (studentId) => http<StudentDetail>('GET', `/school/students/${id(studentId)}`),
  create: (input: StudentCreateInput) => http<Student>('POST', '/school/students', { body: input }),
  update: (studentId, input: StudentInput) => http<Student>('PUT', `/school/students/${id(studentId)}`, { body: input }),
  setArchived: (studentId, archived) => http<Student>('PUT', `/school/students/${id(studentId)}/archived`, { body: { archived } }),
  importRows: (rows) => http<Awaited<ReturnType<Students['importRows']>>>('POST', '/school/students/import', { body: { rows } }),
  history: (studentId) => http<StudentHistory>('GET', `/school/students/${id(studentId)}/history`),
  notes: (studentId) => http<StudentNoteRow[]>('GET', `/school/students/${id(studentId)}/notes`),
  addNote: (studentId, text) => http<StudentNote>('POST', `/school/students/${id(studentId)}/notes`, { body: { text } }),
  deleteNote: (noteId) => http<void>('DELETE', `/school/students/notes/${id(noteId)}`),
};

export const guardiansHttp: Guardians = {
  list: (filter = {}) => http<GuardianPage>('GET', '/school/guardians', { query: filter }),
  stats: () => http<Awaited<ReturnType<Guardians['stats']>>>('GET', '/school/guardians/stats'),
  invite: (guardianId) => http<Guardian>('POST', `/school/guardians/${id(guardianId)}/invite`),
  /** Demo: haqiqiy rejimda ota-ona kodni Parvoz Parents ilovasida o'zi kiritadi. */
  simulateLink: () => Promise.reject(new ServiceError('UNKNOWN', 'demo-only')),
  unlink: (guardianId) => http<Guardian>('POST', `/school/guardians/${id(guardianId)}/unlink`),
  addToStudent: (studentId, input: GuardianInput) => http<Guardian>('POST', `/school/students/${id(studentId)}/guardians`, { body: input }),
  update: (guardianId, input: GuardianInput) => http<Guardian>('PUT', `/school/guardians/${id(guardianId)}`, { body: input }),
};

export const parentsHttp: typeof parentsService = {
  linkSummary: () => http<Awaited<ReturnType<(typeof parentsService)['linkSummary']>>>('GET', '/school/guardians/link-summary'),
};
