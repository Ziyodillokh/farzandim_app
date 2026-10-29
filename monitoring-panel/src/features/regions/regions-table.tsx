'use client';

import { Landmark, Table2 } from 'lucide-react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useMemo, useState } from 'react';

import { ErrorState } from '@/components/common/error-state';
import { ExportMenu } from '@/components/common/export-menu';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { MetricKey, RegionRow } from '@/data/contracts';
import { METRICS } from '@/data/mock/model/metrics';
import { REGION_TABLE_METRICS } from '@/data/mock/services/overview';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { downloadCsv, type CsvColumn } from '@/lib/csv';
import { csvMetricHeader, csvNumber, csvStamp } from './kit/csv';
import { columnStats, type ColumnStats } from './kit/heat';
import { KitTable, type KitColumn } from './kit/kit-table';
import { MetricCell } from './kit/metric-cell';
import { PupilsCell } from './kit/pupils-cell';
import { RankBadge, rankMap, rankTone } from './kit/rank';
import { Segmented } from './kit/segmented';
import { bestFirstDir, sortRows, useTableSort, type SortDir } from './kit/sort';
import { groupMetrics, METRIC_GROUPS, type MetricGroupKey } from './metric-groups';
import type { NationalStats } from './use-regions-data';

type SortKey = 'name' | 'covered' | MetricKey;
type CsvLine = { name: string; official: number; covered: number; values: NationalStats };

const firstDir = (key: SortKey): SortDir => (key === 'name' ? 'asc' : key === 'covered' ? 'desc' : bestFirstDir(key));
const profileHref = (id: string) => `/regions/view?id=${id}`;
/** Jadvalning eng kichik eni: nom + o'quvchilar ustunlari va har ko'rsatkich ustuni. */
const MIN_WIDTH_BASE = 262;
const MIN_WIDTH_PER_METRIC = 126;


