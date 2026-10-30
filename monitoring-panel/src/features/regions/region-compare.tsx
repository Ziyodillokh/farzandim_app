'use client';

import { GitCompareArrows } from 'lucide-react';
import { useCallback, useMemo, useState } from 'react';

import { ErrorState } from '@/components/common/error-state';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { RegionRow } from '@/data/contracts';
import type { RegionId } from '@/data/reference/regions';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { cn } from '@/lib/utils';
import { buildCompareRows, summarize } from './compare-model';
import { CompareLegend, CompareMetric } from './kit/compare-bars';
import { COMPARE_METRICS, METRIC_GROUPS } from './metric-groups';
import { RegionPicker } from './region-picker';
import { RegionSummaryCard } from './region-summary-card';
import type { NationalStats } from './use-regions-data';

/** Standart tanlov: poytaxt, yirik viloyat va e'tibor talab hudud. */
const DEFAULT_SELECTION: readonly RegionId[] = ['UZ-TK', 'UZ-SA', 'UZ-SU'];
const MIN_REGIONS = 2;
const MAX_REGIONS = 3;

function nextSelection(current: readonly RegionId[], id: RegionId): readonly RegionId[] {
  if (current.includes(id)) return current.length > MIN_REGIONS ? current.filter((x) => x !== id) : current;
  return current.length < MAX_REGIONS ? [...current, id] : current;
}

/** "Hududlarni solishtirish": 2–3 hudud, xulosa kartalari va ko'rsatkichlar bo'yicha yonma-yon ustunlar. */
export function RegionCompareSection({
  rows,
  national,
  error,
  onRetry,
}: {
  rows: RegionRow[] | undefined;
  national: NationalStats | undefined;
  error: unknown;
  onRetry: () => void;
}) {
  const { t } = useI18n();
  const areaName = useAreaName();
  const [selected, setSelected] = useState<readonly RegionId[]>(DEFAULT_SELECTION);
  const toggle = useCallback((id: RegionId) => setSelected((cur) => nextSelection(cur, id)), []);
  const reset = useCallback(() => setSelected(DEFAULT_SELECTION), []);

  const model = useMemo(() => {
    if (!rows) return null;
    const series = selected.map((id) => ({ id, label: areaName(id, { short: true }) }));
    const compareRows = buildCompareRows(COMPARE_METRICS, rows, selected, national);
    const byId = new Map(rows.map((r) => [r.id, r]));
    const cards = summarize(selected, series, compareRows).flatMap((summary) => {
      const row = byId.get(summary.id);
      return row ? [{ summary, row }] : [];
    });
    return { series, cards, byMetric: new Map(compareRows.map((r) => [r.metric, r])) };
  }, [rows, selected, national, areaName]);

  const referenceText = useCallback((v: string) => t('dashboard.vsNationalShort', { value: v }), [t]);
  const gapText = useCallback((v: string) => t('regions.compare.vsNational', { value: v }), [t]);
  const deltaText = useCallback((v: string) => t('regions.compare.vsLastYear', { value: v }), [t]);

  return (
    <Section id="sec-compare" icon={<GitCompareArrows />} title={t('regions.compare.title')} subtitle={t('regions.compare.subtitle')}>
      <RegionPicker selected={selected} onToggle={toggle} onReset={reset} min={MIN_REGIONS} max={MAX_REGIONS} />
      {error ? (
        <ErrorState error={error} onRetry={onRetry} />
      ) : !model ? (
        <div className="mt-5 space-y-4">
          <div className="grid gap-3 md:grid-cols-3">
            {DEFAULT_SELECTION.map((id) => (
              <Skeleton key={id} className="h-[168px] rounded-2xl" />
            ))}
          </div>
          <Skeleton className="h-[420px] w-full rounded-2xl" />
        </div>
      ) : (
        <div className="mt-5 space-y-5">
          <div className={cn('grid gap-3', model.cards.length > 2 ? 'md:grid-cols-2 xl:grid-cols-3' : 'md:grid-cols-2')}>
            {model.cards.map(({ summary, row }, i) => (
              <RegionSummaryCard key={summary.id} index={i} row={row} summary={summary} />
            ))}
          </div>
          <CompareLegend
            worse={t('regions.compare.legendWorse')}
            better={t('regions.compare.legendBetter')}
            reference={t('regions.compare.legendNational')}
            best={t('regions.compare.legendBest')}
          />
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {METRIC_GROUPS.map((g) => (
              <div key={g.key} className="rounded-2xl p-4 ring-1 ring-inset ring-border/50">
                <h3 className="mb-3 text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-muted-foreground">{t(`regions.groups.${g.key}`)}</h3>
                <div className="space-y-4">
                  {g.metrics.map((m) => {
                    const row = model.byMetric.get(m);
                    if (!row) return null;
                    return (
                      <CompareMetric
                        key={m}
                        row={row}
                        label={t(`metrics.${m}.label`)}
                        series={model.series}
                        referenceText={referenceText}
                        gapText={gapText}
                        deltaText={deltaText}
                        bestLabel={t('regions.compare.best')}
                      />
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
          <p className="text-[0.7rem] text-muted-foreground">{t('regions.compare.scaleNote')}</p>
        </div>
      )}
    </Section>
  );
}
