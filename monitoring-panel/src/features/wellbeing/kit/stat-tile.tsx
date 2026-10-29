'use client';

import { Info } from 'lucide-react';
import type { ReactNode } from 'react';

import { DeltaChip } from '@/components/charts/delta-chip';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import type { MetricKey, Stat } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';

/** Ko'rsatkich ta'rifi — kichik "i" tugmasi (klaviatura bilan ham ochiladi). */
export function InfoTip({ text, className }: { text: string; className?: string }) {
  const { t } = useI18n();
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <button
          type="button"
          aria-label={t('wellbeing.kit.about')}
          className={cn('inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-lg text-muted-foreground/80 transition-colors hover:bg-primary/[0.08] hover:text-foreground', className)}
        >
          <Info className="h-3.5 w-3.5" />
        </button>
      </TooltipTrigger>
      <TooltipContent className="max-w-[280px] whitespace-normal leading-snug">{text}</TooltipContent>
    </Tooltip>
  );
}

/**
 * KPI plitkasi: nom, qiymat, o'tgan yilga nisbatan o'zgarish va (hudud
 * doirasida) respublika qiymati. Sparkline yo'q — ixcham.
 */
export function StatTile({
  metric,
  stat,
  label,
  national,
  description,
  hint,
  format,
  className,
}: {
  metric: MetricKey;
  stat: Stat | undefined;
  label: string;
  /** Hudud doirasida — respublika qiymati ("resp.: …"). */
  national?: number | null;
  description?: string;
  hint?: ReactNode;
  /** Reyestrda yo'q qiymatlar uchun format (standart — ko'rsatkich formati). */
  format?: (v: number | null | undefined) => string;
  className?: string;
}) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const show = format ?? ((v: number | null | undefined) => fmt.value(metric, v));
  return (
    <Card className={cn('relative flex h-full flex-col overflow-hidden p-4', className)}>
      <div aria-hidden className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_100%_0%,hsl(var(--primary)/0.1),transparent_60%)]" />
      <div className="relative flex items-start justify-between gap-1.5">
        <p className="line-clamp-2 min-h-[2.2em] text-[0.78rem] font-medium leading-snug text-muted-foreground">{label}</p>
        {description && <InfoTip text={description} className="-mr-1.5 -mt-1" />}
      </div>
      <p className="relative mt-1.5 font-display text-[1.45rem] font-semibold leading-none tracking-[-0.02em] tabular-nums">{show(stat?.value)}</p>
      <div className="relative mt-2.5 flex flex-wrap items-center gap-x-2 gap-y-1">
        <DeltaChip metric={metric} delta={stat?.delta} title={t('common.vsLastYear')} />
        {national !== undefined && national !== null && (
          <span className="text-[0.7rem] tabular-nums text-muted-foreground">{t('dashboard.vsNationalShort', { value: show(national) })}</span>
        )}
      </div>
      {hint && <div className="relative mt-auto pt-2.5 text-[0.7rem] leading-snug text-muted-foreground">{hint}</div>}
    </Card>
  );
}

export function StatTileSkeleton({ className }: { className?: string }) {
  return (
    <Card className={cn('h-full p-4', className)}>
      <Skeleton className="h-4 w-24" />
      <Skeleton className="mt-3 h-7 w-20" />
      <Skeleton className="mt-3 h-5 w-16" />
    </Card>
  );
}
