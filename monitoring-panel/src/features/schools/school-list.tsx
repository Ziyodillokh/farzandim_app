'use client';

import { LifeBuoy, SearchX, TrendingUp } from 'lucide-react';
import { useMemo } from 'react';

import { DeltaChip } from '@/components/charts/delta-chip';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { ExportMenu } from '@/components/common/export-menu';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { SchoolRow, Scope } from '@/data/contracts';
import { csvNumber, csvStamp } from '@/features/regions/kit/csv';
import { centeredStats } from '@/features/regions/kit/heat';
import { KitTable, type KitColumn } from '@/features/regions/kit/kit-table';
import { MetricCell } from '@/features/regions/kit/metric-cell';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { downloadCsv, type CsvColumn } from '@/lib/csv';
import { useMetricFormat } from '@/lib/format';

export type ListKind = 'top' | 'support';
/** Doira (respublika yoki hudud) o'rtachalari — joriy filtrlar bilan (overview KPI). */
export type ScopeReference = { mastery: number | null; attendance: number | null; wellbeing: number | null; iqMean: number | null };

type RankedSchool = SchoolRow & { rank: number };

/** Doira o'rtachasi atrofida rang: mayda farqlar bo'rttirilmasin. */
const MIN_SPREAD = { mastery: 6, attendance: 1.5, wellbeing: 4 } as const;
const MIN_WIDTH = 860;

/** Maktablar reytingi (eng ko'p o'sgan yoki qo'llab-quvvatlash kerak) — anonim kodlar bilan. */
export function SchoolListSection({
  kind,
  rows,
  scope,
  reference,
  error,
  onRetry,
}: {
  kind: ListKind;
  rows: SchoolRow[] | undefined;
  scope: Scope;
  reference: ScopeReference;
  error: unknown;
  onRetry: () => void;
}) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const national = scope.kind === 'NATIONAL';

  const ranked = useMemo<RankedSchool[] | undefined>(() => rows?.map((r, i) => ({ ...r, rank: i + 1 })), [rows]);
  const stats = useMemo(
    () => ({
      mastery: centeredStats(rows?.map((r) => r.mastery) ?? [], reference.mastery, MIN_SPREAD.mastery),
      attendance: centeredStats(rows?.map((r) => r.attendance) ?? [], reference.attendance, MIN_SPREAD.attendance),
      wellbeing: centeredStats(rows?.map((r) => r.wellbeing) ?? [], reference.wellbeing, MIN_SPREAD.wellbeing),
    }),
    [rows, reference.mastery, reference.attendance, reference.wellbeing],
  );

  const district = (r: SchoolRow) => areaName(r.districtId, { fallback: r.districtName });

  const columns: KitColumn<RankedSchool>[] = [
    {
      key: 'code',
      header: t('schools.list.code'),
      cell: (r) => (
        <span className="flex items-center gap-2.5" title={t('schools.list.codeHint')}>
          <span className="w-5 text-right text-[0.7rem] font-semibold tabular-nums text-muted-foreground">{r.rank}</span>
          <span className="rounded-md bg-primary/[0.07] px-1.5 py-0.5 text-[0.78rem] font-semibold tabular-nums tracking-wide ring-1 ring-inset ring-border/60 dark:bg-white/[0.05]">
            {r.code}
          </span>
        </span>
      ),
    },
    {
      key: 'district',
      header: t('schools.list.district'),
      align: 'left',
      cell: (r) => (
        <span className="block min-w-[9rem] leading-tight">
          <span className="block font-medium">{district(r)}</span>
          {national && <span className="block text-[0.7rem] text-muted-foreground">{areaName(r.regionId, { short: true })}</span>}
        </span>
      ),
    },
    {
      key: 'type',
      header: t('schools.list.type'),
      cell: (r) => (
        <span className="inline-flex rounded-full bg-primary/[0.07] px-2 py-0.5 text-[0.7rem] font-semibold text-muted-foreground ring-1 ring-inset ring-border/60 dark:bg-white/[0.04]">
          {t(`enums.schoolType.${r.type}`)}
        </span>
      ),
    },
    { key: 'pupils', header: t('schools.list.pupils'), align: 'right', className: 'pr-3', cell: (r) => fmt.count(r.pupils) },
    { key: 'mastery', header: t('metrics.mastery.label'), cell: (r) => <MetricCell metric="mastery" value={r.mastery} stats={stats.mastery} /> },
    {
      key: 'growth',
      header: t('schools.list.growth'),
      sub: t('schools.list.growthSub'),
      cell: (r) => (r.growth === null ? <span className="text-muted-foreground">—</span> : <DeltaChip metric="mastery" delta={r.growth} title={t('common.vsLastYear')} />),
    },
    { key: 'attendance', header: t('metrics.attendance.label'), cell: (r) => <MetricCell metric="attendance" value={r.attendance} stats={stats.attendance} /> },
    { key: 'wellbeing', header: t('metrics.wellbeing.label'), cell: (r) => <MetricCell metric="wellbeing" value={r.wellbeing} stats={stats.wellbeing} /> },
  ];

  const exportCsv = () => {
    if (!ranked) return;
    const csv: CsvColumn<RankedSchool>[] = [
      { header: t('schools.list.rank'), value: (r) => r.rank },
      { header: t('schools.list.code'), value: (r) => r.code },
      { header: t('schools.list.district'), value: district },
      { header: t('regions.table.region'), value: (r) => areaName(r.regionId) },
      { header: t('schools.list.type'), value: (r) => t(`enums.schoolType.${r.type}`) },
      { header: t('schools.list.pupils'), value: (r) => r.pupils },
      { header: `${t('metrics.mastery.label')}, %`, value: (r) => csvNumber(r.mastery) },
      { header: `${t('schools.list.growth')}, ${t('common.units.pp')}`, value: (r) => csvNumber(r.growth) },
      { header: `${t('metrics.attendance.label')}, %`, value: (r) => csvNumber(r.attendance) },
      { header: t('metrics.wellbeing.label'), value: (r) => csvNumber(r.wellbeing) },
    ];
    downloadCsv(`${t(`schools.${kind}.csvFile`)}-${csvStamp()}`, ranked, csv);
  };

  return (
    <Section
      id={kind === 'top' ? 'sec-growth' : 'sec-support'}
      icon={kind === 'top' ? <TrendingUp /> : <LifeBuoy />}
      title={t(`schools.${kind}.title`)}
      subtitle={t(`schools.${kind}.subtitle`)}
      actions={<ExportMenu onCsv={exportCsv} disabled={!ranked?.length} />}
    >
      {error ? (
        <ErrorState error={error} onRetry={onRetry} />
      ) : !ranked ? (
        <Skeleton className="h-[470px] w-full rounded-xl" />
      ) : ranked.length === 0 ? (
        <EmptyState icon={<SearchX />} title={t('schools.list.empty')} description={t('schools.list.emptyHint')} />
      ) : (
        <>
          <KitTable columns={columns} rows={ranked} rowKey={(r) => r.id} minWidth={MIN_WIDTH} caption={t(`schools.${kind}.title`)} />
          <p className="mt-2.5 text-[0.7rem] text-muted-foreground">{t('schools.list.legend')}</p>
        </>
      )}
    </Section>
  );
}
