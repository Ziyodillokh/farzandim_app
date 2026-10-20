'use client';

import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { api } from '@/data/api';
import type { AssignmentFilter, PsychTestFilter, ResultsFilter } from '@/data/mock/services/assessments';
import type { AssignInput, PsychNormsInput, PsychTestInput } from '@/data/schemas/assessments';
import { type TKey, useI18n } from '@/i18n';
import { psychErrorKey } from './lib/labels';

export const assessmentKeys = {
  all: ['assessments'] as const,
  tests: (f: PsychTestFilter) => ['assessments', 'tests', f] as const,
  test: (id: string) => ['assessments', 'test', id] as const,
  assignments: (f: AssignmentFilter) => ['assessments', 'assignments', f] as const,
  results: (testId: string, f: ResultsFilter) => ['assessments', 'results', testId, f] as const,
};

export function useTests(filter: PsychTestFilter = {}) {
  return useQuery({ queryKey: assessmentKeys.tests(filter), queryFn: () => api.assessments.listTests(filter), placeholderData: keepPreviousData });
}

export function useTest(id: string | null) {
  return useQuery({ queryKey: assessmentKeys.test(id ?? ''), queryFn: () => api.assessments.getTest(id ?? ''), enabled: Boolean(id) });
}

export function useClassOptions() {
  return useQuery({ queryKey: ['assessments', 'class-options'], queryFn: () => api.assessments.classOptions(), staleTime: 60_000 });
}

export function useAssignments(filter: AssignmentFilter = {}) {
  return useQuery({
    queryKey: assessmentKeys.assignments(filter),
    queryFn: () => api.assessments.listAssignments(filter),
    placeholderData: keepPreviousData,
  });
}

export function useResults(testId: string | undefined, filter: ResultsFilter = {}) {
  return useQuery({
    queryKey: assessmentKeys.results(testId ?? '', filter),
    queryFn: () => api.assessments.resultsByTest(testId ?? '', filter),
    enabled: Boolean(testId),
    placeholderData: keepPreviousData,
  });
}

/** O'zgarishlar — barcha ro'yxatlarni yangilaydi va toast ko'rsatadi. */
function useAssessmentsMutation<TVars, TResult>(fn: (vars: TVars) => Promise<TResult>, successKey: TKey | ((result: TResult) => string) | null) {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  return useMutation({
    mutationFn: fn,
    onSuccess: (result) => {
      void queryClient.invalidateQueries();
      if (successKey) toast.success(typeof successKey === 'function' ? successKey(result) : t(successKey));
    },
    onError: (error) => toast.error(t(psychErrorKey(error))),
  });
}

export function useCreateTest() {
  return useAssessmentsMutation((input: PsychTestInput) => api.assessments.createTest(input), 'assessments.newTest.created');
}

export function useUpdateTest() {
  return useAssessmentsMutation(({ id, input }: { id: string; input: PsychTestInput }) => api.assessments.updateTest(id, input), 'assessments.builder.saved');
}

export function useUpdateNorms() {
  return useAssessmentsMutation(
    ({ id, norms }: { id: string; norms: PsychNormsInput | null }) => api.assessments.updateNorms(id, norms),
    null,
  );
}

export function usePublishTest() {
  return useAssessmentsMutation((id: string) => api.assessments.publishTest(id), 'assessments.view.published');
}

export function useArchiveTest() {
  return useAssessmentsMutation((id: string) => api.assessments.archiveTest(id), 'assessments.view.archived');
}

export function useDuplicateTest() {
  return useAssessmentsMutation((id: string) => api.assessments.duplicateTest(id), 'assessments.view.duplicated');
}

export function useImportTest() {
  return useAssessmentsMutation((json: string) => api.assessments.importTest(json), 'assessments.importJson.success');
}

export function useAssign() {
  return useAssessmentsMutation((input: AssignInput) => api.assessments.assign(input), 'assessments.assign.success');
}

export function useUnassign() {
  return useAssessmentsMutation((id: string) => api.assessments.unassign(id), 'assessments.assignments.cancelled');
}

export function useCloseAssignment() {
  return useAssessmentsMutation((id: string) => api.assessments.closeAssignment(id), 'assessments.assignments.closed');
}

export function useSimulateCompletion() {
  const { t } = useI18n();
  return useAssessmentsMutation(
    (id: string) => api.assessments.simulateCompletion(id),
    (r) => (r.created ? t('assessments.assignments.simulated', { count: r.created }) : t('assessments.assignments.simulatedNone')),
  );
}

export function useCsvPreview() {
  return useMutation({ mutationFn: (text: string) => api.assessments.previewResultsCsv(text) });
}

export function useImportResultsCsv() {
  const { t } = useI18n();
  return useAssessmentsMutation(
    (text: string) => api.assessments.importResultsCsv(text),
    (r) => t('assessments.csv.result', { created: r.created, skipped: r.skipped.length }),
  );
}

/** JSON eksport — fayl sifatida yuklab olish. */
export function useExportTest() {
  const { t } = useI18n();
  return useMutation({
    mutationFn: (id: string) => api.assessments.exportTest(id),
    onSuccess: (json, id) => {
      const blob = new Blob([json], { type: 'application/json;charset=utf-8' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `${id}.parvoz-test.json`;
      document.body.appendChild(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      toast.success(t('assessments.view.exported'));
    },
    onError: (error) => toast.error(t(psychErrorKey(error))),
  });
}
