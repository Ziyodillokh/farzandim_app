'use client';

import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { api } from '@/data/api';
import type { CareRequestStatus } from '@/data/contracts';
import type { CareRequestFilter } from '@/data/mock/services/care';
import type { CareAggregateQuery, CareQuestionInput, CareSurveyInput } from '@/data/schemas/care';
import { type TKey, useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';

export const careKeys = {
  all: ['care'] as const,
  surveyOptions: ['care', 'survey-options'] as const,
  aggregate: (query: CareAggregateQuery) => ['care', 'aggregate', query] as const,
  requests: (filter: CareRequestFilter) => ['care', 'requests', filter] as const,
  request: (id: string) => ['care', 'request', id] as const,
  surveys: ['care', 'surveys'] as const,
  questions: ['care', 'questions'] as const,
};

export function useCareSurveyOptions() {
  return useQuery({ queryKey: careKeys.surveyOptions, queryFn: () => api.care.surveyOptions() });
}

export function useCareAggregate(query: CareAggregateQuery, enabled = true) {
  return useQuery({
    queryKey: careKeys.aggregate(query),
    queryFn: () => api.care.aggregate(query),
    placeholderData: keepPreviousData,
    enabled,
  });
}

export function useCareRequests(filter: CareRequestFilter, enabled = true) {
  return useQuery({
    queryKey: careKeys.requests(filter),
    queryFn: () => api.care.listRequests(filter),
    placeholderData: keepPreviousData,
    enabled,
  });
}

export function useCareRequest(id: string | null) {
  return useQuery({ queryKey: careKeys.request(id ?? ''), queryFn: () => api.care.getRequest(id ?? ''), enabled: Boolean(id) });
}

export function useCareSurveys() {
  return useQuery({ queryKey: careKeys.surveys, queryFn: () => api.care.listSurveys() });
}

export function useCareQuestions() {
  return useQuery({ queryKey: careKeys.questions, queryFn: () => api.care.listQuestions() });
}

/** Bola ovozi o'zgarishlari — ro'yxatlarni yangilaydi va toast ko'rsatadi. */
function useCareMutation<TVars, TResult>(fn: (vars: TVars) => Promise<TResult>, successKey: TKey) {
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

export function useUpdateRequestStatus() {
  return useCareMutation(
    ({ id, status }: { id: string; status: CareRequestStatus }) => api.care.updateRequestStatus(id, status),
    'care.request.statusChanged',
  );
}

export function useAddRequestNote() {
  return useCareMutation(({ id, text }: { id: string; text: string }) => api.care.addRequestNote(id, text), 'care.request.noteAdded');
}

export function useScheduleMeeting() {
  return useCareMutation(
    ({ id, meetingAt }: { id: string; meetingAt: string }) => api.care.scheduleMeeting(id, meetingAt),
    'care.request.meetingSaved',
  );
}

export function useActivateProtocol() {
  return useCareMutation((id: string) => api.care.activateProtocol(id), 'care.request.protocol.activated');
}

export function useCreateSurvey() {
  return useCareMutation((input: CareSurveyInput) => api.care.createSurvey(input), 'care.surveys.created');
}

export function useUpdateSurvey() {
  return useCareMutation(({ id, input }: { id: string; input: CareSurveyInput }) => api.care.updateSurvey(id, input), 'care.surveys.updated');
}

export function useDeleteSurvey() {
  return useCareMutation((id: string) => api.care.deleteSurvey(id), 'care.surveys.deleted');
}

export function useActivateSurvey() {
  return useCareMutation((id: string) => api.care.activateSurvey(id), 'care.surveys.activated');
}

export function useCloseSurvey() {
  return useCareMutation((id: string) => api.care.closeSurvey(id), 'care.surveys.closed');
}

export function useCreateQuestion() {
  return useCareMutation((input: CareQuestionInput) => api.care.createQuestion(input), 'care.questions.created');
}

export function useUpdateQuestion() {
  return useCareMutation(
    ({ id, input }: { id: string; input: CareQuestionInput }) => api.care.updateQuestion(id, input),
    'care.questions.updated',
  );
}

export function useDeleteQuestion() {
  return useCareMutation((id: string) => api.care.deleteQuestion(id), 'care.questions.deleted');
}
