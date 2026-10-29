'use client';

import { RotateCcw } from 'lucide-react';

import { REGIONS, type RegionId } from '@/data/reference/regions';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { cn } from '@/lib/utils';

/**
 * Solishtirish uchun hududlar (chiplar): tanlangan hudud tartib raqami bilan —
 * shu raqam kartalar va ustunlar tartibiga mos. Chegara: `min`..`max`.
 */
export function RegionPicker({
  selected,
  onToggle,
  onReset,
  min,
  max,
}: {
  selected: readonly RegionId[];
  onToggle: (id: RegionId) => void;
  onReset: () => void;
  min: number;
  max: number;
}) {
  const { t } = useI18n();
  const areaName = useAreaName();
  const full = selected.length >= max;
  return (
    <div>
      <div className="mb-2.5 flex flex-wrap items-center justify-between gap-x-4 gap-y-1">
        <p className="text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-muted-foreground">{t('regions.compare.pickLabel')}</p>
        <div className="flex items-center gap-2 text-[0.72rem] text-muted-foreground">
          <span aria-live="polite">
            {t('regions.compare.picked', { count: selected.length, max })}
            {full && <span className="hidden sm:inline"> · {t('regions.compare.maxHint', { max })}</span>}
          </span>
          <button
            type="button"
            onClick={onReset}
            className="inline-flex h-7 items-center gap-1 rounded-lg px-2 font-semibold text-primary transition-colors hover:bg-primary/[0.08]"
          >
            <RotateCcw aria-hidden className="h-3.5 w-3.5" />
            {t('regions.compare.reset')}
          </button>
        </div>
      </div>
      <div role="group" aria-label={t('regions.compare.pickLabel')} className="flex flex-wrap gap-1.5">
        {REGIONS.map((r) => {
          const index = selected.indexOf(r.id);
          const on = index >= 0;
          const locked = on ? selected.length <= min : full;
          const hint = locked ? (on ? t('regions.compare.minHint', { min }) : t('regions.compare.maxHint', { max })) : undefined;
          return (
            <button
              key={r.id}
              type="button"
              aria-pressed={on}
              aria-disabled={locked || undefined}
              title={hint}
              onClick={() => {
                if (!locked) onToggle(r.id);
              }}
              className={cn(
                'inline-flex h-8 items-center gap-1.5 rounded-full px-3 text-[0.78rem] font-semibold transition-all',
                on
                  ? 'bg-brand-gradient pl-1.5 text-white shadow-[0_6px_18px_-8px_hsl(var(--primary)/0.9)]'
                  : 'bg-primary/[0.06] text-muted-foreground ring-1 ring-inset ring-border/60 hover:text-foreground dark:bg-white/[0.04]',
                locked && (on ? 'cursor-not-allowed' : 'cursor-not-allowed opacity-45 hover:text-muted-foreground'),
              )}
            >
              {on && (
                <span aria-hidden className="flex h-5 w-5 items-center justify-center rounded-full bg-white/25 text-[0.66rem] font-bold tabular-nums">
                  {index + 1}
                </span>
              )}
              {areaName(r.id, { short: true })}
            </button>
          );
        })}
      </div>
    </div>
  );
}
