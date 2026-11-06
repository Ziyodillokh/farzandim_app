import { ServiceError } from '@/data/contracts';
import type { accessService } from '@/data/mock/services/access';
import type { linkRequestsService } from '@/data/mock/services/link-requests';
import { http } from '../client';
import {
  isNotLinked,
  toChildCredentials,
  toGeneratedInviteCode,
  toInviteCode,
  toIssueBody,
  toIssuedCredentials,
  toLinkRequests,
  toRecoveryRequests,
} from './access-adapters';
import { isRecord } from './care-adapters';

type Access = typeof accessService;
type LinkRequests = typeof linkRequestsService;
const id = (v: string) => encodeURIComponent(v);
const studentPath = (studentId: string) => `/school/students/${id(studentId)}`;

/**
 * Kirish (5-bosqich) servislari — kontrakt K1/K2:
 *  GET|POST /school/students/:id/credentials (409 NOT_LINKED, 409 LOGIN_TAKEN),
 *  POST /school/students/:id/recovery-requests/:requestId/reject,
 *  GET|POST /school/students/:id/invite-code, GET /school/link-requests, POST /school/link-requests/:id/(confirm|reject).
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
  /** Kontraktda alohida GET yo'q — «school student detail» ichida (`recoveryRequests`). */
  recoveryRequests: async (studentId) => {
    const detail = await http<unknown>('GET', studentPath(studentId));
    return toRecoveryRequests(isRecord(detail) ? detail.recoveryRequests : undefined);
  },
  rejectRecovery: async (studentId, requestId) => {
    await http<unknown>('POST', `${studentPath(studentId)}/recovery-requests/${id(requestId)}/reject`);
  },
  /** Faol kod yo'q: `null`/bo'sh javob yoki `404`. */
  inviteCode: async (studentId) => {
    try {
      return toInviteCode(await http<unknown>('GET', `${studentPath(studentId)}/invite-code`));
    } catch (error) {
      if (error instanceof ServiceError && error.code === 'NOT_FOUND') return null;
      throw error;
    }
  },
  generateInviteCode: async (studentId) => toGeneratedInviteCode(await http<unknown>('POST', `${studentPath(studentId)}/invite-code`)),
};

export const linkRequestsHttp: LinkRequests = {
  list: async () => toLinkRequests(await http<unknown>('GET', '/school/link-requests')),
  confirm: async (requestId) => {
    await http<unknown>('POST', `/school/link-requests/${id(requestId)}/confirm`);
  },
  reject: async (requestId) => {
    await http<unknown>('POST', `/school/link-requests/${id(requestId)}/reject`);
  },
};
