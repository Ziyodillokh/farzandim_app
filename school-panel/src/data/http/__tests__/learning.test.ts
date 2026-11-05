import { describe, expect, it } from 'vitest';

import { toSubmissionRows } from '../services/learning';

describe('toSubmissionRows', () => {
  it('backend `students` qatorlarini panel shakliga keltiradi', () => {
    const submission = { id: 's1', status: 'SUBMITTED' as const, comment: null, submittedAt: '2026-11-05T10:00:00.000Z', reviewedAt: null, reviewNote: null, photos: [] };
    const rows = toSubmissionRows({
      students: [
        { studentId: 'st1', name: 'Aliyev Vali', classId: 'c1', submission },
        { studentId: 'st2', name: 'Karimova Zuhra', classId: 'c1', submission: null },
      ],
    });
    expect(rows).toEqual([
      { student: { id: 'st1', fullName: 'Aliyev Vali' }, classId: 'c1', submission },
      { student: { id: 'st2', fullName: 'Karimova Zuhra' }, classId: 'c1', submission: null },
    ]);
  });

  it("bo'sh javobda bo'sh ro'yxat", () => {
    expect(toSubmissionRows({})).toEqual([]);
  });
});
