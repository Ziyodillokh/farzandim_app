'use client';

import { Suspense } from 'react';

import { ClassView } from '@/features/attendance/components/class-view';
import { PageSkeleton } from '@/features/attendance/components/page-skeleton';

export default function AttendanceClassPage() {
  return (
    <Suspense fallback={<PageSkeleton />}>
      <ClassView />
    </Suspense>
  );
}
