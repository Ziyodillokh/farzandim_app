'use client';

import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { api } from '@/data/api';
import type { AssignmentInput, MaterialFilter, ReviewInput } from '@/data/schemas/learning';
import { type TKey, useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';
import { applyOptimisticReview, rollbackReview, submissionsKey } from './lib/optimistic-review';

export const learningKeys = {
  all: ['learning'] as const,
  activity: (classId?: string) => ['learning', 'activity', classId ?? 'all'] as const,
  interests: ['learning', 'interests'] as const,
  materials: (filter: MaterialFilter) => ['learning', 'materials', filter] as const,
  assignments: ['learning', 'assignments'] as const,
  classOptions: ['learning', 'class-options'] as const,
  submissions: submissionsKey,
};

/** Rasm havolalari ~1 soat amal qiladi — ro'yxat shundan ancha oldin yangilanadi. */
const SUBMISSIONS_STALE_MS = 10 * 60_000;

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

/** Yozma vazifa topshiriqlari (o'quvchilar va ularning ishlari). `enabled=false` — so'rov yuborilmaydi. */
export function useAssignmentSubmissions(assignmentId: string | null, enabled = true) {
  return useQuery({
    queryKey: learningKeys.submissions(assignmentId ?? ''),
    queryFn: () => api.learning.submissions(assignmentId ?? ''),
    enabled: Boolean(assignmentId) && enabled,
    staleTime: SUBMISSIONS_STALE_MS,
  });
}

type ReviewVars = { submissionId: string; review: ReviewInput };

/**
 * Ishni tekshirish: natija darhol jadvalda ko'rinadi (optimistik), xato bo'lsa avvalgi holat qaytariladi.
 * Server javobiga tayanmaymiz — yakunda ro'yxat qayta yuklanadi.
 */
export function useReviewSubmission(assignmentId: string) {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  return useMutation({
    mutationFn: ({ submissionId, review }: ReviewVars) => api.learning.reviewSubmission(submissionId, review),
    onMutate: ({ submissionId, review }) => applyOptimisticReview(queryClient, assignmentId, submissionId, review),
    onError: (error, _vars, context) => {
      rollbackReview(queryClient, assignmentId, context);
      toast.error(`${t('learning.submissions.drawer.failed')}. ${t(errorKey(error))}`);
    },
    onSuccess: (_result, { review }) => {
      toast.success(t(review.status === 'ACCEPTED' ? 'learning.submissions.drawer.accepted' : 'learning.submissions.drawer.returned'));
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: learningKeys.submissions(assignmentId) });
    },
  });
}
