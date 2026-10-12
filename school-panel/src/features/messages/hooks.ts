'use client';

import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { api } from '@/data/api';
import type { AnnouncementFilter, SendOptions } from '@/data/mock/services/comms';
import type { AnnouncementInput, AudienceInput } from '@/data/schemas/comms';
import { type TKey, useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';

export const messageKeys = {
  all: ['comms'] as const,
  list: (filter: AnnouncementFilter) => ['comms', 'announcements', 'list', filter] as const,
  detail: (id: string) => ['comms', 'announcements', 'detail', id] as const,
  reach: (audience: AudienceInput) => ['comms', 'reach', audience] as const,
  templates: ['comms', 'templates'] as const,
  guardians: (search: string) => ['guardians', 'picker', search] as const,
};

/** "O'qildi" vaqt bilan o'sadi — ro'yxat har 20 soniyada yangilanadi. */
const LIVE_REFRESH_MS = 20_000;

export function useAnnouncements(filter: AnnouncementFilter) {
  return useQuery({
    queryKey: messageKeys.list(filter),
    queryFn: () => api.comms.announcements.list(filter),
    placeholderData: keepPreviousData,
    refetchInterval: LIVE_REFRESH_MS,
  });
}

export function useAnnouncement(id: string | null) {
  return useQuery({
    queryKey: messageKeys.detail(id ?? ''),
    queryFn: () => api.comms.announcements.get(id ?? ''),
    enabled: Boolean(id),
    refetchInterval: LIVE_REFRESH_MS,
  });
}

export function useAudienceReach(audience: AudienceInput) {
  return useQuery({
    queryKey: messageKeys.reach(audience),
    queryFn: () => api.comms.audienceSize(audience),
    placeholderData: keepPreviousData,
  });
}

export function useTemplates() {
  return useQuery({ queryKey: messageKeys.templates, queryFn: () => api.comms.templates(), staleTime: Infinity });
}

export function useGuardianSearch(search: string) {
  return useQuery({
    queryKey: messageKeys.guardians(search),
    queryFn: () => api.guardians.list({ search, limit: 8 }),
    placeholderData: keepPreviousData,
  });
}

export function useClassChoices() {
  return useQuery({ queryKey: ['classes', 'options'], queryFn: () => api.classes.list(), staleTime: 60_000 });
}

/** Mutatsiya: muvaffaqiyatda barcha so'rovlar yangilanadi va toast chiqadi. */
export function useCommsMutation<TVars, TResult>(fn: (vars: TVars) => Promise<TResult>, successKey: TKey | ((result: TResult) => string)) {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  return useMutation({
    mutationFn: fn,
    onSuccess: (result) => {
      void queryClient.invalidateQueries();
      toast.success(typeof successKey === 'function' ? successKey(result) : t(successKey));
    },
    onError: (error) => toast.error(t(errorKey(error))),
  });
}

export function useSaveDraft() {
  return useCommsMutation(({ input, id }: { input: AnnouncementInput; id?: string }) => api.comms.announcements.saveDraft(input, id), 'messages.toasts.drafted');
}

export function useSendAnnouncement() {
  const { t } = useI18n();
  return useCommsMutation(
    ({ input, options }: { input: AnnouncementInput; options: SendOptions }) => api.comms.announcements.send(input, options),
    (result) => t(result.status === 'SCHEDULED' ? 'messages.toasts.scheduled' : 'messages.toasts.sent'),
  );
}

export function useSendNow() {
  return useCommsMutation((id: string) => api.comms.announcements.sendNow(id), 'messages.toasts.sent');
}

export function useRemoveAnnouncement() {
  return useCommsMutation((id: string) => api.comms.announcements.remove(id), 'messages.toasts.deleted');
}

export function useDuplicateAnnouncement() {
  return useCommsMutation((id: string) => api.comms.announcements.duplicate(id), 'messages.toasts.duplicated');
}