/** "Barcha hududlar": saralanadigan jadval, ko'rsatkich guruhlari, o'rinlar, CSV. */
export function RegionsTableSection({
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
  const { t, locale } = useI18n();
  const areaName = useAreaName();
  const router = useRouter();
  const [group, setGroup] = useState<MetricGroupKey>('learning');
  const { sort, toggle, setSort } = useTableSort<SortKey>({ key: 'mastery', dir: 'desc' }, firstDir);
  const metrics = groupMetrics(group);
  const visible: readonly MetricKey[] = useMemo(() => ['coverage', ...metrics], [metrics]);

  const changeGroup = (next: MetricGroupKey) => {
    setGroup(next);
    const nextMetrics = groupMetrics(next);
    const keep = sort.key === 'name' || sort.key === 'covered' || sort.key === 'coverage' || nextMetrics.includes(sort.key);
    if (!keep) setSort({ key: nextMetrics[0], dir: firstDir(nextMetrics[0]) });
  };

  const view = useMemo(() => {
    if (!rows) return null;
    const valueOf = (key: SortKey) => (r: RegionRow) =>
      key === 'name' ? areaName(r.id, { short: true }) : key === 'covered' ? r.covered : (r.values[key]?.value ?? null);
    const rankKey: Exclude<SortKey, 'name'> = sort.key === 'name' ? metrics[0] : sort.key;
    const better = rankKey === 'covered' ? 'up' : METRICS[rankKey].better;
    const ranks = rankMap(rows, (r) => r.id, valueOf(rankKey) as (r: RegionRow) => number | null, better);
    const stats = Object.fromEntries(visible.map((m) => [m, columnStats(rows.map((r) => r.values[m]?.value))])) as Record<MetricKey, ColumnStats | null>;
    return {
      sorted: sortRows(rows, valueOf(sort.key), sort.dir, locale),
      ranks,
      polar: rankKey !== 'covered' && better !== 'neutral',
      stats,
      official: rows.reduce((s, r) => s + r.official, 0),
      covered: rows.reduce((s, r) => s + r.covered, 0),
    };
  }, [rows, sort, locale, metrics, visible, areaName]);

  const exportCsv = () => {
    if (!view) return;
    const lines: CsvLine[] = [
      ...view.sorted.map((r) => ({ name: areaName(r.id), official: r.official, covered: r.covered, values: r.values })),
      { name: t('regions.table.national'), official: view.official, covered: view.covered, values: national ?? {} },
    ];
    const columns: CsvColumn<CsvLine>[] = [
      { header: t('regions.table.region'), value: (l) => l.name },
      { header: t('regions.table.csvOfficial'), value: (l) => l.official },
      { header: t('regions.table.csvCovered'), value: (l) => l.covered },
      ...REGION_TABLE_METRICS.flatMap((m): CsvColumn<CsvLine>[] => {
        const label = t(`metrics.${m}.label`);
        return [
          { header: csvMetricHeader(m, label, t('common.units.min')), value: (l) => csvNumber(l.values[m]?.value) },
          { header: t('regions.table.csvChange', { metric: label }), value: (l) => csvNumber(l.values[m]?.delta) },
        ];
      }),
    ];
    downloadCsv(`${t('regions.table.csvFile')}-${csvStamp()}`, lines, columns);
  };

  const columns: KitColumn<RegionRow>[] = view
    ? [
        {
          key: 'name',
          header: t('regions.table.region'),
          sortable: true,
          sortTitle: t('regions.table.sortBy', { column: t('regions.table.region') }),
          cell: (r) => {
            const rank = view.ranks.get(r.id);
            return (
              <span className="flex items-center gap-2.5">
                <RankBadge rank={rank} tone={rankTone(rank, rows?.length ?? 0, view.polar)} title={rank ? t('regions.table.rankTitle', { rank, total: rows?.length ?? 0 }) : undefined} />
                <Link href={profileHref(r.id)} className="truncate underline-offset-4 hover:underline">
                  {areaName(r.id, { short: true })}
                </Link>
              </span>
            );
          },
          footer: (
            <span className="flex items-center gap-2.5">
              <span className="inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary ring-1 ring-inset ring-primary/20">
                <Landmark aria-hidden className="h-3.5 w-3.5" />
              </span>
              {t('regions.table.national')}
            </span>
          ),
        },
        {
          key: 'covered',
          header: t('regions.table.pupils'),
          sub: t('regions.table.pupilsSub'),
          sortable: true,
          sortTitle: t('regions.table.sortBy', { column: t('regions.table.pupils') }),
          align: 'right',
          className: 'pr-3',
          cell: (r) => <PupilsCell covered={r.covered} official={r.official} />,
          footer: <PupilsCell covered={view.covered} official={view.official} />,
        },
        ...visible.map(
          (m): KitColumn<RegionRow> => ({
            key: m,
            header: t(`metrics.${m}.label`),
            sortable: true,
            sortTitle: t('regions.table.sortBy', { column: t(`metrics.${m}.title`) }),
            cell: (r) => <MetricCell metric={m} value={r.values[m]?.value} delta={r.values[m]?.delta ?? null} stats={view.stats[m]} />,
            footer: <MetricCell metric={m} value={national?.[m]?.value} delta={national?.[m]?.delta ?? null} tint={false} />,
          }),
        ),
      ]
    : [];

  return (
    <Section
      id="sec-table"
      icon={<Table2 />}
      title={t('regions.table.title')}
      subtitle={t('regions.table.subtitle')}
      actions={<ExportMenu onCsv={exportCsv} disabled={!view} />}
    >
      {error ? (
        <ErrorState error={error} onRetry={onRetry} />
      ) : !view ? (
        <div className="space-y-3">
          <Skeleton className="h-10 w-80 max-w-full rounded-xl" />
          <Skeleton className="h-[600px] w-full rounded-xl" />
        </div>
      ) : (
        <>
          <div className="mb-3 flex flex-wrap items-center justify-between gap-x-4 gap-y-2">
            <Segmented
              options={METRIC_GROUPS.map((g) => ({ key: g.key, label: t(`regions.groups.${g.key}`) }))}
              value={group}
              onChange={changeGroup}
              label={t('regions.groups.label')}
            />
            <p className="text-[0.7rem] text-muted-foreground">{t('regions.table.legendRank')}</p>
          </div>
          <KitTable
            columns={columns}
            rows={view.sorted}
            rowKey={(r) => r.id}
            sort={sort}
            onSort={(key) => toggle(key as SortKey)}
            onRowClick={(r) => router.push(profileHref(r.id))}
            minWidth={MIN_WIDTH_BASE + visible.length * MIN_WIDTH_PER_METRIC}
            caption={t('regions.table.title')}
          />
          <div className="mt-2.5 space-y-1 text-[0.7rem] text-muted-foreground">
            <p>
              {t('regions.table.legendHeat')} {t('regions.table.legendDelta')}
            </p>
            {metrics.includes('iqMean') && <p>{t('regions.table.neutralHint')}</p>}
          </div>
        </>
      )}
    </Section>
  );
}
