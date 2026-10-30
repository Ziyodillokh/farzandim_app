'use client';

import type { ReactNode } from 'react';

import { DeltaChip } from '@/components/charts/delta-chip';
import { Sparkline } from '@/components/charts/sparkline';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import type { MetricKey, SeriesPoint, Stat } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { deltaTone, useMetricFormat, useMonthLabel } from '@/lib/format';
import { cn } from '@/lib/utils';
import { InfoTip } from './stat-tile';

const SPARK_COLOR = { good: 'hsl(158 64% 45%)', bad: 'hsl(36 92% 56%)', neutral: 'hsl(var(--primary))' } as const;

/**
 * Sahifaning bosh ko'rsatkichi (katta raqam): o'zgarish, respublika qiymati,
 * 12 oylik trend va qo'shimcha mazmun (daraja shkalasi, taqsimot).
 */
export function LeadCard({
  icon,
  label,
  metric,
  stat,
  value,
  suffix,
  badge,
  national,
  series,
  sparkHeight = 56,
  description,
  children,
  className,
}: {
  icon: ReactNode;
  label: string;
  metric: MetricKey;
  stat: Stat | undefined;
  /** Formatlangan qiymat (standart — ko'rsatkich formati, birliksiz). */
  value?: string;
  /** Raqamdan keyingi kichik matn ("/ 100", "daq kuniga"). */
  suffix?: string;
  badge?: ReactNode;
  national?: number | null;
  series?: SeriesPoint[];
  /** Trend chizig'i balandligi (px) — bo'sh joyni to'ldirish uchun. */
  sparkHeight?: number;
  description?: string;
  children?: ReactNode;
  className?: string;
}) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const monthLabel = useMonthLabel();
  const tone = deltaTone(metric, stat?.delta);
  const first = series?.[0];
  const last = series?.[series.length - 1];
  return (
    <Card className={cn('relative flex h-full flex-col overflow-hidden p-5', className)}>
      <div aria-hidden className="pointer-events-none absolute inset-0 bg-[radial-gradient(120%_90%_at_100%_0%,hsl(var(--primary)/0.16),transparent_60%)]" />
      <div className="relative flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-center gap-2.5">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary ring-1 ring-inset ring-primary/20 [&_svg]:size-[18px]">{icon}</span>
          <p className="min-w-0 text-[0.86rem] font-semibold leading-snug">{label}</p>
          {description && <InfoTip text={description} />}
        </div>
        {badge}
      </div>
      <div className="relative mt-4 flex flex-wrap items-end gap-x-3 gap-y-2">
        <p className="font-display text-[2.6rem] font-semibold leading-none tracking-[-0.03em] tabular-nums">
          {value ?? fmt.value(metric, stat?.value, { unit: false })}
          {suffix && <span className="ml-1.5 align-baseline font-sans text-[0.95rem] font-medium tracking-normal text-muted-foreground">{suffix}</span>}
        </p>
        <div className="flex flex-wrap items-center gap-2 pb-1">
          <DeltaChip metric={metric} delta={stat?.delta} title={t('common.vsLastYear')} />
          {national !== undefined && national !== null && (
            <span className="text-[0.72rem] tabular-nums text-muted-foreground">{t('dashboard.vsNationalShort', { value: fmt.value(metric, national) })}</span>
          )}
        </div>
      </div>
      {series && series.length > 1 && first && last && (
        <div className="relative mt-4">
          <div style={{ height: sparkHeight }}>
            <Sparkline series={series} color={SPARK_COLOR[tone]} height={sparkHeight} className="h-full" />
          </div>
          <div className="mt-1.5 flex items-center justify-between gap-2 text-[0.66rem] text-muted-foreground">
            <span className="tabular-nums">{monthLabel(first.key, true)}</span>
            <span className="truncate">{t('wellbeing.kit.trend12')}</span>
            <span className="tabular-nums">{monthLabel(last.key, true)}</span>
          </div>
        </div>
      )}
      {children && <div className="relative mt-auto pt-4">{children}</div>}
    </Card>
  );
}

export function LeadCardSkeleton({ className }: { className?: string }) {
  return (
    <Card className={cn('h-full p-5', className)}>
      <Skeleton className="h-9 w-40" />
      <Skeleton className="mt-5 h-11 w-32" />
      <Skeleton className="mt-4 h-11 w-full" />
      <Skeleton className="mt-5 h-4 w-3/4" />
    </Card>
  );
}
