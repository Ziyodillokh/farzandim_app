'use client';

import { ArrowRight, Landmark, MapPinned } from 'lucide-react';
import { useMemo } from 'react';

import { ErrorState } from '@/components/common/error-state';
import { ExportMenu } from '@/components/common/export-menu';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { MetricKey, RegionRow } from '@/data/contracts';
import { OFFICIAL_NATIONAL, OFFICIAL_REGIONS } from '@/data/reference/official-stats';
import type { RegionId } from '@/data/reference/regions';
import { useScopeRegion } from '@/features/filters/store';
import { CountBar } from '@/features/regions/kit/count-bar';
import { csvNumber, csvStamp } from '@/features/regions/kit/csv';
import { columnStats } from '@/features/regions/kit/heat';
import { KitTable, type KitColumn } from '@/features/regions/kit/kit-table';
import { MetricCell } from '@/features/regions/kit/metric-cell';
import { PupilsCell } from '@/features/regions/kit/pupils-cell';
import { bestFirstDir, sortRows, useTableSort, type SortDir } from '@/features/regions/kit/sort';
import { useRegionsData } from '@/features/regions/use-regions-data';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { downloadCsv, type CsvColumn } from '@/lib/csv';
import { useMetricFormat } from '@/lib/format';

type Line = RegionRow & { schools: number; privateSchools: number };
type SortKey = 'name' | 'schools' | 'privateSchools' | 'covered' | MetricKey;

const SHOWN_METRICS = ['coverage', 'mastery', 'attendance', 'wellbeing'] as const satisfies readonly MetricKey[];
const firstDir = (key: SortKey): SortDir => (key === 'name' ? 'asc' : key === 'schools' || key === 'privateSchools' || key === 'covered' ? 'desc' : bestFirstDir(key));

/**
 * Respublika doirasi (tumanlar yo'q): hududlar bo'yicha rasmiy maktablar soni,
 * qamrov va natijalar. Qatorni bosish — sahifa doirasi shu hududga o'tadi.
 */
