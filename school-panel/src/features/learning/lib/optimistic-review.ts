import type { QueryClient } from '@tanstack/react-query';

import type { StudentSubmissionRow } from '@/data/contracts';
import type { ReviewInput } from '@/data/schemas/learning';
import { applyReview, toReviewBody } from './submissions';

/** Yozma vazifa topshiriqlari so'rov kaliti (hooks bilan bir xil). */
export const submissionsKey = (assignmentId: string) => ['learning', 'submissions', assignmentId] as const;

export type ReviewContext = { previous: StudentSubmissionRow[] | undefined };

/**
 * Optimistik yangilanish: tekshiruv natijasi serverdan javob kelmasdan jadvalda ko'rinadi.
 * Avvalgi holat qaytariladi (`rollbackReview`) — xato bo'lsa jadval eski holatiga qaytadi.
 */
export async function applyOptimisticReview(
  queryClient: QueryClient,
  assignmentId: string,
  submissionId: string,
  review: ReviewInput,
  reviewedAt: string = new Date().toISOString(),
): Promise<ReviewContext> {
  const key = submissionsKey(assignmentId);
  await queryClient.cancelQueries({ queryKey: key });
  const previous = queryClient.getQueryData<StudentSubmissionRow[]>(key);
  const patch = toReviewBody(review.status, review.note ?? '');
  queryClient.setQueryData<StudentSubmissionRow[]>(key, (rows) => rows && applyReview(rows, submissionId, patch, reviewedAt));
  return { previous };
}

export function rollbackReview(queryClient: QueryClient, assignmentId: string, context: ReviewContext | undefined): void {
  if (context?.previous) queryClient.setQueryData(submissionsKey(assignmentId), context.previous);
}
