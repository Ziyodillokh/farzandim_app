'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { useSession } from '@/auth/use-session';
import { api } from '@/data/api';
import type { StaffAvatarInfo } from '@/data/mock/services/profile';
import { useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';

export const profileKeys = {
  me: ['profile', 'me'] as const,
  avatars: ['staff', 'avatars'] as const,
  demo: ['profile', 'demo'] as const,
};

export function useMe() {
  const session = useSession();
  return useQuery({ queryKey: profileKeys.me, queryFn: () => api.profile.me(), enabled: Boolean(session), staleTime: 60_000 });
}

/** Bitta xodim avatari (umumiy kesh, `select` bilan — faqat shu xodim o'zgarsa qayta chiziladi). */
export function useStaffAvatar(staffId: string | null | undefined) {
  const session = useSession();
  return useQuery({
    queryKey: profileKeys.avatars,
    queryFn: () => api.profile.avatars(),
    enabled: Boolean(session && staffId),
    staleTime: 60_000,
    select: (map: Record<string, StaffAvatarInfo>) => (staffId ? map[staffId] : undefined),
  });
}

export function useDemoProfiles() {
  return useQuery({ queryKey: profileKeys.demo, queryFn: () => api.profile.demoProfiles(), staleTime: 60_000 });
}

export function useSetStaffPhoto() {
  const { t } = useI18n();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ staffId, photo }: { staffId: string; photo: string | null }) => api.profile.setPhoto(staffId, photo),
    onSuccess: (_data, vars) => {
      toast.success(t(vars.photo ? 'profile.photo.uploaded' : 'profile.photo.removed'));
      void queryClient.invalidateQueries();
    },
    onError: (error) => toast.error(t(errorKey(error))),
  });
}
