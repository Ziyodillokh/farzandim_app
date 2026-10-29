'use client';

import { ArrowUpRight, Trophy } from 'lucide-react';
import Link from 'next/link';
import type { ReactNode } from 'react';

import type { MetricKey, RegionRow } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';
import type { RegionSummary } from './compare-model';

const TAG_TONE = {
  good: 'bg-cyan-500/12 text-cyan-800 ring-cyan-500/30 dark:text-cyan-200',
  attention: 'bg-amber-500/12 text-amber-800 ring-amber-500/30 dark:text-amber-200',
} as const;

function Figure({ value, label, icon }: { value: string; label: string; icon?: ReactNode }) {
  return (
    <div className="flex flex-col-reverse justify-end rounded-xl bg-white/50 px-3 py-2 ring-1 ring-inset ring-border/50 dark:bg-white/[0.03]">
      <dt className="mt-0.5 text-[0.68rem] leading-snug text-muted-foreground">{label}</dt>
      <dd className="flex items-center gap-1.5 font-display text-[1.05rem] font-semibold">
        {icon}
        {value}
      </dd>
    </div>
  );
}

function TagRow({ label, metrics, tone, empty }: { label: string; metrics: readonly MetricKey[]; tone: keyof typeof TAG_TONE; empty: string }) {
  const { t } = useI18n();
  return (
    <div className="mt-2.5 flex flex-wrap items-center gap-1.5 text-[0.72rem]">
      <span className="mr-0.5 font-semibold text-muted-foreground">{label}:</span>
      {metrics.length ? (
        metrics.map((m) => (
          <span key={m} className={cn('rounded-full px-2 py-0.5 font-semibold ring-1 ring-inset', TAG_TONE[tone])}>
            {t(`metrics.${m}.label`)}
          </span>
        ))
      ) : (
        <span className="text-muted-foreground">{empty}</span>
      )}
    </div>
  );
}

/** Tanlangan hudud xulosasi: qamrov, "eng yaxshi" soni, respublikadan yaxshiroq ko'rsatkichlar, kuchli va e'tibor tomonlari. */
export function RegionSummaryCard({ index, row, summary }: { index: number; row: RegionRow; summary: RegionSummary }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  return (
    <article className="flex h-full flex-col rounded-2xl bg-primary/[0.04] p-4 ring-1 ring-inset ring-border/50 dark:bg-white/[0.025]">
      <div className="flex items-start justify-between gap-3">
        <h3 className="flex min-w-0 items-start gap-2 text-[0.95rem] font-semibold leading-6">
          <span aria-hidden className="flex h-6 w-6 shrink-0 items-center justify-center rounded-lg bg-brand-gradient text-[0.72rem] font-bold text-white">
            {index + 1}
          </span>
          <span className="min-w-0 text-balance">{areaName(row.id)}</span>
        </h3>
        <Link
          href={`/regions/view?id=${row.id}`}
          className="-mr-1 inline-flex h-7 shrink-0 items-center gap-1 rounded-lg px-2 text-[0.74rem] font-semibold text-primary transition-colors hover:bg-primary/[0.08]"
        >
          {t('regions.compare.profile')}
          <ArrowUpRight aria-hidden className="h-3.5 w-3.5" />
        </Link>
      </div>
      <p className="mt-1 flex flex-wrap gap-x-1.5 text-[0.72rem] tabular-nums text-muted-foreground">
        <span className="whitespace-nowrap">{t('regions.compare.pupils', { covered: fmt.count(row.covered), official: fmt.count(row.official) })}</span>
        <span aria-hidden>·</span>
        <span className="whitespace-nowrap">
          {t('metrics.coverage.label')} <b className="font-semibold text-foreground/85">{fmt.value('coverage', row.values.coverage?.value)}</b>
        </span>
      </p>
      <dl className="mt-3 grid grid-cols-2 gap-2">
        <Figure
          value={t('regions.compare.ratio', { count: summary.wins, total: summary.total })}
          label={t('regions.compare.wins')}
          icon={<Trophy aria-hidden className="h-4 w-4 text-cyan-500 dark:text-cyan-300" />}
        />
        <Figure value={t('regions.compare.ratio', { count: summary.above, total: summary.total })} label={t('regions.compare.above')} />
      </dl>
      <TagRow label={t('regions.compare.strengths')} metrics={summary.strengths} tone="good" empty={t('regions.compare.nearNational')} />
      <TagRow label={t('regions.compare.attention')} metrics={summary.attention} tone="attention" empty={t('regions.compare.nearNational')} />
    </article>
  );
}
