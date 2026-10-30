'use client';

import dynamic from 'next/dynamic';
import type { ReactNode } from 'react';

import { DeltaChip } from '@/components/charts/delta-chip';
import { Sparkline } from '@/components/charts/sparkline';
import { DemoBadge } from '@/components/common/demo-badge';
import { ParvozWordmark } from '@/components/layout/parvoz-wordmark';
import { UzMap } from '@/components/map/uz-map';
import { UZ_MAP_VIEWBOX, UZ_REGION_SHAPES } from '@/data/geo/uz-regions';
import { Skeleton } from '@/components/ui/skeleton';
import type { MetricKey, Scope } from '@/data/contracts';
import { METRICS } from '@/data/mock/model/metrics';
import { PROBLEM_METRICS } from '@/data/mock/services/overview';
import { regionName } from '@/data/reference/regions';
import { usePeriodText } from '@/features/dashboard/hero';
import { IQ_BAND_COLORS } from '@/lib/color-scale';
import { useAreaMatrix, useAreaMetric, useInsights, useInterests, useIq, useMastery, useOverview } from '@/features/filters/use-monitoring';
import { InsightList } from '@/features/insights/insight-list';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';

/** Tumanlar geometriyasi (~80 KB) faqat hudud doirasida kerak — alohida bo'lak sifatida yuklanadi. */
const DistrictMap = dynamic(() => import('@/components/map/district-map').then((m) => m.DistrictMap), {
  ssr: false,
  loading: () => <Skeleton className="h-[420px] w-full rounded-2xl" />,
});

type ProblemKey = 'bullying' | 'anxiety' | 'support' | 'sleep' | 'safetyGap' | 'chronic' | 'night';

function useScopeTitle(scope: Scope): string {
  const { t, locale } = useI18n();
  return scope.kind === 'NATIONAL' ? t('shell.scopeNational') : regionName(scope.regionId, locale);
}

/** Slayd ramkasi: yuqorida doira va davr, katta sarlavha (h2). */
function SlideFrame({ scope, title, children }: { scope: Scope; title: string; children: ReactNode }) {
  const scopeTitle = useScopeTitle(scope);
  const periodText = usePeriodText(useOverview(scope).data);
  return (
    <div className="flex h-full flex-col">
      <p className="text-[0.8rem] font-semibold uppercase tracking-[0.18em] text-cyan-300/80">
        {scopeTitle}
        {periodText && <span className="text-white/45"> · {periodText}</span>}
      </p>
      <h2 className="mt-1.5 font-display text-[clamp(1.5rem,2.6vw,2.5rem)] font-semibold leading-tight tracking-[-0.02em]">{title}</h2>
      <div className="mt-6 min-h-0 flex-1">{children}</div>
    </div>
  );
}

const Loading = () => <Skeleton className="h-full min-h-[320px] w-full rounded-3xl bg-white/[0.06]" />;

function Panel({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn('rounded-3xl bg-white/[0.05] p-5 ring-1 ring-inset ring-white/10 backdrop-blur-sm', className)}>{children}</div>;
}

function Bar({ label, value, share, color, emphasis }: { label: string; value: string; share: number; color: string; emphasis?: boolean }) {
  return (
    <div>
      <div className="flex items-baseline justify-between gap-3">
        <span className={cn('truncate text-[clamp(0.85rem,1.1vw,1.05rem)]', emphasis ? 'font-semibold text-white' : 'text-white/80')}>{label}</span>
        <span className="font-display text-[clamp(0.9rem,1.2vw,1.15rem)] font-semibold tabular-nums">{value}</span>
      </div>
      <div className="mt-1.5 h-2.5 overflow-hidden rounded-full bg-white/[0.08]">
        <div className="h-full rounded-full transition-[width] duration-700" style={{ width: `${Math.max(2, Math.min(100, share))}%`, background: color }} />
      </div>
    </div>
  );
}

