'use client';

import { CalendarCheck2, HeartHandshake, Smartphone } from 'lucide-react';
import { useRouter } from 'next/navigation';

import { useCan } from '@/auth/use-session';
import { DeltaChip } from '@/components/charts/delta-chip';
import { Donut } from '@/components/charts/donut';
import { HeatTable } from '@/components/charts/heat-table';
import { ShareBars } from '@/components/charts/share-bars';
import { TrendChart } from '@/components/charts/trend-chart';
import { ScreeningDisclaimer } from '@/components/common/screening-disclaimer';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { MetricKey, Scope, Stat } from '@/data/contracts';
import { PROBLEM_METRICS } from '@/data/mock/services/overview';
import type { Level } from '@/data/reference/domains';
import { useAreaMatrix, useAttendance, useDigital, useWellbeing } from '@/features/filters/use-monitoring';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';

const LEVEL_TONE: Record<Level, string> = {
  GOOD: 'bg-emerald-500/12 text-emerald-700 dark:text-emerald-300',
  MIDDLE: 'bg-sky-500/12 text-sky-700 dark:text-sky-300',
  LOW: 'bg-amber-500/15 text-amber-700 dark:text-amber-300',
};

function SignalStat({ metric, stat, label }: { metric: MetricKey; stat: Stat; label: string }) {
  const fmt = useMetricFormat();
  return (
    <div className="rounded-xl bg-primary/[0.05] px-3 py-2.5 ring-1 ring-inset ring-border/50 dark:bg-white/[0.03]">
      <p className="text-[0.7rem] text-muted-foreground">{label}</p>
      <div className="mt-0.5 flex flex-wrap items-baseline gap-2">
        <span className="font-display text-lg font-semibold tabular-nums">{fmt.value(metric, stat.value)}</span>
        <DeltaChip metric={metric} delta={stat.delta} />
      </div>
    </div>
  );
}

type ProblemKey = 'bullying' | 'anxiety' | 'support' | 'sleep' | 'safetyGap' | 'chronic' | 'night';

/** Hududlar (yoki tumanlar) × muammo signallari — qaysi hududda nima ko'proq. */
function ProblemsHeat({ scope }: { scope: Scope }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const router = useRouter();
  const can = useCan();
  const { data } = useAreaMatrix(PROBLEM_METRICS, scope);
  const national = scope.kind === 'NATIONAL';
  const clickable = national && can('regions.view');
  return (
    <div>
      <p className="mb-2 text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-muted-foreground">
        {national ? t('dashboard.problemsByRegion') : t('dashboard.problemsByDistrict')}
      </p>
      {!data ? (
        <Skeleton className="h-[440px] w-full rounded-xl" />
      ) : (
        <HeatTable
          columns={PROBLEM_METRICS.map((k) => ({ key: k, label: t(`enums.problem.${k as ProblemKey}`), better: 'down' as const }))}
          rows={data.rows.map((r) => ({
            id: r.id,
            label: areaName(r.id, { short: true, fallback: r.name }),
            values: Object.fromEntries(PROBLEM_METRICS.map((k) => [k, r.values[k]?.value ?? null])),
          }))}
          format={(v) => (v === null ? '—' : fmt.num(v, 1))}
          firstHeader={national ? t('nav.regions') : t('common.districtsTitle')}
          onRowClick={clickable ? (id) => router.push(`/regions/view?id=${id}`) : undefined}
          minWidth={600}
        />
      )}
      <p className="mt-2 text-[0.7rem] text-muted-foreground">{clickable ? t('dashboard.problemsHint') : t('dashboard.problemsHintDistrict')}</p>
    </div>
  );
}

