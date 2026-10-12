'use client';

import type { DayCounts } from '@/data/mock/services/attendance';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { COUNT_FIELDS, STATUS_TONE, type StatusKey } from '../lib';

/** Sinf xulosasi — har holat soni; bosilsa ro'yxat shu holat bo'yicha filtrlanadi. */
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
  const chip = 'inline-flex h-9 items-center gap-2 rounded-full border px-3.5 text-sm font-medium transition-all';

  return (
    <div className="mb-4 flex flex-wrap gap-2 no-print" role="toolbar">
      <button
        type="button"
        onClick={() => onChange(undefined)}
        aria-pressed={!value}
        className={cn(chip, !value ? 'border-primary/40 bg-primary/10 text-primary' : 'bg-card hover:bg-accent')}
      >
        {t('common.all')}
        <span className="tabular-nums opacity-70">{formatNumber(counts.total)}</span>
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
            className={cn(
              chip,
              'disabled:cursor-default disabled:opacity-45',
              active ? cn('border-transparent shadow-soft', STATUS_TONE[status].soft, STATUS_TONE[status].text) : 'bg-card hover:bg-accent',
            )}
          >
            <span className={cn('h-2 w-2 rounded-full', STATUS_TONE[status].dot)} />
            {t(labelKey)}
            <span className="font-semibold tabular-nums">{formatNumber(count)}</span>
          </button>
        );
      })}
    </div>
  );
}
