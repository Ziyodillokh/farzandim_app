'use client';

import { ArrowRight, CheckCircle2, Hourglass } from 'lucide-react';
import Link from 'next/link';

import type { ClassBoardRow } from '@/data/mock/services/attendance';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { COUNT_FIELDS, STATUS_TONE, rateTextClass } from '../lib';
import { StackedBar } from './stacked-bar';

/** Taxtadagi sinf kartochkasi (shisha): davomat ulushi, holatlar chizig'i, sonlar. */
export function ClassCard({ row, href }: { row: ClassBoardRow; href: string }) {
  const { t, tc, formatNumber } = useI18n();
  const { counts } = row;
  const decided = counts.total - counts.pending;

  return (
    <Link
      href={href}
      className="glass card-glow group flex flex-col rounded-2xl p-4 animate-fade-in focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <p className="font-display text-xl font-semibold tracking-[-0.02em]">{row.className}</p>
            <span className="rounded-full bg-primary/10 px-2 py-0.5 text-2xs font-semibold text-primary ring-1 ring-inset ring-primary/15">{row.shiftName}</span>
          </div>
          <p className="mt-1 truncate text-xs text-muted-foreground">{row.homeroomName ?? t('attendance.board.noHomeroom')}</p>
        </div>
        {row.schoolDay ? (
          <p className={cn('shrink-0 font-display text-[1.35rem] font-semibold leading-none tabular-nums', decided > 0 ? rateTextClass(row.rate) : 'text-muted-foreground')}>
            {decided > 0 ? `${row.rate}%` : '—'}
          </p>
        ) : (
          <span className="shrink-0 rounded-full bg-muted px-2 py-0.5 text-2xs font-semibold text-muted-foreground">{t('attendance.noSchoolDay')}</span>
        )}
      </div>

      <StackedBar counts={counts} className="mt-4" label={row.className} />

      <div className="mt-3 flex min-h-[1.25rem] flex-wrap gap-x-3 gap-y-1 text-xs">
        {COUNT_FIELDS.filter(({ field }) => field !== 'pending' && counts[field] > 0).map(({ field, status, labelKey }) => (
          <span key={field} className="inline-flex items-center gap-1.5">
            <span className={cn('h-2 w-2 rounded-full', STATUS_TONE[status].dot)} />
            <span className="font-semibold tabular-nums">{formatNumber(counts[field])}</span>
            <span className="text-muted-foreground">{t(labelKey)}</span>
          </span>
        ))}
      </div>

      <div className="mt-4 flex items-center justify-between rounded-xl bg-white/50 px-3 py-2 text-xs ring-1 ring-inset ring-border/60 dark:bg-white/[0.03]">
        {row.schoolDay && counts.pending > 0 ? (
          <span className="inline-flex items-center gap-1.5 font-medium text-muted-foreground">
            <Hourglass className="h-3.5 w-3.5" />
            {t('attendance.board.pendingCount', { count: formatNumber(counts.pending) })}
          </span>
        ) : row.schoolDay ? (
          <span className="inline-flex items-center gap-1.5 font-medium text-success">
            <CheckCircle2 className="h-3.5 w-3.5" />
            {t('attendance.board.allMarked')}
          </span>
        ) : (
          <span className="text-muted-foreground">{row.shiftName}</span>
        )}
        <span className="inline-flex items-center gap-1 text-muted-foreground transition-colors group-hover:text-primary">
          {row.schoolDay && tc('common.studentsCount', counts.total)}
          <ArrowRight className="h-3.5 w-3.5 transition-transform group-hover:translate-x-0.5" />
        </span>
      </div>
    </Link>
  );
}
