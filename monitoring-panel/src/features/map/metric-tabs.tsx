'use client';

import type { MetricKey } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

/** Ko'rsatkich tanlagich (gorizontal "pill" tablar, mobil — aylantiriladi). */
export function MetricTabs({
  metrics,
  value,
  onChange,
  className,
}: {
  metrics: readonly MetricKey[];
  value: MetricKey;
  onChange: (m: MetricKey) => void;
  className?: string;
}) {
  const { t } = useI18n();
  return (
    <div role="tablist" aria-label={t('map.metric')} className={cn('-mx-1 flex gap-1 overflow-x-auto px-1 pb-1', className)}>
      {metrics.map((m) => (
        <button
          key={m}
          role="tab"
          type="button"
          aria-selected={value === m}
          onClick={() => onChange(m)}
          className={cn(
            'h-8 shrink-0 rounded-full px-3 text-[0.78rem] font-semibold transition-all',
            value === m
              ? 'bg-brand-gradient text-white shadow-[0_6px_18px_-8px_hsl(var(--primary)/0.9)]'
              : 'bg-primary/[0.06] text-muted-foreground ring-1 ring-inset ring-border/60 hover:text-foreground dark:bg-white/[0.04]',
          )}
        >
          {t(`metrics.${m}.label`)}
        </button>
      ))}
    </div>
  );
}
