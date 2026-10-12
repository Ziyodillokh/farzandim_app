'use client';

import { Suspense } from 'react';

import { BoardView } from '@/features/attendance/components/board-view';
import { PageSkeleton } from '@/features/attendance/components/page-skeleton';

export default function AttendanceBoardPage() {
  return (
    <Suspense fallback={<PageSkeleton />}>
      <BoardView />
    </Suspense>
  );
}
