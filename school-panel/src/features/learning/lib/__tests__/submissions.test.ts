import { describe, expect, it } from 'vitest';

import type { HomeworkSubmission, StudentSubmissionRow, SubmissionStatus } from '@/data/contracts';
import { applyReview, countSubmissions, filterRows, nextPendingStudentId, reviewNoteError, stateOf, toReviewBody } from '../submissions';

const submission = (id: string, status: SubmissionStatus): HomeworkSubmission => ({
  id,
  status,
  comment: null,
  submittedAt: '2026-10-11T16:00:00',
  reviewedAt: status === 'SUBMITTED' ? null : '2026-10-12T08:30:00',
  reviewNote: status === 'RETURNED' ? 'Qayta yozing' : null,
  photos: [{ id: `${id}-p1`, url: 'https://cdn.test/p1.jpg' }],
});

const row = (studentId: string, status: SubmissionStatus | null): StudentSubmissionRow => ({
  student: { id: studentId, fullName: `O'quvchi ${studentId}` },
  classId: 'cls-7a',
  submission: status ? submission(`sub-${studentId}`, status) : null,
});

const ROWS = [row('a', 'SUBMITTED'), row('b', null), row('c', 'ACCEPTED'), row('d', 'RETURNED'), row('e', 'SUBMITTED'), row('f', null)];

describe('stateOf / countSubmissions', () => {
  it('ish yo\'q — «topshirmagan»', () => {
    expect(stateOf(ROWS[1]!)).toBe('NOT_SUBMITTED');
    expect(stateOf(ROWS[0]!)).toBe('SUBMITTED');
    expect(stateOf(ROWS[3]!)).toBe('RETURNED');
  });

  it('holatlar bo\'yicha sanaydi; topshirgan = topshirmaganlardan tashqari hammasi', () => {
    expect(countSubmissions(ROWS)).toEqual({ total: 6, submitted: 4, pending: 2, accepted: 1, returned: 1, notSubmitted: 2 });
    expect(countSubmissions([])).toEqual({ total: 0, submitted: 0, pending: 0, accepted: 0, returned: 0, notSubmitted: 0 });
  });
});

describe('filterRows', () => {
  it('ALL hammasini (nusxada), aks holda faqat shu holatni qaytaradi', () => {
    expect(filterRows(ROWS, 'ALL')).toEqual(ROWS);
    expect(filterRows(ROWS, 'ALL')).not.toBe(ROWS);
    expect(filterRows(ROWS, 'SUBMITTED').map((r) => r.student.id)).toEqual(['a', 'e']);
    expect(filterRows(ROWS, 'NOT_SUBMITTED').map((r) => r.student.id)).toEqual(['b', 'f']);
  });
});

describe('applyReview (optimistik yangilanish)', () => {
  it('faqat kerakli ishni yangilaydi, asl ro\'yxat o\'zgarmaydi', () => {
    const next = applyReview(ROWS, 'sub-a', { status: 'RETURNED', note: '  Rasm xira  ' }, '2026-10-12T10:00:00');
    expect(next[0]?.submission).toMatchObject({ status: 'RETURNED', reviewNote: 'Rasm xira', reviewedAt: '2026-10-12T10:00:00' });
    expect(next[0]?.submission?.photos).toEqual(ROWS[0]?.submission?.photos);
    expect(next.slice(1)).toEqual(ROWS.slice(1));
    expect(ROWS[0]?.submission?.status).toBe('SUBMITTED');
  });

  it('qabul qilishda izoh bo\'lmasa reviewNote null; oldingi izoh tozalanadi', () => {
    const next = applyReview(ROWS, 'sub-d', { status: 'ACCEPTED' }, '2026-10-12T10:00:00');
    expect(next[3]?.submission).toMatchObject({ status: 'ACCEPTED', reviewNote: null });
  });

  it('noma\'lum ish — o\'zgarishsiz nusxa', () => {
    expect(applyReview(ROWS, 'sub-yoq', { status: 'ACCEPTED' }, 'x')).toEqual(ROWS);
  });
});

describe('reviewNoteError / toReviewBody', () => {
  it('qaytarishda izoh majburiy (probel hisobga olinmaydi), qabulda ixtiyoriy', () => {
    expect(reviewNoteError('RETURNED', '')).toBe('required');
    expect(reviewNoteError('RETURNED', '   ')).toBe('required');
    expect(reviewNoteError('RETURNED', 'Qayta yozing')).toBeNull();
    expect(reviewNoteError('ACCEPTED', '')).toBeNull();
  });

  it('izoh ≤ 500 belgi (kesilgan matn bo\'yicha)', () => {
    expect(reviewNoteError('RETURNED', 'x'.repeat(500))).toBeNull();
    expect(reviewNoteError('RETURNED', 'x'.repeat(501))).toBe('tooLong');
    expect(reviewNoteError('ACCEPTED', `  ${'x'.repeat(500)}  `)).toBeNull();
    expect(reviewNoteError('ACCEPTED', 'x'.repeat(501))).toBe('tooLong');
  });

  it('bo\'sh izoh yuborilmaydi, matn kesiladi', () => {
    expect(toReviewBody('ACCEPTED', '  ')).toEqual({ status: 'ACCEPTED' });
    expect(toReviewBody('RETURNED', ' Qayta yozing ')).toEqual({ status: 'RETURNED', note: 'Qayta yozing' });
  });
});

describe('nextPendingStudentId', () => {
  it('ro\'yxatdagi keyingi tekshirilmagan ishni topadi; oxirida boshiga qaytadi', () => {
    expect(nextPendingStudentId(ROWS, 'a')).toBe('e');
    expect(nextPendingStudentId(ROWS, 'e')).toBe('a');
    expect(nextPendingStudentId(ROWS, 'c')).toBe('e');
  });

  it('boshqa tekshirilmagan ish yo\'q yoki ro\'yxat bo\'sh — null', () => {
    expect(nextPendingStudentId([row('a', 'SUBMITTED'), row('b', 'ACCEPTED')], 'a')).toBeNull();
    expect(nextPendingStudentId([], 'a')).toBeNull();
  });
});
