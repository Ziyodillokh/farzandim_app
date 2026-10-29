'use client';

import { MonitorPlay, Printer, Radio } from 'lucide-react';
import Link from 'next/link';

import { useCan } from '@/auth/use-session';
import { DemoBadge } from '@/components/common/demo-badge';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { UZ_MAP_VIEWBOX, UZ_REGION_SHAPES } from '@/data/geo/uz-regions';
import type { Overview, Scope } from '@/data/contracts';
import { regionName } from '@/data/reference/regions';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';

/** Davr matni: "2026/2027 o'quv yili, 1-chorak". */
export function usePeriodText(o: Overview | undefined): string {
  const { t } = useI18n();
  if (!o) return '';
  const { period } = o;
  return period.quarter ? t('filters.quarterLabel', { ay: period.ayLabel, q: period.quarter }) : t('filters.ayLabel', { ay: period.ayLabel });
}

function Silhouette({ focusId }: { focusId: string | null }) {
  return (
    <svg viewBox={UZ_MAP_VIEWBOX} aria-hidden className="pointer-events-none absolute -right-6 top-1/2 hidden h-[135%] -translate-y-1/2 opacity-[0.22] md:block">
      {UZ_REGION_SHAPES.map((r) => (
        <path
          key={r.id}
          d={r.d}
          fillRule="evenodd"
          fill={focusId === r.id ? 'white' : 'transparent'}
          fillOpacity={focusId === r.id ? 0.55 : 0}
          stroke="white"
          strokeOpacity={0.55}
          strokeWidth={1.2}
        />
      ))}
    </svg>
  );
}

/** Bosh sahifa yuqori qismi: sarlavha (h1), davr, qamrov sonlari va amallar. */
export function DashboardHero({ scope, overview }: { scope: Scope; overview: Overview | undefined }) {
  const { t, locale } = useI18n();
  const fmt = useMetricFormat();
  const can = useCan();
  const periodText = usePeriodText(overview);
  const regionTitle = scope.kind === 'REGION' ? regionName(scope.regionId, locale) : null;
  const c = overview?.counts;
  const stats = c
    ? [
        { value: fmt.count(c.covered), label: t('dashboard.hero.statCovered'), hint: t('dashboard.hero.coveredOf', { official: fmt.count(c.official) }) },
        { value: fmt.count(c.schoolsConnected), label: t('dashboard.hero.statSchools'), hint: t('dashboard.hero.schools', { connected: fmt.count(c.schoolsConnected), schools: fmt.count(c.schools) }) },
        {
          value: scope.kind === 'NATIONAL' ? '14' : fmt.count(c.districts),
          label: scope.kind === 'NATIONAL' ? t('dashboard.hero.statRegions') : t('dashboard.hero.statDistricts'),
          hint: scope.kind === 'NATIONAL' ? t('dashboard.hero.districts', { districts: c.districts }) : '',
        },
      ]
    : null;

  return (
    <section className="relative mb-6 overflow-hidden rounded-3xl bg-hero-gradient p-6 text-white shadow-glass-lg ring-1 ring-inset ring-white/10 md:p-8 animate-fade-in">
      <div aria-hidden className="absolute inset-0 bg-[radial-gradient(60%_80%_at_85%_20%,rgba(56,189,248,0.25),transparent)]" />
      <Silhouette focusId={scope.kind === 'REGION' ? scope.regionId : null} />
      <div className="relative flex flex-wrap items-start justify-between gap-6">
        <div className="min-w-0 max-w-2xl">
          <div className="flex flex-wrap items-center gap-2">
            <span className="inline-flex items-center gap-1.5 rounded-full bg-white/12 px-2.5 py-1 text-[0.7rem] font-semibold uppercase tracking-[0.14em] ring-1 ring-inset ring-white/20">
              <Radio className="h-3.5 w-3.5 animate-pulse text-emerald-300" />
              {scope.kind === 'NATIONAL' ? t('dashboard.hero.eyebrow') : t('dashboard.hero.eyebrowRegion')}
            </span>
            <DemoBadge tone="onDark" />
          </div>
          <h1 className="mt-4 font-display text-[1.9rem] font-semibold leading-tight tracking-[-0.02em] md:text-[2.35rem]">
            {regionTitle ? t('dashboard.titleRegion', { region: regionTitle }) : t('dashboard.title')}
          </h1>
          <div className="mt-2 text-[0.95rem] text-white/75">{periodText ? t('dashboard.subtitle', { period: periodText }) : <Skeleton className="h-5 w-72 bg-white/20" />}</div>
          <p className="mt-1 text-xs text-white/55">{t('filters.periodHint')}</p>
        </div>
        <div className="flex flex-wrap items-center gap-2 no-print">
          {can('present.view') && (
            <Button asChild className="bg-white text-brand-900 shadow-lg hover:bg-white/90">
              <Link href="/present">
                <MonitorPlay />
                {t('nav.present')}
              </Link>
            </Button>
          )}
          <Button variant="ghost" className="bg-white/10 text-white ring-1 ring-inset ring-white/20 hover:bg-white/20 hover:text-white" onClick={() => window.print()}>
            <Printer />
            {t('common.print')}
          </Button>
        </div>
      </div>
      <dl className="relative mt-7 grid grid-cols-1 gap-3 sm:grid-cols-3">
        {stats
          ? stats.map((s) => (
              <div key={s.label} className="rounded-2xl bg-white/[0.08] px-4 py-3 ring-1 ring-inset ring-white/15 backdrop-blur-sm">
                <dt className="text-[0.72rem] font-medium uppercase tracking-[0.1em] text-white/60">{s.label}</dt>
                <dd className="mt-1 font-display text-[1.6rem] font-semibold tabular-nums">{s.value}</dd>
                {s.hint && <dd className={cn('mt-0.5 text-xs text-white/60')}>{s.hint}</dd>}
              </div>
            ))
          : [0, 1, 2].map((i) => <Skeleton key={i} className="h-[88px] rounded-2xl bg-white/10" />)}
      </dl>
    </section>
  );
}
