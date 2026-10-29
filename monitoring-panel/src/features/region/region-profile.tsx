'use client';

import { MapPinOff } from 'lucide-react';
import Link from 'next/link';

import { Forbidden } from '@/auth/guards';
import { useCan, useSession } from '@/auth/use-session';
import { EmptyState } from '@/components/common/empty-state';
import { Button } from '@/components/ui/button';
import { isRegionId, type RegionId } from '@/data/reference/regions';
import { DashboardView } from '@/features/dashboard/dashboard-view';
import { useI18n } from '@/i18n';
import { RegionRanks } from './region-ranks';
import { RegionSwitcher } from './region-switcher';

function RegionNotFound() {
  const { t } = useI18n();
  const can = useCan();
  return (
    <div className="py-10">
      <h1 className="sr-only">{t('region.notFound')}</h1>
      <EmptyState
        icon={<MapPinOff />}
        title={t('region.notFound')}
        description={t('region.notFoundText')}
        action={
          <Button asChild>
            <Link href={can('regions.view') ? '/regions' : '/dashboard'}>{can('regions.view') ? t('region.notFoundAction') : t('region.backDashboard')}</Link>
          </Button>
        }
      />
    </div>
  );
}

/**
 * Hudud profili: dashboardning hudud doirasidagi ko'rinishi + respublikadagi o'rni.
 * Viloyat hisobi faqat o'z hududini ochadi, boshqasida — "Ruxsat yo'q".
 */
export function RegionProfile({ id }: { id: string | null }) {
  const { t } = useI18n();
  const session = useSession();
  const can = useCan();
  if (!isRegionId(id)) return <RegionNotFound />;
  if (session?.role === 'REGIONAL' && session.regionId !== id) return <Forbidden />;
  const regionId: RegionId = id;
  const national = can('regions.view');
  return (
    <DashboardView
      scope={{ kind: 'REGION', regionId }}
      profile={{
        backHref: national ? '/regions' : '/dashboard',
        backLabel: national ? t('region.back') : t('region.backDashboard'),
        switcher: national ? <RegionSwitcher value={regionId} /> : undefined,
        extra: <RegionRanks regionId={regionId} />,
      }}
    />
  );
}
