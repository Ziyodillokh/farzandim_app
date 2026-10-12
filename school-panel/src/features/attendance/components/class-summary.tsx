'use client';

import type { DayCounts } from '@/data/mock/services/attendance';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { COUNT_FIELDS, STATUS_TONE, type StatusKey } from '../lib';

const PILL = 'inline-flex h-9 items-center gap-1.5 whitespace-nowrap rounded-xl px-2.5 text-sm font-medium transition-all disabled:cursor-default disabled:opacity-40';
const ACTIVE = 'bg-card shadow-soft ring-1 ring-border/60';
const IDLE = 'text-muted-foreground hover:bg-primary/[0.05] hover:text-foreground';

/** Sinf xulosasi — segmentli boshqaruv: har holat soni; bosilsa ro'yxat shu holat bo'yicha filtrlanadi. */
export function ClassSummary({
  counts,
  value,
  onChange,
}: {
  counts: DayCounts;
  value: StatusKey | undefined;
  onChange: (status: StatusKey | undefined) => void;
}) {
  const { t, formatNumber } = useI18n();

  return (
    <div className="glass flex flex-wrap items-center gap-0.5 rounded-2xl p-1.5 no-print" role="toolbar">
      <button type="button" onClick={() => onChange(undefined)} aria-pressed={!value} className={cn(PILL, !value ? cn(ACTIVE, 'text-primary') : IDLE)}>
        {t('common.all')}
        <span className="font-semibold tabular-nums">{formatNumber(counts.total)}</span>
      </button>
      {COUNT_FIELDS.map(({ field, status, labelKey }) => {
        const active = value === status;
        const count = counts[field];
        return (
          <button
            key={field}
            type="button"
            disabled={count === 0 && !active}
            onClick={() => onChange(active ? undefined : status)}
            aria-pressed={active}
            className={cn(PILL, active ? cn(ACTIVE, STATUS_TONE[status].text) : IDLE)}
          >
            <span className={cn('h-2 w-2 rounded-full', STATUS_TONE[status].dot)} />
            {t(labelKey)}
            <span className={cn('font-semibold tabular-nums', !active && 'text-foreground/80')}>{formatNumber(count)}</span>
          </button>
        );
      })}
    </div>
  );
}
