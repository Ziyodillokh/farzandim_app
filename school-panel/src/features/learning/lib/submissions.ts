import type { StudentSubmissionRow, SubmissionState, SubmissionStatus } from '@/data/contracts';
import { REVIEW_NOTE_MAX } from '@/data/schemas/learning';

/**
 * Yozma vazifa topshiriqlari: holat, sanoq, filtr va tekshiruvni "xushxabar bilan" (optimistik)
 * qo'llash — hammasi sof funksiyalar (testlanadi).
 */

/** Jadval holatlari tartibi (filtr va xulosa uchun). */
export const SUBMISSION_STATES: readonly SubmissionState[] = ['SUBMITTED', 'ACCEPTED', 'RETURNED', 'NOT_SUBMITTED'];

export function stateOf(row: Pick<StudentSubmissionRow, 'submission'>): SubmissionState {
  return row.submission?.status ?? 'NOT_SUBMITTED';
}

export type SubmissionCounts = {
  total: number;
  /** Ish yuborganlar (har qanday holatda). */
  submitted: number;
  /** Tekshirilishini kutayotganlar. */
  pending: number;
  accepted: number;
  returned: number;
  notSubmitted: number;
};

export function countSubmissions(rows: readonly StudentSubmissionRow[]): SubmissionCounts {
  const counts: SubmissionCounts = { total: rows.length, submitted: 0, pending: 0, accepted: 0, returned: 0, notSubmitted: 0 };
  for (const row of rows) {
    const state = stateOf(row);
    if (state === 'NOT_SUBMITTED') counts.notSubmitted += 1;
    else counts.submitted += 1;
    if (state === 'SUBMITTED') counts.pending += 1;
    if (state === 'ACCEPTED') counts.accepted += 1;
    if (state === 'RETURNED') counts.returned += 1;
  }
  return counts;
}

export type SubmissionFilter = SubmissionState | 'ALL';

export function filterRows(rows: readonly StudentSubmissionRow[], filter: SubmissionFilter): StudentSubmissionRow[] {
  return filter === 'ALL' ? [...rows] : rows.filter((row) => stateOf(row) === filter);
}

/** Tekshirish natijasi (optimistik yangilanish uchun). */
export type ReviewPatch = { status: Extract<SubmissionStatus, 'ACCEPTED' | 'RETURNED'>; note?: string };

/** Berilgan ish holatini yangilaydi (asl ro'yxat o'zgarmaydi); topilmasa — o'sha ro'yxat. */
export function applyReview(rows: readonly StudentSubmissionRow[], submissionId: string, review: ReviewPatch, reviewedAt: string): StudentSubmissionRow[] {
  if (!rows.some((row) => row.submission?.id === submissionId)) return [...rows];
  return rows.map((row) =>
    row.submission?.id === submissionId
      ? { ...row, submission: { ...row.submission, status: review.status, reviewedAt, reviewNote: review.note?.trim() || null } }
      : row,
  );
}

export type ReviewNoteError = 'required' | 'tooLong';

/** Qaytarishda izoh majburiy; har holda ≤ 500 belgi. */
export function reviewNoteError(status: ReviewPatch['status'], note: string): ReviewNoteError | null {
  const text = note.trim();
  if (text.length > REVIEW_NOTE_MAX) return 'tooLong';
  if (status === 'RETURNED' && text.length === 0) return 'required';
  return null;
}

/** Jo'natiladigan tana: bo'sh izoh umuman yuborilmaydi. */
export function toReviewBody(status: ReviewPatch['status'], note: string): ReviewPatch {
  const text = note.trim();
  return text ? { status, note: text } : { status };
}

/** Joriy ishdan keyingi tekshirilmagan ish (ro'yxat tartibida, oxiriga yetsa boshidan); yo'q bo'lsa `null`. */
export function nextPendingStudentId(rows: readonly StudentSubmissionRow[], currentStudentId: string): string | null {
  const start = rows.findIndex((row) => row.student.id === currentStudentId);
  for (let step = 1; step <= rows.length; step++) {
    const row = rows[(start + step) % rows.length];
    if (row && row.student.id !== currentStudentId && stateOf(row) === 'SUBMITTED') return row.student.id;
  }
  return null;
}
