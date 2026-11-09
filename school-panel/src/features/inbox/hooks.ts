'use client';

import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { useCan } from '@/auth/use-session';
import { api } from '@/data/api';
import type { InboxFilter, ParentThreadDetail, ParentThreadStatus } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';

export const inboxKeys = {
  all: ['inbox'] as const,
  list: (filter: InboxFilter) => ['inbox', 'list', filter] as const,
  summary: ['inbox', 'summary'] as const,
  thread: (id: string) => ['inbox', 'thread', id] as const,
};

/** Menyu nishoni va ro'yxat yangilanish davri (yangi xabarlar). */
const REFETCH_MS = 45_000;

export function useInboxList(filter: InboxFilter) {
  return useQuery({
    queryKey: inboxKeys.list(filter),
    queryFn: () => api.inbox.list(filter),
    placeholderData: keepPreviousData,
    refetchInterval: REFETCH_MS,
  });
}

/** O'qilmagan yozishmalar soni (menyu nishoni) — `inbox.parents` bo'lmasa so'rov yuborilmaydi. */
export function useInboxUnread(): number {
  const can = useCan();
  const query = useQuery({
    queryKey: inboxKeys.summary,
    queryFn: () => api.inbox.summary(),
    enabled: can('inbox.parents'),
    refetchInterval: REFETCH_MS,
  });
  return query.data?.unread ?? 0;
}

export function useInboxThread(id: string | null) {
  return useQuery({
    queryKey: inboxKeys.thread(id ?? ''),
    queryFn: () => api.inbox.get(id ?? ''),
    enabled: Boolean(id),
    refetchInterval: REFETCH_MS,
  });
}

function useApplyThread() {
  const qc = useQueryClient();
  return (thread: ParentThreadDetail) => {
    qc.setQueryData(inboxKeys.thread(thread.id), thread);
    void qc.invalidateQueries({ queryKey: ['inbox', 'list'] });
    void qc.invalidateQueries({ queryKey: inboxKeys.summary });
  };
}

/** Yozishma ochildi — ota-ona xabarlari o'qilgan (nishon va ro'yxat yangilanadi). */
export function useMarkThreadRead() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => api.inbox.markRead(id),
    onSuccess: (_, id) => {
      void qc.invalidateQueries({ queryKey: inboxKeys.thread(id) });
      void qc.invalidateQueries({ queryKey: ['inbox', 'list'] });
      void qc.invalidateQueries({ queryKey: inboxKeys.summary });
      void qc.invalidateQueries({ queryKey: ['notifications'] });
    },
  });
}

export function useReplyToThread() {
  const { t } = useI18n();
  const apply = useApplyThread();
  return useMutation({
    mutationFn: ({ id, body }: { id: string; body: string }) => api.inbox.reply(id, body),
    onSuccess: (thread) => {
      apply(thread);
      toast.success(t('inbox.reply.sent'));
    },
    onError: (error) => toast.error(t(errorKey(error))),
  });
}

export function useSetThreadStatus() {
  const { t } = useI18n();
  const apply = useApplyThread();
  return useMutation({
    mutationFn: ({ id, status }: { id: string; status: ParentThreadStatus }) => api.inbox.setStatus(id, status),
    onSuccess: (thread) => {
      apply(thread);
      toast.success(t(thread.status === 'RESOLVED' ? 'inbox.resolved' : 'inbox.reopened'));
    },
    onError: (error) => toast.error(t(errorKey(error))),
  });
}
