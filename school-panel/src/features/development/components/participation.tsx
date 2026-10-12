'use client';

import { ClipboardCheck } from 'lucide-react';

import { SectionCard } from '@/components/common/section-card';
import { Progress } from '@/components/ui/progress';
import { Skeleton } from '@/components/ui/skeleton';
import type { SchoolDevOverview } from '@/data/contracts';
import { TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { formatTerm } from '../lib/domains';

/** Qatnashish: tanlangan chorak + choraklar bo'yicha qatnashganlar soni. */
export function Participation({ overview, loading }: { overview: SchoolDevOverview | undefined; loading?: boolean }) {
  const { t, formatNumber } = useI18n();
  const p = overview?.participation;
  const max = Math.max(1, ...(overview?.trend ?? []).map((x) => x.n));
  return (
    <SectionCard title={t('development.charts.participationTitle')} description={t('development.charts.participationHint')} icon={<ClipboardCheck />}>
      {loading && !overview ? (
        <Skeleton className="h-56 w-full rounded-xl" />
      ) : (
        <div className="space-y-5 animate-fade-in">
          <div>
            <p className="font-display text-[2rem] font-semibold leading-none tracking-[-0.02em] tabular-nums">{p?.rate ?? 0}%</p>
            <p className="mt-1.5 text-sm text-muted-foreground">
              {t('development.stats.participationHint', { assessed: formatNumber(p?.assessed ?? 0), eligible: formatNumber(p?.eligible ?? 0) })}
            </p>
            <Progress value={p?.rate ?? 0} className="mt-3" aria-label={t('development.charts.participationTitle')} />
          </div>
          <div>
            <p className="mb-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">{t('development.charts.byTerm')}</p>
            <ul className="space-y-1.5">
              {[...(overview?.trend ?? [])].reverse().map((x) => (
                <li key={x.termKey} className={cn(TILE, 'flex items-center gap-3 px-3 py-2', x.termKey === overview?.termKey && 'ring-primary/30')}>
                  <span className="w-32 shrink-0 truncate text-xs text-foreground/80">{formatTerm(x.termKey, t)}</span>
                  <span className="relative h-1.5 flex-1 overflow-hidden rounded-full bg-primary/10">
                    <span className="absolute inset-y-0 left-0 rounded-full bg-primary" style={{ width: `${(x.n / max) * 100}%` }} />
                  </span>
                  <span className="w-10 text-right text-xs font-semibold tabular-nums">{formatNumber(x.n)}</span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}
    </SectionCard>
  );
}
