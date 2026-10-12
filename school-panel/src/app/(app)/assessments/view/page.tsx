'use client';

import { Suspense } from 'react';

import { TestView } from '@/features/assessments/components/view/test-view';

export default function Page() {
  return (
    <Suspense>
      <TestView />
    </Suspense>
  );
}
