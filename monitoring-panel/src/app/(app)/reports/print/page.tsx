'use client';

import { useSearchParams } from 'next/navigation';
import { Suspense } from 'react';

import { Skeleton } from '@/components/ui/skeleton';
import { PrintReport } from '@/features/reports/print-report';

function PrintInner() {
  const params = useSearchParams();
  return <PrintReport id={params.get('id')} />;
}

/** Chop etiladigan hisobot (brauzerda "PDF sifatida saqlash"). */
export default function ReportPrintPage() {
  return (
    <Suspense fallback={<Skeleton className="mx-auto h-[900px] w-full max-w-[960px] rounded-2xl" />}>
      <PrintInner />
    </Suspense>
  );
}