export function TitleSlide({ scope }: { scope: Scope }) {
  const { t, formatDate } = useI18n();
  const fmt = useMetricFormat();
  const scopeTitle = useScopeTitle(scope);
  const o = useOverview(scope).data;
  const periodText = usePeriodText(o);
  const stats = o
    ? [
        { value: fmt.count(o.counts.covered), label: t('dashboard.hero.statCovered') },
        { value: fmt.count(o.counts.schoolsConnected), label: t('dashboard.hero.statSchools') },
        { value: scope.kind === 'NATIONAL' ? '14' : fmt.count(o.counts.districts), label: scope.kind === 'NATIONAL' ? t('dashboard.hero.statRegions') : t('dashboard.hero.statDistricts') },
      ]
    : [];
  return (
    <div className="relative flex h-full flex-col items-start justify-center">
      <svg viewBox={UZ_MAP_VIEWBOX} aria-hidden className="pointer-events-none absolute -right-4 top-1/2 hidden w-[52%] -translate-y-1/2 lg:block">
        <defs>
          <linearGradient id="present-uz" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="hsl(214 92% 60%)" stopOpacity="0.32" />
            <stop offset="100%" stopColor="hsl(186 90% 50%)" stopOpacity="0.12" />
          </linearGradient>
        </defs>
        {UZ_REGION_SHAPES.map((r) => (
          <path key={r.id} d={r.d} fillRule="evenodd" fill={scope.kind === 'REGION' && scope.regionId === r.id ? 'hsl(186 90% 55% / 0.55)' : 'url(#present-uz)'} stroke="hsl(195 100% 75% / 0.45)" strokeWidth={1.2} />
        ))}
      </svg>
      <ParvozWordmark size="lg" sub="MONITORING" tone="onDark" />
      <h2 className="mt-10 max-w-4xl font-display text-[clamp(2.2rem,5vw,4.6rem)] font-semibold leading-[1.05] tracking-[-0.03em]">{t('present.slides.heading')}</h2>
      <p className="mt-4 text-[clamp(1.1rem,1.8vw,1.6rem)] text-white/80">{scopeTitle}</p>
      <p className="mt-1 text-[clamp(0.9rem,1.2vw,1.1rem)] text-white/55">{periodText}</p>
      <dl className="mt-10 grid w-full max-w-5xl grid-cols-1 gap-4 sm:grid-cols-3">
        {stats.map((s) => (
          <div key={s.label} className="rounded-3xl bg-white/[0.06] px-6 py-5 ring-1 ring-inset ring-white/12">
            <dt className="text-xs font-semibold uppercase tracking-[0.14em] text-white/55">{s.label}</dt>
            <dd className="mt-2 font-display text-[clamp(1.8rem,3.4vw,3.2rem)] font-semibold tabular-nums">{s.value}</dd>
          </div>
        ))}
      </dl>
      <div className="mt-8 flex flex-wrap items-center gap-3 text-sm text-white/50">
        <DemoBadge tone="onDark" />
        {o && <span>{t('present.slides.asOf', { date: formatDate(o.period.asOf, 'd MMMM yyyy') })}</span>}
      </div>
    </div>
  );
}

export function KpisSlide({ scope }: { scope: Scope }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const o = useOverview(scope).data;
  return (
    <SlideFrame scope={scope} title={t('present.slides.kpis')}>
      {!o ? (
        <Loading />
      ) : (
        <div className="grid h-full auto-rows-fr grid-cols-2 gap-4 lg:grid-cols-4">
          {o.kpis.map((k) => (
            <Panel key={k.key} className="flex flex-col justify-between">
              <div>
                <p className="text-[clamp(0.8rem,1vw,0.95rem)] font-medium text-white/65">{t(`metrics.${k.key}.label`)}</p>
                <p className="mt-2 font-display text-[clamp(1.8rem,3.2vw,3.1rem)] font-semibold leading-none tabular-nums">{fmt.value(k.key, k.value)}</p>
                <div className="mt-3 flex flex-wrap items-center gap-2">
                  <DeltaChip metric={k.key} delta={k.delta} />
                  {k.national !== undefined && k.national !== null && (
                    <span className="text-xs text-white/50">{t('dashboard.vsNationalShort', { value: fmt.value(k.key, k.national) })}</span>
                  )}
                </div>
              </div>
              <Sparkline series={k.series} height={76} color="hsl(190 92% 55%)" className="mt-4" />
            </Panel>
          ))}
        </div>
      )}
    </SlideFrame>
  );
}

