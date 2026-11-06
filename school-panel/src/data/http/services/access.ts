import type { accessService } from '@/data/mock/services/access';
import type { linkRequestsService } from '@/data/mock/services/link-requests';
import { http } from '../client';
import {
  asStudentArchived,
  isNotLinked,
  toChildCredentials,
  toGeneratedInviteCode,
  toInviteCode,
  toIssueBody,
  toIssuedCredentials,
  toLinkDecision,
  toLinkRequests,
  toStudentRecoveryRequests,
} from './access-adapters';

type Access = typeof accessService;
type LinkRequests = typeof linkRequestsService;
const id = (v: string) => encodeURIComponent(v);
const studentPath = (studentId: string) => `/school/students/${id(studentId)}`;

/**
 * Kirish (5-bosqich) servislari — backend kontraktlari (K1 `KIRISH-AUTH-API.md`, K2 `KIRISH-SCHOOL-API.md`):
 *  GET|POST  /school/students/:id/credentials                               (`students.manage`; 409 NOT_LINKED | LOGIN_TAKEN | STUDENT_ARCHIVED)
 *  GET       /school/students/:id                                           (`recoveryRequests` maydoni)
 *  POST      /school/students/:id/recovery-requests/:requestId/reject       (`students.manage`; 404 REQUEST_NOT_FOUND | 409 ALREADY_RESOLVED | NOT_LINKED)
 *  GET|POST  /school/students/:id/invite-code                               (`guardians.link`; GET: faol kod yoki `null`; POST: 409 — arxivdagi o'quvchi)
 *  GET       /school/link-requests                                          (`guardians.link`; massiv, eng eskilari birinchi)
 *  POST      /school/link-requests/:id/(confirm|reject)                     (id shaffof — URL-kodlanadi; 409 REQUEST_STALE | STUDENT_LINKED_ELSEWHERE | ALREADY_ENROLLED, 404)
 */
export const accessHttp: Access = {
  /** `409 NOT_LINKED` xato emas: o'quvchi hali bola profiliga ulanmagan (`linked: false`). */
  credentials: async (studentId) => {
    try {
      return { linked: true, credentials: toChildCredentials(await http<unknown>('GET', `${studentPath(studentId)}/credentials`)) };
    } catch (error) {
      if (isNotLinked(error)) return { linked: false, credentials: null };
      throw error;
    }
  },
  issueCredentials: async (studentId, input = {}) =>
    toIssuedCredentials(await http<unknown>('POST', `${studentPath(studentId)}/credentials`, { body: toIssueBody(input) })),
  /** Alohida GET yo'q — o'quvchi kartasi ichida (`recoveryRequests`, K1 §5). */
  recoveryRequests: async (studentId) => toStudentRecoveryRequests(await http<unknown>('GET', studentPath(studentId))),
  rejectRecovery: async (studentId, requestId) => {
    await http<unknown>('POST', `${studentPath(studentId)}/recovery-requests/${id(requestId)}/reject`);
  },
  /** Faol kod yo'q: JSON `null` (200). `404` (begona maktab / noma'lum id) va `403` (sinf doirasidan tashqari) — xato, «kod yo'q» emas. */
  inviteCode: async (studentId) => toInviteCode(await http<unknown>('GET', `${studentPath(studentId)}/invite-code`)),
  generateInviteCode: async (studentId) => {
    try {
      return toGeneratedInviteCode(await http<unknown>('POST', `${studentPath(studentId)}/invite-code`));
    } catch (error) {
      throw asStudentArchived(error);
    }
  },
};

export const linkRequestsHttp: LinkRequests = {
  list: async () => toLinkRequests(await http<unknown>('GET', '/school/link-requests')),
  /** REVIEW: bog'lanishni tasdiqlash; CORRECTION: bog'lanishni SAQLASH. */
  confirm: async (requestId) => toLinkDecision(await http<unknown>('POST', `/school/link-requests/${id(requestId)}/confirm`), 'confirm'),
  /** REVIEW: o'quvchi o'rnini bo'shatish; CORRECTION: bog'lanishni UZISH. */
  reject: async (requestId) => toLinkDecision(await http<unknown>('POST', `/school/link-requests/${id(requestId)}/reject`), 'reject'),
};
