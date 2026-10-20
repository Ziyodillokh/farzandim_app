import type { SchoolClass } from '@/data/contracts';
import type { ClassDetail, ClassModeNow, ClassRow, classesService } from '@/data/mock/services/classes';
import type { BulkInviteInput, ClassInput } from '@/data/schemas/classes';
import { http } from '../client';

type Classes = typeof classesService;
const id = (v: string) => encodeURIComponent(v);

export const classesHttp: Classes = {
  list: (filter = {}) => http<ClassRow[]>('GET', '/school/classes', { query: filter }),
  get: (classId) => http<ClassRow>('GET', `/school/classes/${id(classId)}`),
  detail: (classId) => http<ClassDetail>('GET', `/school/classes/${id(classId)}/detail`),
  modeNow: (classId) => http<ClassModeNow>('GET', `/school/school-mode/classes/${id(classId)}/now`),
  modesNow: () => http<Awaited<ReturnType<Classes['modesNow']>>>('GET', '/school/school-mode/classes/now'),
  create: (input: ClassInput) => http<SchoolClass>('POST', '/school/classes', { body: input }),
  update: (classId, input: ClassInput) => http<SchoolClass>('PUT', `/school/classes/${id(classId)}`, { body: input }),
  remove: (classId) => http<void>('DELETE', `/school/classes/${id(classId)}`),
  today: (classId) => http<Awaited<ReturnType<Classes['today']>>>('GET', `/school/attendance/classes/${id(classId)}/today`),
  inviteGuardians: (input: BulkInviteInput = {}) => http<{ invited: number }>('POST', '/school/guardians/invite-bulk', { body: input }),
};
