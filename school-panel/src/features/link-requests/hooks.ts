'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { useCan } from '@/auth/use-session';
import { api } from '@/data/api';
import type { LinkRequest } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useSingleFlight } from '@/lib/single-flight';
import { DECISION_ERROR_TOAST_MS, decisionErrorKey, type LinkDecision, runDecision, toastKeyFor } from './lib/decisions';

export type { LinkDecision } from './lib/decisions';

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

/**
 * Tasdiqlash / rad etish (REVIEW) yoki ulanishni saqlash / uzish (CORRECTION): endpoint `LINK_ACTIONS` jadvalidan.
 * Muvaffaqiyat xabari backend natijasidan (`kind` + `status`). Xato bo'lsa ham ro'yxat yangilanadi: `409 REQUEST_STALE` (boshqa xodim
 * hal qilgan yoki so'rov o'zgargan) va `404` (so'rov yo'q) holatlarida eskirgan qator yo'qolishi kerak.
 * Muvaffaqiyatda yangilanish TUGAGUNCHA kutiladi: tasdiq oynasi yopilganda qator allaqachon yo'q bo'lsin (fokus to'g'ri joyga qaytadi).
 */
export function useDecideLinkRequest(): { decide: (vars: { request: LinkRequest; decision: LinkDecision }) => Promise<void>; isPending: boolean } {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  const mutation = useMutation({
    mutationFn: ({ request, decision }: { request: LinkRequest; decision: LinkDecision }) => runDecision(api.linkRequests, request.id, decision),
    onSuccess: async (result) => {
      toast.success(t(toastKeyFor(result)));
      await queryClient.invalidateQueries();
    },
    onError: (error) => {
      toast.error(t(decisionErrorKey(error)), { duration: DECISION_ERROR_TOAST_MS });
      void queryClient.invalidateQueries({ queryKey: linkRequestKeys.all });
    },
  });
  // Tez-tez bosish ikkinchi qaror yubormasin (u «allaqachon ko'rib chiqilgan» xatosini berardi).
  const once = useSingleFlight(mutation.mutateAsync);
  return { decide: (vars) => once(vars).then(() => undefined), isPending: mutation.isPending };
}
