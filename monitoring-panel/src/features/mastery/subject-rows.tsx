'use client';

import { Award, CircleAlert } from 'lucide-react';

import { DeltaChip } from '@/components/charts/delta-chip';
import type { MetricKey } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';
import type { RankedSubject, SubjectTag } from './subject-rank';

const WIDE_NATIONAL = 'xl:grid-cols-[2rem_minmax(8rem,10rem)_minmax(0,1fr)_7rem_6rem]';
const WIDE_REGION = 'xl:grid-cols-[2rem_minmax(8rem,10rem)_minmax(0,1fr)_7rem_8rem_6rem]';

const ROW_TONE: Record<Exclude<SubjectTag, null>, string> = {
  top: 'bg-emerald-500/[0.07] ring-1 ring-inset ring-emerald-500/20',
  bottom: 'bg-amber-500/[0.08] ring-1 ring-inset ring-amber-500/25',
};

const BAR_TONE: Record<Exclude<SubjectTag, null>, string> = {
  top: 'bg-gradient-to-r from-emerald-500 to-emerald-400',
  bottom: 'bg-gradient-to-r from-amber-500 to-amber-400',
};

const clampPct = (v: number) => `${Math.min(100, Math.max(0, v))}%`;

function TagBadge({ tag }: { tag: Exclude<SubjectTag, null> }) {
  const { t } = useI18n();
  const top = tag === 'top';
  return (
    <span
      className={cn(
        'inline-flex h-5 shrink-0 items-center gap-1 rounded-full px-1.5 text-[0.64rem] font-semibold uppercase tracking-[0.06em] ring-1 ring-inset',
        top ? 'bg-emerald-500/10 text-emerald-700 ring-emerald-500/25 dark:text-emerald-300' : 'bg-amber-500/10 text-amber-700 ring-amber-500/30 dark:text-amber-300',
      )}
    >
      {top ? <Award className="h-3 w-3" /> : <CircleAlert className="h-3 w-3" />}
      {top ? t('mastery.subjects.tagTop') : t('mastery.subjects.tagBottom')}
    </span>
  );
}

function SubjectName({ row }: { row: RankedSubject }) {
  const { t } = useI18n();
  return (
    <span className="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-1">
      <span className="truncate text-[0.85rem] font-medium">{t(`enums.subject.${row.subject}`)}</span>
      {row.tag && <TagBadge tag={row.tag} />}
    </span>
  );
}

/** O'zlashtirish ustuni (0–100): respublika qiymati — vertikal chiziq (hudud doirasida). */
function MasteryBar({ row, region, className }: { row: RankedSubject; region: boolean; className?: string }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  return (
    <span className={cn('relative block h-2.5 min-w-0 rounded-full bg-muted/70', className)} title={t('mastery.subjects.successTitle', { value: fmt.pct(row.success) })}>
      {row.value !== null && (
        <span className={cn('absolute inset-y-0 left-0 rounded-full bg-brand-gradient transition-[width] duration-700', row.tag && BAR_TONE[row.tag])} style={{ width: clampPct(row.value) }} />
      )}
      {region && row.national !== null && <span className="absolute -top-1 h-[18px] w-0.5 rounded-full bg-foreground/70" style={{ left: clampPct(row.national) }} />}
    </span>
  );
}

function DeltaCell({ metric, delta, title }: { metric: MetricKey; delta: number | null; title: string }) {
  if (delta === null) return <span className="text-[0.75rem] text-muted-foreground">—</span>;
  return <DeltaChip metric={metric} delta={delta} title={title} />;
}

function WideRow({ row, region }: { row: RankedSubject; region: boolean }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  return (
    <div className={cn('hidden items-center gap-x-3 rounded-xl px-2 py-2 xl:grid', region ? WIDE_REGION : WIDE_NATIONAL, row.tag && ROW_TONE[row.tag])}>
      <span className="text-center text-[0.72rem] font-semibold tabular-nums text-muted-foreground">{row.rank ?? '—'}</span>
      <SubjectName row={row} />
      <span className="flex min-w-0 items-center gap-3">
        <MasteryBar row={row} region={region} className="flex-1" />
        <span className="w-14 shrink-0 text-right text-[0.85rem] font-semibold tabular-nums">{fmt.value('mastery', row.value)}</span>
      </span>
      <span className="flex justify-end">
        <DeltaCell metric="mastery" delta={row.delta} title={t('common.vsLastYear')} />
      </span>
      {region && (
        <span className="flex justify-end">
          <DeltaCell metric="mastery" delta={row.vsNational} title={t('common.vsNational')} />
        </span>
      )}
      <span className="text-right text-[0.82rem] tabular-nums text-muted-foreground">{fmt.pct(row.interest)}</span>
    </div>
  );
}

function CompactRow({ row, region }: { row: RankedSubject; region: boolean }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const meta = [t('mastery.subjects.metaInterest', { value: fmt.pct(row.interest) })];
  if (region && row.national !== null) {
    const diff = row.vsNational === null ? '' : ` (${fmt.delta('mastery', row.vsNational)})`;
    meta.push(`${t('mastery.subjects.metaNational', { value: fmt.value('mastery', row.national) })}${diff}`);
  }
  return (
    <div className={cn('grid grid-cols-[1.5rem_minmax(0,1fr)_auto] items-center gap-x-2 gap-y-1.5 rounded-xl px-2 py-2.5 xl:hidden', row.tag && ROW_TONE[row.tag])}>
      <span className="text-center text-[0.72rem] font-semibold tabular-nums text-muted-foreground">{row.rank ?? '—'}</span>
      <SubjectName row={row} />
      <span className="flex items-center gap-1.5">
        <span className="text-[0.85rem] font-semibold tabular-nums">{fmt.value('mastery', row.value)}</span>
        <DeltaCell metric="mastery" delta={row.delta} title={t('common.vsLastYear')} />
      </span>
      <MasteryBar row={row} region={region} className="col-span-2 col-start-2" />
      <span className="col-span-2 col-start-2 text-[0.7rem] tabular-nums text-muted-foreground">{meta.join(' · ')}</span>
    </div>
  );
}

function WideHeader({ region }: { region: boolean }) {
  const { t } = useI18n();
  const cell = 'text-[0.66rem] font-semibold uppercase tracking-[0.08em] text-muted-foreground';
  return (
    <div className={cn('hidden gap-x-3 px-2 pb-1.5 xl:grid', region ? WIDE_REGION : WIDE_NATIONAL)}>
      <span className={cn(cell, 'text-center')}>{t('mastery.subjects.colRank')}</span>
      <span className={cell}>{t('mastery.subjects.colSubject')}</span>
      <span className={cell}>{t('mastery.subjects.colMastery')}</span>
      <span className={cn(cell, 'text-right')}>{t('mastery.subjects.colChange')}</span>
      {region && <span className={cn(cell, 'text-right')}>{t('mastery.subjects.colVsNational')}</span>}
      <span className={cn(cell, 'text-right')}>{t('mastery.subjects.colInterest')}</span>
    </div>
  );
}

/** Fanlar reytingi: keng ekranda jadval, torroqda — ixcham kartochkalar. */
export function SubjectRows({ rows, region }: { rows: RankedSubject[]; region: boolean }) {
  return (
    <div>
      <WideHeader region={region} />
      <ul className="space-y-1">
        {rows.map((row) => (
          <li key={row.subject}>
            <WideRow row={row} region={region} />
            <CompactRow row={row} region={region} />
          </li>
        ))}
      </ul>
    </div>
  );
}
