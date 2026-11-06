'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback, useState } from 'react';
import { toast } from 'sonner';

import { api } from '@/data/api';
import type { IssuedCredentials, IssueCredentialsInput } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';

export const accessKeys = {
  all: ['access'] as const,
  credentials: (studentId: string) => ['access', 'credentials', studentId] as const,
  recovery: (studentId: string) => ['access', 'recovery', studentId] as const,
  inviteCode: (studentId: string) => ['access', 'invite-code', studentId] as const,
};

export function useCredentials(studentId: string, enabled: boolean) {
  return useQuery({ queryKey: accessKeys.credentials(studentId), queryFn: () => api.access.credentials(studentId), enabled });
}

export function useRecoveryRequests(studentId: string, enabled: boolean) {
  return useQuery({ queryKey: accessKeys.recovery(studentId), queryFn: () => api.access.recoveryRequests(studentId), enabled });
}

export function useInviteCode(studentId: string, enabled: boolean) {
  return useQuery({ queryKey: accessKeys.inviteCode(studentId), queryFn: () => api.access.inviteCode(studentId), enabled });
}

/**
 * Kirish ma'lumotlarini berish/tiklash. Vaqtinchalik parol `useMutation` orqali EMAS (uning natijasi RQ keshida qoladi),
 * oddiy async chaqiruv bilan: natija faqat chaqiruvchi komponent holatida yashaydi va oyna yopilganda yo'qoladi.
 */
export function useIssueCredentials(studentId: string): { issue: (input: IssueCredentialsInput) => Promise<IssuedCredentials>; pending: boolean } {
  const queryClient = useQueryClient();
  const [pending, setPending] = useState(false);
  const issue = useCallback(
    async (input: IssueCredentialsInput) => {
      setPending(true);
      try {
        const issued = await api.access.issueCredentials(studentId, input);
        void queryClient.invalidateQueries({ queryKey: accessKeys.all });
        return issued;
      } finally {
        setPending(false);
      }
    },
    [queryClient, studentId],
  );
  return { issue, pending };
}

/** Yangi 6 xonali kod (oldingisi yopiladi). */
export function useGenerateInviteCode(studentId: string) {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  return useMutation({
    mutationFn: () => api.access.generateInviteCode(studentId),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: accessKeys.all });
      toast.success(t('access.invite.created'));
    },
    onError: (error) => toast.error(t(errorKey(error))),
  });
}

export function useRejectRecovery(studentId: string) {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  return useMutation({
    mutationFn: (requestId: string) => api.access.rejectRecovery(studentId, requestId),
    // Yangilanish tugagach tasdiq oynasi yopiladi: so'rov yo'qolgan bo'ladi va fokus to'g'ri joyga qaytadi.
    onSuccess: async () => {
      toast.success(t('access.recovery.rejected'));
      await queryClient.invalidateQueries({ queryKey: accessKeys.all });
    },
    onError: (error) => toast.error(t(errorKey(error))),
  });
}
