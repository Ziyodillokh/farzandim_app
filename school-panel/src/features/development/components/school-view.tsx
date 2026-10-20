'use client';

import { Brain, ClipboardCheck, EyeOff, Lock, UserRoundSearch } from 'lucide-react';
import { useState } from 'react';

import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { StatCard } from '@/components/common/stat-card';
import { Card } from '@/components/ui/card';
import { Progress } from '@/components/ui/progress';
import type { SchoolDevOverview } from '@/data/contracts';
import { ICON_CHIP, TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useDevSchool, useDevTerms } from '../hooks';
import { DomainAverages } from './domain-averages';
import { GradeDistribution } from './grade-distribution';
import { HeatTable } from './heat-table';
import { Participation } from './participation';
import { TermSelect } from './term-select';
import { TermTrend } from './term-trend';

/** Direktor/admin: shaxsiy natijalar yo'q, kichik guruhlar yashirin. */
export function DevPrivacyBanner() {
  const { t } = useI18n();
  return (
    <Card role="region" aria-label={t('development.privacy.title')} className="flex items-start gap-3 p-4 animate-fade-in">
      <span className={cn(ICON_CHIP, 'h-9 w-9 bg-primary/10 text-primary ring-primary/15')}>
        <Lock className="h-4 w-4" />
      </span>
      <div className="min-w-0">
        <p className="text-sm font-semibold">{t('development.privacy.title')}</p>
        <p className="mt-0.5 text-sm text-muted-foreground">{t('development.privacy.text')}</p>
      </div>
    </Card>
  );
}

function CoarseTiles({ overview }: { overview: SchoolDevOverview }) {
  const { t } = useI18n();
  const c = overview.cognitiveCoarse;
  if (!c) return null;
  const items = [
    { key: 'below', label: t('development.charts.coarseBelow'), value: c.below },
    { key: 'within', label: t('development.charts.coarseWithin'), value: c.within },
    { key: 'above', label: t('development.charts.coarseAbove'), value: c.above },
  ];
  return (
    <Card className="p-5">
      <p className="text-[0.95rem] font-semibold">{t('development.charts.coarseTitle')}</p>
      <p className="mt-0.5 text-sm text-muted-foreground">{t('development.iqShort')}</p>
      <ul className="mt-4 grid gap-2 sm:grid-cols-3">
        {items.map((it) => (
          <li key={it.key} className={cn(TILE, 'px-3.5 py-3')}>
            <p className="text-xs text-muted-foreground">{it.label}</p>
            <p className="mt-1 flex items-center gap-1.5 font-display text-xl font-semibold tabular-nums">
              {it.value ?? <EyeOff className="h-4 w-4 text-muted-foreground" aria-label={t('development.charts.hiddenValue')} />}
            </p>
          </li>
        ))}
      </ul>
    </Card>
  );
}

/** Maktab kesimi — psixolog (to'liq) va direktor/admin (k-anonim). */
export function SchoolView() {
  const { t, formatNumber } = useI18n();
  const [termKey, setTermKey] = useState<string | undefined>();
  const terms = useDevTerms();
  const school = useDevSchool(termKey);
  const o = school.data;
  const loading = school.isLoading;
  const reasoning = o?.domainAverages.find((d) => d.domain === 'REASONING');

  if (school.error) return <ErrorState error={school.error} onRetry={() => void school.refetch()} />;
  if (!loading && o && o.trend.length === 0) {
    return (
      <Card>
        <EmptyState icon={<Brain />} title={t('development.empty.noResults')} description={t('development.empty.noResultsHint')} />
      </Card>
    );
  }
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <TermSelect value={o?.termKey ?? termKey} options={terms.data} onChange={setTermKey} />
        {o?.suppressed && (
          <p className="flex items-center gap-1.5 text-xs text-muted-foreground">
            <EyeOff className="h-3.5 w-3.5" />
            {t('development.empty.hiddenHint')}
          </p>
        )}
      </div>
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        <StatCard
          icon={<ClipboardCheck />}
          label={t('development.stats.participation')}
          value={`${o?.participation.rate ?? 0}%`}
          hint={t('development.stats.participationHint', { assessed: formatNumber(o?.participation.assessed ?? 0), eligible: formatNumber(o?.participation.eligible ?? 0) })}
          loading={loading}
          footer={!loading && <Progress value={o?.participation.rate ?? 0} />}
        />
        <StatCard
          icon={<Brain />}
          tone="info"
          label={t('development.stats.cognitive')}
          value={reasoning?.index ?? '—'}
          hint={t('development.stats.cognitiveHint')}
          loading={loading}
        />
        <StatCard
          icon={<UserRoundSearch />}
          tone="primary"
          label={t('development.stats.attention')}
          value={o?.attentionCount ?? '—'}
          hint={t('development.stats.attentionHint')}
          loading={loading}
        />
      </div>
      <div className="grid gap-6 xl:grid-cols-3">
        <div className="xl:col-span-2">
          <DomainAverages rows={o?.domainAverages} loading={loading} />
        </div>
        <Participation overview={o} loading={loading} />
      </div>
      <div className="grid gap-6 xl:grid-cols-2">
        <GradeDistribution overview={o} loading={loading} />
        <TermTrend overview={o} loading={loading} />
      </div>
      {o && <CoarseTiles overview={o} />}
      <HeatTable overview={o} loading={loading} />
    </div>
  );
}
