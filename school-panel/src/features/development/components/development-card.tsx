'use client';

import { ArrowRight, Sprout } from 'lucide-react';
import Link from 'next/link';
import type { ReactNode } from 'react';

import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import type { DevDomain, DevelopmentSummary } from '@/data/contracts';
import { TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn, percent } from '@/lib/utils';
import { domainKey, formatTerm } from '../lib/domains';

function Number_({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className={cn(TILE, 'px-3 py-2.5')}>
      <p className="truncate text-xs text-muted-foreground">{label}</p>
      <p className="mt-0.5 font-display text-xl font-semibold tabular-nums">{value}</p>
    </div>
  );
}

/** Mini soha ustunlari: indeks 0..100, 50 — me'yor belgisi. */
function MiniBars({ domains }: { domains: Array<{ domain: DevDomain; index: number | null }> }) {
  const { t } = useI18n();
  const shown = domains.filter((d) => d.index !== null);
  if (shown.length === 0) return null;
  return (
    <ul className="space-y-2">
      {shown.map((d) => (
        <li key={d.domain} className="flex items-center gap-3 text-xs">
          <span className="w-28 shrink-0 truncate text-muted-foreground">{t(domainKey(d.domain))}</span>
          <span className="relative h-1.5 flex-1 overflow-hidden rounded-full bg-primary/10" aria-hidden>
            <span className="absolute inset-y-0 left-0 rounded-full bg-primary" style={{ width: `${d.index ?? 0}%` }} />
            <span className="absolute inset-y-0 left-1/2 w-px bg-foreground/30" />
          </span>
          <span className="w-7 text-right font-semibold tabular-nums">{d.index}</span>
        </li>
      ))}
    </ul>
  );
}

function Numbers({ summary }: { summary: DevelopmentSummary }) {
  const { t } = useI18n();
  switch (summary.mode) {
    case 'AGGREGATE':
      return (
        <div className="grid grid-cols-2 gap-2">
          <Number_ label={t('development.stats.participation')} value={`${summary.participation}%`} />
          <Number_ label={t('development.term.label')} value={<span className="text-sm">{formatTerm(summary.termKey, t)}</span>} />
        </div>
      );
    case 'CLASS':
      return (
        <div className="grid grid-cols-2 gap-2">
          <Number_ label={summary.className} value={`${percent(summary.assessed, summary.total)}%`} />
          <Number_ label={t('development.stats.assessed')} value={`${summary.assessed}/${summary.total}`} />
        </div>
      );
    case 'PSYCHOLOGIST':
      return (
        <div className="grid grid-cols-3 gap-2">
          <Number_ label={t('development.card.activeAssignments')} value={summary.activeAssignments} />
          <Number_ label={t('development.card.completedWeek')} value={summary.completedThisWeek} />
          <Number_ label={t('development.card.attention')} value={summary.attention} />
        </div>
      );
  }
}

/** Bosh sahifa: rivojlanish xulosasi (direktor — umumlashgan, sinf rahbari — sinf, psixolog — ish holati). */
export function DevelopmentCard({ summary }: { summary: DevelopmentSummary }) {
  const { t } = useI18n();
  return (
    <SectionCard
      title={t('development.card.title')}
      description={t('development.indexScale')}
      icon={<Sprout />}
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/development">
            {t('development.card.open')}
            <ArrowRight />
          </Link>
        </Button>
      }
    >
      <div className="space-y-4">
        <Numbers summary={summary} />
        <MiniBars domains={summary.domains} />
      </div>
    </SectionCard>
  );
}
