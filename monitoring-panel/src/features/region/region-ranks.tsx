'use client';

import { Trophy } from 'lucide-react';

import { Skeleton } from '@/components/ui/skeleton';
import type { MetricKey } from '@/data/contracts';
import type { RegionId } from '@/data/reference/regions';
import { useAreaMetric } from '@/features/filters/use-monitoring';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';

const RANK_METRICS: readonly MetricKey[] = ['mastery', 'iqParticipation', 'wellbeing', 'bullying', 'attendance', 'coverage'];
const NATIONAL = { kind: 'NATIONAL' } as const;

function RankChip({ metric, regionId }: { metric: MetricKey; regionId: RegionId }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const { data } = useAreaMetric(metric, NATIONAL);
  const area = data?.areas.find((a) => a.id === regionId);
  if (!data || !area) return <Skeleton className="h-[52px] w-[150px] rounded-xl bg-white/10" />;
  const total = data.areas.filter((a) => a.rank !== null).length;
  const top = area.rank !== null && area.rank <= 3;
  const low = area.rank !== null && area.rank > total - 3;
  return (
    <div className="rounded-xl bg-white/[0.07] px-3 py-2 ring-1 ring-inset ring-white/15">
      <p className="text-[0.68rem] font-medium uppercase tracking-[0.08em] text-white/60">{t(`metrics.${metric}.label`)}</p>
      <p className="mt-0.5 flex items-baseline gap-2">
        <span
          className={cn(
            'font-display text-base font-semibold tabular-nums',
            top ? 'text-cyan-200' : low ? 'text-amber-200' : 'text-white',
          )}
        >
          {area.rank === null ? '—' : t('region.rank', { rank: area.rank, total })}
        </span>
        <span className="text-xs tabular-nums text-white/60">{fmt.value(metric, area.value)}</span>
      </p>
    </div>
  );
}

/** Hududning respublikadagi o'rni — asosiy ko'rsatkichlar bo'yicha. */
export function RegionRanks({ regionId }: { regionId: RegionId }) {
  const { t } = useI18n();
  return (
    <div>
      <p className="mb-2 flex items-center gap-1.5 text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-white/60">
        <Trophy className="h-3.5 w-3.5" />
        {t('region.ranksTitle')} <span className="font-normal normal-case tracking-normal">· {t('region.rankHint')}</span>
      </p>
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 xl:grid-cols-6">
        {RANK_METRICS.map((m) => (
          <RankChip key={m} metric={m} regionId={regionId} />
        ))}
      </div>
    </div>
  );
}
