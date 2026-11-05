import { SchoolHomeworkPhoto, SchoolHomeworkSubmission } from '@prisma/client';
import { countStatuses, toChildSubmissionView, toStaffSubmissionView, toSubmissionSummary } from './homework-view';

const photo = (id: string, position: number): SchoolHomeworkPhoto => ({ id, submissionId: 's', key: `secret/key/${id}`, contentType: 'image/jpeg', size: 10, position });
const submission = (over: Partial<SchoolHomeworkSubmission> = {}): SchoolHomeworkSubmission => ({
  id: 's',
  assignmentId: 'a',
  studentId: 'st',
  comment: null,
  status: 'RETURNED',
  submittedAt: new Date('2026-10-20T05:00:00Z'),
  reviewedAt: new Date('2026-10-20T06:00:00Z'),
  reviewedByStaffId: 'staff-1',
  reviewNote: 'Aniqroq',
  requestId: 'req-1',
  ...over,
});
const urlOf = (id: string) => `https://x/photos/${id}`;

describe('submission views', () => {
  it('child view orders photos by position, exposes signed urls and hides storage keys, staff ids and requestId', () => {
    const view = toChildSubmissionView({ ...submission(), photos: [photo('b', 1), photo('a', 0)] }, urlOf);

    expect(view.photos.map((p) => [p.id, p.url, p.position])).toEqual([['a', 'https://x/photos/a', 0], ['b', 'https://x/photos/b', 1]]);
    expect(view).toMatchObject({ status: 'RETURNED', reviewNote: 'Aniqroq', reviewedAt: '2026-10-20T06:00:00.000Z' });
    expect(JSON.stringify(view)).not.toMatch(/secret\/key|staff-1|req-1/);
  });

  it('staff view adds the reviewer id but still hides keys', () => {
    const view = toStaffSubmissionView({ ...submission(), photos: [photo('a', 0)] }, urlOf);

    expect(view.reviewedByStaffId).toBe('staff-1');
    expect(JSON.stringify(view)).not.toContain('secret/key');
  });

  it('summary carries the photo count without urls', () => {
    expect(toSubmissionSummary(submission({ status: 'SUBMITTED', reviewedAt: null, reviewNote: null }), 3)).toEqual({
      status: 'SUBMITTED',
      submittedAt: '2026-10-20T05:00:00.000Z',
      reviewedAt: null,
      reviewNote: null,
      photoCount: 3,
    });
  });
});

describe('countStatuses', () => {
  it('counts each status and missing (null)', () => {
    expect(countStatuses(['SUBMITTED', 'ACCEPTED', 'ACCEPTED', 'RETURNED', null, null, null])).toEqual({
      total: 7,
      submitted: 1,
      accepted: 2,
      returned: 1,
      missing: 3,
    });
    expect(countStatuses([])).toEqual({ total: 0, submitted: 0, accepted: 0, returned: 0, missing: 0 });
  });
});
