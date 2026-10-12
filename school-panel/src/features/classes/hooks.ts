'use client';

import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { api } from '@/data/api';
import { ServiceError } from '@/data/contracts';
import type { StudentFilter } from '@/data/mock/services/students';
import type { BulkInviteInput, ClassInput } from '@/data/schemas/classes';
import { type TKey, useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';

const MODE_REFRESH_MS = 15_000;
const BOARD_REFRESH_MS = 30_000;

export type ClassFilter = { shiftId?: string; search?: string };

export const classKeys = {
  all: ['classes'] as const,
  list: (filter: ClassFilter) => ['classes', 'list', filter] as const,
  detail: (id: string) => ['classes', 'detail', id] as const,
  modes: ['classes', 'modes'] as const,
  mode: (id: string) => ['classes', 'mode', id] as const,
  board: ['classes', 'attendance-today'] as const,
  homerooms: ['staff', 'options', 'HOMEROOM'] as const,
  students: (filter: StudentFilter) => ['classes', 'students', filter] as const,
};

export function useClasses(filter: ClassFilter) {
  return useQuery({ queryKey: classKeys.list(filter), queryFn: () => api.classes.list(filter), placeholderData: keepPreviousData });
}

export function useClassDetail(id: string | null) {
  return useQuery({ queryKey: classKeys.detail(id ?? ''), queryFn: () => api.classes.detail(id ?? ''), enabled: Boolean(id) });
}

/** Sinf sahifasidagi o'quvchilar ro'yxati (sahifalangan). */
export function useClassStudents(filter: StudentFilter, enabled: boolean) {
  return useQuery({ queryKey: classKeys.students(filter), queryFn: () => api.students.list(filter), enabled, placeholderData: keepPreviousData });
}

/** Barcha sinflarning School Mode holati — demo soati bilan birga yangilanadi. */
export function useClassModes() {
  return useQuery({ queryKey: classKeys.modes, queryFn: () => api.classes.modesNow(), refetchInterval: MODE_REFRESH_MS });
}

export function useClassMode(id: string | null) {
  return useQuery({
    queryKey: classKeys.mode(id ?? ''),
    queryFn: () => api.classes.modeNow(id ?? ''),
    enabled: Boolean(id),
    refetchInterval: MODE_REFRESH_MS,
  });
}

/** Bugungi davomat taxtasi (faqat `attendance.view` bo'lsa). */
export function useTodayBoard(enabled: boolean) {
  return useQuery({ queryKey: classKeys.board, queryFn: () => api.attendance.board(), enabled, refetchInterval: BOARD_REFRESH_MS });
}

export function useHomeroomOptions(enabled = true) {
  return useQuery({ queryKey: classKeys.homerooms, queryFn: () => api.staff.options('HOMEROOM'), enabled, staleTime: 60_000 });
}

function isConflict(error: unknown): boolean {
  return error instanceof ServiceError && error.code === 'CONFLICT';
}

/** Sinf o'zgarishlari: barcha ro'yxatlarni yangilash, toast; CONFLICT — maxsus matn. */
function useClassMutation<TVars, TResult>(
  fn: (vars: TVars) => Promise<TResult>,
  success: (result: TResult, t: ReturnType<typeof useI18n>['t']) => string,
  conflictKey?: TKey,
) {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  return useMutation({
    mutationFn: fn,
    onSuccess: (result) => {
      void queryClient.invalidateQueries();
      toast.success(success(result, t));
    },
    onError: (error) => toast.error(t(conflictKey && isConflict(error) ? conflictKey : errorKey(error))),
  });
}

export function useCreateClass() {
  return useClassMutation((input: ClassInput) => api.classes.create(input), (_r, t) => t('classes.created'), 'classes.errors.duplicate');
}

export function useUpdateClass() {
  return useClassMutation(
    ({ id, input }: { id: string; input: ClassInput }) => api.classes.update(id, input),
    (_r, t) => t('classes.updated'),
    'classes.errors.duplicate',
  );
}

export function useDeleteClass() {
  return useClassMutation((id: string) => api.classes.remove(id), (_r, t) => t('classes.deleted'), 'classes.errors.hasStudents');
}

export function useInviteClassGuardians() {
  return useClassMutation(
    (filter: BulkInviteInput) => api.classes.inviteGuardians(filter),
    (r, t) => t('classes.view.invited', { count: r.invited }),
  );
}
