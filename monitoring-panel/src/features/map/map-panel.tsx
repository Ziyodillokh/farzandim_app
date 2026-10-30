'use client';

import dynamic from 'next/dynamic';
import { useRouter } from 'next/navigation';
import { useState } from 'react';

import { useCan } from '@/auth/use-session';
import { RankBars } from '@/components/charts/rank-bars';
import { MapLegend, UzMap } from '@/components/map/uz-map';
import { Skeleton } from '@/components/ui/skeleton';
import type { MetricKey, Scope } from '@/data/contracts';
import { METRICS } from '@/data/mock/model/metrics';
import type { RegionId } from '@/data/reference/regions';
import { useAreaMetric } from '@/features/filters/use-monitoring';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';
import { MetricTabs } from './metric-tabs';

/** Tumanlar geometriyasi (~80 KB) faqat hudud doirasida kerak — alohida bo'lak sifatida yuklanadi. */
const DistrictMap = dynamic(() => import('@/components/map/district-map').then((m) => m.DistrictMap), {
  ssr: false,
  loading: () => <Skeleton className="h-[360px] w-full rounded-2xl" />,
});

/** Xaritada tanlash mumkin bo'lgan ko'rsatkichlar (standart to'plam). */
export const MAP_METRICS: readonly MetricKey[] = ['mastery', 'iqMean', 'wellbeing', 'bullying', 'attendance', 'screenTime', 'coverage'];

/**
 * Xarita + reyting paneli: respublika doirasida 14 hudud (bosish — hudud profili),
 * hudud doirasida tumanlar xaritasi. Ko'rsatkich tablar bilan almashadi.
 */
export function MapPanel({
  scope,
  metrics = MAP_METRICS,
  initial = 'mastery',
  height = 'auto',
  showTabs = true,
  className,
}: {
  scope: Scope;
  metrics?: readonly MetricKey[];
  initial?: MetricKey;
  height?: 'auto' | 'compact';
  showTabs?: boolean;
  className?: string;
}) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const router = useRouter();
  const can = useCan();
  const [metric, setMetric] = useState<MetricKey>(initial);
  const [selected, setSelected] = useState<string | null>(null);
  const { data, isLoading } = useAreaMetric(metric, scope);
  const def = METRICS[metric];
  const center = data?.scopeValue.value ?? null;
  const format = (v: number | null) => fmt.value(metric, v);
  const openRegion = (id: RegionId) => {
    if (can('regions.view')) router.push(`/regions/view?id=${id}`);
    else setSelected(id);
  };

  return (
    <div className={cn('grid gap-5 xl:grid-cols-[minmax(0,1.55fr)_minmax(0,1fr)]', className)}>
      <div className="min-w-0">
        {showTabs && <MetricTabs metrics={metrics} value={metric} onChange={setMetric} className="mb-3" />}
        {isLoading || !data ? (
          <Skeleton className={cn('w-full rounded-2xl', height === 'compact' ? 'h-[300px]' : 'h-[420px]')} />
        ) : scope.kind === 'NATIONAL' ? (
          <UzMap
            data={data.areas}
            center={center}
            better={def.better}
            format={format}
            formatDelta={(d) => fmt.delta(metric, d)}
            selectedId={selected}
            onSelect={openRegion}
            labels="value"
            ariaLabel={t('map.title')}
          />
        ) : (
          <DistrictMap
            regionId={scope.regionId}
            data={data.areas}
            center={center}
            better={def.better}
            format={format}
            selectedId={selected}
            onSelect={setSelected}
            ariaLabel={t('map.districtsTitle')}
          />
        )}
        <div className="mt-3 flex flex-wrap items-center justify-between gap-2">
          <MapLegend better={def.better} centerLabel={`${scope.kind === 'NATIONAL' ? t('common.nationalAvg') : t('common.value')}: ${format(center)}`} />
          {scope.kind === 'NATIONAL' && can('regions.view') && <span className="text-[0.7rem] text-muted-foreground">{t('map.clickHint')}</span>}
        </div>
      </div>
      <div className="min-w-0">
        <p className="mb-2 text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-muted-foreground">
          {t('map.ranking')} · {t(`metrics.${metric}.title`)}
        </p>
        {isLoading || !data ? (
          <Skeleton className="h-[380px] w-full rounded-2xl" />
        ) : (
          <RankBars
            metric={metric}
            areas={data.areas}
            center={center}
            selectedId={selected}
            onSelect={scope.kind === 'NATIONAL' ? (id) => openRegion(id as RegionId) : setSelected}
            limit={scope.kind === 'NATIONAL' ? undefined : 16}
          />
        )}
      </div>
    </div>
  );
}
