'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { useCan } from '@/auth/use-session';
import { api } from '@/data/api';
import type { LinkRequest } from '@/data/contracts';
import { type TKey, useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';

export const linkRequestKeys = { all: ['link-requests'] as const };

/** Menyudagi nishon uchun yangilanish davri. */
const COUNT_REFETCH_MS = 60_000;

export function useLinkRequests() {
  return useQuery({ queryKey: linkRequestKeys.all, queryFn: () => api.linkRequests.list() });
}

/** Ochiq so'rovlar soni (menyu nishoni) — `guardians.link` bo'lmasa so'rov yuborilmaydi. Ro'yxat bilan bir xil kesh. */
export function useLinkRequestCount(): number {
  const can = useCan();
  const query = useQuery({
    queryKey: linkRequestKeys.all,
    queryFn: () => api.linkRequests.list(),
    enabled: can('guardians.link'),
    refetchInterval: COUNT_REFETCH_MS,
    select: (items: LinkRequest[]) => items.length,
  });
  return query.data ?? 0;
}

export type LinkDecision = 'confirm' | 'reject';

const TOASTS: Record<LinkRequest['kind'], Record<LinkDecision, TKey>> = {
  REVIEW: { confirm: 'linkRequests.toast.confirmed', reject: 'linkRequests.toast.rejected' },
  CORRECTION: { confirm: 'linkRequests.toast.kept', reject: 'linkRequests.toast.unlinked' },
};

/**
 * Tasdiqlash / rad etish. Natijadan qat'i nazar ro'yxat yangilanadi (so'rov allaqachon hal qilingan bo'lishi mumkin).
 * Muvaffaqiyatda yangilanish TUGAGUNCHA kutiladi: tasdiq oynasi yopilganda qator allaqachon yo'q bo'lsin (fokus to'g'ri joyga qaytadi).
 */
export function useDecideLinkRequest() {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  return useMutation({
    mutationFn: ({ request, decision }: { request: LinkRequest; decision: LinkDecision }) =>
      decision === 'confirm' ? api.linkRequests.confirm(request.id) : api.linkRequests.reject(request.id),
    onSuccess: async (_result, { request, decision }) => {
      toast.success(t(TOASTS[request.kind][decision]));
      await queryClient.invalidateQueries();
    },
    onError: (error) => {
      toast.error(t(errorKey(error)));
      void queryClient.invalidateQueries({ queryKey: linkRequestKeys.all });
    },
  });
}
