'use client';

import { useSearchParams } from 'next/navigation';
import { Suspense } from 'react';

import { Skeleton } from '@/components/ui/skeleton';
import { RegionProfile } from '@/features/region/region-profile';

function RegionViewInner() {
  const params = useSearchParams();
  return <RegionProfile id={params.get('id')} />;
}

/** Hudud profili: `/regions/view?id=UZ-SA` (statik eksport — dinamik yo'l o'rniga query). */
export default function RegionViewPage() {
  return (
    <Suspense fallback={<Skeleton className="h-[320px] w-full rounded-3xl" />}>
      <RegionViewInner />
    </Suspense>
  );
}
