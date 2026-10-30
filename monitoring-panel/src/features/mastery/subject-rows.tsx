'use client';

import { Award, CircleAlert } from 'lucide-react';
import type { ReactNode } from 'react';

import { DeltaChip } from '@/components/charts/delta-chip';
import type { MetricKey } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';
import type { RankedSubject, SubjectTag } from './subject-rank';

const WIDE_NATIONAL = 'xl:grid-cols-[2rem_minmax(8rem,10rem)_minmax(0,1fr)_6.5rem_7rem_6rem]';
const WIDE_REGION = 'xl:grid-cols-[2rem_minmax(8rem,10rem)_minmax(0,1fr)_6.5rem_7rem_8rem_6rem]';

const ROW_TONE: Record<Exclude<SubjectTag, null>, string> = {
  top: 'bg-emerald-500/[0.07] ring-1 ring-inset ring-emerald-500/20',
  bottom: 'bg-amber-500/[0.08] ring-1 ring-inset ring-amber-500/25',
};

const BAR_TONE: Record<Exclude<SubjectTag, null>, string> = {
  top: 'bg-gradient-to-r from-emerald-500 to-emerald-400',
  bottom: 'bg-gradient-to-r from-amber-500 to-amber-400',
};

const clampPct = (v: number) => `${Math.min(100, Math.max(0, v))}%`;

/** Ustun nomi ekran o'quvchisi uchun (keng ekrandagi sarlavha qatori faqat ko'rinish uchun). */
function SrLabel({ children }: { children: string }) {
  return <span className="sr-only">{children}: </span>;
}

/** Katak: ekran o'quvchisi uchun ustun nomi + qiymat. */
function Cell({ label, className, children }: { label: string; className?: string; children: ReactNode }) {
  return (
    <span className={className}>
      <SrLabel>{label}</SrLabel>
      {children}
    </span>
  );
}

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
      {top ? <Award aria-hidden className="h-3 w-3" /> : <CircleAlert aria-hidden className="h-3 w-3" />}
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

/** O'zlashtirish ustuni (0–100): respublika qiymati — vertikal chiziq (hudud doirasida). Qiymatlar matnda ham bor. */
function MasteryBar({ row, region, className }: { row: RankedSubject; region: boolean; className?: string }) {
  return (
    <span aria-hidden className={cn('relative block h-2.5 min-w-0 rounded-full bg-muted/70', className)}>
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
      <Cell label={t('mastery.subjects.colRank')} className="text-center text-[0.72rem] font-semibold tabular-nums text-muted-foreground">
        {row.rank ?? '—'}
      </Cell>
      <SubjectName row={row} />
      <span className="flex min-w-0 items-center gap-3">
        <MasteryBar row={row} region={region} className="flex-1" />
        <Cell label={t('mastery.subjects.colMastery')} className="w-14 shrink-0 text-right text-[0.85rem] font-semibold tabular-nums">
          {fmt.value('mastery', row.value)}
        </Cell>
      </span>
      <Cell label={t('mastery.subjects.colSuccess')} className="text-right text-[0.82rem] tabular-nums text-muted-foreground">
        {fmt.pct(row.success)}
      </Cell>
      <Cell label={t('mastery.subjects.colChange')} className="flex justify-end">
        <DeltaCell metric="mastery" delta={row.delta} title={t('common.vsLastYear')} />
      </Cell>
      {region && (
        <Cell label={t('mastery.subjects.colVsNational')} className="flex justify-end">
          <DeltaCell metric="mastery" delta={row.vsNational} title={t('common.vsNational')} />
        </Cell>
      )}
      <Cell label={t('mastery.subjects.colInterest')} className="text-right text-[0.82rem] tabular-nums text-muted-foreground">
        {fmt.pct(row.interest)}
      </Cell>
    </div>
  );
}

function CompactRow({ row, region }: { row: RankedSubject; region: boolean }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const meta = [t('mastery.subjects.metaSuccess', { value: fmt.pct(row.success) }), t('mastery.subjects.metaInterest', { value: fmt.pct(row.interest) })];
  if (region && row.national !== null) {
    const diff = row.vsNational === null ? '' : ` (${fmt.delta('mastery', row.vsNational)})`;
    meta.push(`${t('mastery.subjects.metaNational', { value: fmt.value('mastery', row.national) })}${diff}`);
  }
  return (
    <div className={cn('grid grid-cols-[1.5rem_minmax(0,1fr)_auto] items-center gap-x-2 gap-y-1.5 rounded-xl px-2 py-2.5 xl:hidden', row.tag && ROW_TONE[row.tag])}>
      <Cell label={t('mastery.subjects.colRank')} className="text-center text-[0.72rem] font-semibold tabular-nums text-muted-foreground">
        {row.rank ?? '—'}
      </Cell>
      <SubjectName row={row} />
      <span className="flex items-center gap-1.5">
        <Cell label={t('mastery.subjects.colMastery')} className="text-[0.85rem] font-semibold tabular-nums">
          {fmt.value('mastery', row.value)}
        </Cell>
        <Cell label={t('mastery.subjects.colChange')}>
          <DeltaCell metric="mastery" delta={row.delta} title={t('common.vsLastYear')} />
        </Cell>
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
    <div aria-hidden className={cn('hidden gap-x-3 px-2 pb-1.5 xl:grid', region ? WIDE_REGION : WIDE_NATIONAL)}>
      <span className={cn(cell, 'text-center')}>{t('mastery.subjects.colRank')}</span>
      <span className={cell}>{t('mastery.subjects.colSubject')}</span>
      <span className={cell}>{t('mastery.subjects.colMastery')}</span>
      <span className={cn(cell, 'text-right')}>{t('mastery.subjects.colSuccess')}</span>
      <span className={cn(cell, 'text-right')}>{t('mastery.subjects.colChange')}</span>
      {region && <span className={cn(cell, 'text-right')}>{t('mastery.subjects.colVsNational')}</span>}
      <span className={cn(cell, 'text-right')}>{t('mastery.subjects.colInterest')}</span>
    </div>
  );
}

/**
 * Fanlar reytingi: keng ekranda jadval ko'rinishi, torroqda — ixcham kartochkalar.
 * Har katakda ekran o'quvchisi uchun ustun nomi bor.
 */
export function SubjectRows({ rows, region }: { rows: RankedSubject[]; region: boolean }) {
  const { t } = useI18n();
  return (
    <div>
      <WideHeader region={region} />
      <ul className="space-y-1" aria-label={t('mastery.sections.subjects')}>
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
