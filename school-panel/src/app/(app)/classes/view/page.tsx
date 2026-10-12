'use client';

import { useSearchParams } from 'next/navigation';
import { Suspense } from 'react';

import { ClassDetailSkeleton, ClassDetailView } from '@/features/classes/components/class-detail';

function ClassViewContent() {
  const id = useSearchParams().get('id');
  return <ClassDetailView key={id ?? 'none'} id={id} />;
}

export default function ClassViewPage() {
  return (
    <Suspense fallback={<ClassDetailSkeleton />}>
      <ClassViewContent />
    </Suspense>
  );
}
