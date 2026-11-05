import { QueryClient } from '@tanstack/react-query';
import { beforeEach, describe, expect, it } from 'vitest';

import type { StudentSubmissionRow } from '@/data/contracts';
import { applyOptimisticReview, rollbackReview, submissionsKey } from '../optimistic-review';

const ROWS: StudentSubmissionRow[] = [
  {
    student: { id: 'stu-1', fullName: 'Aliyev Vali' },
    classId: 'cls-7a',
    submission: { id: 'sub-1', status: 'SUBMITTED', comment: null, submittedAt: '2026-10-11T16:00:00', reviewedAt: null, reviewNote: null, photos: [] },
  },
  { student: { id: 'stu-2', fullName: 'Karimova Zilola' }, classId: 'cls-7a', submission: null },
];

describe('optimistik tekshiruv va qaytarish (rollback)', () => {
  let client: QueryClient;
  const key = submissionsKey('asg-6');

  beforeEach(() => {
    client = new QueryClient();
    client.setQueryData(key, ROWS);
  });

  it('natija so\'rov keshida darhol ko\'rinadi', async () => {
    await applyOptimisticReview(client, 'asg-6', 'sub-1', { status: 'RETURNED', note: ' Qayta yozing ' }, '2026-10-12T10:00:00');
    const after = client.getQueryData<StudentSubmissionRow[]>(key);
    expect(after?.[0]?.submission).toMatchObject({ status: 'RETURNED', reviewNote: 'Qayta yozing', reviewedAt: '2026-10-12T10:00:00' });
    expect(after?.[1]).toEqual(ROWS[1]);
  });

  it('xatoda rollback avvalgi holatni to\'liq tiklaydi', async () => {
    const context = await applyOptimisticReview(client, 'asg-6', 'sub-1', { status: 'ACCEPTED' }, '2026-10-12T10:00:00');
    expect(client.getQueryData<StudentSubmissionRow[]>(key)?.[0]?.submission?.status).toBe('ACCEPTED');
    rollbackReview(client, 'asg-6', context);
    expect(client.getQueryData<StudentSubmissionRow[]>(key)).toEqual(ROWS);
  });

  it('kesh bo\'sh bo\'lsa — hech narsa yaratilmaydi, rollback ham zararsiz', async () => {
    const empty = new QueryClient();
    const context = await applyOptimisticReview(empty, 'asg-6', 'sub-1', { status: 'ACCEPTED' });
    expect(context.previous).toBeUndefined();
    expect(empty.getQueryData(key)).toBeUndefined();
    expect(() => rollbackReview(empty, 'asg-6', context)).not.toThrow();
    expect(() => rollbackReview(empty, 'asg-6', undefined)).not.toThrow();
  });

  it('boshqa topshiriq keshiga tegmaydi', async () => {
    client.setQueryData(submissionsKey('asg-7'), ROWS);
    await applyOptimisticReview(client, 'asg-6', 'sub-1', { status: 'ACCEPTED' });
    expect(client.getQueryData(submissionsKey('asg-7'))).toEqual(ROWS);
  });
});
