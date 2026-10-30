'use client';

import { MapPinned } from 'lucide-react';
import { useMemo } from 'react';

import { ErrorState } from '@/components/common/error-state';
import { ExportMenu } from '@/components/common/export-menu';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { MetricKey, Schools } from '@/data/contracts';
import type { RegionId } from '@/data/reference/regions';
import { CountBar } from '@/features/regions/kit/count-bar';
import { csvNumber, csvStamp } from '@/features/regions/kit/csv';
import { columnStats } from '@/features/regions/kit/heat';
import { KitTable, type KitColumn } from '@/features/regions/kit/kit-table';
import { MetricCell } from '@/features/regions/kit/metric-cell';
import { bestFirstDir, sortRows, useTableSort, type SortDir } from '@/features/regions/kit/sort';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { downloadCsv, type CsvColumn } from '@/lib/csv';
import { useMetricFormat } from '@/lib/format';
import type { ScopeReference } from './school-list';

type District = Schools['districts'][number];
type SortKey = 'name' | 'schools' | 'mastery' | 'attendance' | 'wellbeing';

const DISTRICT_METRICS = ['mastery', 'attendance', 'wellbeing'] as const satisfies readonly MetricKey[];
const firstDir = (key: SortKey): SortDir => (key === 'name' ? 'asc' : key === 'schools' ? 'desc' : bestFirstDir(key));

/** Hudud doirasi: tumanlar bo'yicha maktablar soni va asosiy ko'rsatkichlar (saralanadi, CSV). */
export function DistrictsSection({
  regionId,
  districts,
  reference,
  error,
  onRetry,
}: {
  regionId: RegionId;
  districts: District[] | undefined;
  reference: ScopeReference;
  error: unknown;
  onRetry: () => void;
}) {
  const { t, locale } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const { sort, toggle } = useTableSort<SortKey>({ key: 'mastery', dir: 'desc' }, firstDir);
  const nameOf = (d: District) => areaName(d.id, { fallback: d.name });

  const view = useMemo(() => {
    if (!districts) return null;
    const value = (d: District) => (sort.key === 'name' ? areaName(d.id, { fallback: d.name }) : d[sort.key]);
    return {
      sorted: sortRows(districts, value, sort.dir, locale),
      schools: districts.reduce((s, d) => s + d.schools, 0),
      maxSchools: Math.max(0, ...districts.map((d) => d.schools)),
      stats: {
        mastery: columnStats(districts.map((d) => d.mastery)),
        attendance: columnStats(districts.map((d) => d.attendance)),
        wellbeing: columnStats(districts.map((d) => d.wellbeing)),
      },
    };
  }, [districts, sort, locale, areaName]);

  const columns: KitColumn<District>[] = view
    ? [
        { key: 'name', header: t('schools.list.district'), sortable: true, cell: nameOf, footer: areaName(regionId) },
        {
          key: 'schools',
          header: t('schools.districts.schools'),
          sortable: true,
          align: 'right',
          className: 'pr-3',
          cell: (d) => <CountBar value={d.schools} max={view.maxSchools} />,
          footer: fmt.count(view.schools),
        },
        ...DISTRICT_METRICS.map(
          (m): KitColumn<District> => ({
            key: m,
            header: t(`metrics.${m}.label`),
            sortable: true,
            sortTitle: t('regions.table.sortBy', { column: t(`metrics.${m}.title`) }),
            cell: (d) => <MetricCell metric={m} value={d[m]} stats={view.stats[m]} />,
            footer: <MetricCell metric={m} value={reference[m]} tint={false} />,
          }),
        ),
      ]
    : [];

  const exportCsv = () => {
    if (!view) return;
    const csv: CsvColumn<District>[] = [
      { header: t('schools.list.district'), value: nameOf },
      { header: t('schools.districts.schools'), value: (d) => d.schools },
      { header: `${t('metrics.mastery.label')}, %`, value: (d) => csvNumber(d.mastery) },
      { header: `${t('metrics.attendance.label')}, %`, value: (d) => csvNumber(d.attendance) },
      { header: t('metrics.wellbeing.label'), value: (d) => csvNumber(d.wellbeing) },
    ];
    downloadCsv(`${t('schools.districts.csvFile')}-${csvStamp()}`, view.sorted, csv);
  };

  return (
    <Section
      id="sec-districts"
      icon={<MapPinned />}
      title={t('schools.districts.title')}
      subtitle={t('schools.districts.subtitle')}
      actions={<ExportMenu onCsv={exportCsv} disabled={!view?.sorted.length} />}
    >
      {error ? (
        <ErrorState error={error} onRetry={onRetry} />
      ) : !view ? (
        <Skeleton className="h-[520px] w-full rounded-xl" />
      ) : (
        <>
          <KitTable
            columns={columns}
            rows={view.sorted}
            rowKey={(d) => d.id}
            sort={sort}
            onSort={(key) => toggle(key as SortKey)}
            minWidth={620}
            caption={t('schools.districts.title')}
          />
          <p className="mt-2.5 text-[0.7rem] text-muted-foreground">{t('regions.table.legendHeat')}</p>
        </>
      )}
    </Section>
  );
}
