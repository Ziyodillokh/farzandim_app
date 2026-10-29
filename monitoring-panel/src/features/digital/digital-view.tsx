'use client';

import { TrendingUp } from 'lucide-react';
import { useMemo } from 'react';

import { ErrorState } from '@/components/common/error-state';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { MetricKey, Scope } from '@/data/contracts';
import { useDigital } from '@/features/filters/use-monitoring';
import { extremeAllBy } from '@/features/wellbeing/kit/analysis';
import { AreaTableSection } from '@/features/wellbeing/kit/area-table-section';
import { ChartBlock } from '@/features/wellbeing/kit/chart-block';
import { ComparedTrend } from '@/features/wellbeing/kit/compared-trend';
import { PageNav } from '@/features/wellbeing/kit/page-nav';
import { MapSection, NATIONAL_SCOPE, PageFootnote } from '@/features/wellbeing/kit/page-parts';
import { useI18n } from '@/i18n';
import { useMetricFormat, useMonthLabel } from '@/lib/format';
import { ConsentNote, DigitalOverview } from './digital-overview';
import { DigitalGroupsSection } from './groups-section';
import { UsageSection } from './usage-section';

const IDS = {
  overview: 'dg-overview',
  usage: 'dg-usage',
  map: 'dg-map',
  groups: 'dg-groups',
  trend: 'dg-trend',
  areas: 'dg-areas',
} as const;

const DIGITAL_METRICS: readonly MetricKey[] = ['screenTime', 'night', 'schoolMode', 'steps'];
/** Ekran vaqti trendi o'qi kamida 30 daqiqa oraliqda. */
const SCREEN_MIN_SPAN = 30;

/**
 * "Raqamli odatlar": faqat ota-ona roziligi bilan ulangan qurilmalardan,
 * faqat agregat — ekran vaqti, tungi foydalanish, dars rejimi, qadamlar,
 * ilova toifalari, sutkalik profil, kayfiyat, kesimlar, xarita va jadval.
 */
export function DigitalView({ scope }: { scope: Scope }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const monthLabel = useMonthLabel();
  const regionScope = scope.kind === 'REGION';
  const digital = useDigital(scope);
  const national = useDigital(NATIONAL_SCOPE);
  const nationalData = regionScope ? national.data : undefined;
  const data = digital.data;

  const nav = useMemo(
    () => (Object.keys(IDS) as Array<keyof typeof IDS>).map((key) => ({ id: IDS[key], label: t(`digital.nav.${key}`) })),
    [t],
  );

  if (digital.isError) return <ErrorState error={digital.error} onRetry={() => void digital.refetch()} />;

  const peakMonths = data ? extremeAllBy(data.trend, (p) => p.value, 'max') : null;

  return (
    <>
      <PageNav items={nav} label={t('digital.nav.label')} />
      <div className="space-y-5">
        <ConsentNote devices={data?.devices} />
        <DigitalOverview id={IDS.overview} data={data} national={nationalData} />
        <UsageSection id={IDS.usage} data={data} />
        <MapSection id={IDS.map} scope={scope} metrics={DIGITAL_METRICS} initial="screenTime" />
        <DigitalGroupsSection id={IDS.groups} data={data} />
        <Section id={IDS.trend} className="scroll-mt-32" icon={<TrendingUp />} title={t('digital.trend.title')} subtitle={t('digital.trend.subtitle')}>
          {!data ? (
            <Skeleton className="h-[240px] w-full rounded-xl" />
          ) : (
            <ChartBlock
              title={t('metrics.screenTime.title')}
              caption={peakMonths && t('wellbeing.kit.highest', { label: peakMonths.items.map((p) => monthLabel(p.key, true)).join(', '), value: fmt.value('screenTime', peakMonths.value) })}
            >
              <ComparedTrend scope={scope} metric="screenTime" points={data.trend} nationalPoints={nationalData?.trend} minSpan={SCREEN_MIN_SPAN} height={240} />
            </ChartBlock>
          )}
        </Section>
        <AreaTableSection
          id={IDS.areas}
          scope={scope}
          metrics={DIGITAL_METRICS}
          title={regionScope ? t('digital.areas.titleDistrict') : t('digital.areas.title')}
          csvFile={t('digital.areas.csvFile')}
        />
        <PageFootnote>
          <p>
            <b className="text-foreground">{t('metrics.night.title')}:</b> {t('metrics.night.description')}{' '}
            <b className="text-foreground">{t('metrics.schoolMode.title')}:</b> {t('metrics.schoolMode.description')}
          </p>
        </PageFootnote>
      </div>
    </>
  );
}