export function RegionSchoolsSection() {
  const { t, locale } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const { rows, national, error, retry } = useRegionsData();
  const [, setScopeRegion] = useScopeRegion();
  const { sort, toggle } = useTableSort<SortKey>({ key: 'schools', dir: 'desc' }, firstDir);

  const openRegion = (id: RegionId) => {
    setScopeRegion(id);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const view = useMemo(() => {
    if (!rows) return null;
    const lines: Line[] = rows.map((r) => ({
      ...r,
      schools: OFFICIAL_REGIONS[r.id]?.schools ?? 0,
      privateSchools: OFFICIAL_REGIONS[r.id]?.privateSchools ?? 0,
    }));
    const value = (l: Line) =>
      sort.key === 'name'
        ? areaName(l.id, { short: true })
        : sort.key === 'schools' || sort.key === 'privateSchools' || sort.key === 'covered'
          ? l[sort.key]
          : (l.values[sort.key]?.value ?? null);
    return {
      sorted: sortRows(lines, value, sort.dir, locale),
      maxSchools: Math.max(0, ...lines.map((l) => l.schools)),
      covered: rows.reduce((s, r) => s + r.covered, 0),
      official: rows.reduce((s, r) => s + r.official, 0),
      stats: Object.fromEntries(SHOWN_METRICS.map((m) => [m, columnStats(rows.map((r) => r.values[m]?.value))])) as Record<
        (typeof SHOWN_METRICS)[number],
        ReturnType<typeof columnStats>
      >,
    };
  }, [rows, sort, locale, areaName]);

  const countColumn = (key: 'schools' | 'privateSchools', header: string, footer: number, max?: number): KitColumn<Line> => ({
    key,
    header,
    sortable: true,
    align: 'right',
    className: 'pr-3',
    cell: (l) => (max === undefined ? fmt.count(l[key]) : <CountBar value={l[key]} max={max} />),
    footer: fmt.count(footer),
  });

  const columns: KitColumn<Line>[] = view
    ? [
        {
          key: 'name',
          header: t('regions.table.region'),
          sortable: true,
          cell: (l) => (
            <button
              type="button"
              onClick={() => openRegion(l.id)}
              className="group/open inline-flex items-center gap-1.5 rounded-md text-left underline-offset-4 hover:text-primary hover:underline"
            >
              {areaName(l.id, { short: true })}
              <ArrowRight aria-hidden className="h-3.5 w-3.5 opacity-0 transition-opacity group-hover/open:opacity-100 group-hover:opacity-60" />
            </button>
          ),
          footer: (
            <span className="flex items-center gap-2">
              <Landmark aria-hidden className="h-3.5 w-3.5 text-primary" />
              {t('schools.regionsTable.national')}
            </span>
          ),
        },
        countColumn('schools', t('schools.regionsTable.schools'), OFFICIAL_NATIONAL.schools, view.maxSchools),
        countColumn('privateSchools', t('schools.regionsTable.private'), OFFICIAL_NATIONAL.privateSchools),
        {
          key: 'covered',
          header: t('regions.table.pupils'),
          sub: t('regions.table.pupilsSub'),
          sortable: true,
          align: 'right',
          className: 'pr-3',
          cell: (l) => <PupilsCell covered={l.covered} official={l.official} />,
          footer: <PupilsCell covered={view.covered} official={view.official} />,
        },
        ...SHOWN_METRICS.map(
          (m): KitColumn<Line> => ({
            key: m,
            header: t(`metrics.${m}.label`),
            sortable: true,
            sortTitle: t('regions.table.sortBy', { column: t(`metrics.${m}.title`) }),
            // O'zgarishlar "Hududlar" sahifasida; bu yerda — ixcham: soni va daraja.
            cell: (l) => <MetricCell metric={m} value={l.values[m]?.value} stats={view.stats[m]} />,
            footer: <MetricCell metric={m} value={national?.[m]?.value} tint={false} />,
          }),
        ),
      ]
    : [];

  const exportCsv = () => {
    if (!view) return;
    const csv: CsvColumn<Line>[] = [
      { header: t('regions.table.region'), value: (l) => areaName(l.id) },
      { header: t('schools.regionsTable.schools'), value: (l) => l.schools },
      { header: t('schools.regionsTable.private'), value: (l) => l.privateSchools },
      { header: t('regions.table.csvOfficial'), value: (l) => l.official },
      { header: t('regions.table.csvCovered'), value: (l) => l.covered },
      ...SHOWN_METRICS.map((m): CsvColumn<Line> => ({ header: t(`metrics.${m}.label`), value: (l) => csvNumber(l.values[m]?.value) })),
    ];
    downloadCsv(`${t('schools.regionsTable.csvFile')}-${csvStamp()}`, view.sorted, csv);
  };

  return (
    <Section
      id="sec-districts"
      icon={<MapPinned />}
      title={t('schools.regionsTable.title')}
      subtitle={t('schools.regionsTable.subtitle')}
      actions={<ExportMenu onCsv={exportCsv} disabled={!view} />}
    >
      {error ? (
        <ErrorState error={error} onRetry={retry} />
      ) : !view ? (
        <Skeleton className="h-[600px] w-full rounded-xl" />
      ) : (
        <>
          <KitTable
            columns={columns}
            rows={view.sorted}
            rowKey={(l) => l.id}
            sort={sort}
            onSort={(key) => toggle(key as SortKey)}
            onRowClick={(l) => openRegion(l.id)}
            minWidth={860}
            caption={t('schools.regionsTable.title')}
          />
          <p className="mt-2.5 text-[0.7rem] text-muted-foreground">
            {t('schools.regionsTable.hint')} {t('regions.table.legendHeat')}
          </p>
        </>
      )}
    </Section>
  );
}
