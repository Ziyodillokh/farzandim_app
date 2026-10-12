'use client';

import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { api } from '@/data/api';
import type { StudentFilter } from '@/data/mock/services/students';
import type { GuardianInput, StudentCreateInput, StudentInput } from '@/data/schemas/students';
import { useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';

export const studentKeys = {
  all: ['students'] as const,
  list: (filter: StudentFilter) => ['students', 'list', filter] as const,
  detail: (id: string) => ['students', 'detail', id] as const,
  month: (id: string, month: string) => ['students', 'month', id, month] as const,
  guardians: ['guardians'] as const,
};

export function useStudents(filter: StudentFilter) {
  return useQuery({ queryKey: studentKeys.list(filter), queryFn: () => api.students.list(filter), placeholderData: keepPreviousData });
}

export function useStudent(id: string | null) {
  return useQuery({ queryKey: studentKeys.detail(id ?? ''), queryFn: () => api.students.get(id ?? ''), enabled: Boolean(id) });
}

export function useStudentMonth(id: string | null, month: string) {
  return useQuery({
    queryKey: studentKeys.month(id ?? '', month),
    queryFn: () => api.attendance.studentMonth(id ?? '', month),
    enabled: Boolean(id),
  });
}

export function useClassOptions() {
  return useQuery({ queryKey: ['students', 'class-options'], queryFn: () => api.students.classOptions(), staleTime: 60_000 });
}

/** O'quvchi o'zgarishlari — barcha bog'liq ro'yxatlarni yangilaydi va toast ko'rsatadi. */
function useStudentMutation<TVars, TResult>(fn: (vars: TVars) => Promise<TResult>, successKey: Parameters<ReturnType<typeof useI18n>['t']>[0]) {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  return useMutation({
    mutationFn: fn,
    onSuccess: () => {
      void queryClient.invalidateQueries();
      toast.success(t(successKey));
    },
    onError: (error) => toast.error(t(errorKey(error))),
  });
}

export function useCreateStudent() {
  return useStudentMutation((input: StudentCreateInput) => api.students.create(input), 'students.created');
}

export function useUpdateStudent() {
  return useStudentMutation(({ id, input }: { id: string; input: StudentInput }) => api.students.update(id, input), 'students.updated');
}

export function useArchiveStudent() {
  return useStudentMutation(({ id, archived }: { id: string; archived: boolean }) => api.students.setArchived(id, archived), 'common.saved');
}

export function useInviteGuardian() {
  return useStudentMutation((guardianId: string) => api.guardians.invite(guardianId), 'common.done');
}

export function useSimulateLink() {
  return useStudentMutation((guardianId: string) => api.guardians.simulateLink(guardianId), 'common.done');
}

export function useAddGuardian() {
  return useStudentMutation(({ studentId, input }: { studentId: string; input: GuardianInput }) => api.guardians.addToStudent(studentId, input), 'common.saved');
}
