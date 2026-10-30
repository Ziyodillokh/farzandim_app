'use client';

import { GraduationCap, TrendingUp } from 'lucide-react';

import { TrendChart } from '@/components/charts/trend-chart';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Mastery, Scope } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { GradeLine } from './grade-line';
import { Note } from './kit/layout';
import { gap, pctScale } from './kit/num';
import { useScopeLabels } from './kit/scope';

const CHART_HEIGHT = 240;

/** 1–11-sinflar bo'yicha o'zlashtirish: chiziq, o'rtacha chizig'i va 1→11 o'zgarish. */
export function GradeSection({ data }: { data: Mastery | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const points = (data?.byGrade ?? []).filter((g) => g.value !== null);
  const first = points[0];
  const last = points[points.length - 1];
  const change = first && last && first.grade !== last.grade ? gap(last.value, first.value) : null;
  return (
    <Section id="mastery-grades" icon={<GraduationCap />} title={t('mastery.sections.grades')} subtitle={t('mastery.sections.gradesSub')}>
      {!data ? (
        <Skeleton className="h-[280px] w-full rounded-xl" />
      ) : points.length === 0 ? (
        <Note>{t('common.noData')}</Note>
      ) : (
        <>
          <GradeLine
            points={points.map((g) => ({ key: String(g.grade), label: t('common.gradeShort', { grade: g.grade }), value: g.value }))}
            name={t('metrics.mastery.label')}
            format={(v) => fmt.value('mastery', v)}
            tickFormat={(v) => fmt.pct(v, 0)}
            formatLabel={(label) => t('common.grade', { grade: label })}
            reference={data.overall.value}
            height={CHART_HEIGHT}
          />
          <div className="mt-2 flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
            <Note>{t('mastery.grades.avgLine', { value: fmt.value('mastery', data.overall.value) })}</Note>
            {change !== null && first && last && (
              <Note className="font-semibold text-foreground">{t('mastery.grades.change', { from: first.grade, to: last.grade, value: fmt.delta('mastery', change) })}</Note>
            )}
          </div>
        </>
      )}
    </Section>
  );
}

/** Oxirgi 12 o'quv oyi: doira o'zlashtirishi, hudud doirasida — respublika chizig'i bilan. */
export function TrendSection({ scope, data }: { scope: Scope; data: Mastery | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const { national, scopeName } = useScopeLabels(scope);
  const reference = national || !data ? null : data.national.overall;
  const hasTrend = data ? data.trend.some((p) => p.value !== null) : false;
  return (
    <Section id="mastery-trend" icon={<TrendingUp />} title={t('mastery.sections.trend')} subtitle={t('mastery.sections.trendSub')}>
      {!data ? (
        <Skeleton className="h-[280px] w-full rounded-xl" />
      ) : !hasTrend ? (
        <Note>{t('common.noData')}</Note>
      ) : (
        <TrendChart
          series={[{ key: 'scope', label: scopeName, points: data.trend }]}
          format={(v) => fmt.value('mastery', v)}
          axisFormat={(v) => fmt.pct(v, 0)}
          height={CHART_HEIGHT + 24}
          reference={reference}
          referenceLabel={t('common.nationalAvg')}
          domain={pctScale([...data.trend.map((p) => p.value), reference])?.domain}
        />
      )}
    </Section>
  );
}
