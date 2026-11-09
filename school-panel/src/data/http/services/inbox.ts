import type { InboxCounts, InboxPage, ParentThreadDetail } from '@/data/contracts';
import type { inboxService } from '@/data/mock/services/inbox';
import { http } from '../client';

type Inbox = typeof inboxService;
const BASE = '/school/parent-threads';
const id = (v: string) => encodeURIComponent(v);

/** Backend `/api/school/parent-threads/*` — javob shakli panel kontrakti bilan bir xil. */
export const inboxHttp: Inbox = {
  list: (filter = { status: 'OPEN' }) =>
    http<InboxPage>('GET', BASE, { query: { status: filter.status, search: filter.search || undefined, page: filter.page, limit: filter.limit } }),
  summary: () => http<InboxCounts>('GET', `${BASE}/summary`),
  get: (threadId) => http<ParentThreadDetail>('GET', `${BASE}/${id(threadId)}`),
  reply: (threadId, body) => http<ParentThreadDetail>('POST', `${BASE}/${id(threadId)}/messages`, { body: { body } }),
  markRead: (threadId) => http<{ id: string; readAt: string }>('POST', `${BASE}/${id(threadId)}/read`),
  setStatus: (threadId, status) => http<ParentThreadDetail>('POST', `${BASE}/${id(threadId)}/status`, { body: { status } }),
};
