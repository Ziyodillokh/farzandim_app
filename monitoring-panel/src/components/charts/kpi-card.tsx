'use client';

import Link from 'next/link';
import type { ReactNode } from 'react';

import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import type { Kpi } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { deltaTone, useMetricFormat } from '@/lib/format';
import { useCountUp } from '@/lib/use-count-up';
import { cn } from '@/lib/utils';
import { DeltaChip } from './delta-chip';
import { Sparkline } from './sparkline';

const TONE_COLOR = { good: 'hsl(158 64% 45%)', bad: 'hsl(36 92% 56%)', neutral: 'hsl(var(--primary))' } as const;

/**
 * KPI kartasi: nom, katta raqam (silliq o'sish), o'tgan yilga nisbatan o'zgarish,
 * 12 oylik trend va (viloyat doirasida) respublika qiymati.
 */
export function KpiCard({ kpi, icon, href, className }: { kpi: Kpi; icon?: ReactNode; href?: string; className?: string }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const animated = useCountUp(kpi.value);
  const tone = deltaTone(kpi.key, kpi.delta);
  const body = (
    <Card className={cn('card-glow group relative h-full overflow-hidden p-4', className)}>
      <div aria-hidden className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_100%_0%,hsl(var(--primary)/0.12),transparent_60%)]" />
      <div className="relative flex items-start justify-between gap-2">
        <p className="text-[0.8rem] font-medium text-muted-foreground">{t(`metrics.${kpi.key}.label`)}</p>
        {icon && <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary ring-1 ring-inset ring-primary/20 [&_svg]:size-4">{icon}</span>}
      </div>
      <p className="relative mt-1 font-display text-[1.7rem] font-semibold leading-none tracking-[-0.02em] tabular-nums">{fmt.value(kpi.key, animated)}</p>
      <div className="relative mt-2 flex flex-wrap items-center gap-1.5">
        <DeltaChip metric={kpi.key} delta={kpi.delta} title={t('common.vsLastYear')} />
        {kpi.national !== undefined && kpi.national !== null && (
          <span className="text-[0.7rem] text-muted-foreground tabular-nums">{t('dashboard.vsNationalShort', { value: fmt.value(kpi.key, kpi.national) })}</span>
        )}
      </div>
      <Sparkline series={kpi.series} color={TONE_COLOR[tone]} className="relative mt-3" />
    </Card>
  );
  if (!href) return body;
  return (
    <Link href={href} className="block h-full rounded-2xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring" aria-label={t(`metrics.${kpi.key}.title`)}>
      {body}
    </Link>
  );
}

export function KpiCardSkeleton() {
  return (
    <Card className="h-full p-4">
      <Skeleton className="h-4 w-24" />
      <Skeleton className="mt-3 h-7 w-20" />
      <Skeleton className="mt-3 h-5 w-16" />
      <Skeleton className="mt-3 h-9 w-full" />
    </Card>
  );
}
