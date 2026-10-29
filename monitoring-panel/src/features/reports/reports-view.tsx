'use client';

import { CalendarRange, FileSpreadsheet, MapPin, SlidersHorizontal } from 'lucide-react';
import type { ReactNode } from 'react';

import { Section } from '@/components/common/section';
import { usePageScope } from '@/features/filters/scope-select';
import { useFilters } from '@/features/filters/store';
import { useOverview } from '@/features/filters/use-monitoring';
import { usePeriodText } from '@/features/dashboard/hero';
import { regionName } from '@/data/reference/regions';
import { useI18n } from '@/i18n';
import { DATASET_KEYS } from './datasets';
import { DatasetCard } from './dataset-card';
import { PrintCard } from './print-card';

function ContextChip({ icon, label, value }: { icon: ReactNode; label: string; value: string }) {
  return (
    <div className="flex min-w-0 items-center gap-2.5 rounded-xl bg-primary/[0.05] px-3 py-2 ring-1 ring-inset ring-border/60 dark:bg-white/[0.03]">
      <span className="text-primary [&>svg]:h-4 [&>svg]:w-4">{icon}</span>
      <span className="min-w-0">
        <span className="block text-[0.66rem] font-semibold uppercase tracking-[0.1em] text-muted-foreground">{label}</span>
        <span className="block truncate text-[0.82rem] font-medium">{value || '…'}</span>
      </span>
    </div>
  );
}

/** Hisobotlar: CSV to'plamlari va chop etiladigan hisobot. Joriy doira va filtrlar ko'rsatiladi. */
export function ReportsView() {
  const { t, locale } = useI18n();
  const scope = usePageScope();
  const [filters] = useFilters();
  const overview = useOverview(scope);
  const periodText = usePeriodText(overview.data);
  const districts = overview.data?.counts.districts;
  const areasLabel = scope.kind === 'NATIONAL' ? t('reports.rowsRegions') : t('reports.rowsDistricts', { n: districts ?? '…' });
  const filterText = [
    t(`enums.gradeBand.${filters.grades}`),
    t(`enums.gender.${filters.gender}`),
    t(`enums.schoolType.${filters.schoolType}`),
  ].join(' · ');

  return (
    <div className="space-y-5">
      <div className="grid gap-2 sm:grid-cols-3">
        <ContextChip icon={<MapPin />} label={t('reports.scopeLabel')} value={scope.kind === 'NATIONAL' ? t('shell.scopeNational') : regionName(scope.regionId, locale)} />
        <ContextChip icon={<CalendarRange />} label={t('reports.periodLabel')} value={periodText} />
        <ContextChip icon={<SlidersHorizontal />} label={t('reports.filtersLabel')} value={filterText} />
      </div>
      <Section id="csv" icon={<FileSpreadsheet />} title={t('reports.csvTitle')} subtitle={t('reports.csvSub')}>
        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          {DATASET_KEYS.map((k) => (
            <DatasetCard key={k} dataset={k} scope={scope} filters={filters} rowsLabel={k === 'schools' ? t('reports.lists.topGrowth') + ' · ' + t('reports.lists.needSupport') : areasLabel} />
          ))}
        </div>
        <p className="mt-4 text-xs leading-relaxed text-muted-foreground">{t('reports.privacyNote')}</p>
      </Section>
      <PrintCard scope={scope} />
    </div>
  );
}
