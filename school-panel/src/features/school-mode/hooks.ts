'use client';

import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { api } from '@/data/api';
import type { DeviceFilter, ExceptionFilter, RemindResult } from '@/data/mock/services/school-mode';
import type { HolidayInput } from '@/data/schemas/school';
import type { AllowedAppInput, EmergencyInput, ExceptionInput, PolicyPatch, ShiftUpdateInput } from '@/data/schemas/school-mode';
import { type TKey, useI18n } from '@/i18n';
import { smErrorKey } from './lib';

/** Jonli holat yangilanish oralig'i. */
export const LIVE_INTERVAL_MS = 10_000;
const SLOW_INTERVAL_MS = 30_000;

export const smKeys = {
  all: ['schoolMode'] as const,
  overview: ['schoolMode', 'overview'] as const,
  devices: (filter: DeviceFilter) => ['schoolMode', 'devices', filter] as const,
  policy: ['schoolMode', 'policy'] as const,
  shifts: ['schoolMode', 'shifts'] as const,
  exceptions: (filter: ExceptionFilter) => ['schoolMode', 'exceptions', filter] as const,
};

export function useSmOverview() {
  return useQuery({ queryKey: smKeys.overview, queryFn: () => api.schoolMode.overview(), refetchInterval: LIVE_INTERVAL_MS });
}

export function useSmDevices(filter: DeviceFilter) {
  return useQuery({
    queryKey: smKeys.devices(filter),
    queryFn: () => api.schoolMode.devices(filter),
    placeholderData: keepPreviousData,
    refetchInterval: LIVE_INTERVAL_MS,
  });
}

export function useSmPolicy() {
  return useQuery({ queryKey: smKeys.policy, queryFn: () => api.schoolMode.policy() });
}

export function useSmShifts() {
  return useQuery({ queryKey: smKeys.shifts, queryFn: () => api.schoolMode.shifts(), refetchInterval: SLOW_INTERVAL_MS });
}

export function useSmExceptions(filter: ExceptionFilter) {
  return useQuery({
    queryKey: smKeys.exceptions(filter),
    queryFn: () => api.schoolMode.exceptions(filter),
    placeholderData: keepPreviousData,
    refetchInterval: SLOW_INTERVAL_MS,
  });
}

/** O'zgarish: barcha so'rovlarni yangilaydi, toast ko'rsatadi (xato — modul kaliti bilan). */
function useSmMutation<TVars, TResult>(fn: (vars: TVars) => Promise<TResult>, success: TKey | ((result: TResult) => string | null)) {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  return useMutation({
    mutationFn: fn,
    onSuccess: (result) => {
      void queryClient.invalidateQueries();
      const message = typeof success === 'function' ? success(result) : t(success);
      if (message) toast.success(message);
    },
    onError: (error) => toast.error(t(smErrorKey(error))),
  });
}

export function useUpdatePolicy() {
  return useSmMutation((patch: PolicyPatch) => api.schoolMode.updatePolicy(patch), 'schoolMode.policies.saved');
}

export function useAddAllowedApp() {
  return useSmMutation((input: AllowedAppInput) => api.schoolMode.addAllowedApp(input), 'schoolMode.policies.appAdded');
}

export function useRemoveAllowedApp() {
  return useSmMutation((id: string) => api.schoolMode.removeAllowedApp(id), 'schoolMode.policies.appRemoved');
}

export function useUpdateShift() {
  return useSmMutation(({ id, input }: { id: string; input: ShiftUpdateInput }) => api.schoolMode.updateShift(id, input), 'schoolMode.schedule.saved');
}

export function useCreateException() {
  return useSmMutation((input: ExceptionInput) => api.schoolMode.createException(input), 'schoolMode.exceptions.created');
}

export function useRevokeException() {
  return useSmMutation((id: string) => api.schoolMode.revokeException(id), 'schoolMode.exceptions.revoked');
}

export function useActivateEmergency() {
  return useSmMutation((input: EmergencyInput) => api.schoolMode.activateEmergency(input), 'schoolMode.emergency.activated');
}

export function useDeactivateEmergency() {
  return useSmMutation(() => api.schoolMode.deactivateEmergency(), 'schoolMode.emergency.restored');
}

export function useRemindParents() {
  const { t } = useI18n();
  return useSmMutation(
    (studentIds: string[]) => api.schoolMode.remindParents(studentIds),
    (result: RemindResult) => (result.sent > 0 ? t('schoolMode.devices.remindSent', { count: result.sent }) : t('schoolMode.devices.remindNone')),
  );
}

export function useAddHoliday() {
  return useSmMutation((input: HolidayInput) => api.school.addHoliday(input), 'schoolMode.holidays.added');
}

export function useRemoveHoliday() {
  return useSmMutation((id: string) => api.school.removeHoliday(id), 'schoolMode.holidays.removed');
}
