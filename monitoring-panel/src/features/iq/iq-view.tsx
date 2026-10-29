'use client';

import { Map as MapIcon } from 'lucide-react';

import { ScreeningDisclaimer } from '@/components/common/screening-disclaimer';
import { Section } from '@/components/common/section';
import type { MetricKey, Scope } from '@/data/contracts';
import { useIq } from '@/features/filters/use-monitoring';
import { MapPanel } from '@/features/map/map-panel';
import { LearningFooter, QueryError } from '@/features/mastery/kit/layout';
import { useScopeLabels } from '@/features/mastery/kit/scope';
import { useI18n } from '@/i18n';
import { IqAreasSection } from './iq-areas';
import { IqBandsSection } from './iq-bands';
import { IqKpis } from './iq-kpis';
import { IqDomainsSection, IqGenderSection, IqGradeBandsSection, IqTrendSection } from './iq-panels';

const MAP_METRICS: readonly MetricKey[] = ['iqMean', 'iqParticipation', 'iqHigh', 'iqGrowthZone'];
/** Norma tasdiqlanmagan bo'lsa o'rtacha ball xaritada ham ko'rsatilmaydi. */
const MAP_METRICS_BANDS: readonly MetricKey[] = ['iqParticipation', 'iqHigh', 'iqGrowthZone'];

function IqMapSection({ scope, normed }: { scope: Scope; normed: boolean }) {
  const { t } = useI18n();
  const { national, mapTitle } = useScopeLabels(scope);
  return (
    <Section id="iq-map" icon={<MapIcon />} title={mapTitle} subtitle={national ? t('iq.map.sub') : t('iq.map.subDistricts')}>
      <MapPanel key={normed ? 'n' : 'b'} scope={scope} metrics={normed ? MAP_METRICS : MAP_METRICS_BANDS} initial="iqParticipation" />
    </Section>
  );
}

/**
 * IQ va tafakkur: skrining izohi, KPI, daraja taqsimoti (norma bilan), yo'nalishlar,
 * qamrov dinamikasi, xarita, hududlar bo'yicha taqsimot, sinf guruhlari va jins.
 */
export function IqView({ scope }: { scope: Scope }) {
  const query = useIq(scope);
  if (query.isError) return <QueryError error={query.error} onRetry={() => void query.refetch()} />;
  const data = query.data;
  return (
    <div className="space-y-5">
      <ScreeningDisclaimer variant="banner" withIq />
      <IqKpis data={data} />
      <IqBandsSection data={data} />
      <div className="grid gap-5 xl:grid-cols-2">
        <IqDomainsSection scope={scope} data={data} />
        <IqTrendSection scope={scope} data={data} />
      </div>
      <IqMapSection scope={scope} normed={data?.normed ?? true} />
      <IqAreasSection scope={scope} data={data} />
      <div className="grid gap-5 xl:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)]">
        <IqGradeBandsSection data={data} />
        <IqGenderSection data={data} />
      </div>
      <LearningFooter />
    </div>
  );
}
