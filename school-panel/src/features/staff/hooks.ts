'use client';

import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { api } from '@/data/api';
import type { ListQuery, RoleKey } from '@/data/contracts';
import type { StaffInput } from '@/data/schemas/staff';
import { useI18n } from '@/i18n';
import { staffErrorKey } from './account';

export type StaffFilter = ListQuery & { role?: RoleKey; active?: boolean };

export const staffKeys = {
  list: (filter: StaffFilter) => ['staff', 'list', filter] as const,
  summary: ['staff', 'summary'] as const,
  roles: ['staff', 'roles'] as const,
};

export function useStaffList(filter: StaffFilter) {
  return useQuery({ queryKey: staffKeys.list(filter), queryFn: () => api.staff.list(filter), placeholderData: keepPreviousData });
}

export function useStaffSummary() {
  return useQuery({ queryKey: staffKeys.summary, queryFn: () => api.staff.summary() });
}

export function useRoles() {
  return useQuery({ queryKey: staffKeys.roles, queryFn: () => api.staff.roles(), staleTime: Infinity });
}

function useStaffMutation<TVars, TResult>(fn: (vars: TVars) => Promise<TResult>, success: (result: TResult) => string) {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  return useMutation({
    mutationFn: fn,
    onSuccess: (result) => {
      void queryClient.invalidateQueries();
      toast.success(success(result));
    },
    // 409 'username' — band login haqida aniq xabar; boshqa 409 — demo / o'z hisobi xabari; qolganlari — umumiy.
    onError: (error) => toast.error(t(staffErrorKey(error))),
  });
}

export function useCreateStaff() {
  const { t } = useI18n();
  return useStaffMutation((input: StaffInput) => api.staff.create(input), () => t('staff.created'));
}

export function useUpdateStaff() {
  const { t } = useI18n();
  return useStaffMutation(({ id, input }: { id: string; input: StaffInput }) => api.staff.update(id, input), () => t('staff.updated'));
}

export function useSetStaffActive() {
  const { t } = useI18n();
  return useStaffMutation(
    ({ id, active }: { id: string; active: boolean }) => api.staff.setActive(id, active),
    (s) => t(s.active ? 'staff.activated' : 'staff.deactivated'),
  );
}

export function useSetStaffAccount() {
  const { t } = useI18n();
  return useStaffMutation(
    ({ id, username, password }: { id: string; username: string; password: string }) => api.staff.setAccount(id, { username, password }),
    () => t('staff.account.saved'),
  );
}

export function useRemoveStaffAccount() {
  const { t } = useI18n();
  return useStaffMutation((id: string) => api.staff.removeAccount(id), () => t('staff.account.removed'));
}
