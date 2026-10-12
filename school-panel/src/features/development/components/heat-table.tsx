'use client';

import { Grid3X3 } from 'lucide-react';

import { EmptyState } from '@/components/common/empty-state';
import { SectionCard } from '@/components/common/section-card';
import { Skeleton } from '@/components/ui/skeleton';
import type { SchoolDevOverview } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { DOMAINS, domainKey, heatStyle } from '../lib/domains';
import { HATCH } from './chart-parts';

type Row = SchoolDevOverview['heat'][number];

function Cell({ value, hidden, label }: { value: number | null | undefined; hidden: boolean; label: string }) {
  const { t } = useI18n();
  if (hidden) {
    return <div className={cn('flex h-9 items-center justify-center rounded-lg text-[0.65rem] text-muted-foreground ring-1 ring-inset ring-border/60', HATCH)} title={`${label}: ${t('development.charts.heatHidden')}`} />;
  }
  if (typeof value !== 'number') {
    return <div className="flex h-9 items-center justify-center rounded-lg text-xs text-muted-foreground/70 ring-1 ring-inset ring-border/40" title={`${label}: ${t('development.charts.heatNoData')}`}>—</div>;
  }
  return (
    <div className="flex h-9 items-center justify-center rounded-lg text-xs font-semibold tabular-nums" style={heatStyle(value)} title={`${label}: ${value}`}>
      {value}
    </div>
  );
}

function Legend() {
  const { t } = useI18n();
  return (
    <div className="mt-4 flex flex-wrap items-center gap-x-6 gap-y-2 text-xs text-muted-foreground">
      <span className="flex items-center gap-2">
        {t('development.charts.heatLow')}
        <span className="h-2.5 w-32 rounded-full" style={{ background: `linear-gradient(90deg, ${heatStyle(0).background}, ${heatStyle(50).background}, ${heatStyle(100).background})` }} />
        {t('development.charts.heatHigh')}
      </span>
      <span className="flex items-center gap-2">
        <span className={cn('h-3.5 w-5 rounded ring-1 ring-inset ring-border/60', HATCH)} />
        {t('development.charts.heatHidden')}
      </span>
    </div>
  );
}

/** Sinflar × sohalar: ketma-ket osmon → ko'k shkala; yashirin guruhlar shtrixlangan. */
export function HeatTable({ overview, loading }: { overview: SchoolDevOverview | undefined; loading?: boolean }) {
  const { t } = useI18n();
  const rows: Row[] = (overview?.heat ?? []).filter((r) => r.n > 0 || r.hidden);
  const domains = DOMAINS.filter((d) => rows.some((r) => typeof r.cells[d] === 'number'));
  return (
    <SectionCard title={t('development.charts.heatTitle')} description={t('development.charts.heatHint')} icon={<Grid3X3 />}>
      {loading && !overview ? (
        <Skeleton className="h-72 w-full rounded-xl" />
      ) : rows.length === 0 || domains.length === 0 ? (
        <EmptyState title={t('development.empty.noTerm')} className="py-10" />
      ) : (
        <>
          <div className="-mx-1 overflow-x-auto px-1 animate-fade-in">
            <table className="w-full min-w-[560px] table-fixed border-separate border-spacing-1 text-sm">
              <thead>
                <tr>
                  <th className="w-24 px-1 text-left text-xs font-medium text-muted-foreground" scope="col" />
                  {domains.map((d) => (
                    <th key={d} scope="col" className="px-1 pb-1 text-center text-[0.7rem] font-medium leading-tight text-muted-foreground">
                      {t(domainKey(d))}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.classId}>
                    <th scope="row" className="whitespace-nowrap px-1 text-left text-xs font-semibold">
                      {r.className}
                      {!r.hidden && <span className="ml-1 font-normal text-muted-foreground tabular-nums">n={r.n}</span>}
                    </th>
                    {domains.map((d) => (
                      <td key={d}>
                        <Cell value={r.cells[d]} hidden={r.hidden} label={`${r.className} · ${t(domainKey(d))}`} />
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <Legend />
        </>
      )}
    </SectionCard>
  );
}
