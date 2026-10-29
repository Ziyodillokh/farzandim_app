'use client';

import { BookHeart, CircleAlert, Sparkle } from 'lucide-react';

import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Interests } from '@/data/contracts';
import { Note } from '@/features/mastery/kit/layout';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';
import { type ChoiceRow, classifySubjects, type SubjectSignal } from './subject-signal';

const WIDE = 'xl:grid-cols-[1.75rem_minmax(8rem,10rem)_minmax(0,1.15fr)_minmax(0,1fr)_10.5rem]';
const MASTERY_BAR = 'bg-gradient-to-r from-cyan-500 to-sky-400';
const pct = (v: number) => `${Math.min(100, Math.max(0, v))}%`;

const SIGNAL_TONE: Record<Exclude<SubjectSignal, null>, string> = {
  priority: 'bg-amber-500/10 text-amber-700 ring-amber-500/30 dark:text-amber-300',
  engage: 'bg-sky-500/10 text-sky-700 ring-sky-500/30 dark:text-sky-300',
};

function SignalTag({ signal }: { signal: Exclude<SubjectSignal, null> }) {
  const { t } = useI18n();
  return (
    <span className={cn('inline-flex h-6 shrink-0 items-center gap-1 rounded-full px-2 text-[0.68rem] font-semibold ring-1 ring-inset', SIGNAL_TONE[signal])}>
      {signal === 'priority' ? <CircleAlert className="h-3.5 w-3.5" /> : <Sparkle className="h-3.5 w-3.5" />}
      {signal === 'priority' ? t('interests.subjects.priority') : t('interests.subjects.engage')}
    </span>
  );
}

function Bar({ value, className, barClassName }: { value: number | null; className?: string; barClassName?: string }) {
  return (
    <span className={cn('relative block h-2 min-w-0 rounded-full bg-muted/70', className)}>
      {value !== null && <span className={cn('absolute inset-y-0 left-0 rounded-full bg-brand-gradient transition-[width] duration-700', barClassName)} style={{ width: pct(value) }} />}
    </span>
  );
}

function WideRow({ row }: { row: ChoiceRow }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  return (
    <div className={cn('hidden items-center gap-x-4 rounded-xl px-2 py-2 xl:grid', WIDE)}>
      <span className="text-center text-[0.72rem] font-semibold tabular-nums text-muted-foreground">{row.rank}</span>
      <span className="truncate text-[0.85rem] font-medium">{t(`enums.subject.${row.key}`)}</span>
      <span className="flex min-w-0 items-center gap-3">
        <Bar value={row.share} className="flex-1" />
        <span className="w-12 shrink-0 text-right text-[0.85rem] font-semibold tabular-nums">{fmt.pct(row.share)}</span>
      </span>
      <span className="flex min-w-0 items-center gap-3">
        <Bar value={row.mastery} className="flex-1" barClassName={MASTERY_BAR} />
        <span className="w-12 shrink-0 text-right text-[0.85rem] tabular-nums text-muted-foreground">{fmt.value('mastery', row.mastery)}</span>
      </span>
      <span className="flex justify-end">{row.signal && <SignalTag signal={row.signal} />}</span>
    </div>
  );
}

function CompactRow({ row }: { row: ChoiceRow }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  return (
    <div className="grid grid-cols-[1.5rem_minmax(0,1fr)_auto] items-center gap-x-2 gap-y-1.5 rounded-xl px-2 py-2 xl:hidden">
      <span className="text-center text-[0.72rem] font-semibold tabular-nums text-muted-foreground">{row.rank}</span>
      <span className="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-1">
        <span className="truncate text-[0.85rem] font-medium">{t(`enums.subject.${row.key}`)}</span>
        {row.signal && <SignalTag signal={row.signal} />}
      </span>
      <span className="text-[0.85rem] font-semibold tabular-nums">{fmt.pct(row.share)}</span>
      <Bar value={row.share} className="col-span-2 col-start-2" />
      <span className="col-span-2 col-start-2 flex items-center gap-2 text-[0.7rem] text-muted-foreground">
        <Bar value={row.mastery} className="w-16 shrink-0" barClassName={MASTERY_BAR} />
        <span className="tabular-nums">{t('interests.subjects.masteryShort', { value: fmt.value('mastery', row.mastery) })}</span>
      </span>
    </div>
  );
}

function WideHeader() {
  const { t } = useI18n();
  const cell = 'text-[0.66rem] font-semibold uppercase tracking-[0.08em] text-muted-foreground';
  return (
    <div className={cn('hidden gap-x-4 px-2 pb-1.5 xl:grid', WIDE)}>
      <span className={cn(cell, 'text-center')}>{t('interests.subjects.colRank')}</span>
      <span className={cell}>{t('interests.subjects.colSubject')}</span>
      <span className={cell}>{t('interests.subjects.colShare')}</span>
      <span className={cell}>{t('interests.subjects.colMastery')}</span>
      <span className={cn(cell, 'text-right')}>{t('interests.subjects.colSignal')}</span>
    </div>
  );
}

/** Tanlangan fanlar: ulush va shu fan bo'yicha o'zlashtirish, resurs signallari bilan. */
export function SubjectChoiceSection({ data }: { data: Interests | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const { rows, untaught, medianShare, medianMastery } = classifySubjects(data?.subjects ?? []);
  const hasPriority = rows.some((r) => r.signal === 'priority');
  const hasEngage = rows.some((r) => r.signal === 'engage');
  return (
    <Section
      id="interests-subjects"
      icon={<BookHeart />}
      title={t('interests.sections.subjects')}
      subtitle={t('interests.sections.subjectsSub')}
      href="/mastery"
      hrefLabel={t('interests.subjects.toMastery')}
    >
      {!data ? (
        <Skeleton className="h-[480px] w-full rounded-xl" />
      ) : (
        <div className="space-y-4">
          <div>
            <WideHeader />
            <ul className="space-y-0.5">
              {rows.map((row) => (
                <li key={row.key}>
                  <WideRow row={row} />
                  <CompactRow row={row} />
                </li>
              ))}
            </ul>
          </div>
          <div className="space-y-1">
            {hasPriority && <Note>{t('interests.subjects.priorityHint')}</Note>}
            {hasEngage && <Note>{t('interests.subjects.engageHint')}</Note>}
            {medianShare !== null && medianMastery !== null && (
              <Note>{t('interests.subjects.median', { share: fmt.pct(medianShare), mastery: fmt.value('mastery', medianMastery) })}</Note>
            )}
            {untaught.length > 0 && <Note>{t('mastery.kit.notTaught', { list: untaught.map((s) => t(`enums.subject.${s}`)).join(', ') })}</Note>}
          </div>
        </div>
      )}
    </Section>
  );
}