export function MapSlide({ scope, metric }: { scope: Scope; metric: MetricKey }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const { data } = useAreaMetric(metric, scope);
  const def = METRICS[metric];
  const national = scope.kind === 'NATIONAL';
  const title = t(national ? 'present.slides.map' : 'present.slides.mapDistricts', { metric: t(`metrics.${metric}.title`) });
  const format = (v: number | null) => fmt.value(metric, v);
  const ranked = (data?.areas ?? []).filter((a) => a.rank !== null).sort((a, b) => (a.rank as number) - (b.rank as number));
  const list = (items: typeof ranked, tone: 'best' | 'attention') => (
    <ol className="space-y-2">
      {items.map((a) => (
        <li key={a.id} className="flex items-center justify-between gap-3 text-[clamp(0.85rem,1.1vw,1.05rem)]">
          <span className="flex min-w-0 items-center gap-2.5">
            <span className={cn('flex h-7 w-7 shrink-0 items-center justify-center rounded-lg font-display text-xs font-semibold', tone === 'best' ? 'bg-cyan-400/15 text-cyan-200' : 'bg-amber-400/15 text-amber-200')}>{a.rank}</span>
            <span className="truncate">{areaName(a.id, { short: true, fallback: a.name })}</span>
          </span>
          <span className="font-semibold tabular-nums">{format(a.value)}</span>
        </li>
      ))}
    </ol>
  );
  return (
    <SlideFrame scope={scope} title={title}>
      {!data ? (
        <Loading />
      ) : (
        <div className="grid h-full items-center gap-8 lg:grid-cols-[minmax(0,1.7fr)_minmax(0,1fr)]">
          <div className="mx-auto w-full max-w-[min(100%,calc((100vh-230px)*1.5))]">
            {national ? (
              <UzMap data={data.areas} center={data.scopeValue.value} better={def.better} format={format} labels="value" ariaLabel={title} />
            ) : (
              <DistrictMap regionId={scope.regionId} data={data.areas} center={data.scopeValue.value} better={def.better} format={format} ariaLabel={title} />
            )}
          </div>
          <div className="space-y-4">
            <Panel>
              <p className="text-sm text-white/60">{national ? t('present.slides.scopeValueNational') : t('present.slides.scopeValueRegion')}</p>
              <p className="mt-1 flex flex-wrap items-baseline gap-3">
                <span className="font-display text-[clamp(2rem,3.6vw,3.4rem)] font-semibold leading-none tabular-nums">{format(data.scopeValue.value)}</span>
                <DeltaChip metric={metric} delta={data.scopeValue.delta} />
              </p>
            </Panel>
            {ranked.length >= 6 && (
              <>
                <Panel>
                  <p className="mb-3 text-xs font-semibold uppercase tracking-[0.14em] text-cyan-300/80">{t('present.slides.best')}</p>
                  {list(ranked.slice(0, 3), 'best')}
                </Panel>
                <Panel>
                  <p className="mb-3 text-xs font-semibold uppercase tracking-[0.14em] text-amber-300/80">{t('present.slides.attention')}</p>
                  {list(ranked.slice(-3).reverse(), 'attention')}
                </Panel>
              </>
            )}
          </div>
        </div>
      )}
    </SlideFrame>
  );
}

export function SubjectsSlide({ scope }: { scope: Scope }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const { data } = useMastery(scope);
  const sorted = [...(data?.bySubject ?? [])].filter((s) => s.value !== null).sort((a, b) => (b.value as number) - (a.value as number));
  const top = sorted[0];
  const low = sorted[sorted.length - 1];
  return (
    <SlideFrame scope={scope} title={t('present.slides.subjects')}>
      {!data || !top || !low ? (
        <Loading />
      ) : (
        <div className="grid h-full items-center gap-8 lg:grid-cols-[minmax(0,1.6fr)_minmax(0,1fr)]">
          <Panel className="space-y-3.5">
            {sorted.map((s) => (
              <Bar
                key={s.subject}
                label={t(`enums.subject.${s.subject}`)}
                value={fmt.value('mastery', s.value)}
                share={s.value ?? 0}
                emphasis={s === top || s === low}
                color={s === low ? 'hsl(36 92% 56%)' : s === top ? 'hsl(186 90% 50%)' : 'hsl(214 90% 60%)'}
              />
            ))}
          </Panel>
          <div className="space-y-4">
            {[
              { label: t('present.slides.strongest'), s: top, tone: 'text-cyan-200' },
              { label: t('present.slides.weakest'), s: low, tone: 'text-amber-200' },
            ].map(({ label, s, tone }) => (
              <Panel key={label}>
                <p className="text-sm text-white/60">{label}</p>
                <p className={cn('mt-1 font-display text-[clamp(1.4rem,2.4vw,2.2rem)] font-semibold', tone)}>{t(`enums.subject.${s.subject}`)}</p>
                <p className="mt-1 flex items-center gap-2 text-lg tabular-nums">
                  {fmt.value('mastery', s.value)} <DeltaChip metric="mastery" delta={s.delta} />
                </p>
              </Panel>
            ))}
          </div>
        </div>
      )}
    </SlideFrame>
  );
}

