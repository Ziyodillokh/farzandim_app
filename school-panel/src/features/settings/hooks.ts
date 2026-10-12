'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { api } from '@/data/api';
import type { SchoolProfileInput } from '@/data/schemas/school';
import { useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';

function useSettingsMutation<TVars, TResult>(fn: (vars: TVars) => Promise<TResult>, success: (vars: TVars) => string) {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  return useMutation({
    mutationFn: fn,
    onSuccess: (_result, vars) => {
      void queryClient.invalidateQueries();
      toast.success(success(vars));
    },
    onError: (error) => toast.error(t(errorKey(error))),
  });
}

export function useUpdateProfile() {
  const { t } = useI18n();
  return useSettingsMutation((input: SchoolProfileInput) => api.school.updateProfile(input), () => t('settings.profile.saved'));
}

export function useSetLogo() {
  const { t } = useI18n();
  return useSettingsMutation(
    (logo: string | null) => api.school.setLogo(logo),
    (logo) => t(logo ? 'settings.logo.uploaded' : 'settings.logo.removed'),
  );
}

/** Demo ma'lumotlarni tiklash (sinxron servis) — barcha so'rovlar yangilanadi. */
export function useDemoReset(): () => boolean {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  return () => {
    try {
      api.demo.reset();
      void queryClient.invalidateQueries();
      toast.success(t('demo.resetDone'));
      return true;
    } catch (error) {
      toast.error(t(errorKey(error)));
      return false;
    }
  };
}