export function WellbeingSection({ scope }: { scope: Scope }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const { data } = useWellbeing(scope);
  return (
    <Section id="sec-wellbeing" icon={<HeartHandshake />} title={t('dashboard.sections.wellbeing')} subtitle={t('dashboard.wellbeingSub')} href="/wellbeing" hrefLabel={t('dashboard.openSection')}>
      {!data ? (
        <Skeleton className="h-[560px] w-full rounded-xl" />
      ) : (
        <div className="space-y-5">
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6">
            <SignalStat metric="wellbeing" stat={data.index} label={t('metrics.wellbeing.label')} />
            <SignalStat metric="bullying" stat={data.bullying} label={t('metrics.bullying.label')} />
            <SignalStat metric="anxiety" stat={data.anxiety} label={t('metrics.anxiety.label')} />
            <SignalStat metric="support" stat={data.support} label={t('enums.problem.support')} />
            <SignalStat metric="sleep" stat={data.sleep} label={t('metrics.sleep.label')} />
            <SignalStat metric="careRequests" stat={data.careRequests} label={t('dashboard.carePer1000')} />
          </div>
          <div className="grid gap-6 xl:grid-cols-[minmax(0,1.75fr)_minmax(0,1fr)]">
            <ProblemsHeat scope={scope} />
            <div className="space-y-6">
              <div>
                <p className="mb-2 text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-muted-foreground">{t('dashboard.wellbeingTopics')}</p>
                <ul className="space-y-2">
                  {data.topics.map((tp) => (
                    <li key={tp.topic} className="flex items-center justify-between gap-3 text-[0.82rem]">
                      <span className="min-w-0 truncate">{t(`enums.wellbeingTopic.${tp.topic}`)}</span>
                      <span className="flex shrink-0 items-center gap-2">
                        <span className="font-semibold tabular-nums">{tp.score ?? '—'}</span>
                        {tp.level && <span className={cn('rounded-full px-2 py-0.5 text-[0.66rem] font-semibold', LEVEL_TONE[tp.level])}>{t(`enums.level.${tp.level}`)}</span>}
                      </span>
                    </li>
                  ))}
                </ul>
              </div>
              <div>
                <p className="mb-2 text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-muted-foreground">{t('dashboard.careTopics')}</p>
                <ShareBars rows={data.careTopics.slice(0, 5).map((c) => ({ key: c.key, label: t(`enums.careTopic.${c.key}`), share: c.share }))} barClassName="bg-gradient-to-r from-sky-500 to-cyan-400" />
                <p className="mt-2 text-[0.72rem] text-muted-foreground">
                  {t('dashboard.careRate', { value: fmt.num(data.careRequests.value ?? 0, 1), urgent: fmt.pct(data.urgentShare) })}
                </p>
              </div>
            </div>
          </div>
          <ScreeningDisclaimer />
        </div>
      )}
    </Section>
  );
}

export function AttendanceSection({ scope }: { scope: Scope }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const { data } = useAttendance(scope);
  return (
    <Section id="sec-attendance" icon={<CalendarCheck2 />} title={t('dashboard.sections.attendance')} subtitle={t('dashboard.attendanceSub')} href="/attendance" hrefLabel={t('dashboard.openSection')}>
      {!data ? (
        <Skeleton className="h-[300px] w-full rounded-xl" />
      ) : (
        <div className="space-y-4">
          <div className="grid grid-cols-3 gap-3">
            <SignalStat metric="attendance" stat={data.rate} label={t('metrics.attendance.label')} />
            <SignalStat metric="late" stat={data.late} label={t('metrics.late.label')} />
            <SignalStat metric="chronic" stat={data.chronic} label={t('metrics.chronic.label')} />
          </div>
          <TrendChart series={[{ key: 'rate', label: t('metrics.attendance.label'), points: data.byMonth }]} format={(v) => fmt.value('attendance', v)} height={200} />
        </div>
      )}
    </Section>
  );
}

export function DigitalSection({ scope }: { scope: Scope }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const { data } = useDigital(scope);
  return (
    <Section id="sec-digital" icon={<Smartphone />} title={t('dashboard.sections.digital')} subtitle={t('dashboard.digitalSub')} href="/digital" hrefLabel={t('dashboard.openSection')}>
      {!data ? (
        <Skeleton className="h-[300px] w-full rounded-xl" />
      ) : (
        <div className="space-y-4">
          <div className="grid grid-cols-3 gap-3">
            <SignalStat metric="screenTime" stat={data.screenTime} label={t('metrics.screenTime.label')} />
            <SignalStat metric="night" stat={data.night} label={t('metrics.night.label')} />
            <SignalStat metric="schoolMode" stat={data.schoolMode} label={t('metrics.schoolMode.label')} />
          </div>
          <Donut
            size={150}
            thickness={20}
            slices={data.categories.map((c) => ({ key: c.key, label: t(`enums.appCategory.${c.key}`), value: c.share }))}
            centerValue={fmt.value('screenTime', data.screenTime.value)}
            centerLabel={t('common.units.perDay')}
          />
        </div>
      )}
    </Section>
  );
}
