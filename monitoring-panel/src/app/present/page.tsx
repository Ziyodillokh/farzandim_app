'use client';

import { useSearchParams } from 'next/navigation';
import { Suspense } from 'react';

import { AuthGuard, Forbidden, FullScreenLoader, HydrationGate } from '@/auth/guards';
import { useCan, useSession } from '@/auth/use-session';
import type { Scope } from '@/data/contracts';
import { isRegionId } from '@/data/reference/regions';
import { useUserScope } from '@/features/filters/use-monitoring';
import { PresentStage } from '@/features/present/present-stage';

function Present() {
  const params = useSearchParams();
  const session = useSession();
  const can = useCan();
  const userScope = useUserScope();
  const id = params.get('id');
  if (!can('present.view')) return <Forbidden />;
  // Viloyat hisobi faqat o'z hududini ko'rsatadi; respublika — istalgan hududni.
  if (isRegionId(id) && session?.role === 'REGIONAL' && session.regionId !== id) return <Forbidden />;
  const scope: Scope = isRegionId(id) ? { kind: 'REGION', regionId: id } : userScope;
  const exitHref = isRegionId(id) && can('regions.view') ? `/regions/view?id=${id}` : '/dashboard';
  return <PresentStage scope={scope} exitHref={exitHref} />;
}

/** Taqdimot rejimi: to'liq ekran, avtomatik slaydlar (uchrashuv va televizor uchun). */
export default function PresentPage() {
  return (
    <HydrationGate>
      <AuthGuard>
        <Suspense fallback={<FullScreenLoader />}>
          <Present />
        </Suspense>
      </AuthGuard>
    </HydrationGate>
  );
}
