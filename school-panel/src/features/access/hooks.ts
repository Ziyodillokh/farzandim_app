'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback, useState } from 'react';
import { toast } from 'sonner';

import { api } from '@/data/api';
import type { InviteCode, IssuedCredentials, IssueCredentialsInput } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';
import { useSingleFlight } from '@/lib/single-flight';
import { accessKeys } from './keys';
import { REFRESH_WAIT_MS, settleWithin } from './lib/settle';

export { accessKeys, markNotLinked } from './keys';

export function useCredentials(studentId: string) {
  return useQuery({ queryKey: accessKeys.credentials(studentId), queryFn: () => api.access.credentials(studentId) });
}

export function useRecoveryRequests(studentId: string) {
  return useQuery({ queryKey: accessKeys.recovery(studentId), queryFn: () => api.access.recoveryRequests(studentId) });
}

export function useInviteCode(studentId: string) {
  return useQuery({ queryKey: accessKeys.inviteCode(studentId), queryFn: () => api.access.inviteCode(studentId) });
}

/**
 * Kirish ma'lumotlarini berish/tiklash. Vaqtinchalik parol `useMutation` orqali EMAS (uning natijasi RQ keshida qoladi),
 * oddiy async chaqiruv bilan: natija faqat chaqiruvchi komponent holatida yashaydi va oyna yopilganda yo'qoladi.
 */
export function useIssueCredentials(studentId: string): { issue: (input: IssueCredentialsInput) => Promise<IssuedCredentials>; pending: boolean } {
  const queryClient = useQueryClient();
  const [pending, setPending] = useState(false);
  const run = useCallback(
    async (input: IssueCredentialsInput) => {
      setPending(true);
      try {
        const issued = await api.access.issueCredentials(studentId, input);
        // Karta yangilanishi kutiladi (xatosi yutiladi, lekin `REFRESH_WAIT_MS` dan ortiq emas): ochish oynasi yopilganda
        // «Berish» tugmasi allaqachon tafsilotga almashgan bo'lsin — aks holda fokus yo'qolayotgan tugmaga qaytadi.
        // Chegara: yangilanish osilib qolsa ham bir martalik parol ko'rsatiladi.
        await settleWithin(queryClient.invalidateQueries({ queryKey: accessKeys.all }), REFRESH_WAIT_MS);
        return issued;
      } finally {
        setPending(false);
      }
    },
    [queryClient, studentId],
  );
  // Ikki marta yuborish (Enter + tugma, dblclick) ikkita parol yaratmasin: ikkinchi chaqiruv birinchisining natijasini oladi.
  const issue = useSingleFlight(run);
  return { issue, pending };
}

/**
 * Yangi 6 xonali kod (oldingisi yopiladi). Natija darhol keshga yoziladi: «yaratildi» xabaridan keyin ham eski (yopiq) kod
 * ko'rinib qolmasin va bo'sh holatdagi «Kod yaratish» tugmasi eski `null` bilan qayta faollashib, ikkinchi kod yaratmasin.
 */
export function useGenerateInviteCode(studentId: string): { generate: () => Promise<InviteCode>; isPending: boolean } {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  const mutation = useMutation({
    mutationFn: () => api.access.generateInviteCode(studentId),
    onSuccess: (invite: InviteCode) => {
      queryClient.setQueryData<InviteCode | null>(accessKeys.inviteCode(studentId), invite);
      void queryClient.invalidateQueries({ queryKey: accessKeys.all });
      toast.success(t('access.invite.created'));
    },
    onError: (error) => toast.error(t(errorKey(error))),
  });
  // Tez-tez bosish ikkinchi kod yaratmasin (`isPending` qayta chizilgunicha tugma hali faol bo'ladi).
  const once = useSingleFlight(mutation.mutateAsync);
  return { generate: () => once(), isPending: mutation.isPending };
}

export function useRejectRecovery(studentId: string): { reject: (requestId: string) => Promise<void>; isPending: boolean } {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  const mutation = useMutation({
    mutationFn: (requestId: string) => api.access.rejectRecovery(studentId, requestId),
    // Yangilanish tugagach tasdiq oynasi yopiladi: so'rov yo'qolgan bo'ladi va fokus to'g'ri joyga qaytadi.
    onSuccess: async () => {
      toast.success(t('access.recovery.rejected'));
      await queryClient.invalidateQueries({ queryKey: accessKeys.all });
    },
    onError: (error) => toast.error(t(errorKey(error))),
  });
  const once = useSingleFlight(mutation.mutateAsync);
  return { reject: (requestId) => once(requestId), isPending: mutation.isPending };
}
