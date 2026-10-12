'use client';

import { Suspense } from 'react';

import { AssessmentsPage } from '@/features/assessments/components/assessments-page';

export default function Page() {
  return (
    <Suspense>
      <AssessmentsPage />
    </Suspense>
  );
}
