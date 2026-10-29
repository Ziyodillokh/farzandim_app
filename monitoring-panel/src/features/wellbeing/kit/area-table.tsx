'use client';

import Link from 'next/link';
import { useCallback, useMemo, useState } from 'react';

import { useCan } from '@/auth/use-session';
import { type Column, DataTable, type SortState } from '@/components/common/data-table';
import type { AreaMatrix, AreaRow, MetricKey, Scope } from '@/data/contracts';
import { METRICS } from '@/data/mock/model/metrics';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { heatStyle } from '@/lib/color-scale';
import { type CsvColumn, downloadCsv } from '@/lib/csv';
import { deltaTone, TONE_TEXT, useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';
import { meanOf } from './analysis';
import { csvHeader, csvNumber, csvStamp } from './csv';

type ColumnStat = { mean: number; spread: number };

const valueOf = (row: AreaRow, key: MetricKey) => row.values[key]?.value ?? null;

/** Standart saralash: birinchi ko'rsatkich, eng yaxshisi tepada. */
function defaultSort(metrics: readonly MetricKey[]): SortState {
  const first = metrics[0];
  if (!first) return { sortBy: 'name', sortDir: 'asc' };
  return { sortBy: first, sortDir: METRICS[first].better === 'down' ? 'asc' : 'desc' };
}

function columnStats(rows: readonly AreaRow[], metrics: readonly MetricKey[]): Partial<Record<MetricKey, ColumnStat>> {
  const out: Partial<Record<MetricKey, ColumnStat>> = {};
  for (const m of metrics) {
    const values = rows.map((r) => valueOf(r, m)).filter((v): v is number => v !== null);
    const mean = meanOf(values);
    if (mean === null) continue;
    out[m] = { mean, spread: Math.max(...values.map((v) => Math.abs(v - mean))) };
  }
  return out;
}

/** Hudud/tuman qatorlari CSV (Excel uz/ru: vergulli kasr) — joriy til nomlari va birliklar bilan. */
export function useAreaCsv(scope: Scope, metrics: readonly MetricKey[]) {
  const { t } = useI18n();
  const areaName = useAreaName();
  return useCallback(
    (filename: string, rows: readonly AreaRow[]) => {
      const minutes = t('common.units.min');
      const columns: CsvColumn<AreaRow>[] = [
        { header: scope.kind === 'NATIONAL' ? t('nav.regions') : t('common.districtsTitle'), value: (r) => areaName(r.id, { fallback: r.name }) },
        { header: t('wellbeing.kit.covered'), value: (r) => r.covered },
        ...metrics.flatMap((m): CsvColumn<AreaRow>[] => [
          { header: csvHeader(m, t(`metrics.${m}.title`), minutes), value: (r) => csvNumber(valueOf(r, m)) },
          { header: `${t(`metrics.${m}.label`)} — ${t('common.change')}`, value: (r) => csvNumber(r.values[m]?.delta) },
        ]),
      ];
      downloadCsv(`${filename}-${csvStamp()}`, rows, columns);
    },
    [areaName, metrics, scope.kind, t],
  );
}

/**
 * Hududlar (yoki tumanlar) × ko'rsatkichlar jadvali: sarlavhani bosib saralash,
 * katakcha rangi — ustun o'rtachasiga nisbatan (moviy — yaxshiroq, amber — e'tibor),
 * ostida — o'tgan yilga nisbatan o'zgarish.
 */
export function AreaTable({ scope, metrics, data, loading }: { scope: Scope; metrics: readonly MetricKey[]; data: AreaMatrix | undefined; loading?: boolean }) {
  const { t, locale } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const can = useCan();
  const [sort, setSort] = useState<SortState>(() => defaultSort(metrics));
  const linkable = scope.kind === 'NATIONAL' && can('regions.view');
  const stats = useMemo(() => columnStats(data?.rows ?? [], metrics), [data, metrics]);

  const rows = useMemo(() => {
    if (!data) return undefined;
    const dir = sort.sortDir === 'desc' ? -1 : 1;
    const key = sort.sortBy ?? 'name';
    const name = (r: AreaRow) => areaName(r.id, { short: true, fallback: r.name });
    return [...data.rows].sort((a, b) => {
      if (key === 'name') return dir * name(a).localeCompare(name(b), locale);
      if (key === 'covered') return dir * (a.covered - b.covered);
      const va = valueOf(a, key as MetricKey);
      const vb = valueOf(b, key as MetricKey);
      if (va === null || vb === null) return va === null ? (vb === null ? 0 : 1) : -1;
      return dir * (va - vb);
    });
  }, [areaName, data, locale, sort]);

  const rankOf = useMemo(() => new Map((rows ?? []).map((r, i) => [r.id, i + 1])), [rows]);

  const columns: Column<AreaRow>[] = [
    {
      key: 'rank',
      header: '#',
      cell: (r) => <span className="text-[0.75rem] font-semibold tabular-nums text-muted-foreground">{rankOf.get(r.id)}</span>,
      className: 'w-10 pr-0',
      headerClassName: 'w-10 pr-0',
    },
    {
      key: 'name',
      header: <span className="uppercase">{scope.kind === 'NATIONAL' ? t('nav.regions') : t('common.districtsTitle')}</span>,
      sortKey: 'name',
      cell: (r) =>
        linkable ? (
          <Link href={`/regions/view?id=${r.id}`} className="font-medium hover:text-primary hover:underline" title={t('wellbeing.kit.regionProfile')}>
            {areaName(r.id, { short: true, fallback: r.name })}
          </Link>
        ) : (
          <span className="font-medium">{areaName(r.id, { short: true, fallback: r.name })}</span>
        ),
      className: 'min-w-[9.5rem] whitespace-nowrap',
    },
    {
      key: 'covered',
      header: <span className="uppercase">{t('wellbeing.kit.covered')}</span>,
      sortKey: 'covered',
      cell: (r) => <span className="tabular-nums text-muted-foreground">{fmt.count(r.covered)}</span>,
      className: 'whitespace-nowrap text-right',
      headerClassName: 'text-right',
    },
    ...metrics.map<Column<AreaRow>>((m) => ({
      key: m,
      header: <span className="uppercase">{t(`metrics.${m}.label`)}</span>,
      sortKey: m,
      className: 'px-2 py-2 text-center',
      headerClassName: 'px-2 text-center',
      cell: (r) => {
        const s = r.values[m];
        const v = s?.value ?? null;
        const col = stats[m];
        const better = METRICS[m].better;
        const style = col && better !== 'neutral' ? heatStyle(v, col.mean, col.spread, better) : undefined;
        return (
          <div className="inline-flex items-center gap-2">
            <span className="inline-block min-w-[4.6rem] rounded-md px-2 py-1 text-center font-semibold tabular-nums" style={style}>
              {fmt.value(m, v)}
            </span>
            <span className={cn('w-[4.2rem] text-left text-[0.68rem] tabular-nums', TONE_TEXT[deltaTone(m, s?.delta)])} title={t('common.vsLastYear')}>
              {s?.delta !== null && s?.delta !== undefined ? fmt.delta(m, s.delta) : ''}
            </span>
          </div>
        );
      },
    })),
  ];

  return (
    <DataTable
      columns={columns}
      rows={rows}
      rowKey={(r) => r.id}
      loading={loading}
      sort={sort}
      onSortChange={setSort}
      skeletonRows={scope.kind === 'NATIONAL' ? 14 : 10}
      className="shadow-none"
    />
  );
}