export function IqInterestsSlide({ scope }: { scope: Scope }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const iq = useIq(scope).data;
  const interests = useInterests(scope).data;
  return (
    <SlideFrame scope={scope} title={t('present.slides.iqInterests')}>
      {!iq || !interests ? (
        <Loading />
      ) : (
        <div className="grid h-full items-start gap-6 lg:grid-cols-2">
          <Panel>
            <p className="text-xs font-semibold uppercase tracking-[0.14em] text-cyan-300/80">{t('present.slides.iqBands')}</p>
            <p className="mt-1 text-sm text-white/60">{t('present.slides.iqMeta', { value: fmt.value('iqParticipation', iq.participation.value), count: fmt.count(iq.participants) })}</p>
            <div className="mt-5 flex h-12 overflow-hidden rounded-2xl ring-1 ring-inset ring-white/10">
              {iq.bands.map((b) => (
                <div key={b.key} style={{ width: `${b.share}%`, background: IQ_BAND_COLORS[b.key] }} title={t(`enums.iqBand.${b.key}`)} />
              ))}
            </div>
            <ul className="mt-5 grid gap-x-6 gap-y-2.5 sm:grid-cols-2">
              {iq.bands.map((b) => (
                <li key={b.key} className="flex items-center justify-between gap-3 text-[clamp(0.85rem,1.05vw,1rem)]">
                  <span className="flex items-center gap-2">
                    <span className="h-3 w-3 rounded-full" style={{ background: IQ_BAND_COLORS[b.key] }} />
                    {t(`enums.iqBand.${b.key}`)}
                  </span>
                  <span className="font-semibold tabular-nums">{fmt.pct(b.share)}</span>
                </li>
              ))}
            </ul>
            <p className="mt-5 text-xs leading-relaxed text-white/45">{t('common.screening.notIq')}</p>
          </Panel>
          <Panel className="space-y-6">
            <div>
              <p className="mb-3 text-xs font-semibold uppercase tracking-[0.14em] text-cyan-300/80">{t('present.slides.topSubjects')}</p>
              <div className="space-y-3">
                {interests.subjects.flatMap((s) => (s.share === null ? [] : [{ key: s.key, share: s.share }])).slice(0, 5).map((s) => (
                  <Bar key={s.key} label={t(`enums.subject.${s.key}`)} value={fmt.pct(s.share)} share={s.share} color="hsl(214 90% 60%)" />
                ))}
              </div>
            </div>
            <div>
              <p className="mb-3 text-xs font-semibold uppercase tracking-[0.14em] text-cyan-300/80">{t('present.slides.careerFields')}</p>
              <div className="space-y-3">
                {interests.careerFields.slice(0, 4).map((f) => (
                  <Bar key={f.key} label={t(`enums.careerField.${f.key}`)} value={fmt.pct(f.share)} share={f.share * 3} color="hsl(186 90% 50%)" />
                ))}
              </div>
            </div>
          </Panel>
        </div>
      )}
    </SlideFrame>
  );
}

export function ProblemsSlide({ scope }: { scope: Scope }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const { data } = useAreaMatrix(PROBLEM_METRICS, scope);
  return (
    <SlideFrame scope={scope} title={t('present.slides.problems')}>
      {!data ? (
        <Loading />
      ) : (
        <div className="flex h-full flex-col">
          <div className="grid flex-1 auto-rows-fr grid-cols-2 gap-4 lg:grid-cols-4">
            {PROBLEM_METRICS.map((k) => {
              const s = data.scope[k];
              const worst = [...data.rows].sort((a, b) => (b.values[k]?.value ?? -1) - (a.values[k]?.value ?? -1))[0];
              return (
                <Panel key={k} className="flex flex-col justify-between">
                  <div>
                    <p className="text-[clamp(0.85rem,1.05vw,1rem)] font-medium text-white/70">{t(`enums.problem.${k as ProblemKey}`)}</p>
                    <p className="mt-2 font-display text-[clamp(1.8rem,3vw,2.9rem)] font-semibold leading-none tabular-nums">{fmt.value(k, s?.value)}</p>
                    <div className="mt-3">
                      <DeltaChip metric={k} delta={s?.delta} />
                    </div>
                  </div>
                  {worst && (
                    <p className="mt-4 text-xs text-amber-200/80">
                      {t('present.slides.mostAffected', { area: areaName(worst.id, { short: true, fallback: worst.name }), value: fmt.value(k, worst.values[k]?.value) })}
                    </p>
                  )}
                </Panel>
              );
            })}
          </div>
          <p className="mt-4 text-xs text-white/45">
            <b>{t('common.screening.title')}.</b> {t('common.screening.text')}
          </p>
        </div>
      )}
    </SlideFrame>
  );
}

export function InsightsSlide({ scope }: { scope: Scope }) {
  const { t } = useI18n();
  const { data } = useInsights(scope);
  return (
    <SlideFrame scope={scope} title={t('present.slides.insights')}>
      {!data ? (
        <Loading />
      ) : (
        <InsightList
          insights={data}
          limit={8}
          className="grid gap-4 space-y-0 lg:grid-cols-2 [&_a]:p-5 [&_span.block]:text-[clamp(0.95rem,1.25vw,1.2rem)] [&_span.block]:leading-relaxed"
        />
      )}
    </SlideFrame>
  );
}
