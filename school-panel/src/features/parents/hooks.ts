'use client';

import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { toast } from 'sonner';

import { api } from '@/data/api';
import type { ListQuery, ParentLinkStatus } from '@/data/contracts';
import type { BulkInviteInput } from '@/data/schemas/classes';
import { isHttpMode } from '@/data/source';
import { type TKey, useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';

export type GuardianFilter = ListQuery & { linkStatus?: ParentLinkStatus; classId?: string };
export type GuardianRow = Awaited<ReturnType<typeof api.guardians.list>>['items'][number];

const EXPORT_PAGE_LIMIT = 500;

export const parentKeys = {
  list: (filter: GuardianFilter) => ['parents', 'list', filter] as const,
  stats: ['parents', 'stats'] as const,
  linkSummary: ['parents', 'link-summary'] as const,
  pending: (filter: BulkInviteInput) => ['parents', 'pending', filter] as const,
};

export function useGuardians(filter: GuardianFilter) {
  return useQuery({ queryKey: parentKeys.list(filter), queryFn: () => api.guardians.list(filter), placeholderData: keepPreviousData });
}

export function useGuardianStats() {
  return useQuery({ queryKey: parentKeys.stats, queryFn: () => api.guardians.stats() });
}

/** Ulanish ulushlari: o'quvchilar va ota-onalar (bosh sahifa bilan yagona hisob). */
export function useParentLinkSummary() {
  return useQuery({ queryKey: parentKeys.linkSummary, queryFn: () => api.parents.linkSummary() });
}

/** Joriy filtr (sinf + qidiruv) bo'yicha taklif qilinmaganlar soni — ommaviy taklif uchun. */
export function usePendingInvites(filter: BulkInviteInput, enabled: boolean) {
  return useQuery({
    queryKey: parentKeys.pending(filter),
    queryFn: async () => (await api.guardians.list({ ...filter, linkStatus: 'NOT_INVITED', limit: 1 })).pagination.total,
    enabled,
  });
}

/** Eksport: filtr bo'yicha barcha sahifalar. */
export async function fetchAllGuardians(filter: GuardianFilter): Promise<GuardianRow[]> {
  const out: GuardianRow[] = [];
  for (let page = 1; ; page++) {
    const res = await api.guardians.list({ ...filter, page, limit: EXPORT_PAGE_LIMIT });
    out.push(...res.items);
    if (page >= res.pagination.totalPages) return out;
  }
}

function useParentMutation<TVars, TResult>(fn: (vars: TVars) => Promise<TResult>, success: (result: TResult) => string) {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  return useMutation({
    mutationFn: fn,
    onSuccess: (result) => {
      void queryClient.invalidateQueries();
      toast.success(success(result));
    },
    onError: (error) => toast.error(t(errorKey(error))),
  });
}

export function useInvite() {
  const { t } = useI18n();
  return useParentMutation((guardianId: string) => api.guardians.invite(guardianId), () => t(isHttpMode ? 'parents.toast.invitedCode' : 'parents.toast.invited'));
}

export function useUnlink() {
  const { t } = useI18n();
  return useParentMutation((guardianId: string) => api.guardians.unlink(guardianId), () => t('parents.toast.unlinked'));
}

export function useResend() {
  const { t } = useI18n();
  return useParentMutation((guardianId: string) => api.guardians.invite(guardianId), () => t('parents.toast.resent'));
}

export function useSimulateLink() {
  const { t } = useI18n();
  return useParentMutation((guardianId: string) => api.guardians.simulateLink(guardianId), () => t('parents.toast.linked'));
}

export function useBulkInvite() {
  const { t } = useI18n();
  return useParentMutation(
    (filter: BulkInviteInput) => api.classes.inviteGuardians(filter),
    (r) => t(r.invited > 0 ? 'parents.bulk.done' : 'parents.bulk.nothing', { count: r.invited }),
  );
}

/** Buferga nusxa olish (xavfsiz bo'lmagan kontekstda xato — toast). */
export function useCopy(): (text: string, successKey?: TKey) => Promise<void> {
  const { t } = useI18n();
  return useCallback(
    async (text: string, successKey: TKey = 'common.copied') => {
      try {
        await navigator.clipboard.writeText(text);
        toast.success(t(successKey));
      } catch {
        toast.error(t('parents.copyFailed'));
      }
    },
    [t],
  );
}
