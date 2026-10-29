'use client';

import { TrendingUp } from 'lucide-react';

import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Scope, Wellbeing } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useMetricFormat, useMonthLabel } from '@/lib/format';
import { extremeBy } from './kit/analysis';
import { ChartBlock } from './kit/chart-block';
import { ComparedTrend } from './kit/compared-trend';

/** Y o'qining eng kichik oralig'i: indeks — 6 ball, bulling — 3 p.p. (kichik o'zgarish bo'rttirilmaydi). */
const WELLBEING_SPAN = 6;
const BULLYING_SPAN = 3;

/** Farovonlik indeksi va bulling signali — oxirgi 12 o'quv oyi (hududda — respublika bilan). */
export function TrendsSection({ id, scope, data, national }: { id: string; scope: Scope; data: Wellbeing | undefined; national: Wellbeing | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const monthLabel = useMonthLabel();
  const peakBullying = data ? extremeBy(data.bullyingTrend, (p) => p.value, 'max') : null;
  const lowWellbeing = data ? extremeBy(data.trend, (p) => p.value, 'min') : null;
  return (
    <Section id={id} className="scroll-mt-32" icon={<TrendingUp />} title={t('wellbeing.trends.title')} subtitle={t('wellbeing.trends.subtitle')}>
      {!data ? (
        <Skeleton className="h-[260px] w-full rounded-xl" />
      ) : (
        <div className="grid gap-6 lg:grid-cols-2">
          <ChartBlock
            title={t('metrics.wellbeing.title')}
            caption={lowWellbeing && t('wellbeing.kit.lowest', { label: monthLabel(lowWellbeing.key, true), value: fmt.value('wellbeing', lowWellbeing.value) })}
          >
            <ComparedTrend scope={scope} metric="wellbeing" points={data.trend} nationalPoints={national?.trend} minSpan={WELLBEING_SPAN} />
          </ChartBlock>
          <ChartBlock
            title={t('metrics.bullying.title')}
            caption={peakBullying && t('wellbeing.kit.highest', { label: monthLabel(peakBullying.key, true), value: fmt.value('bullying', peakBullying.value) })}
          >
            <ComparedTrend scope={scope} metric="bullying" points={data.bullyingTrend} nationalPoints={national?.bullyingTrend} minSpan={BULLYING_SPAN} />
          </ChartBlock>
        </div>
      )}
    </Section>
  );
}
