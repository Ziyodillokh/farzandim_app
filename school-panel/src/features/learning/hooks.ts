'use client';

import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { api } from '@/data/api';
import type { AssignmentInput, MaterialFilter } from '@/data/schemas/learning';
import { type TKey, useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';

export const learningKeys = {
  all: ['learning'] as const,
  activity: (classId?: string) => ['learning', 'activity', classId ?? 'all'] as const,
  interests: ['learning', 'interests'] as const,
  materials: (filter: MaterialFilter) => ['learning', 'materials', filter] as const,
  assignments: ['learning', 'assignments'] as const,
  classOptions: ['learning', 'class-options'] as const,
};

export function useLearningActivity(classId?: string) {
  return useQuery({ queryKey: learningKeys.activity(classId), queryFn: () => api.learning.activity({ classId }), placeholderData: keepPreviousData });
}

export function useLearningInterests() {
  return useQuery({ queryKey: learningKeys.interests, queryFn: () => api.learning.interests(), staleTime: 5 * 60_000 });
}

export function useLearningMaterials(filter: MaterialFilter) {
  return useQuery({ queryKey: learningKeys.materials(filter), queryFn: () => api.learning.materials(filter), placeholderData: keepPreviousData });
}

export function useLearningAssignments() {
  return useQuery({ queryKey: learningKeys.assignments, queryFn: () => api.learning.assignments() });
}

export function useLearningClassOptions() {
  return useQuery({ queryKey: learningKeys.classOptions, queryFn: () => api.learning.classOptions(), staleTime: 60_000 });
}

function useLearningMutation<TVars, TResult>(fn: (vars: TVars) => Promise<TResult>, successKey: TKey) {
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

export function useCreateAssignment() {
  return useLearningMutation((input: AssignmentInput) => api.learning.createAssignment(input), 'learning.assignments.created');
}

export function useDeleteAssignment() {
  return useLearningMutation((id: string) => api.learning.deleteAssignment(id), 'learning.assignments.deleted');
}
